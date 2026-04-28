import 'package:equatable/equatable.dart';

/// Rol del usuario en el sistema.
enum UserRole {
  /// Dueño del local. Gestiona menú, ve analítica, hace onboarding.
  owner,

  /// Personal de sala. Toma pedidos en mesas.
  staff,
}

/// Entidad de usuario de la aplicación.
///
/// Mapea a la tabla `app_user` de Supabase.
/// El `venueId` es el eje del multi-tenant.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.venueId,
    required this.displayName,
  });

  /// UUID del usuario (= auth.users.id en Supabase).
  final String id;

  /// Email del usuario.
  final String email;

  /// Rol: owner o staff.
  final UserRole role;

  /// UUID del venue al que pertenece.
  final String venueId;

  /// Nombre para mostrar.
  final String displayName;

  /// ¿Es owner?
  bool get isOwner => role == UserRole.owner;

  /// ¿Es staff (garzón)?
  bool get isStaff => role == UserRole.staff;

  @override
  List<Object?> get props => [id, email, role, venueId, displayName];
}
