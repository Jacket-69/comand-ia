import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';

/// Contrato de acceso local (Drift) al menú.
///
/// La implementación concreta es [DriftMenuLocalRepository] en data/.
/// Este archivo no importa Flutter ni Drift — solo entidades de dominio.
abstract class MenuLocalRepository {
  /// Reemplaza la caché local de categorías con la lista sincronizada.
  Future<void> cacheCategories(List<MenuCategory> categories);

  /// Retorna todas las categorías activas de un venue, ordenadas por [sortOrder].
  Future<List<MenuCategory>> categories(String venueId);

  /// Reemplaza la caché local de ítems con la lista sincronizada.
  Future<void> cacheItems(List<MenuItem> items);

  /// Retorna los ítems activos de una categoría para un venue.
  Future<List<MenuItem>> itemsByCategory(String venueId, String categoryId);

  /// Stream reactivo de todos los ítems activos de un venue.
  Stream<List<MenuItem>> watchItems(String venueId);
}
