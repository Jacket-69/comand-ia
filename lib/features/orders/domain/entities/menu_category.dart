import 'package:equatable/equatable.dart';

/// Categoría de menú del local.
///
/// Mapea a `menu_category` en Supabase y `MenuCategories` en Drift local.
/// Agrupa ítems de menú con el mismo tipo (ej. "Bebidas", "Fondos").
class MenuCategory extends Equatable {
  const MenuCategory({
    required this.id,
    required this.venueId,
    required this.name,
    this.sortOrder = 0,
    this.active = true,
    this.updatedAt,
  });

  /// UUID de la categoría (generado en cliente, compartido con Supabase).
  final String id;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// Nombre visible de la categoría.
  final String name;

  /// Posición relativa para ordenar en la UI.
  final int sortOrder;

  /// Si la categoría está activa y visible.
  final bool active;

  /// Timestamp del servidor (usado para LWW). Nullable hasta que haya sync.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, venueId, name, sortOrder, active, updatedAt];
}
