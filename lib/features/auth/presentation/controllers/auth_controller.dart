import 'package:comand_ia/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:comand_ia/features/auth/domain/entities/user.dart';
import 'package:comand_ia/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider del repositorio de autenticación.
///
/// En Sprint 1 usa `MockAuthRepository`.
/// En Sprint 3+ se reemplaza por `SupabaseAuthRepository`.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

/// Estado de autenticación.
sealed class AuthState {
  const AuthState();
}

/// Estado inicial: no se ha verificado la sesión aún.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Cargando (login en progreso).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Autenticado.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

/// No autenticado.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Error de autenticación.
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

/// Controller de autenticación con Riverpod.
///
/// Maneja el estado de sesión y expone métodos de login/logout.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthUnauthenticated());

  final AuthRepository _repository;

  /// Login como owner (magic link).
  Future<void> loginAsOwner(String email) async {
    state = const AuthLoading();
    try {
      final user = await _repository.loginOwner(email: email);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Login como staff (nombre + PIN).
  Future<void> loginAsStaff({
    required String name,
    required String pin,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.loginStaff(name: name, pin: pin);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Cerrar sesión.
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }
}

/// Provider del AuthController.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Shortcut: ¿está autenticado?
final isAuthenticatedProvider = Provider<bool>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated;
});

/// Shortcut: usuario actual (null si no autenticado).
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthAuthenticated) {
    return state.user;
  }
  return null;
});
