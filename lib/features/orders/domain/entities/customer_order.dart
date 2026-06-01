import 'package:equatable/equatable.dart';

/// Estado del pedido en su ciclo de vida.
///
/// Valores espejados del ENUM `order_status` en Supabase.
/// Se almacena como text en Drift; conversión via [OrderStatus.fromDb]/[OrderStatus.toDb].
enum OrderStatus {
  /// Pedido recién creado; el garzón puede agregar/quitar ítems.
  open,

  /// Pedido enviado a cocina; visible en KDS.
  sent,

  /// Cocina está preparando el pedido.
  preparing,

  /// Pedido listo para servir.
  ready,

  /// Pedido cobrado y cerrado. Estado terminal — no se puede modificar (ACID-4).
  closed,

  /// Pedido cancelado. No suma al total.
  cancelled;

  /// Convierte el valor de texto de la BD a [OrderStatus].
  static OrderStatus fromDb(String value) => switch (value) {
    'open' => OrderStatus.open,
    'sent' => OrderStatus.sent,
    'preparing' => OrderStatus.preparing,
    'ready' => OrderStatus.ready,
    'closed' => OrderStatus.closed,
    'cancelled' => OrderStatus.cancelled,
    _ => throw ArgumentError('OrderStatus desconocido: $value'),
  };

  /// Convierte [OrderStatus] al texto usado en la BD.
  String toDb() => name;
}

/// Método de pago del pedido al cierre.
///
/// Valores espejados del ENUM `payment_method` en Supabase.
/// Se almacena como text en Drift; conversión via [PaymentMethod.fromDb]/[PaymentMethod.toDb].
enum PaymentMethod {
  /// Pago en efectivo.
  cash,

  /// Pago con tarjeta (débito o crédito).
  card,

  /// Transferencia bancaria.
  transfer,

  /// Otro método no clasificado.
  other;

  /// Convierte el valor de texto de la BD a [PaymentMethod].
  static PaymentMethod fromDb(String value) => switch (value) {
    'cash' => PaymentMethod.cash,
    'card' => PaymentMethod.card,
    'transfer' => PaymentMethod.transfer,
    'other' => PaymentMethod.other,
    _ => throw ArgumentError('PaymentMethod desconocido: $value'),
  };

  /// Convierte [PaymentMethod] al texto usado en la BD.
  String toDb() => name;
}

/// Pedido de un cliente vinculado a una mesa.
///
/// Mapea a `customer_order` en Supabase y `CustomerOrders` en Drift local.
/// Renombrado de `order` para evitar colisión con SQL (convención canónica).
///
/// ACID-3: [totalCents] lo recalcula el repositorio desde los ítems.
/// La UI nunca escribe [totalCents] directamente.
/// [tipCents] es la propina del comensal; es independiente de [totalCents] y
/// jamás entra en el cálculo del total (ACID-3).
class CustomerOrder extends Equatable {
  const CustomerOrder({
    required this.id,
    required this.venueId,
    required this.diningTableId,
    required this.status,
    required this.openedAt,
    required this.totalCents,
    this.openedBy,
    this.closedAt,
    this.paymentMethod,
    this.tipCents = 0,
    this.notes,
    this.updatedAt,
  });

  /// UUID del pedido (generado en cliente, compartido con Supabase).
  final String id;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// UUID de la mesa asociada.
  final String diningTableId;

  /// Estado actual del pedido.
  final OrderStatus status;

  /// UUID del usuario que abrió el pedido (nullable: el sistema puede abrirlo).
  final String? openedBy;

  /// Timestamp de apertura del pedido.
  final DateTime openedAt;

  /// Timestamp de cierre (solo cuando status == closed).
  final DateTime? closedAt;

  /// Total en centavos, recalculado por el repositorio (ACID-3).
  /// Suma de [priceCentsSnapshot] × quantity de ítems con status != cancelled.
  final int totalCents;

  /// Método de pago (solo cuando status == closed).
  final PaymentMethod? paymentMethod;

  /// Propina en centavos (CLP × 100). Separada de [totalCents] — ACID-3:
  /// el total del pedido nunca incluye la propina. La decide el comensal al cierre.
  final int tipCents;

  /// Notas libres opcionales del pedido.
  final String? notes;

  /// Timestamp del servidor (usado para LWW). Nullable hasta que haya sync.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    venueId,
    diningTableId,
    status,
    openedBy,
    openedAt,
    closedAt,
    totalCents,
    paymentMethod,
    tipCents,
    notes,
    updatedAt,
  ];
}
