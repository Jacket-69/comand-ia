import 'package:equatable/equatable.dart';

/// Salud del sync offline, observable por la UI.
enum SyncHealth {
  /// Sin trabajo pendiente o esperando el próximo disparo.
  idle,

  /// Drenando la cola en este momento.
  syncing,

  /// Una op superó el umbral de reintentos (offline-first.md: attempts > 10).
  ///
  /// La cola NO se detiene — sigue reintentando con el backoff cap — pero el
  /// owner debe verificar conectividad o credenciales.
  degraded,
}

/// Estado observable del SyncService (banner de "sync degradada" del owner).
class SyncStatus extends Equatable {
  const SyncStatus(this.health, {this.lastError});

  /// Estado inicial del servicio.
  static const initial = SyncStatus(SyncHealth.idle);

  /// Salud actual del sync.
  final SyncHealth health;

  /// Último error registrado (solo relevante en [SyncHealth.degraded]).
  final String? lastError;

  @override
  List<Object?> get props => [health, lastError];
}
