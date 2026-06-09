import 'package:comand_ia/features/orders/data/local/tables.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Base de datos Drift local de COMAND-IA.
///
/// Contiene las tablas de menú, mesas, pedidos, ítems y la cola FIFO offline.
/// Patrón de conexión web replicado del spike [SpikeDatabase] (COMA-004).
///
/// Para tests: usar el constructor [AppDatabase.forTesting] con
/// [NativeDatabase.memory()] para aislar cada test en memoria.
@DriftDatabase(
  tables: [
    MenuCategories,
    MenuItems,
    DiningTables,
    CustomerOrders,
    OrderItems,
    PendingOps,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Constructor de producción: persiste en IndexedDB (web) o SQLite (nativo).
  AppDatabase() : super(_openConnection());

  /// Constructor para tests: acepta cualquier [QueryExecutor] (ej. memoria).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v1 → v2: agrega 'description' a menu_items. Aditivo y no destructivo:
      // NO se tocan customer_orders, order_items ni pending_ops, para no perder
      // pedidos abiertos ni la cola FIFO de sincronización offline (ACID-7).
      if (from < 2) {
        await m.addColumn(menuItems, menuItems.description);
      }
      // v2 → v3: agrega 'tip_cents' a customer_orders. Aditivo y no destructivo:
      // la propina es un campo separado de totalCents (ACID-3). El default 0
      // garantiza compatibilidad con pedidos preexistentes en SQLite.
      if (from < 3) {
        await m.addColumn(customerOrders, customerOrders.tipCents);
      }
      // v3 → v4: agrega 'status' y 'last_error' a pending_ops (COMA-008).
      // Aditivo y no destructivo: las ops preexistentes quedan 'pending' por
      // default y siguen participando del drenaje FIFO (ACID-7).
      if (from < 4) {
        await m.addColumn(pendingOps, pendingOps.status);
        await m.addColumn(pendingOps, pendingOps.lastError);
      }
    },
  );
}

/// Abre la conexión según plataforma (web = IndexedDB vía WASM; nativo = SQLite).
///
/// Patrón idéntico al spike de COMA-004 ([SpikeDatabase._openConnection]).
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'comand_ia',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
