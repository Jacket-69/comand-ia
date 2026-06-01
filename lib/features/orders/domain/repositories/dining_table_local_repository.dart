import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';

/// Contrato de acceso local (Drift) a mesas.
///
/// La implementación concreta es [DriftDiningTableLocalRepository] en data/.
/// Este archivo no importa Flutter ni Drift — solo entidades de dominio.
abstract class DiningTableLocalRepository {
  /// Stream reactivo de mesas activas de un venue, ordenadas por sortOrder asc.
  ///
  /// Filtra active == true. Emite cada vez que cambia cualquier mesa del venue.
  Stream<List<DiningTable>> watchTables(String venueId);
}
