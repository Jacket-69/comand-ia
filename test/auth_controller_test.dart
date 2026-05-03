import 'package:comand_ia/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:comand_ia/features/auth/domain/entities/user.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthController', () {
    late MockAuthRepository repository;
    late AuthController controller;

    setUp(() {
      repository = MockAuthRepository();
      controller = AuthController(repository);
    });

    test('estado inicial es AuthUnauthenticated', () {
      expect(controller.state, isA<AuthUnauthenticated>());
    });

    test('loginAsOwner cambia estado a AuthAuthenticated', () async {
      await controller.loginAsOwner('test@restaurant.cl');

      expect(controller.state, isA<AuthAuthenticated>());
      final state = controller.state as AuthAuthenticated;
      expect(state.user.email, 'test@restaurant.cl');
      expect(state.user.role, UserRole.owner);
      expect(state.user.isOwner, isTrue);
      expect(state.user.isStaff, isFalse);
      expect(state.user.props, [
        state.user.id,
        state.user.email,
        state.user.role,
        state.user.venueId,
        state.user.displayName,
      ]);
    });

    test('loginAsStaff cambia estado a AuthAuthenticated', () async {
      await controller.loginAsStaff(name: 'Carlos', pin: '1234');

      expect(controller.state, isA<AuthAuthenticated>());
      final state = controller.state as AuthAuthenticated;
      expect(state.user.displayName, 'Carlos');
      expect(state.user.role, UserRole.staff);
      expect(state.user.isOwner, isFalse);
      expect(state.user.isStaff, isTrue);
    });

    test('loginAsStaff con PIN corto da error', () async {
      await controller.loginAsStaff(name: 'Carlos', pin: '12');

      expect(controller.state, isA<AuthError>());
    });

    test('logout cambia estado a AuthUnauthenticated', () async {
      await controller.loginAsOwner('test@restaurant.cl');
      expect(controller.state, isA<AuthAuthenticated>());

      await controller.logout();
      expect(controller.state, isA<AuthUnauthenticated>());
    });
  });
}
