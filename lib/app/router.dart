import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/auth/presentation/screens/login_screen.dart';
import 'package:comand_ia/features/orders/presentation/screens/table_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const login = '/login';
  static const tables = '/tables';
  static const order = '/order/:tableId';
  static const kitchen = '/kitchen';
  static const dashboard = '/dashboard';
}

/// Provider de GoRouter con auth redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.tables,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState is AuthAuthenticated;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      // Si no está autenticado y no está en login → redirigir a login
      if (!isAuthenticated && !isOnLogin) {
        return AppRoutes.login;
      }

      // Si está autenticado y está en login → redirigir a mesas
      if (isAuthenticated && isOnLogin) {
        return AppRoutes.tables;
      }

      return null; // Sin redirección
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.tables,
        name: 'tables',
        builder: (context, state) => const TableGridScreen(),
      ),
      GoRoute(
        path: AppRoutes.order,
        name: 'order',
        builder: (context, state) {
          final tableId = state.pathParameters['tableId'] ?? '';
          return Scaffold(
            body: Center(child: Text('Pedido mesa $tableId - Sprint 2')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.kitchen,
        name: 'kitchen',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('KDS Cocina — Sprint 2')),
            ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('Dashboard — Sprint 2')),
            ),
      ),
    ],
  );
});
