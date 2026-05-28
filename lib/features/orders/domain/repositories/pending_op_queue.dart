import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';

/// Contrato de la cola FIFO de operaciones pendientes de sincronización.
///
/// La implementación concreta es [DriftPendingOpQueue] en data/.
/// Este archivo no importa Flutter ni Drift — solo entidades de dominio.
///
/// ACID-7: las operaciones se procesan en FIFO estricto por [venueId],
/// ordenadas por el id autoincremental de inserción.
abstract class PendingOpQueue {
  /// Encola una operación pendiente.
  ///
  /// Serializa [payload] a JSON y retorna el id autoincremental asignado.
  Future<int> enqueue({
    required String venueId,
    required PendingOpType opType,
    required Map<String, dynamic> payload,
  });

  /// Retorna todas las operaciones pendientes de un venue en orden FIFO (id asc).
  Future<List<PendingOp>> peek(String venueId);

  /// Retorna la primera operación pendiente de un venue (cabeza de la cola), o null.
  Future<PendingOp?> head(String venueId);

  /// Incrementa el contador de intentos de una operación (base del backoff).
  Future<void> markAttempt(int id);

  /// Elimina la operación de la cola (tras sync exitoso).
  Future<void> remove(int id);
}
