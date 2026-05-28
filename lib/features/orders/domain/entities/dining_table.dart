import 'package:equatable/equatable.dart';

/// Mesa del local gastronómico.
///
/// Mapea a `dining_table` en Supabase y `DiningTables` en Drift local.
/// Renombrado de `table` para evitar colisión con SQL (convención canónica).
class DiningTable extends Equatable {
  const DiningTable({
    required this.id,
    required this.venueId,
    required this.label,
    this.capacity = 4,
    this.active = true,
    this.sortOrder = 0,
    this.updatedAt,
  });

  /// UUID de la mesa (generado en cliente, compartido con Supabase).
  final String id;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// Etiqueta visible de la mesa (ej. "Mesa 5", "Terraza 2").
  final String label;

  /// Capacidad máxima de personas.
  final int capacity;

  /// Si la mesa está activa y visible en la grilla.
  final bool active;

  /// Posición relativa para ordenar en la UI.
  final int sortOrder;

  /// Timestamp del servidor (usado para LWW). Nullable hasta que haya sync.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    venueId,
    label,
    capacity,
    active,
    sortOrder,
    updatedAt,
  ];
}
