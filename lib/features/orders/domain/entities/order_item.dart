import 'package:equatable/equatable.dart';

/// Estado de un ítem dentro de un pedido.
///
/// Valores espejados del ENUM `order_item_status` en Supabase.
/// Se almacena como text en Drift; conversión via [OrderItemStatus.fromDb]/[OrderItemStatus.toDb].
enum OrderItemStatus {
  /// Ítem enviado a cocina.
  sent,

  /// Cocina está preparando el ítem.
  preparing,

  /// Ítem listo para servir.
  ready,

  /// Ítem cancelado. No suma al total del pedido.
  cancelled;

  /// Convierte el valor de texto de la BD a [OrderItemStatus].
  static OrderItemStatus fromDb(String value) => switch (value) {
    'sent' => OrderItemStatus.sent,
    'preparing' => OrderItemStatus.preparing,
    'ready' => OrderItemStatus.ready,
    'cancelled' => OrderItemStatus.cancelled,
    _ => throw ArgumentError('OrderItemStatus desconocido: $value'),
  };

  /// Convierte [OrderItemStatus] al texto usado en la BD.
  String toDb() => name;
}

/// Línea de un pedido: referencia un ítem del menú con snapshots inmutables.
///
/// Mapea a `order_item` en Supabase y `OrderItems` en Drift local.
///
/// ACID-2: [nameSnapshot] y [priceCentsSnapshot] se fijan desde el menú al
/// momento del INSERT y no cambian. Editar el menú no afecta pedidos pasados.
class OrderItem extends Equatable {
  const OrderItem({
    required this.id,
    required this.venueId,
    required this.orderId,
    required this.menuItemId,
    required this.nameSnapshot,
    required this.priceCentsSnapshot,
    required this.quantity,
    required this.status,
    this.comments,
    this.updatedAt,
  });

  /// UUID del ítem de pedido (generado en cliente, compartido con Supabase).
  final String id;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// UUID del pedido al que pertenece.
  final String orderId;

  /// UUID del ítem de menú referenciado.
  final String menuItemId;

  /// Nombre del ítem en el momento del pedido (inmutable — ACID-2).
  final String nameSnapshot;

  /// Precio en centavos en el momento del pedido (inmutable — ACID-2). Nunca float.
  final int priceCentsSnapshot;

  /// Cantidad pedida.
  final int quantity;

  /// Estado del ítem en cocina.
  final OrderItemStatus status;

  /// Comentario libre del garzón (ej. "sin cebolla").
  final String? comments;

  /// Timestamp del servidor (usado para LWW). Nullable hasta que haya sync.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    venueId,
    orderId,
    menuItemId,
    nameSnapshot,
    priceCentsSnapshot,
    quantity,
    status,
    comments,
    updatedAt,
  ];
}
