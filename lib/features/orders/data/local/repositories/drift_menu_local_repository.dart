import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/repositories/menu_local_repository.dart';
import 'package:drift/drift.dart';

/// Implementación Drift de [MenuLocalRepository].
///
/// Usa upsert (insertOrReplace) para que cachear sea idempotente:
/// una sync posterior sobreescribe con datos frescos del servidor.
class DriftMenuLocalRepository implements MenuLocalRepository {
  const DriftMenuLocalRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> cacheCategories(List<MenuCategory> categories) async {
    // Upsert en lote: reemplaza si el id ya existe
    await _db.batch((batch) {
      for (final category in categories) {
        batch.insertAll(_db.menuCategories, [
          menuCategoryToCompanion(category),
        ], mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<List<MenuCategory>> categories(String venueId) async {
    final rows =
        await (_db.select(_db.menuCategories)
              ..where((t) => t.venueId.equals(venueId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(menuCategoryFromRow).toList();
  }

  @override
  Future<void> cacheItems(List<MenuItem> items) async {
    await _db.batch((batch) {
      for (final item in items) {
        batch.insertAll(_db.menuItems, [
          menuItemToCompanion(item),
        ], mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<List<MenuItem>> itemsByCategory(
    String venueId,
    String categoryId,
  ) async {
    final rows =
        await (_db.select(_db.menuItems)
              ..where(
                (t) =>
                    t.venueId.equals(venueId) & t.categoryId.equals(categoryId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(menuItemFromRow).toList();
  }

  @override
  Stream<List<MenuItem>> watchItems(String venueId) {
    return (_db.select(_db.menuItems)
          ..where((t) => t.venueId.equals(venueId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(menuItemFromRow).toList());
  }
}
