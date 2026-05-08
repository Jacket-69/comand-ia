import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'spike_db.g.dart';

/// Spike DB para validar Drift en Flutter web (IndexedDB) — COMA-004.
///
/// Modela un subset mínimo de `pending_op` (la cola FIFO offline-first) para
/// probar INSERT + SELECT + persistencia entre recargas en Chrome.
/// Se reemplaza por la base real en `lib/features/orders/data/local/` cuando
/// COMA-006 entre a implementación.
@DataClassName('SpikePendingOp')
class SpikePendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get venueId => text()();
  TextColumn get opType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [SpikePendingOps])
class SpikeDatabase extends _$SpikeDatabase {
  SpikeDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> enqueue({
    required String venueId,
    required String opType,
    required String payload,
  }) {
    return into(spikePendingOps).insert(
      SpikePendingOpsCompanion.insert(
        venueId: venueId,
        opType: opType,
        payload: payload,
      ),
    );
  }

  Future<List<SpikePendingOp>> all() {
    return (select(spikePendingOps)
      ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  Future<int> count() async {
    final row =
        await customSelect(
          'SELECT COUNT(*) AS c FROM spike_pending_ops',
          readsFrom: {spikePendingOps},
        ).getSingle();
    return row.read<int>('c');
  }

  Future<void> clearAll() async {
    await delete(spikePendingOps).go();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'coma_004_spike',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
