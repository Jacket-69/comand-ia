import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftPendingOpQueue queue;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = DriftPendingOpQueue(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('enqueue', () {
    test('encola una operación y retorna id > 0', () async {
      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'order_id': 'ord-1'},
      );

      expect(id, greaterThan(0));
    });

    test('serializa el payload como JSON', () async {
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'order_id': 'ord-1', 'table': 3},
      );

      final ops = await queue.peek('venue-A');
      expect(ops.first.payload, contains('order_id'));
      expect(ops.first.payload, contains('ord-1'));
    });
  });

  group('peek y aislamiento por venue (ACID-7)', () {
    test('peek retorna solo ops del venue solicitado en orden FIFO', () async {
      // Venue A: 3 ops
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'seq': 1},
      );
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.updateOrderItem,
        payload: {'seq': 2},
      );
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.closeOrder,
        payload: {'seq': 3},
      );

      // Venue B: 1 op (no debe aparecer en peek de A)
      await queue.enqueue(
        venueId: 'venue-B',
        opType: PendingOpType.createOrder,
        payload: {'seq': 99},
      );

      final opsA = await queue.peek('venue-A');

      // Solo venue A, exactamente 3 ops
      expect(opsA.length, 3);
      expect(opsA.every((op) => op.venueId == 'venue-A'), isTrue);

      // FIFO: orden creciente de id (orden de inserción)
      expect(opsA[0].opType, PendingOpType.createOrder);
      expect(opsA[1].opType, PendingOpType.updateOrderItem);
      expect(opsA[2].opType, PendingOpType.closeOrder);

      expect(opsA[0].id, lessThan(opsA[1].id));
      expect(opsA[1].id, lessThan(opsA[2].id));
    });

    test('peek de venue-B retorna solo su op', () async {
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'x': 1},
      );
      await queue.enqueue(
        venueId: 'venue-B',
        opType: PendingOpType.updateOrderStatus,
        payload: {'x': 2},
      );

      final opsB = await queue.peek('venue-B');
      expect(opsB.length, 1);
      expect(opsB.first.venueId, 'venue-B');
      expect(opsB.first.opType, PendingOpType.updateOrderStatus);
    });

    test('peek retorna lista vacía si el venue no tiene ops', () async {
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      final opsC = await queue.peek('venue-C');
      expect(opsC, isEmpty);
    });
  });

  group('head', () {
    test('head retorna la primera op (cabeza de la cola FIFO)', () async {
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'first': true},
      );
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.closeOrder,
        payload: {'first': false},
      );

      final first = await queue.head('venue-A');

      expect(first, isNotNull);
      expect(first!.opType, PendingOpType.createOrder);
    });

    test('head retorna null si la cola está vacía', () async {
      final result = await queue.head('venue-vacía');
      expect(result, isNull);
    });
  });

  group('markAttempt', () {
    test('incrementa attempts en 1', () async {
      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'x': 1},
      );

      final before = await queue.head('venue-A');
      expect(before!.attempts, 0);

      await queue.markAttempt(id);

      final after = await queue.head('venue-A');
      expect(after!.attempts, 1);
    });

    test('markAttempt acumulativo en múltiples llamadas', () async {
      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      await queue.markAttempt(id);
      await queue.markAttempt(id);
      await queue.markAttempt(id);

      final op = await queue.head('venue-A');
      expect(op!.attempts, 3);
    });
  });

  group('remove', () {
    test('elimina la op de la cola', () async {
      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      await queue.remove(id);

      final ops = await queue.peek('venue-A');
      expect(ops, isEmpty);
    });

    test('remove no afecta ops de otro venue', () async {
      final idA = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );
      await queue.enqueue(
        venueId: 'venue-B',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      await queue.remove(idA);

      final opsA = await queue.peek('venue-A');
      final opsB = await queue.peek('venue-B');

      expect(opsA, isEmpty);
      expect(opsB.length, 1);
    });

    test('tras remove la siguiente op pasa a ser la cabeza', () async {
      final id1 = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {'order': 1},
      );
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.closeOrder,
        payload: {'order': 2},
      );

      await queue.remove(id1);

      final head = await queue.head('venue-A');
      expect(head!.opType, PendingOpType.closeOrder);
    });
  });

  group('markAttempt con error', () {
    test('registra el último error sin tocar el status', () async {
      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      await queue.markAttempt(id, error: 'red caída');

      final op = await queue.head('venue-A');
      expect(op!.attempts, 1);
      expect(op.lastError, 'red caída');
      expect(op.status, PendingOpStatus.pending);
    });
  });

  group('markDead (dead-letter, COMA-008)', () {
    test(
      'la op dead sale de peek/head pero se conserva con su error',
      () async {
        final id1 = await queue.enqueue(
          venueId: 'venue-A',
          opType: PendingOpType.createOrder,
          payload: {'seq': 1},
        );
        await queue.enqueue(
          venueId: 'venue-A',
          opType: PendingOpType.closeOrder,
          payload: {'seq': 2},
        );

        await queue.markDead(id1, '23503: FK inválida');

        // La cola sigue: la siguiente op pasa a ser la cabeza (ACID-7 sin
        // head-of-line blocking permanente).
        final head = await queue.head('venue-A');
        expect(head!.opType, PendingOpType.closeOrder);

        final pending = await queue.peek('venue-A');
        expect(pending, hasLength(1));

        // La fila dead sigue existiendo para diagnóstico.
        final rows = await db.select(db.pendingOps).get();
        final deadRow = rows.singleWhere((r) => r.id == id1);
        expect(deadRow.status, 'dead');
        expect(deadRow.lastError, '23503: FK inválida');
      },
    );
  });

  group('venuesWithPending', () {
    test('retorna los venues con ops pending, sin duplicados', () async {
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );
      await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.closeOrder,
        payload: {},
      );
      final idB = await queue.enqueue(
        venueId: 'venue-B',
        opType: PendingOpType.createOrder,
        payload: {},
      );

      expect((await queue.venuesWithPending())..sort(), ['venue-A', 'venue-B']);

      // Un venue cuya única op murió ya no aparece.
      await queue.markDead(idB, 'error permanente');
      expect(await queue.venuesWithPending(), ['venue-A']);
    });
  });

  group('watchPendingCount', () {
    test('emite el total de ops pending y reacciona a cambios', () async {
      final counts = <int>[];
      final sub = queue.watchPendingCount().listen(counts.add);
      addTearDown(sub.cancel);

      final id = await queue.enqueue(
        venueId: 'venue-A',
        opType: PendingOpType.createOrder,
        payload: {},
      );
      await pumpEventQueue();
      await queue.remove(id);
      await pumpEventQueue();

      expect(counts, containsAllInOrder([1, 0]));
    });
  });

  group('conversión PendingOpType round-trip', () {
    test('todos los tipos sobreviven enqueue + peek', () async {
      final types = PendingOpType.values;

      for (final opType in types) {
        await queue.enqueue(
          venueId: 'venue-round',
          opType: opType,
          payload: {'type': opType.toDb()},
        );
      }

      final ops = await queue.peek('venue-round');
      expect(ops.length, types.length);

      for (var i = 0; i < types.length; i++) {
        expect(ops[i].opType, types[i]);
      }
    });
  });
}
