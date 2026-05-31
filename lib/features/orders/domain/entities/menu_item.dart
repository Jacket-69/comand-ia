import 'package:equatable/equatable.dart';

/// Ítem del menú del local.
///
/// Mapea a `menu_item` en Supabase y `MenuItems` en Drift local.
/// El precio siempre en centavos (int), jamás float.
class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.venueId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    this.active = true,
    this.imageUrl,
    this.sortOrder = 0,
    this.updatedAt,
  });

  /// UUID del ítem (generado en cliente, compartido con Supabase).
  final String id;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// UUID de la categoría a la que pertenece.
  final String categoryId;

  /// Nombre del ítem.
  final String name;

  /// Descripción del ítem.
  final String description;

  /// Precio en centavos (CLP × 100). Nunca float.
  final int priceCents;

  /// Si el ítem está activo y visible.
  final bool active;

  /// URL de imagen opcional.
  final String? imageUrl;

  /// Posición relativa para ordenar en la UI.
  final int sortOrder;

  /// Timestamp del servidor (usado para LWW). Nullable hasta que haya sync.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    venueId,
    categoryId,
    name,
    description,
    priceCents,
    active,
    imageUrl,
    sortOrder,
    updatedAt,
  ];
}
