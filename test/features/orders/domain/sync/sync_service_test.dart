import 'dart:async';

import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_apply_result.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_local_reconciler.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_service.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gateway falso programable: el test decide el resultado de cada apply.
class _FakeGateway implements OrderRemoteGateway {
  bool ready = true;
  final readyController = StreamController<bool>.broadcast();
  final applied = <PendingOp>[];
  SyncApplyResult Function(PendingOp op) handler = (_) => const SyncApplied();

  @override
  Future<bool> ensureReady() async => ready;

  @override
  Stream<bool> get readyChanges => readyController.stream;

  @override
  Future<SyncApplyResult> apply(PendingOp op) async {
    applied.add(op);
    return handler(op);
  }

  Future<void> close() => readyController.close();
}

/// Reconciliador falso: registra las adopciones LWW que pidió el servicio.
class _FakeReconciler implements SyncLocalReconciler {
  final orders = <(String, DateTime)>[];
  final items = <(String, DateTime)>[];

  @override
  Future<void> markOrderSynced(String orderId, DateTime serverUpdatedAt) async {
    orders.add((orderId, serverUpdatedAt));
  }

  @override
  Future<void> markOrderItemSynced(
    String orderItemId,
    DateTime serverUpdatedAt,
  ) async {
    items.add((orderItemId, serverUpdatedAt));
  }
}

/// Espera manual: registra los delays pedidos y los libera bajo demanda,
/// para testear el backoff sin relojes reales (tests determinísticos).
class _ManualWait {
  final delays = <Duration>[];
  final _completers = <Completer<void>>[];

  Future<void> call(Duration delay) {
    delays.add(delay);
    final completer = Completer<void>();
    _completers.add(completer);
    return completer.future;
  }

  void releaseAll() {
    final pending = List.of(_completers);
    _completers.clear();
    for (final completer in pending) {
      completer.complete();
    }
  }
}

