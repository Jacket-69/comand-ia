import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Constantes compartidas ───────────────────────────────────────────────────

/// Coincide con el fallback del controller cuando no hay usuario autenticado.
const kVenueId = 'venue-001-mock';

const _menuItem = MenuItem(
  id: 'menu-1',
  venueId: kVenueId,
  categoryId: 'cat-1',
  name: 'Empanada de Pino',
  description: 'Empanada frita.',
  priceCents: 250000, // $2.500 CLP
);

const _menuItem2 = MenuItem(
  id: 'menu-2',
  venueId: kVenueId,
  categoryId: 'cat-1',
  name: 'Bebida',
  description: 'Bebida en lata.',
  priceCents: 120000, // $1.200 CLP
);

// ─── Helpers ──────────────────────────────────────────────────────────────────

ProviderContainer buildContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
}

/// Crea un pedido con al menos un ítem y retorna su ID.
Future<String> seedOrder(AppDatabase db) async {
  final repo = DriftOrderLocalRepository(db);
  final order = await repo.createOrder(
    venueId: kVenueId,
    diningTableId: 'table-test',
  );
  await repo.addItem(orderId: order.id, menuItem: _menuItem, quantity: 2);
  await repo.addItem(orderId: order.id, menuItem: _menuItem2, quantity: 1);
  return order.id;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = buildContainer(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  CheckoutController makeCtrl() =>
      container.read(checkoutControllerProvider.notifier);

  group('CheckoutController.close — flujo feliz', () {
    test('cierra el pedido con método de pago y propina correctos', () async {
      final orderId = await seedOrder(db);
      final ctrl = makeCtrl();

      await ctrl.close(
        orderId: orderId,
        paymentMethod: PaymentMethod.cash,
        tipCents: 50000, // $500 CLP
      );

      final repo = DriftOrderLocalRepository(db);
      final fromDb = await repo.orderById(orderId);
      expect(fromDb, isNotNull);
      expect(fromDb!.status, OrderStatus.closed);
      expect(fromDb.paymentMethod, PaymentMethod.cash);
      expect(fromDb.tipCents, 50000);
      expect(fromDb.closedAt, isNotNull);
    });

    test(
      'ACID-3: totalCents no cambia al cerrar (propina es campo aparte)',
      () async {
        final orderId = await seedOrder(db);
        // 250000×2 + 120000×1 = 620000
        final ctrl = makeCtrl();

        await ctrl.close(
          orderId: orderId,
          paymentMethod: PaymentMethod.card,
          tipCents: 60000,
        );

        final repo = DriftOrderLocalRepository(db);
        final fromDb = await repo.orderById(orderId);
        expect(fromDb!.totalCents, 620000);
        expect(fromDb.tipCents, 60000);
        // El total no absorbió la propina
        expect(fromDb.totalCents, isNot(620000 + 60000));
      },
    );

    test('encola pending_op de tipo close_order (ACID-7)', () async {
      final orderId = await seedOrder(db);
      final ctrl = makeCtrl();

      await ctrl.close(
        orderId: orderId,
        paymentMethod: PaymentMethod.transfer,
        tipCents: 0,
      );

      final opQueue = DriftPendingOpQueue(db);
      final ops = await opQueue.peek(kVenueId);
      expect(ops.isNotEmpty, isTrue);
      expect(ops.last.opType.toDb(), 'close_order');
    });

    test(
      'payload de la op contiene order_id, payment_method y tip_cents',
      () async {
        final orderId = await seedOrder(db);
        final ctrl = makeCtrl();

        await ctrl.close(
          orderId: orderId,
          paymentMethod: PaymentMethod.other,
          tipCents: 25000,
        );

        final opQueue = DriftPendingOpQueue(db);
        final ops = await opQueue.peek(kVenueId);
        final payload = ops.last.payload;
        expect(payload, contains('"order_id"'));
        expect(payload, contains('"payment_method":"other"'));
        expect(payload, contains('"tip_cents":25000'));
      },
    );

    test('estado pasa a closed=true tras cierre exitoso', () async {
      final orderId = await seedOrder(db);
      final ctrl = makeCtrl();

      await ctrl.close(
        orderId: orderId,
        paymentMethod: PaymentMethod.cash,
        tipCents: 0,
      );

      final state = container.read(checkoutControllerProvider);
      expect(state.closed, isTrue);
      expect(state.isClosing, isFalse);
      expect(state.error, isNull);
    });
  });

  group('CheckoutController.close — errores', () {
    test('ACID-4: cerrar un pedido ya cerrado lanza StateError', () async {
      final orderId = await seedOrder(db);
      final ctrl = makeCtrl();

      // Primer cierre
      await ctrl.close(
        orderId: orderId,
        paymentMethod: PaymentMethod.cash,
        tipCents: 0,
      );

      // Segundo cierre debe lanzar
      await expectLater(
        ctrl.close(
          orderId: orderId,
          paymentMethod: PaymentMethod.cash,
          tipCents: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('cerrar un pedido inexistente lanza ArgumentError', () async {
      final ctrl = makeCtrl();

      await expectLater(
        ctrl.close(
          orderId: 'no-existe',
          paymentMethod: PaymentMethod.cash,
          tipCents: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
