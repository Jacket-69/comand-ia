import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MenuCategory mappers', () {
    test('menuCategoryToCompanion / menuCategoryFromRow round-trip', () async {
      final entity = MenuCategory(
        id: 'cat-uuid-1',
        venueId: 'venue-1',
        name: 'Entradas',
        sortOrder: 2,
        active: false,
        updatedAt: DateTime(2026, 5, 28),
      );

      final companion = menuCategoryToCompanion(entity);
      await db.into(db.menuCategories).insert(companion);

      final row =
          await (db.select(db.menuCategories)
            ..where((t) => t.id.equals('cat-uuid-1'))).getSingle();

      final result = menuCategoryFromRow(row);

      expect(result.id, entity.id);
      expect(result.venueId, entity.venueId);
      expect(result.name, entity.name);
      expect(result.sortOrder, entity.sortOrder);
      expect(result.active, entity.active);
      expect(result.updatedAt, entity.updatedAt);
    });
  });

  group('MenuItem mappers', () {
    test('menuItemToCompanion / menuItemFromRow round-trip', () async {
      final entity = MenuItem(
        id: 'item-uuid-1',
        venueId: 'venue-1',
        categoryId: 'cat-1',
        name: 'Empanada de Pino',
        description: 'Empanada frita con pino de vacuno.',
        priceCents: 2500,
        active: true,
        imageUrl: 'https://example.com/empanada.jpg',
        sortOrder: 1,
        updatedAt: DateTime(2026, 5, 28),
      );

      final companion = menuItemToCompanion(entity);
      await db.into(db.menuItems).insert(companion);

      final row =
          await (db.select(db.menuItems)
            ..where((t) => t.id.equals('item-uuid-1'))).getSingle();

      final result = menuItemFromRow(row);

      expect(result.id, entity.id);
      expect(result.priceCents, entity.priceCents);
      expect(result.imageUrl, entity.imageUrl);
      expect(result.priceCents, isA<int>());
    });
  });

  group('DiningTable mappers', () {
    test('diningTableToCompanion / diningTableFromRow round-trip', () async {
      final entity = DiningTable(
        id: 'table-uuid-1',
        venueId: 'venue-1',
        label: 'Mesa 7',
        capacity: 6,
        active: true,
        sortOrder: 7,
        updatedAt: DateTime(2026, 5, 28),
      );

      final companion = diningTableToCompanion(entity);
      await db.into(db.diningTables).insert(companion);

      final row =
          await (db.select(db.diningTables)
            ..where((t) => t.id.equals('table-uuid-1'))).getSingle();

      final result = diningTableFromRow(row);

      expect(result.id, entity.id);
      expect(result.label, entity.label);
      expect(result.capacity, entity.capacity);
    });
  });

  group('CustomerOrder mappers', () {
    test(
      'customerOrderToCompanion / customerOrderFromRow round-trip open order',
      () async {
        final now = DateTime(2026, 5, 28, 10);
        final entity = CustomerOrder(
          id: 'order-uuid-1',
          venueId: 'venue-1',
          diningTableId: 'table-1',
          status: OrderStatus.open,
          openedAt: now,
          totalCents: 0,
        );

        final companion = customerOrderToCompanion(entity);
        await db.into(db.customerOrders).insert(companion);

        final row =
            await (db.select(db.customerOrders)
              ..where((t) => t.id.equals('order-uuid-1'))).getSingle();

        final result = customerOrderFromRow(row);

        expect(result.id, entity.id);
        expect(result.status, OrderStatus.open);
        expect(result.totalCents, isA<int>());
        expect(result.paymentMethod, isNull);
        expect(result.closedAt, isNull);
      },
    );

    test('customerOrderFromRow con paymentMethod y closedAt', () async {
      final now = DateTime(2026, 5, 28, 10);
      final closed = now.add(const Duration(hours: 1));
      final entity = CustomerOrder(
        id: 'order-uuid-2',
        venueId: 'venue-1',
        diningTableId: 'table-1',
        status: OrderStatus.closed,
        openedAt: now,
        closedAt: closed,
        totalCents: 7500,
        paymentMethod: PaymentMethod.card,
        notes: 'mesa VIP',
      );

      final companion = customerOrderToCompanion(entity);
      await db.into(db.customerOrders).insert(companion);

      final row =
          await (db.select(db.customerOrders)
            ..where((t) => t.id.equals('order-uuid-2'))).getSingle();

      final result = customerOrderFromRow(row);

      expect(result.status, OrderStatus.closed);
      expect(result.paymentMethod, PaymentMethod.card);
      expect(result.totalCents, 7500);
      expect(result.notes, 'mesa VIP');
    });
  });

  group('OrderItem mappers', () {
    test('orderItemToCompanion / orderItemFromRow round-trip', () async {
      final entity = OrderItem(
        id: 'oi-uuid-1',
        venueId: 'venue-1',
        orderId: 'order-1',
        menuItemId: 'menu-1',
        nameSnapshot: 'Lomo al Jugo',
        priceCentsSnapshot: 8900,
        quantity: 2,
        status: OrderItemStatus.preparing,
        comments: 'sin papa',
        updatedAt: DateTime(2026, 5, 28),
      );

      final companion = orderItemToCompanion(entity);
      await db.into(db.orderItems).insert(companion);

      final row =
          await (db.select(db.orderItems)
            ..where((t) => t.id.equals('oi-uuid-1'))).getSingle();

      final result = orderItemFromRow(row);

      expect(result.nameSnapshot, entity.nameSnapshot);
      expect(result.priceCentsSnapshot, entity.priceCentsSnapshot);
      expect(result.priceCentsSnapshot, isA<int>());
      expect(result.status, OrderItemStatus.preparing);
      expect(result.comments, 'sin papa');
    });
  });

  group('PendingOp mappers', () {
    test('pendingOpFromRow convierte correctamente una fila', () async {
      await db
          .into(db.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              venueId: 'venue-1',
              opType: 'create_order',
              payload: '{"order_id":"x"}',
            ),
          );

      final row = await db.select(db.pendingOps).getSingle();
      final result = pendingOpFromRow(row);

      expect(result.venueId, 'venue-1');
      expect(result.opType, PendingOpType.createOrder);
      expect(result.payload, '{"order_id":"x"}');
      expect(result.attempts, 0);
      expect(result.id, greaterThan(0));
    });
  });
}
