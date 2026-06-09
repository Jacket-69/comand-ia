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

  /// Drenaje en curso (null si no hay ninguno). [dispose] lo espera para no
  /// escribir contra una base ya cerrada por el owner.
  Future<void>? _draining;
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
    if (_draining != null) {
      _dirty = true;
      return;
    }
    final loop = _drainLoop();
    _draining = loop;
    try {
      await loop;
    } finally {
      _draining = null;
    }
  }

  Future<void> _drainLoop() async {
    do {
      _dirty = false;
      await _drainAll();
    } while (_dirty && !_disposed);
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

    // La degradación y el backoff se agregan sobre TODA la pasada y se aplican
    // al cierre. El estado no se muta por venue (un venue OK no pisa el
    // 'degraded' de otro), y el reintento usa el MENOR backoff de los venues
    // que fallaron: así el venue con la espera más corta no queda preso del
    // backoff del primero que falló. Independiente del orden de venuesWithPending().
    String? degradedReason;
    Duration? nextRetry;
    for (final venueId in venues) {
      if (_disposed) return;
      final outcome = await _drainVenue(venueId);
      if (outcome.degraded != null) degradedReason = outcome.degraded;
      if (outcome.retry != null &&
          (nextRetry == null || outcome.retry! < nextRetry)) {
        nextRetry = outcome.retry;
      }
    }
    if (_disposed) return;

    _setStatus(
      degradedReason != null
          ? SyncStatus(SyncHealth.degraded, lastError: degradedReason)
          : SyncStatus.initial,
    );
    if (nextRetry != null) _scheduleRetry(nextRetry);
  }

  /// Drena un venue en orden FIFO estricto (ACID-7: jamás se reordena).
  ///
  /// Retorna el backoff a esperar si el venue quedó bloqueado por un fallo
  /// recuperable (head-of-line), y el último error si además superó
  /// [degradedThreshold]. [_drainAll] agrega ambos sobre la pasada completa: no
  /// se muta el estado ni se agenda el retry aquí.
  Future<({Duration? retry, String? degraded})> _drainVenue(
    String venueId,
  ) async {
    while (!_disposed) {
      final op = await _queue.head(venueId);
      if (op == null) return (retry: null, degraded: null);

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
          return (
            retry: _backoffPolicy.delayFor(attempts),
            degraded: attempts > degradedThreshold ? reason : null,
          );
      }
    }
    return (retry: null, degraded: null);
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
  ///
  /// Espera a que termine el drenaje en curso antes de cerrar: así ninguna
  /// escritura a la cola corre contra una base ya cerrada por el owner (evita
  /// excepciones async tras el teardown o el hot-restart).
  Future<void> dispose() async {
    _disposed = true;
    await _queueSub?.cancel();
    await _readySub?.cancel();
    try {
      await _draining;
    } catch (_) {
      // Un fallo del drenaje en curso no debe romper el teardown.
    }
    await _statusController.close();
  }
}
