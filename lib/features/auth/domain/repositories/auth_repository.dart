import 'package:comand_ia/features/auth/domain/entities/user.dart';

/// Contrato abstracto de autenticación.
///
/// La implementación concreta puede ser:
/// - `MockAuthRepository` (Sprint 1)
/// - `SupabaseAuthRepository` (Sprint 3+)
abstract class AuthRepository {
  /// Login de owner con magic link (email).
  ///
  /// En mock: siempre exitoso.
  /// En prod: envía magic link via Supabase Auth.
  Future<AppUser> loginOwner({required String email});

  /// Login de garzón con nombre + PIN.
  ///
  /// En mock: siempre exitoso si PIN tiene 4-6 dígitos.
  /// En prod: llama a `verify_pin()` SECURITY DEFINER.
  Future<AppUser> loginStaff({required String name, required String pin});

  /// Cierra la sesión y limpia estado local.
  Future<void> logout();

  /// Stream del usuario actual. `null` si no hay sesión.
  Stream<AppUser?> get authStateChanges;
}
