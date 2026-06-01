import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftOrderLocalRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftOrderLocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Ítem de menú reutilizable en los tests
  const testMenuItem = MenuItem(
    id: 'menu-item-1',
    venueId: 'venue-A',
    categoryId: 'cat-1',
    name: 'Empanada de Pino',
    description: 'Empanada frita con pino de vacuno.',
    priceCents: 2500,
  );

  const testMenuItem2 = MenuItem(
    id: 'menu-item-2',
    venueId: 'venue-A',
    categoryId: 'cat-1',
    name: 'Bebida',
    description: 'Bebida en lata 350ml.',
    priceCents: 1200,
  );

  group('closeOrder', () {
    test(
      'cierre feliz: pedido queda closed con closedAt, paymentMethod y tipCents',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );
        await repo.addItem(orderId: order.id, menuItem: testMenuItem);

        final closed = await repo.closeOrder(
          orderId: order.id,
          paymentMethod: PaymentMethod.cash,
          tipCents: 500,
        );

        expect(closed.status, OrderStatus.closed);
        expect(closed.closedAt, isNotNull);
        expect(closed.paymentMethod, PaymentMethod.cash);
        expect(closed.tipCents, 500);
      },
    );

    test(
      'ACID-3: totalCents no cambia al cerrar (sigue siendo suma de ítems)',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );
        // 2500 × 1 + 1200 × 2 = 2500 + 2400 = 4900
        await repo.addItem(orderId: order.id, menuItem: testMenuItem);
        await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem2,
          quantity: 2,
        );

        final beforeClose = await repo.orderById(order.id);
        expect(beforeClose!.totalCents, 4900);

        final closed = await repo.closeOrder(
          orderId: order.id,
          paymentMethod: PaymentMethod.card,
          tipCents: 1000,
        );

        // totalCents sigue siendo solo los ítems; la propina es campo aparte
        expect(closed.totalCents, 4900);
        expect(closed.tipCents, 1000);
        // El total no absorbió la propina
        expect(closed.totalCents, isNot(4900 + 1000));
      },
    );

    test('ACID-4: cerrar un pedido ya cerrado lanza StateError', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      // Primer cierre: OK
      await repo.closeOrder(
        orderId: order.id,
        paymentMethod: PaymentMethod.transfer,
        tipCents: 0,
      );

      // Segundo cierre: debe lanzar StateError
      await expectLater(
        repo.closeOrder(orderId: order.id, paymentMethod: PaymentMethod.cash),
        throwsA(isA<StateError>()),
      );
    });

    test('cierre con id inexistente lanza ArgumentError', () async {
      await expectLater(
        repo.closeOrder(
          orderId: 'no-existe',
          paymentMethod: PaymentMethod.cash,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('propina se persiste separada: round-trip desde la BD', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );
      await repo.addItem(orderId: order.id, menuItem: testMenuItem); // 2500

      await repo.closeOrder(
        orderId: order.id,
        paymentMethod: PaymentMethod.other,
        tipCents: 750,
      );

      // Releer desde BD para confirmar persistencia
      final fromDb = await repo.orderById(order.id);
      expect(fromDb, isNotNull);
      expect(fromDb!.tipCents, 750);
      expect(fromDb.totalCents, 2500); // solo ítems, sin propina
      expect(fromDb.paymentMethod, PaymentMethod.other);
      expect(fromDb.status, OrderStatus.closed);
    });

    test('tipCents default 0 cuando no se pasa propina', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      final closed = await repo.closeOrder(
        orderId: order.id,
        paymentMethod: PaymentMethod.card,
        // tipCents no se pasa → usa default 0
      );

      expect(closed.tipCents, 0);
    });
  });
}
