import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:drift/drift.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';

/// Conversores entre filas Drift y entidades de dominio.
///
/// Centralizar aquí la lógica de mapping evita duplicación y facilita los tests.
/// Las conversiones enum <-> text también viven en las entidades de dominio
/// (fromDb / toDb) para que sean testeables independientemente.

// ── MenuCategory ─────────────────────────────────────────────────────────────

/// Convierte una fila Drift [MenuCategoryRow] a entidad de dominio [MenuCategory].
MenuCategory menuCategoryFromRow(MenuCategoryRow row) => MenuCategory(
  id: row.id,
  venueId: row.venueId,
  name: row.name,
  sortOrder: row.sortOrder,
  active: row.active,
  updatedAt: row.updatedAt,
);

/// Convierte una entidad [MenuCategory] a companion Drift para INSERT/UPDATE.
MenuCategoriesCompanion menuCategoryToCompanion(MenuCategory entity) =>
    MenuCategoriesCompanion.insert(
      id: entity.id,
      venueId: entity.venueId,
      name: entity.name,
      sortOrder: Value(entity.sortOrder),
      active: Value(entity.active),
      updatedAt: Value(entity.updatedAt),
    );

// ── MenuItem ──────────────────────────────────────────────────────────────────

/// Convierte una fila Drift [MenuItemRow] a entidad de dominio [MenuItem].
MenuItem menuItemFromRow(MenuItemRow row) => MenuItem(
  id: row.id,
  venueId: row.venueId,
  categoryId: row.categoryId,
  name: row.name,
  description: row.description,
  priceCents: row.priceCents,
  active: row.active,
  imageUrl: row.imageUrl,
  sortOrder: row.sortOrder,
  updatedAt: row.updatedAt,
);

/// Convierte una entidad [MenuItem] a companion Drift para INSERT/UPDATE.
MenuItemsCompanion menuItemToCompanion(MenuItem entity) =>
    MenuItemsCompanion.insert(
      id: entity.id,
      venueId: entity.venueId,
      categoryId: entity.categoryId,
      name: entity.name,
      description: entity.description,
      priceCents: entity.priceCents,
      active: Value(entity.active),
      imageUrl: Value(entity.imageUrl),
      sortOrder: Value(entity.sortOrder),
      updatedAt: Value(entity.updatedAt),
    );

// ── DiningTable ───────────────────────────────────────────────────────────────

/// Convierte una fila Drift [DiningTableRow] a entidad de dominio [DiningTable].
DiningTable diningTableFromRow(DiningTableRow row) => DiningTable(
  id: row.id,
  venueId: row.venueId,
  label: row.label,
  capacity: row.capacity,
  active: row.active,
  sortOrder: row.sortOrder,
  updatedAt: row.updatedAt,
);

/// Convierte una entidad [DiningTable] a companion Drift para INSERT/UPDATE.
DiningTablesCompanion diningTableToCompanion(DiningTable entity) =>
    DiningTablesCompanion.insert(
      id: entity.id,
      venueId: entity.venueId,
      label: entity.label,
      capacity: Value(entity.capacity),
      active: Value(entity.active),
      sortOrder: Value(entity.sortOrder),
      updatedAt: Value(entity.updatedAt),
    );

// ── CustomerOrder ─────────────────────────────────────────────────────────────

/// Convierte una fila Drift [CustomerOrderRow] a entidad de dominio [CustomerOrder].
CustomerOrder customerOrderFromRow(CustomerOrderRow row) => CustomerOrder(
  id: row.id,
  venueId: row.venueId,
  diningTableId: row.diningTableId,
  status: OrderStatus.fromDb(row.status),
  openedBy: row.openedBy,
  openedAt: row.openedAt,
  closedAt: row.closedAt,
  totalCents: row.totalCents,
  paymentMethod:
      row.paymentMethod != null
          ? PaymentMethod.fromDb(row.paymentMethod!)
          : null,
  notes: row.notes,
  updatedAt: row.updatedAt,
);

/// Convierte una entidad [CustomerOrder] a companion Drift para INSERT/UPDATE.
CustomerOrdersCompanion customerOrderToCompanion(CustomerOrder entity) =>
    CustomerOrdersCompanion.insert(
      id: entity.id,
      venueId: entity.venueId,
      diningTableId: entity.diningTableId,
      status: Value(entity.status.toDb()),
      openedBy: Value(entity.openedBy),
      openedAt: entity.openedAt,
      closedAt: Value(entity.closedAt),
      totalCents: Value(entity.totalCents),
      paymentMethod: Value(entity.paymentMethod?.toDb()),
      notes: Value(entity.notes),
      updatedAt: Value(entity.updatedAt),
    );

// ── OrderItem ─────────────────────────────────────────────────────────────────

/// Convierte una fila Drift [OrderItemRow] a entidad de dominio [OrderItem].
OrderItem orderItemFromRow(OrderItemRow row) => OrderItem(
  id: row.id,
  venueId: row.venueId,
  orderId: row.orderId,
  menuItemId: row.menuItemId,
  nameSnapshot: row.nameSnapshot,
  priceCentsSnapshot: row.priceCentsSnapshot,
  quantity: row.quantity,
  status: OrderItemStatus.fromDb(row.status),
  comments: row.comments,
  updatedAt: row.updatedAt,
);

/// Convierte una entidad [OrderItem] a companion Drift para INSERT/UPDATE.
OrderItemsCompanion orderItemToCompanion(OrderItem entity) =>
    OrderItemsCompanion.insert(
      id: entity.id,
      venueId: entity.venueId,
      orderId: entity.orderId,
      menuItemId: entity.menuItemId,
      nameSnapshot: entity.nameSnapshot,
      priceCentsSnapshot: entity.priceCentsSnapshot,
      quantity: Value(entity.quantity),
      comments: Value(entity.comments),
      status: Value(entity.status.toDb()),
      updatedAt: Value(entity.updatedAt),
    );

// ── PendingOp ─────────────────────────────────────────────────────────────────

/// Convierte una fila Drift [PendingOpRow] a entidad de dominio [PendingOp].
PendingOp pendingOpFromRow(PendingOpRow row) => PendingOp(
  id: row.id,
  venueId: row.venueId,
  opType: PendingOpType.fromDb(row.opType),
  payload: row.payload,
  createdAt: row.createdAt,
  attempts: row.attempts,
);
