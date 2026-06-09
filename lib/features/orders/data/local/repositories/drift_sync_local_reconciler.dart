import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_local_reconciler.dart';
import 'package:drift/drift.dart';

/// Implementación Drift de [SyncLocalReconciler].
///
/// Adopta los `updated_at` retornados por el servidor tras un sync exitoso
/// (LWW, ADR-0008). El cliente nunca genera estos timestamps; si la fila
/// local ya no existe, el write afecta 0 filas y no es un error.
class DriftSyncLocalReconciler implements SyncLocalReconciler {
  const DriftSyncLocalReconciler(this._db);

  final AppDatabase _db;

  @override
  Future<void> markOrderSynced(String orderId, DateTime serverUpdatedAt) async {
    await (_db.update(_db.customerOrders)..where(
      (t) => t.id.equals(orderId),
    )).write(CustomerOrdersCompanion(updatedAt: Value(serverUpdatedAt)));
  }

  @override
  Future<void> markOrderItemSynced(
    String orderItemId,
    DateTime serverUpdatedAt,
  ) async {
    await (_db.update(_db.orderItems)..where(
      (t) => t.id.equals(orderItemId),
    )).write(OrderItemsCompanion(updatedAt: Value(serverUpdatedAt)));
  }
}
