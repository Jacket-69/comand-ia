/// Adopción local de los timestamps del servidor tras un sync exitoso (LWW).
///
/// Paso 6 del flujo offline-first: el servidor retorna `updated_at` y el
/// espejo local lo adopta. El cliente nunca genera esos timestamps (ADR-0008).
/// La implementación concreta es [DriftSyncLocalReconciler] en data/local/.
abstract class SyncLocalReconciler {
  /// Adopta el `updated_at` del servidor para un pedido local.
  ///
  /// Si la fila local ya no existe, no hace nada.
  Future<void> markOrderSynced(String orderId, DateTime serverUpdatedAt);

  /// Adopta el `updated_at` del servidor para un ítem de pedido local.
  ///
  /// Si la fila local ya no existe, no hace nada.
  Future<void> markOrderItemSynced(
    String orderItemId,
    DateTime serverUpdatedAt,
  );
}
