import 'dart:async';

import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/orders/domain/repositories/pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_apply_result.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_backoff_policy.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_local_reconciler.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_status.dart';

/// Drena la cola FIFO `pending_op` hacia el backend remoto (COMA-008).
///
/// Reglas (ADR-0008 + offline-first.md):
/// - FIFO estricto por venue, orden por id autoincremental (ACID-7). Un fallo
///   recuperable detiene el venue (head-of-line) hasta el próximo backoff;
///   un rechazo permanente va a dead-letter y la cola sigue.
/// - Backoff exponencial `2^attempts` s con cap 5 min ([SyncBackoffPolicy]).
/// - `attempts > [degradedThreshold]` → estado [SyncHealth.degraded] observable
///   por la UI, sin detener la cola.
/// - Al éxito adopta los `updated_at` del servidor (LWW) y borra la op.
///
/// Disparadores del drenaje: cambios en la cola ([PendingOpQueue.watchPendingCount]),
/// cambios de sesión ([OrderRemoteGateway.readyChanges]) y el timer de backoff.
/// No se usa detección de conectividad: el primer intento fallido ya programa
/// el reintento, y encolar una op nueva con red de vuelta drena todo lo previo.
///
/// La UI nunca se bloquea: el servicio vive fuera del árbol de widgets y toda
/// su E/S es asíncrona (RNF-PERF-002).
class SyncService {
  SyncService({
    required PendingOpQueue queue,
    required OrderRemoteGateway gateway,
    required SyncLocalReconciler reconciler,
    SyncBackoffPolicy backoffPolicy = const SyncBackoffPolicy(),
    Future<void> Function(Duration delay)? wait,
    this.degradedThreshold = 10,
  }) : _queue = queue,
       _gateway = gateway,
       _reconciler = reconciler,
       _backoffPolicy = backoffPolicy,
       _wait = wait ?? ((delay) => Future<void>.delayed(delay));

  static const _tag = 'SyncService';

  final PendingOpQueue _queue;
  final OrderRemoteGateway _gateway;
  final SyncLocalReconciler _reconciler;
  final SyncBackoffPolicy _backoffPolicy;

  /// Espera inyectable (tests la reemplazan para controlar el tiempo).
  final Future<void> Function(Duration delay) _wait;

  /// Umbral de reintentos sobre el cual se notifica "sync degradada".
  final int degradedThreshold;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.initial;

  StreamSubscription<int>? _queueSub;
  StreamSubscription<bool>? _readySub;
  bool _draining = false;
  bool _dirty = false;
  bool _retryScheduled = false;
  bool _disposed = false;

  /// Estado actual del sync (último valor emitido por [statusStream]).
  SyncStatus get status => _status;

  /// Stream observable del estado del sync (banner de la UI).
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Comienza a escuchar la cola y la sesión, y dispara un primer drenaje.
  void start() {
    _queueSub = _queue.watchPendingCount().listen((_) => kick());
    _readySub = _gateway.readyChanges.listen((ready) {
      if (ready) kick();
    });
  }

  /// Solicita un drenaje. Si ya hay uno en curso, se repite al terminar.
  ///
  /// Serializa los drenajes: nunca corren dos a la vez (preserva el FIFO).
  Future<void> kick() async {
    if (_disposed) return;
    if (_draining) {
      _dirty = true;
      return;
    }
    _draining = true;
    try {
      do {
        _dirty = false;
        await _drainAll();
      } while (_dirty && !_disposed);
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainAll() async {
    if (!await _gateway.ensureReady()) {
      // Sin sesión utilizable no se consume ningún intento de las ops:
      // el fallo no es culpa de ellas. Se reintenta al cap del backoff
      // o antes, si cambia la sesión o entra una op nueva.
      _scheduleRetry(_backoffPolicy.cap);
      return;
    }

    final venues = await _queue.venuesWithPending();
    if (venues.isEmpty) return;

    _setStatus(const SyncStatus(SyncHealth.syncing));

    // La degradación se recolecta sobre TODA la pasada y el estado se deriva al
    // cierre, en vez de mutarlo por venue: así un venue que sincroniza OK no
    // pisa el 'degraded' de otro que sigue fallando (el banner del owner debe
    // sobrevivir en multi-tenant). El resultado no depende del orden de
    // venuesWithPending(), y un venue que se recupera vuelve a 'idle' solo.
    String? degradedReason;
    for (final venueId in venues) {
      if (_disposed) return;
      final reason = await _drainVenue(venueId);
      if (reason != null) degradedReason = reason;
    }
    if (_disposed) return;

    _setStatus(
      degradedReason != null
          ? SyncStatus(SyncHealth.degraded, lastError: degradedReason)
          : SyncStatus.initial,
    );
  }

  /// Drena un venue en orden FIFO estricto (ACID-7: jamás se reordena).
  ///
  /// Retorna el último error si el venue quedó sobre [degradedThreshold] (para
  /// que [_drainAll] derive el estado agregado de la pasada), o null si drenó
  /// limpio o falló por debajo del umbral. No muta el estado del servicio: la
  /// observabilidad la decide [_drainAll] al cerrar la pasada completa.
  Future<String?> _drainVenue(String venueId) async {
    while (!_disposed) {
      final op = await _queue.head(venueId);
      if (op == null) return null;

      final result = await _gateway.apply(op);
      switch (result) {
        case SyncApplied():
          for (final entry in result.orderTimestamps.entries) {
            await _reconciler.markOrderSynced(entry.key, entry.value);
          }
          for (final entry in result.itemTimestamps.entries) {
            await _reconciler.markOrderItemSynced(entry.key, entry.value);
          }
          await _queue.remove(op.id);
          AppLogger.info(
            'sync.flushed op=${op.id} type=${op.opType.toDb()} venue=$venueId',
            tag: _tag,
          );

        case SyncRejected(reason: final reason):
          await _queue.markDead(op.id, reason);
          AppLogger.warning(
            'sync.dead_letter op=${op.id} type=${op.opType.toDb()} '
            'venue=$venueId reason=$reason',
            tag: _tag,
          );

        case SyncUnavailable(reason: final reason):
          await _queue.markAttempt(op.id, error: reason);
          final attempts = op.attempts + 1;
          AppLogger.info(
            'sync.retry_scheduled op=${op.id} attempts=$attempts '
            'venue=$venueId reason=$reason',
            tag: _tag,
          );
          // Head-of-line: este venue espera su backoff; no se salta la op.
          _scheduleRetry(_backoffPolicy.delayFor(attempts));
          return attempts > degradedThreshold ? reason : null;
      }
    }
    return null;
  }

  void _scheduleRetry(Duration delay) {
    if (_retryScheduled || _disposed) return;
    _retryScheduled = true;
    unawaited(
      _wait(delay).then((_) {
        _retryScheduled = false;
        if (!_disposed) kick();
      }),
    );
  }

  void _setStatus(SyncStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  /// Detiene el servicio y libera recursos.
  Future<void> dispose() async {
    _disposed = true;
    await _queueSub?.cancel();
    await _readySub?.cancel();
    await _statusController.close();
  }
}
