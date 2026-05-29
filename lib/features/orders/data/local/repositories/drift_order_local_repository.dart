import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/domain/repositories/order_local_repository.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Implementación Drift de [OrderLocalRepository].
///
/// ACID-3: [totalCents] se recalcula en [addItem] como espejo del trigger
/// Postgres [compute_order_total]: SUM(priceCentsSnapshot × quantity) de ítems
/// con status != cancelled. El cliente nunca escribe totalCents directamente.
///
/// ACID-2: [nameSnapshot] y [priceCentsSnapshot] se fijan desde [menuItem] al
/// INSERT y son inmutables.
class DriftOrderLocalRepository implements OrderLocalRepository {
  DriftOrderLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<CustomerOrder> createOrder({
    required String venueId,
    required String diningTableId,
    String? openedBy,
  }) async {
    final id = _uuid.v4();
    final openedAt = DateTime.now();

    final companion = CustomerOrdersCompanion.insert(
      id: id,
      venueId: venueId,
      diningTableId: diningTableId,
      openedAt: openedAt,
      openedBy: Value(openedBy),
    );

    await _db.into(_db.customerOrders).insert(companion);

    final row =
        await (_db.select(_db.customerOrders)
          ..where((t) => t.id.equals(id))).getSingle();

    return customerOrderFromRow(row);
  }

  @override
  Future<OrderItem> addItem({
    required String orderId,
    required MenuItem menuItem,
    int quantity = 1,
    String? comments,
  }) async {
    // Recupera el pedido para obtener venueId
    final orderRow =
        await (_db.select(_db.customerOrders)
          ..where((t) => t.id.equals(orderId))).getSingle();

    final itemId = _uuid.v4();

    // ACID-2: snapshots fijados desde menuItem al momento del INSERT
    final companion = OrderItemsCompanion.insert(
      id: itemId,
      venueId: orderRow.venueId,
      orderId: orderId,
      menuItemId: menuItem.id,
      nameSnapshot: menuItem.name,
      priceCentsSnapshot: menuItem.priceCents,
      quantity: Value(quantity),
      comments: Value(comments),
    );

    await _db.into(_db.orderItems).insert(companion);

    // ACID-3: recalcula totalCents del pedido (espejo de compute_order_total)
    await _recalculateTotal(orderId);

    final itemRow =
        await (_db.select(_db.orderItems)
          ..where((t) => t.id.equals(itemId))).getSingle();

    return orderItemFromRow(itemRow);
  }

  @override
  Future<CustomerOrder?> orderById(String id) async {
    final rows =
        await (_db.select(_db.customerOrders)
          ..where((t) => t.id.equals(id))).get();

    if (rows.isEmpty) return null;
    return customerOrderFromRow(rows.first);
  }

  @override
  Future<List<OrderItem>> itemsOf(String orderId) async {
    final rows =
        await (_db.select(_db.orderItems)
          ..where((t) => t.orderId.equals(orderId))).get();
    return rows.map(orderItemFromRow).toList();
  }

  @override
  Stream<List<CustomerOrder>> watchOpenOrders(String venueId) {
    return (_db.select(_db.customerOrders)
          ..where(
            (t) =>
                t.venueId.equals(venueId) &
                t.status.equals(OrderStatus.open.toDb()),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.openedAt)]))
        .watch()
        .map((rows) => rows.map(customerOrderFromRow).toList());
  }

  @override
  Future<CustomerOrder> updateStatus(String orderId, OrderStatus status) async {
    // ACID-4: el estado `closed` es terminal; no se puede modificar.
    final current = await orderById(orderId);
    if (current == null) {
      throw ArgumentError('Pedido no encontrado: $orderId');
    }
    if (current.status == OrderStatus.closed) {
      throw StateError(
        'El pedido $orderId está cerrado (ACID-4); no se puede cambiar su estado.',
      );
    }

    await (_db.update(_db.customerOrders)..where(
      (t) => t.id.equals(orderId),
    )).write(CustomerOrdersCompanion(status: Value(status.toDb())));

    final row =
        await (_db.select(_db.customerOrders)
          ..where((t) => t.id.equals(orderId))).getSingle();
    return customerOrderFromRow(row);
  }

  /// Recalcula [CustomerOrderRow.totalCents] = SUM(priceCentsSnapshot × quantity)
  /// de ítems con status != cancelled. Espejo del trigger Postgres.
  Future<void> _recalculateTotal(String orderId) async {
    final items =
        await (_db.select(_db.orderItems)..where(
          (t) =>
              t.orderId.equals(orderId) &
              t.status.isNotValue(OrderItemStatus.cancelled.toDb()),
        )).get();

    final total = items.fold<int>(
      0,
      (acc, row) => acc + row.priceCentsSnapshot * row.quantity,
    );

    await (_db.update(_db.customerOrders)..where(
      (t) => t.id.equals(orderId),
    )).write(CustomerOrdersCompanion(totalCents: Value(total)));
  }
}
