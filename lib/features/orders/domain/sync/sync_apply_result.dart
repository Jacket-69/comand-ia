/// Resultado de aplicar una operación pendiente contra el backend remoto.
///
/// La distinción recuperable/permanente es la que protege el FIFO (ACID-7):
/// un fallo recuperable espera backoff sin perder la op; un rechazo permanente
/// jamás se resuelve reintentando y se descarta a dead-letter para no bloquear
/// la cola del venue. Ante un error desconocido el gateway clasifica como
/// recuperable: nunca se descartan datos por un error no identificado.
sealed class SyncApplyResult {
  const SyncApplyResult();
}

/// La operación quedó aplicada en el servidor (incluye "ya estaba aplicada").
///
/// Trae los `updated_at` que retornó el servidor para que el SyncService
/// los adopte localmente (LWW, paso 6 del flujo de offline-first.md).
class SyncApplied extends SyncApplyResult {
  const SyncApplied({
    this.orderTimestamps = const {},
    this.itemTimestamps = const {},
  });

  /// `customer_order.id` → `updated_at` del servidor.
  final Map<String, DateTime> orderTimestamps;

  /// `order_item.id` → `updated_at` del servidor.
  final Map<String, DateTime> itemTimestamps;
}

/// Rechazo permanente del servidor (FK inválida, invariante violado).
///
/// Reintentar no lo arregla: la op va a dead-letter y la cola sigue.
class SyncRejected extends SyncApplyResult {
  const SyncRejected(this.reason);

  /// Descripción del rechazo (se registra en `pending_op.last_error`).
  final String reason;
}

/// Fallo recuperable (red caída, backend no disponible, sesión inválida).
///
/// La op se mantiene en cola: attempts++ y backoff exponencial.
class SyncUnavailable extends SyncApplyResult {
  const SyncUnavailable(this.reason);

  /// Descripción del fallo (se registra en `pending_op.last_error`).
  final String reason;
}
