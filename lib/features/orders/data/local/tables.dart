import 'package:drift/drift.dart';

/// Categorías del menú del local.
///
/// Espejo local de `menu_category` (Supabase). PKs son UUID generados en cliente.
@DataClassName('MenuCategoryRow')
class MenuCategories extends Table {
  /// UUID de la categoría (generado en cliente, compartido con Supabase).
  TextColumn get id => text()();

  /// UUID del venue al que pertenece.
  TextColumn get venueId => text()();

  /// Nombre visible de la categoría.
  TextColumn get name => text()();

  /// Posición relativa para ordenar en la UI.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Si la categoría está activa y visible.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Timestamp del servidor (LWW). Nullable hasta que haya sync.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ítems del menú del local.
///
/// Espejo local de `menu_item` (Supabase). El precio en centavos (int).
@DataClassName('MenuItemRow')
class MenuItems extends Table {
  /// UUID del ítem (generado en cliente, compartido con Supabase).
  TextColumn get id => text()();

  /// UUID del venue al que pertenece.
  TextColumn get venueId => text()();

  /// UUID de la categoría a la que pertenece.
  TextColumn get categoryId => text()();

  /// Nombre del ítem.
  TextColumn get name => text()();

  /// Precio en centavos (CLP × 100). Nunca float.
  IntColumn get priceCents => integer()();

  /// Si el ítem está activo y visible.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// URL de imagen opcional.
  TextColumn get imageUrl => text().nullable()();

  /// Posición relativa para ordenar en la UI.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Timestamp del servidor (LWW). Nullable hasta que haya sync.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mesas del local gastronómico.
///
/// Espejo local de `dining_table` (Supabase).
/// Renombrado de `table` para evitar colisión con SQL (convención canónica).
@DataClassName('DiningTableRow')
class DiningTables extends Table {
  /// UUID de la mesa (generado en cliente, compartido con Supabase).
  TextColumn get id => text()();

  /// UUID del venue al que pertenece.
  TextColumn get venueId => text()();

  /// Etiqueta visible de la mesa (ej. "Mesa 5", "Terraza 2").
  TextColumn get label => text()();

  /// Capacidad máxima de personas.
  IntColumn get capacity => integer().withDefault(const Constant(4))();

  /// Si la mesa está activa y visible en la grilla.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Posición relativa para ordenar en la UI.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Timestamp del servidor (LWW). Nullable hasta que haya sync.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pedidos de clientes vinculados a mesas.
///
/// Espejo local de `customer_order` (Supabase).
/// status y paymentMethod se guardan como text; el mapper convierte a/desde enums.
/// ACID-3: totalCents lo recalcula el repositorio, nunca el cliente directamente.
@DataClassName('CustomerOrderRow')
class CustomerOrders extends Table {
  /// UUID del pedido (generado en cliente, compartido con Supabase).
  TextColumn get id => text()();

  /// UUID del venue al que pertenece.
  TextColumn get venueId => text()();

  /// UUID de la mesa asociada.
  TextColumn get diningTableId => text()();

  /// Estado del pedido como text (mapeado desde/hacia [OrderStatus]).
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// UUID del usuario que abrió el pedido (nullable).
  TextColumn get openedBy => text().nullable()();

  /// Timestamp de apertura del pedido.
  DateTimeColumn get openedAt => dateTime()();

  /// Timestamp de cierre (solo cuando cerrado).
  DateTimeColumn get closedAt => dateTime().nullable()();

  /// Total en centavos, recalculado por el repositorio (ACID-3).
  IntColumn get totalCents => integer().withDefault(const Constant(0))();

  /// Método de pago como text (mapeado desde/hacia [PaymentMethod]). Nullable.
  TextColumn get paymentMethod => text().nullable()();

  /// Notas libres opcionales.
  TextColumn get notes => text().nullable()();

  /// Timestamp del servidor (LWW). Nullable hasta que haya sync.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Líneas de un pedido con snapshots inmutables de precio y nombre.
///
/// Espejo local de `order_item` (Supabase).
/// ACID-2: nameSnapshot y priceCentsSnapshot se fijan al INSERT y no cambian.
@DataClassName('OrderItemRow')
class OrderItems extends Table {
  /// UUID del ítem de pedido (generado en cliente, compartido con Supabase).
  TextColumn get id => text()();

  /// UUID del venue al que pertenece.
  TextColumn get venueId => text()();

  /// UUID del pedido al que pertenece.
  TextColumn get orderId => text()();

  /// UUID del ítem de menú referenciado.
  TextColumn get menuItemId => text()();

  /// Nombre del ítem en el momento del pedido (inmutable — ACID-2).
  TextColumn get nameSnapshot => text()();

  /// Precio en centavos en el momento del pedido (inmutable — ACID-2). Nunca float.
  IntColumn get priceCentsSnapshot => integer()();

  /// Cantidad pedida.
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Comentario libre del garzón (ej. "sin cebolla"). Nullable.
  TextColumn get comments => text().nullable()();

  /// Estado del ítem como text (mapeado desde/hacia [OrderItemStatus]).
  TextColumn get status => text().withDefault(const Constant('sent'))();

  /// Timestamp del servidor (LWW). Nullable hasta que haya sync.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cola FIFO de operaciones pendientes de sincronización con Supabase.
///
/// Solo vive en Drift — no existe en el schema Postgres (verificado por pgTAP).
/// ACID-7: orden de procesamiento = orden de inserción (id asc, por venue).
@DataClassName('PendingOpRow')
class PendingOps extends Table {
  /// ID autoincremental = orden de inserción = orden FIFO de procesamiento.
  IntColumn get id => integer().autoIncrement()();

  /// UUID del venue (permite filtrar la cola por tenant).
  TextColumn get venueId => text()();

  /// Tipo de operación como text (mapeado desde/hacia [PendingOpType]).
  TextColumn get opType => text()();

  /// Cuerpo de la operación serializado como JSON.
  TextColumn get payload => text()();

  /// Timestamp local de creación (solo para ordenar, no para LWW).
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Número de intentos de sync realizados (base del backoff exponencial).
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
