import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
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
    name: 'Hamburguesa Clásica',
    description: 'Rica hamburguesa de vacuno',
    priceCents: 5900,
  );

  const testMenuItem2 = MenuItem(
    id: 'menu-item-2',
    venueId: 'venue-A',
    categoryId: 'cat-1',
    name: 'Coca-Cola 350ml',
    description: 'Refresco en lata',
    priceCents: 1500,
  );

  group('createOrder', () {
    test('crea pedido en estado open con totalCents 0', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      expect(order.status, OrderStatus.open);
      expect(order.totalCents, 0);
      expect(order.venueId, 'venue-A');
      expect(order.diningTableId, 'table-1');
      expect(order.openedBy, isNull);
      // El UUID tiene 36 caracteres
      expect(order.id.length, 36);
    });

    test('orderById retorna el pedido creado', () async {
      final created = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
        openedBy: 'user-1',
      );

      final found = await repo.orderById(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.openedBy, 'user-1');
    });

    test('orderById retorna null para id inexistente', () async {
      final result = await repo.orderById('no-existe');
      expect(result, isNull);
    });
  });

  group('addItem', () {
    test('fija snapshots desde el MenuItem (ACID-2)', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      final item = await repo.addItem(
        orderId: order.id,
        menuItem: testMenuItem,
      );

      // ACID-2: snapshots deben ser exactamente los del menú
      expect(item.nameSnapshot, testMenuItem.name);
      expect(item.priceCentsSnapshot, testMenuItem.priceCents);
      expect(item.priceCentsSnapshot, isA<int>());
      expect(item.menuItemId, testMenuItem.id);
      expect(item.quantity, 1);
      expect(item.status, OrderItemStatus.sent);
      expect(item.orderId, order.id);
    });

    test(
      'recalcula totalCents del pedido tras agregar ítem (ACID-3)',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );

        await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem, // 5900 × 1
        );

        final updated = await repo.orderById(order.id);
        expect(updated!.totalCents, 5900);
      },
    );

    test(
      'totalCents acumula correctamente 2 ítems con cantidades (ACID-3)',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );

        // Ítem 1: 5900 × 2 = 11800
        await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem,
          quantity: 2,
        );

        // Ítem 2: 1500 × 3 = 4500
        await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem2,
          quantity: 3,
          comments: 'sin hielo',
        );

        final updated = await repo.orderById(order.id);
        // Total esperado: 11800 + 4500 = 16300
        expect(updated!.totalCents, 16300);
      },
    );

    test('itemsOf retorna los ítems del pedido', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      await repo.addItem(orderId: order.id, menuItem: testMenuItem);
      await repo.addItem(
        orderId: order.id,
        menuItem: testMenuItem2,
        comments: 'sin hielo',
      );

      final items = await repo.itemsOf(order.id);

      expect(items.length, 2);

      final hamburgesa = items.firstWhere(
        (i) => i.menuItemId == testMenuItem.id,
      );
      expect(hamburgesa.nameSnapshot, 'Hamburguesa Clásica');
      expect(hamburgesa.priceCentsSnapshot, 5900);
      expect(hamburgesa.comments, isNull);

      final cola = items.firstWhere((i) => i.menuItemId == testMenuItem2.id);
      expect(cola.nameSnapshot, 'Coca-Cola 350ml');
      expect(cola.priceCentsSnapshot, 1500);
      expect(cola.comments, 'sin hielo');
    });

    test('itemsOf retorna lista vacía para pedido sin ítems', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      final items = await repo.itemsOf(order.id);
      expect(items, isEmpty);
    });
  });

  group('updateStatus', () {
    test('cambia el status del pedido a sent', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );
      expect(order.status, OrderStatus.open);

      final updated = await repo.updateStatus(order.id, OrderStatus.sent);
      expect(updated.status, OrderStatus.sent);

      // Verificación en BD
      final fromDb = await repo.orderById(order.id);
      expect(fromDb!.status, OrderStatus.sent);
    });

    test('lanza ArgumentError para id inexistente', () async {
      await expectLater(
        repo.updateStatus('no-existe', OrderStatus.sent),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'lanza StateError al intentar modificar pedido cerrado (ACID-4)',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );
        // Llevar a closed directamente (estado terminal)
        await repo.updateStatus(order.id, OrderStatus.closed);

        await expectLater(
          repo.updateStatus(order.id, OrderStatus.sent),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('watchOpenOrders', () {
    test('emite pedidos abiertos del venue', () async {
      await repo.createOrder(venueId: 'venue-A', diningTableId: 'table-1');
      await repo.createOrder(venueId: 'venue-A', diningTableId: 'table-2');

      final orders = await repo.watchOpenOrders('venue-A').first;
      expect(orders.length, 2);
      expect(orders.every((o) => o.status == OrderStatus.open), isTrue);
    });

    test('no incluye pedidos de otros venues', () async {
      await repo.createOrder(venueId: 'venue-A', diningTableId: 'table-1');
      await repo.createOrder(venueId: 'venue-B', diningTableId: 'table-1');

      final ordersA = await repo.watchOpenOrders('venue-A').first;
      expect(ordersA.length, 1);
      expect(ordersA.first.venueId, 'venue-A');
    });
  });

  group('activeOrderForTable', () {
    test('retorna el pedido activo de la mesa', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );

      final active = await repo.activeOrderForTable('venue-A', 'table-1');
      expect(active, isNotNull);
      expect(active!.id, order.id);
      expect(active.status, OrderStatus.open);
    });

    test('retorna null si no hay pedido activo en la mesa', () async {
      final active = await repo.activeOrderForTable('venue-A', 'table-1');
      expect(active, isNull);
    });

    test('retorna null si el único pedido de la mesa está cerrado', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );
      await repo.updateStatus(order.id, OrderStatus.closed);

      final active = await repo.activeOrderForTable('venue-A', 'table-1');
      expect(active, isNull);
    });

    test('retorna null si el único pedido de la mesa está cancelado', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );
      await repo.updateStatus(order.id, OrderStatus.cancelled);

      final active = await repo.activeOrderForTable('venue-A', 'table-1');
      expect(active, isNull);
    });

    test('no incluye pedidos de otras mesas del mismo venue', () async {
      await repo.createOrder(venueId: 'venue-A', diningTableId: 'table-2');

      final active = await repo.activeOrderForTable('venue-A', 'table-1');
      expect(active, isNull);
    });
  });

  group('recomputeOrderStatus', () {
    test('deriva sent cuando todos los ítems están en sent', () async {
      final order = await repo.createOrder(
        venueId: 'venue-A',
        diningTableId: 'table-1',
      );
      await repo.addItem(orderId: order.id, menuItem: testMenuItem);
      await repo.addItem(orderId: order.id, menuItem: testMenuItem2);
      // Tras addItem los ítems quedan en sent; updateStatus para reflejar eso.
      await repo.updateStatus(order.id, OrderStatus.sent);

      // recomputeOrderStatus con todos sent → debe quedar sent.
      await repo.recomputeOrderStatus(order.id);
      final updated = await repo.orderById(order.id);
      expect(updated!.status, OrderStatus.sent);
    });

    test(
      'deriva ready cuando todos los ítems no-cancelados están en ready',
      () async {
        final order = await repo.createOrder(
          venueId: 'venue-A',
          diningTableId: 'table-1',
        );
        final item1 = await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem,
        );
        final item2 = await repo.addItem(
          orderId: order.id,
          menuItem: testMenuItem2,
        );
        await repo.updateItemStatus(item1.id, OrderItemStatus.ready);
        await repo.updateItemStatus(item2.id, OrderItemStatus.ready);

        await repo.recomputeOrderStatus(order.id);
        final updated = await repo.orderById(order.id);
        expect(updated!.status, OrderStatus.ready);
      },
    );
  });
}
