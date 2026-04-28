import 'dart:async';

import 'package:comand_ia/features/auth/domain/entities/user.dart';
import 'package:comand_ia/features/auth/domain/repositories/auth_repository.dart';
import 'package:uuid/uuid.dart';

/// Implementación mock del repositorio de autenticación.
///
/// Acepta cualquier email/PIN válido y retorna un usuario fake.
/// Se reemplaza por `SupabaseAuthRepository` en Sprint 3.
class MockAuthRepository implements AuthRepository {
  final _authStateController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  static const _uuid = Uuid();
  static const _mockVenueId = 'venue-001-mock';

  @override
  Future<AppUser> loginOwner({required String email}) async {
    // Simula latencia de red
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (email.isEmpty) {
      throw ArgumentError('El email no puede estar vacío');
    }

    final user = AppUser(
      id: _uuid.v4(),
      email: email,
      role: UserRole.owner,
      venueId: _mockVenueId,
      displayName: email.split('@').first,
    );

    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<AppUser> loginStaff({
    required String name,
    required String pin,
  }) async {
    // Simula latencia de red
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (name.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío');
    }
    if (pin.length < 4 || pin.length > 6) {
      throw ArgumentError('El PIN debe tener entre 4 y 6 dígitos');
    }

    final user = AppUser(
      id: _uuid.v4(),
      email: '$name@staff.comandia.local',
      role: UserRole.staff,
      venueId: _mockVenueId,
      displayName: name,
    );

    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  /// Acceso sincrónico al usuario actual (para guards).
  AppUser? get currentUser => _currentUser;
}
