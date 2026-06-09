import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';

/// Contrato de la cola FIFO de operaciones pendientes de sincronización.
///
/// La implementación concreta es [DriftPendingOpQueue] en data/.
/// Este archivo no importa Flutter ni Drift — solo entidades de dominio.
///
/// ACID-7: las operaciones se procesan en FIFO estricto por [venueId],
/// ordenadas por el id autoincremental de inserción. Solo participan del
/// drenaje las ops con status `pending`; las `dead` (error permanente) se
/// conservan para diagnóstico sin bloquear la cola.
abstract class PendingOpQueue {
  /// Encola una operación pendiente.
  ///
  /// Serializa [payload] a JSON y retorna el id autoincremental asignado.
  Future<int> enqueue({
    required String venueId,
    required PendingOpType opType,
    required Map<String, dynamic> payload,
  });

  /// Retorna las operaciones `pending` de un venue en orden FIFO (id asc).
  Future<List<PendingOp>> peek(String venueId);

  /// Retorna la primera operación `pending` de un venue (cabeza), o null.
  Future<PendingOp?> head(String venueId);

  /// Incrementa el contador de intentos de una operación (base del backoff).
  ///
  /// Si se entrega [error], lo registra como último error de la operación.
  Future<void> markAttempt(int id, {String? error});

  /// Marca la operación como `dead` por error permanente y registra [error].
  ///
  /// La op deja de participar del drenaje pero se conserva para diagnóstico.
  Future<void> markDead(int id, String error);

  /// Elimina la operación de la cola (tras sync exitoso).
  Future<void> remove(int id);

  /// Venues con al menos una operación `pending`, sin orden garantizado.
  Future<List<String>> venuesWithPending();

  /// Stream reactivo del total de operaciones `pending` (todos los venues).
  ///
  /// Emite en cada cambio de la cola; dispara el drenaje del SyncService.
  Stream<int> watchPendingCount();
}
