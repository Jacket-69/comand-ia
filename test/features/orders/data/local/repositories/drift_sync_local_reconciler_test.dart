import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_sync_local_reconciler.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftSyncLocalReconciler reconciler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reconciler = DriftSyncLocalReconciler(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedOrder(String id, {DateTime? updatedAt}) {
    return db
        .into(db.customerOrders)
        .insert(
          CustomerOrdersCompanion.insert(
            id: id,
            venueId: 'venue-1',
            diningTableId: 'table-1',
            openedAt: DateTime.utc(2026, 6, 9, 10),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<void> seedItem(String id, String orderId) {
    return db
        .into(db.orderItems)
        .insert(
          OrderItemsCompanion.insert(
            id: id,
            venueId: 'venue-1',
            orderId: orderId,
            menuItemId: 'menu-1',
            nameSnapshot: 'Lomo',
            priceCentsSnapshot: 1500,
          ),
        );
  }

  Future<CustomerOrderRow> order(String id) =>
      (db.select(db.customerOrders)..where((t) => t.id.equals(id))).getSingle();

  Future<OrderItemRow> item(String id) =>
      (db.select(db.orderItems)..where((t) => t.id.equals(id))).getSingle();

  group('markOrderSynced (LWW, ADR-0008)', () {
    test('adopta el updated_at del servidor en el pedido local', () async {
      await seedOrder('order-1');
      final serverTime = DateTime.utc(2026, 6, 9, 12, 30);

      await reconciler.markOrderSynced('order-1', serverTime);

      expect((await order('order-1')).updatedAt!.toUtc(), serverTime);
    });

    test('id inexistente es no-op: 0 filas, sin excepción', () async {
      final original = DateTime.utc(2026, 1, 1);
      await seedOrder('order-1', updatedAt: original);

      // La op pudo borrarse localmente antes del ack del servidor; adoptar el
      // timestamp de una fila que ya no existe no es un error (no debe lanzar).
      await reconciler.markOrderSynced(
        'order-ausente',
        DateTime.utc(2026, 6, 9),
      );

      // La fila existente queda intacta.
      expect((await order('order-1')).updatedAt!.toUtc(), original);
    });

    test('solo toca el pedido del id dado (aislamiento por id)', () async {
      await seedOrder('order-1');
      await seedOrder('order-2');

      await reconciler.markOrderSynced('order-1', DateTime.utc(2026, 6, 9, 14));

      expect((await order('order-2')).updatedAt, isNull);
    });
  });

  group('markOrderItemSynced (LWW, ADR-0008)', () {
    test('adopta el updated_at del servidor en el ítem local', () async {
      await seedOrder('order-1');
      await seedItem('item-1', 'order-1');
      final serverTime = DateTime.utc(2026, 6, 9, 13);

      await reconciler.markOrderItemSynced('item-1', serverTime);

      expect((await item('item-1')).updatedAt!.toUtc(), serverTime);
    });

    test('id inexistente es no-op: 0 filas, sin excepción', () async {
      await reconciler.markOrderItemSynced(
        'item-ausente',
        DateTime.utc(2026, 6, 9),
      );

      expect(await db.select(db.orderItems).get(), isEmpty);
    });
  });
}