void main() {
  late AppDatabase db;
  late DriftPendingOpQueue queue;
  late _FakeGateway gateway;
  late _FakeReconciler reconciler;
  late _ManualWait wait;
  late SyncService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = DriftPendingOpQueue(db);
    gateway = _FakeGateway();
    reconciler = _FakeReconciler();
    wait = _ManualWait();
    service = SyncService(
      queue: queue,
      gateway: gateway,
      reconciler: reconciler,
      wait: wait.call,
    );
  });

  tearDown(() async {
    await service.dispose();
    await gateway.close();
    await db.close();
  });

  Future<int> enqueue(
    String venueId,
    PendingOpType type, [
    Map<String, dynamic> payload = const {},
  ]) {
    return queue.enqueue(venueId: venueId, opType: type, payload: payload);
  }

  group('drenaje FIFO (ACID-7, CA-004)', () {
    test(
      'drena 5 ops en orden estricto de inserción y vacía la cola',
      () async {
        final ids = <int>[
          await enqueue('venue-A', PendingOpType.createOrder),
          await enqueue('venue-A', PendingOpType.addOrderItem),
          await enqueue('venue-A', PendingOpType.updateOrderItem),
          await enqueue('venue-A', PendingOpType.updateOrderItem),
          await enqueue('venue-A', PendingOpType.closeOrder),
        ];

        await service.kick();

        expect(gateway.applied.map((op) => op.id), ids);
        expect(await queue.peek('venue-A'), isEmpty);
      },
    );

    test(
      'al éxito elimina la op y adopta los updated_at del server (LWW)',
      () async {
        final serverTime = DateTime.utc(2026, 6, 9, 12);
        gateway.handler =
            (_) => SyncApplied(
              orderTimestamps: {'order-1': serverTime},
              itemTimestamps: {'item-1': serverTime},
            );
        await enqueue('venue-A', PendingOpType.createOrder);

        await service.kick();

        expect(reconciler.orders, [('order-1', serverTime)]);
        expect(reconciler.items, [('item-1', serverTime)]);
        expect(await queue.head('venue-A'), isNull);
      },
    );

    test(
      'un venue con fallo recuperable no bloquea a los demás venues',
      () async {
        gateway.handler =
            (op) =>
                op.venueId == 'venue-A'
                    ? const SyncUnavailable('red caída hacia A')
                    : const SyncApplied();
        await enqueue('venue-A', PendingOpType.createOrder);
        await enqueue('venue-B', PendingOpType.createOrder);

        await service.kick();

        // B drenado; A sigue en cola con un intento consumido.
        expect(await queue.peek('venue-B'), isEmpty);
        final opA = await queue.head('venue-A');
        expect(opA!.attempts, 1);
      },
    );
  });

  group('fallo recuperable (criterio 3 del issue)', () {
    test(
      'attempts++ con error registrado, backoff 2^attempts y reintento',
      () async {
        var failures = 0;
        gateway.handler = (_) {
          if (failures < 2) {
            failures++;
            return const SyncUnavailable('timeout');
          }
          return const SyncApplied();
        };
        await enqueue('venue-A', PendingOpType.closeOrder);

        await service.kick();

        // Primer fallo: la op sigue en cola, attempts 1, backoff 2^1 = 2 s.
        var op = await queue.head('venue-A');
        expect(op!.attempts, 1);
        expect(op.lastError, 'timeout');
        expect(wait.delays, [const Duration(seconds: 2)]);

        // "Pasa" el backoff → segundo fallo → 2^2 = 4 s.
        wait.releaseAll();
        await pumpEventQueue();
        op = await queue.head('venue-A');
        expect(op!.attempts, 2);
        expect(wait.delays.last, const Duration(seconds: 4));

        // Tercer intento: éxito → la cola queda vacía (reconexión, CA-004).
        wait.releaseAll();
        await pumpEventQueue();
        expect(await queue.head('venue-A'), isNull);
      },
    );

    test(
      'una op sobre el umbral emite estado degraded sin detener la cola',
      () async {
        final id = await enqueue('venue-A', PendingOpType.createOrder);
        // Simula una op que ya falló 10 veces (umbral por defecto).
        for (var i = 0; i < 10; i++) {
          await queue.markAttempt(id);
        }
        gateway.handler = (_) => const SyncUnavailable('sigue caído');
        final statuses = <SyncStatus>[];
        final sub = service.statusStream.listen(statuses.add);
        addTearDown(sub.cancel);

        await service.kick();
        await pumpEventQueue();

        expect(
          statuses,
          contains(
            const SyncStatus(SyncHealth.degraded, lastError: 'sigue caído'),
          ),
        );
        // La op NO se descarta: sigue pending con backoff cap programado.
        final op = await queue.head('venue-A');
        expect(op!.attempts, 11);
        expect(wait.delays.last, const Duration(minutes: 5));
      },
    );
  });

  group('error permanente (dead-letter)', () {
    test(
      'descarta la op con su error y la cola sigue con la siguiente',
      () async {
        gateway.handler =
            (op) =>
                op.opType == PendingOpType.createOrder
                    ? const SyncRejected('23503: FK inválida')
                    : const SyncApplied();
        final deadId = await enqueue('venue-A', PendingOpType.createOrder);
        await enqueue('venue-A', PendingOpType.closeOrder);

        await service.kick();

        // Ambas ops fueron procesadas en orden; la cola pending quedó vacía.
        expect(gateway.applied, hasLength(2));
        expect(await queue.peek('venue-A'), isEmpty);

        // La op rechazada quedó dead con su diagnóstico, no eliminada.
        final rows = await db.select(db.pendingOps).get();
        final dead = rows.singleWhere((r) => r.id == deadId);
        expect(dead.status, 'dead');
        expect(dead.lastError, '23503: FK inválida');
      },
    );
  });

  group('gateway no listo', () {
    test(
      'no aplica ni consume attempts; reintenta al cap del backoff',
      () async {
        gateway.ready = false;
        await enqueue('venue-A', PendingOpType.createOrder);

        await service.kick();

        expect(gateway.applied, isEmpty);
        final op = await queue.head('venue-A');
        expect(op!.attempts, 0);
        expect(wait.delays, [const Duration(minutes: 5)]);
      },
    );

    test('al volver la sesión (readyChanges) drena la cola', () async {
      gateway.ready = false;
      service.start();
      await enqueue('venue-A', PendingOpType.createOrder);
      await pumpEventQueue();
      expect(gateway.applied, isEmpty);

      gateway.ready = true;
      gateway.readyController.add(true);
      await pumpEventQueue();

      expect(gateway.applied, hasLength(1));
      expect(await queue.head('venue-A'), isNull);
    });
  });

  group('start() reactivo', () {
    test(
      'encolar una op dispara el drenaje sin kick manual (UI no bloquea)',
      () async {
        service.start();
        await pumpEventQueue();

        await enqueue('venue-A', PendingOpType.createOrder);
        await pumpEventQueue();

        expect(gateway.applied, hasLength(1));
        expect(await queue.head('venue-A'), isNull);
      },
    );
  });

  group('degraded multi-venue (observabilidad cross-venue)', () {
    test(
      'un venue degradado conserva el banner aunque otro venue sincronice OK '
      'en la misma pasada',
      () async {
        // venue-A: op que ya superó el umbral (10) y sigue cayendo.
        final idA = await enqueue('venue-A', PendingOpType.createOrder);
        for (var i = 0; i < 10; i++) {
          await queue.markAttempt(idA);
        }
        // venue-B: op que sincroniza sin problemas en la misma pasada.
        await enqueue('venue-B', PendingOpType.createOrder);
        gateway.handler =
            (op) =>
                op.venueId == 'venue-A'
                    ? const SyncUnavailable('A sigue caído')
                    : const SyncApplied();

        await service.kick();

        // B drenó; el estado FINAL es degraded (no idle): el éxito de B no
        // borra el banner del owner que viene de A. Independiente del orden
        // en que venuesWithPending() liste A y B.
        expect(await queue.peek('venue-B'), isEmpty);
        expect(
          service.status,
          const SyncStatus(SyncHealth.degraded, lastError: 'A sigue caído'),
        );
      },
    );

    test(
      'cuando el venue degradado se recupera, el banner vuelve a idle solo',
      () async {
        final idA = await enqueue('venue-A', PendingOpType.createOrder);
        for (var i = 0; i < 10; i++) {
          await queue.markAttempt(idA);
        }
        gateway.handler = (_) => const SyncUnavailable('caído');

        await service.kick();
        expect(service.status.health, SyncHealth.degraded);

        // Vuelve la red: al disparar el backoff, la siguiente pasada drena A
        // y el estado se re-deriva a idle sin intervención externa.
        gateway.handler = (_) => const SyncApplied();
        wait.releaseAll();
        await pumpEventQueue();

        expect(await queue.head('venue-A'), isNull);
        expect(service.status.health, SyncHealth.idle);
      },
    );
  });
}
