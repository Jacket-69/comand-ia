import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_apply_result.dart';

/// Contrato del backend remoto para el drenaje de la cola FIFO (COMA-008).
///
/// La implementación concreta es [SupabaseOrderRemoteGateway] en data/remote/.
/// Este archivo no importa Flutter ni Supabase — solo dominio.
abstract class OrderRemoteGateway {
  /// Verdadero si hay sesión válida y el usuario es miembro activo del venue.
  ///
  /// Sin esto el SyncService no drena: con RLS deny-by-default, escribir sin
  /// sesión solo produciría fallos que no son culpa de las operaciones.
  Future<bool> ensureReady();

  /// Cambios de disponibilidad de la sesión (login/logout/refresh).
  ///
  /// Emitir `true` re-dispara el drenaje de la cola.
  Stream<bool> get readyChanges;

  /// Aplica una operación pendiente contra el backend.
  ///
  /// Implementaciones deben ser idempotentes ante reintentos (una op aplicada
  /// y re-enviada retorna [SyncApplied], no un error) y no escribir jamás
  /// campos gestionados por el servidor (`total_cents`, `updated_at` — ACID-3).
  Future<SyncApplyResult> apply(PendingOp op);
}
