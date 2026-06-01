import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_dining_table_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const kVenue = 'venue-test';

const _menuItem1 = MenuItem(
  id: 'menu-1',
  venueId: kVenue,
  categoryId: 'cat-1',
  name: 'Lomo saltado',
  description: 'Plato de fondo',
  priceCents: 9500,
);

const _menuItem2 = MenuItem(
  id: 'menu-2',
  venueId: kVenue,
  categoryId: 'cat-1',
  name: 'Agua mineral',
  description: 'Bebida',
  priceCents: 1200,
);

/// Inserta una mesa activa con el sortOrder dado.
Future<void> insertTable(
  AppDatabase db, {
  required String id,
  required String label,
  int sortOrder = 0,
  bool active = true,
}) async {
  await db
      .into(db.diningTables)
      .insert(
        DiningTablesCompanion.insert(
          id: id,
          venueId: kVenue,
          label: label,
          sortOrder: Value(sortOrder),
          active: Value(active),
        ),
      );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late DriftOrderLocalRepository orderRepo;
  late DriftDiningTableLocalRepository tableRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orderRepo = DriftOrderLocalRepository(db);
    tableRepo = DriftDiningTableLocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ─── updateItemStatus ──────────────────────────────────────────────────────

  group('updateItemStatus', () {
    test('actualiza status del ítem de sent a preparing', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 'table-1',
      );
      final item = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      expect(item.status, OrderItemStatus.sent);

      final updated = await orderRepo.updateItemStatus(
        item.id,
        OrderItemStatus.preparing,
      );
      expect(updated.status, OrderItemStatus.preparing);
    });

    test('actualiza status del ítem de preparing a ready', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 'table-1',
      );
      final item = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      await orderRepo.updateItemStatus(item.id, OrderItemStatus.preparing);
      final updated = await orderRepo.updateItemStatus(
        item.id,
        OrderItemStatus.ready,
      );
      expect(updated.status, OrderItemStatus.ready);
    });

    test(
      're-deriva status del pedido a preparing cuando algún ítem avanza',
      () async {
        final order = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 'table-1',
        );
        // Necesitamos llevar el pedido a sent para que _deriveOrderStatus opere
        // sobre estados coherentes.
        await orderRepo.updateStatus(order.id, OrderStatus.sent);

        final item1 = await orderRepo.addItem(
          orderId: order.id,
          menuItem: _menuItem1,
        );
        await orderRepo.addItem(orderId: order.id, menuItem: _menuItem2);

        // Avanzar solo ítem1 → alguno en preparing → pedido preparing.
        await orderRepo.updateItemStatus(item1.id, OrderItemStatus.preparing);

        final updatedOrder = await orderRepo.orderById(order.id);
        expect(updatedOrder!.status, OrderStatus.preparing);
      },
    );

    test(
      're-deriva status del pedido a ready cuando todos los ítems están ready',
      () async {
        final order = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 'table-1',
        );
        await orderRepo.updateStatus(order.id, OrderStatus.sent);

        final item1 = await orderRepo.addItem(
          orderId: order.id,
          menuItem: _menuItem1,
        );
        final item2 = await orderRepo.addItem(
          orderId: order.id,
          menuItem: _menuItem2,
        );

        // Llevar ambos a ready.
        await orderRepo.updateItemStatus(item1.id, OrderItemStatus.ready);
        await orderRepo.updateItemStatus(item2.id, OrderItemStatus.ready);

        final updatedOrder = await orderRepo.orderById(order.id);
        expect(updatedOrder!.status, OrderStatus.ready);
      },
    );

    test(
      'mantiene status del pedido en sent cuando todos los ítems están en sent',
      () async {
        final order = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 'table-1',
        );
        await orderRepo.updateStatus(order.id, OrderStatus.sent);

        final item1 = await orderRepo.addItem(
          orderId: order.id,
          menuItem: _menuItem1,
        );
        // item2 queda en sent; se usa solo para verificar la derivación.
        await orderRepo.addItem(orderId: order.id, menuItem: _menuItem2);

        // Avanzar item1 a preparing y luego volver a verificar con item2 en sent.
        await orderRepo.updateItemStatus(item1.id, OrderItemStatus.preparing);
        // Ahora item1 está en preparing, item2 en sent → pedido en preparing.
        // Retroceder semánticamente no se hace en producción, pero verificamos
        // la regla con item1=sent, item2=sent al recrear.
        final order2 = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 'table-2',
        );
        await orderRepo.updateStatus(order2.id, OrderStatus.sent);
        final i1 = await orderRepo.addItem(
          orderId: order2.id,
          menuItem: _menuItem1,
        );
        final i2 = await orderRepo.addItem(
          orderId: order2.id,
          menuItem: _menuItem2,
        );
        // Ambos en sent (estado inicial de addItem).
        // Simular que la derivación ocurre con todos en sent.
        await orderRepo.updateItemStatus(i1.id, OrderItemStatus.sent);
        await orderRepo.updateItemStatus(i2.id, OrderItemStatus.sent);

        final updatedOrder2 = await orderRepo.orderById(order2.id);
        expect(updatedOrder2!.status, OrderStatus.sent);
      },
    );

    test('ignora ítems cancelados al derivar el status del pedido', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 'table-1',
      );
      await orderRepo.updateStatus(order.id, OrderStatus.sent);

      final item1 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      final item2 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem2,
      );

      // Cancelar ítem2; avanzar ítem1 a ready.
      await orderRepo.updateItemStatus(item2.id, OrderItemStatus.cancelled);
      await orderRepo.updateItemStatus(item1.id, OrderItemStatus.ready);

      // Solo el ítem no-cancelado (item1=ready) → pedido ready.
      final updatedOrder = await orderRepo.orderById(order.id);
      expect(updatedOrder!.status, OrderStatus.ready);
    });

    test('lanza StateError si el pedido padre está cerrado (ACID-4)', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 'table-1',
      );
      final item = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      // Llevar pedido a estado closed (terminal).
      await orderRepo.updateStatus(order.id, OrderStatus.closed);

      await expectLater(
        orderRepo.updateItemStatus(item.id, OrderItemStatus.preparing),
        throwsA(isA<StateError>()),
      );
    });

    test('lanza ArgumentError si el itemId no existe', () async {
      await expectLater(
        orderRepo.updateItemStatus('no-existe', OrderItemStatus.preparing),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─── watchActiveOrders ────────────────────────────────────────────────────

  group('watchActiveOrders', () {
    test('devuelve solo pedidos en sent, preparing o ready', () async {
      // Pedidos con distintos estados.
      final open = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-open',
      ); // open
      final sent = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-sent',
      );
      await orderRepo.updateStatus(sent.id, OrderStatus.sent);

      final preparing = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-preparing',
      );
      await orderRepo.updateStatus(preparing.id, OrderStatus.preparing);

      final ready = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-ready',
      );
      await orderRepo.updateStatus(ready.id, OrderStatus.ready);

      final closed = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-closed',
      );
      await orderRepo.updateStatus(closed.id, OrderStatus.closed);

      final result = await orderRepo.watchActiveOrders(kVenue).first;
      final ids = result.map((o) => o.id).toSet();

      expect(ids, contains(sent.id));
      expect(ids, contains(preparing.id));
      expect(ids, contains(ready.id));
      expect(ids, isNot(contains(open.id)));
      expect(ids, isNot(contains(closed.id)));
      expect(result.length, 3);
    });

    test('no incluye pedidos de otros venues', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-1',
      );
      await orderRepo.updateStatus(order.id, OrderStatus.sent);

      await orderRepo
          .createOrder(venueId: 'venue-otro', diningTableId: 't-1')
          .then((o) => orderRepo.updateStatus(o.id, OrderStatus.sent));

      final result = await orderRepo.watchActiveOrders(kVenue).first;
      expect(result.every((o) => o.venueId == kVenue), isTrue);
      expect(result.length, 1);
    });
  });

  // ─── watchNonClosedOrders ─────────────────────────────────────────────────

  group('watchNonClosedOrders', () {
    test(
      'incluye open, sent, preparing y ready; excluye closed y cancelled',
      () async {
        final open = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-1',
        );
        final sent = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-2',
        );
        await orderRepo.updateStatus(sent.id, OrderStatus.sent);
        final closed = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-3',
        );
        await orderRepo.updateStatus(closed.id, OrderStatus.closed);
        final cancelled = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-4',
        );
        await orderRepo.updateStatus(cancelled.id, OrderStatus.cancelled);

        final result = await orderRepo.watchNonClosedOrders(kVenue).first;
        final ids = result.map((o) => o.id).toSet();

        expect(ids, contains(open.id));
        expect(ids, contains(sent.id));
        expect(ids, isNot(contains(closed.id)));
        expect(ids, isNot(contains(cancelled.id)));
        expect(result.length, 2);
      },
    );
  });

  // ─── DiningTableLocalRepository.watchTables ───────────────────────────────

  group('DiningTableLocalRepository.watchTables', () {
    test('devuelve mesas activas ordenadas por sortOrder', () async {
      await insertTable(db, id: 'mesa-3', label: 'Mesa 3', sortOrder: 3);
      await insertTable(db, id: 'mesa-1', label: 'Mesa 1', sortOrder: 1);
      await insertTable(db, id: 'mesa-2', label: 'Mesa 2', sortOrder: 2);

      final result = await tableRepo.watchTables(kVenue).first;

      expect(result.length, 3);
      expect(result[0].id, 'mesa-1');
      expect(result[1].id, 'mesa-2');
      expect(result[2].id, 'mesa-3');
    });

    test('excluye mesas inactivas', () async {
      await insertTable(db, id: 'mesa-activa', label: 'Activa', active: true);
      await insertTable(
        db,
        id: 'mesa-inactiva',
        label: 'Inactiva',
        active: false,
      );

      final result = await tableRepo.watchTables(kVenue).first;
      final ids = result.map((t) => t.id).toList();

      expect(ids, contains('mesa-activa'));
      expect(ids, isNot(contains('mesa-inactiva')));
    });

    test('no incluye mesas de otros venues', () async {
      await insertTable(db, id: 'mesa-propia', label: 'Propia');
      // Insertar mesa de otro venue directamente.
      await db
          .into(db.diningTables)
          .insert(
            DiningTablesCompanion.insert(
              id: 'mesa-ajena',
              venueId: 'venue-otro',
              label: 'Ajena',
            ),
          );

      final result = await tableRepo.watchTables(kVenue).first;
      expect(result.length, 1);
      expect(result.first.id, 'mesa-propia');
    });

    test('retorna lista vacía si no hay mesas activas', () async {
      final result = await tableRepo.watchTables(kVenue).first;
      expect(result, isEmpty);
    });

    test('refleja nuevas mesas insertadas después de la suscripción', () async {
      // Insertar y luego consultar: el stream refleja siempre el estado actual.
      await insertTable(db, id: 'mesa-a', label: 'A', sortOrder: 1);
      final first = await tableRepo.watchTables(kVenue).first;
      expect(first.length, 1);

      await insertTable(db, id: 'mesa-b', label: 'B', sortOrder: 2);
      final second = await tableRepo.watchTables(kVenue).first;
      expect(second.length, 2);
      expect(second.map((t) => t.id), containsAllInOrder(['mesa-a', 'mesa-b']));
    });
  });

  // ─── watchItems ───────────────────────────────────────────────────────────

  group('watchItems', () {
    test('devuelve ítems de un pedido ordenados por id asc', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-1',
      );
      final i1 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      final i2 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem2,
      );

      final items = await orderRepo.watchItems(order.id).first;
      expect(items.length, 2);
      // Orden por id asc (string comparación, UUIDs generados en secuencia).
      final itemIds = items.map((i) => i.id).toList();
      expect(itemIds, containsAllInOrder([i1.id, i2.id].toList()..sort()));
    });

    test('retorna lista vacía si el pedido no tiene ítems', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-1',
      );
      final items = await orderRepo.watchItems(order.id).first;
      expect(items, isEmpty);
    });

    test(
      'refleja nuevos ítems insertados (reactivo por suscripción nueva)',
      () async {
        final order = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-1',
        );

        // Sin ítems: vacío.
        final first = await orderRepo.watchItems(order.id).first;
        expect(first, isEmpty);

        // Agregar ítem; la siguiente suscripción ve el estado actualizado.
        await orderRepo.addItem(orderId: order.id, menuItem: _menuItem1);
        final second = await orderRepo.watchItems(order.id).first;
        expect(second.length, 1);
        expect(second.first.menuItemId, _menuItem1.id);
      },
    );
  });

  // ─── Derivación: casos de borde ───────────────────────────────────────────

  group('derivación de status del pedido (casos borde)', () {
    test(
      'todos los ítems cancelados → no cambia el status del pedido',
      () async {
        final order = await orderRepo.createOrder(
          venueId: kVenue,
          diningTableId: 't-1',
        );
        await orderRepo.updateStatus(order.id, OrderStatus.sent);

        final item = await orderRepo.addItem(
          orderId: order.id,
          menuItem: _menuItem1,
        );
        await orderRepo.updateItemStatus(item.id, OrderItemStatus.cancelled);

        // No hay ítems no-cancelados → el status del pedido no debe cambiar.
        final updatedOrder = await orderRepo.orderById(order.id);
        // El status debe mantenerse en el valor previo (sent).
        expect(updatedOrder!.status, OrderStatus.sent);
      },
    );

    test('mezcla preparing y ready → pedido en preparing', () async {
      final order = await orderRepo.createOrder(
        venueId: kVenue,
        diningTableId: 't-1',
      );
      await orderRepo.updateStatus(order.id, OrderStatus.sent);

      final item1 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem1,
      );
      final item2 = await orderRepo.addItem(
        orderId: order.id,
        menuItem: _menuItem2,
      );

      await orderRepo.updateItemStatus(item1.id, OrderItemStatus.preparing);
      await orderRepo.updateItemStatus(item2.id, OrderItemStatus.ready);

      final updatedOrder = await orderRepo.orderById(order.id);
      // Hay un preparing y un ready → pedido en preparing.
      expect(updatedOrder!.status, OrderStatus.preparing);
    });
  });
}
