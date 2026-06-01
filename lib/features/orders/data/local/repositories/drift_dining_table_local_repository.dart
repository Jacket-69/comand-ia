import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/domain/repositories/dining_table_local_repository.dart';
import 'package:drift/drift.dart';

/// Implementación Drift de [DiningTableLocalRepository].
class DriftDiningTableLocalRepository implements DiningTableLocalRepository {
  DriftDiningTableLocalRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<DiningTable>> watchTables(String venueId) {
    return (_db.select(_db.diningTables)
          ..where((t) => t.venueId.equals(venueId) & t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(diningTableFromRow).toList());
  }
}
