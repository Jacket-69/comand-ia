import 'package:equatable/equatable.dart';

/// Tipo de operación pendiente de sincronización con Supabase.
///
/// Los valores text usados en BD siguen el formato snake_case que documenta
/// [offline-first.md](../../../../../docs/sync/offline-first.md).
enum PendingOpType {
  /// Creación de un pedido nuevo (incluye sus ítems iniciales).
  createOrder,

  /// Agregado de un ítem a un pedido existente (append mode).
  addOrderItem,

  /// Cambio de estado de un ítem existente (KDS: sent → preparing → ready).
  updateOrderItem,

  /// Cierre de un pedido.
  closeOrder,

  /// Cambio de estado de un pedido.
  updateOrderStatus;

  /// Convierte el valor de texto de la BD a [PendingOpType].
  static PendingOpType fromDb(String value) => switch (value) {
    'create_order' => PendingOpType.createOrder,
    'add_order_item' => PendingOpType.addOrderItem,
    'update_order_item' => PendingOpType.updateOrderItem,
    'close_order' => PendingOpType.closeOrder,
    'update_order_status' => PendingOpType.updateOrderStatus,
    _ => throw ArgumentError('PendingOpType desconocido: $value'),
  };

  /// Convierte [PendingOpType] al texto usado en la BD.
  String toDb() => switch (this) {
    PendingOpType.createOrder => 'create_order',
    PendingOpType.addOrderItem => 'add_order_item',
    PendingOpType.updateOrderItem => 'update_order_item',
    PendingOpType.closeOrder => 'close_order',
    PendingOpType.updateOrderStatus => 'update_order_status',
  };
}

/// Estado de una operación en la cola de sincronización.
///
/// `pending` participa del drenaje FIFO. `dead` quedó descartada por un error
/// permanente del servidor (FK inválida, invariante violado): se conserva para
/// diagnóstico pero la cola sigue avanzando — un error permanente jamás se
/// resuelve reintentando y bloquearía el venue completo (ACID-7 head-of-line).
enum PendingOpStatus {
  /// En cola, esperando sincronización.
  pending,

  /// Descartada por error permanente; conservada para diagnóstico.
  dead;

  /// Convierte el valor de texto de la BD a [PendingOpStatus].
  static PendingOpStatus fromDb(String value) => switch (value) {
    'pending' => PendingOpStatus.pending,
    'dead' => PendingOpStatus.dead,
    _ => throw ArgumentError('PendingOpStatus desconocido: $value'),
  };

  /// Convierte [PendingOpStatus] al texto usado en la BD.
  String toDb() => switch (this) {
    PendingOpStatus.pending => 'pending',
    PendingOpStatus.dead => 'dead',
  };
}

/// Operación pendiente de sincronización con Supabase (cola FIFO local).
///
/// Mapea a `PendingOps` en Drift local únicamente — no existe en Supabase.
/// ACID-7: FIFO estricto por [venueId], ordenado por [id] autoincremental.
class PendingOp extends Equatable {
  const PendingOp({
    required this.id,
    required this.venueId,
    required this.opType,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.status = PendingOpStatus.pending,
    this.lastError,
  });

  /// ID autoincremental (orden de inserción = orden de procesamiento FIFO).
  final int id;

  /// UUID del venue (permite filtrar la cola por tenant).
  final String venueId;

  /// Tipo de operación pendiente.
  final PendingOpType opType;

  /// Cuerpo de la operación serializado como JSON.
  final String payload;

  /// Timestamp local de creación (solo para ordenar, no para LWW).
  final DateTime createdAt;

  /// Número de intentos de sync realizados (base del backoff exponencial).
  final int attempts;

  /// Estado de la operación en la cola ([PendingOpStatus.pending] participa
  /// del drenaje; [PendingOpStatus.dead] quedó descartada por error permanente).
  final PendingOpStatus status;

  /// Último error de sincronización registrado (null si nunca falló).
  final String? lastError;

  @override
  List<Object?> get props => [
    id,
    venueId,
    opType,
    payload,
    createdAt,
    attempts,
    status,
    lastError,
  ];
}
