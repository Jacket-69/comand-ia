import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_dining_table_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_menu_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/repositories/dining_table_local_repository.dart';
import 'package:comand_ia/features/orders/domain/repositories/menu_local_repository.dart';
import 'package:comand_ia/features/orders/domain/repositories/order_local_repository.dart';
import 'package:comand_ia/features/orders/domain/repositories/pending_op_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton de [AppDatabase] para toda la app.
///
/// Para tests: hacer override con `AppDatabase.forTesting(NativeDatabase.memory())`.
/// Ver tests de pedido en `test/order_controller_test.dart`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Cierra la conexión al destruir el provider (cleanup lifecycle).
  ref.onDispose(db.close);
  return db;
});

/// Repositorio local de menú (categorías e ítems).
final menuLocalRepositoryProvider = Provider<MenuLocalRepository>((ref) {
  return DriftMenuLocalRepository(ref.watch(appDatabaseProvider));
});

/// Repositorio local de pedidos.
final orderLocalRepositoryProvider = Provider<OrderLocalRepository>((ref) {
  return DriftOrderLocalRepository(ref.watch(appDatabaseProvider));
});

/// Cola FIFO de operaciones pendientes de sincronización.
final pendingOpQueueProvider = Provider<PendingOpQueue>((ref) {
  return DriftPendingOpQueue(ref.watch(appDatabaseProvider));
});

/// Repositorio local de mesas.
final diningTableLocalRepositoryProvider = Provider<DiningTableLocalRepository>(
  (ref) {
    return DriftDiningTableLocalRepository(ref.watch(appDatabaseProvider));
  },
);
