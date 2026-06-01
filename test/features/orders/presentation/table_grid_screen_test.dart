import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/auth/domain/entities/user.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/presentation/providers/tables_provider.dart';
import 'package:comand_ia/features/orders/presentation/screens/table_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const kVenueId = 'venue-001-mock';

const _mockUser = AppUser(
  id: 'user-1',
  email: 'test@test.com',
  role: UserRole.staff,
  venueId: kVenueId,
  displayName: 'Garzón Test',
);

/// Mesa libre (sin pedido).
final _tableViewFree = TableView(
  table: const DiningTable(
    id: '1',
    venueId: kVenueId,
    label: 'Mesa 1',
    sortOrder: 1,
  ),
);

/// Mesa con pedido enviado a cocina (sent → indicador active).
final _tableViewSent = TableView(
  table: const DiningTable(
    id: '2',
    venueId: kVenueId,
    label: 'Mesa 2',
    sortOrder: 2,
  ),
  orderStatus: OrderStatus.sent,
  orderId: 'order-2',
  totalCents: 320000,
);

/// Mesa con pedido listo para servir (ready → indicador readyToServe).
final _tableViewReady = TableView(
  table: const DiningTable(
    id: '3',
    venueId: kVenueId,
    label: 'Mesa 3',
    sortOrder: 3,
  ),
  orderStatus: OrderStatus.ready,
  orderId: 'order-3',
  totalCents: 540000,
);

/// Construye el widget bajo prueba con los overrides necesarios.
Widget buildTestWidget(List<TableView> views) {
  return ProviderScope(
    overrides: [
      // Sobreescribimos el stream de mesas con datos estáticos.
      tablesViewProvider.overrideWith((ref) => Stream.value(views)),
      // Usuario autenticado para que el AppBar muestre el nombre.
      currentUserProvider.overrideWithValue(_mockUser),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      // Envolvemos en Router mínimo para que go_router no falle al hacer
      // context.go(). En este test no verificamos la navegación, solo
      // que los widgets se renderizan correctamente.
      home: const TableGridScreen(),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('TableGridScreen', () {
    testWidgets('renderiza las tres mesas del stub', (tester) async {
      await tester.pumpWidget(
        buildTestWidget([_tableViewFree, _tableViewSent, _tableViewReady]),
      );
      await tester.pump(); // render inicial
      await tester.pump(const Duration(milliseconds: 100)); // async providers

      // Deben aparecer los tres números de mesa
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('mesa libre muestra etiqueta "Libre"', (tester) async {
      await tester.pumpWidget(buildTestWidget([_tableViewFree]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Libre'), findsOneWidget);
    });

    testWidgets('mesa con pedido sent muestra etiqueta "Con orden"', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget([_tableViewSent]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Con orden'), findsOneWidget);
    });

    testWidgets('mesa con pedido ready muestra etiqueta "Con orden"', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget([_tableViewReady]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Con orden'), findsOneWidget);
    });

    testWidgets('stats bar muestra etiquetas libres y con orden', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget([_tableViewFree, _tableViewSent, _tableViewReady]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ambas etiquetas deben aparecer en el stats bar
      expect(find.text('Libres'), findsOneWidget);
      expect(find.text('Con Orden'), findsOneWidget);
    });

    testWidgets('mesa con pedido muestra total formateado en CLP', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget([_tableViewSent]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 320000 centavos = $3.200
      expect(find.text(r'$3.200'), findsOneWidget);
    });

    testWidgets('mesa lista muestra total formateado en CLP', (tester) async {
      await tester.pumpWidget(buildTestWidget([_tableViewReady]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 540000 centavos = $5.400
      expect(find.text(r'$5.400'), findsOneWidget);
    });

    testWidgets('grid vacío no lanza errores', (tester) async {
      await tester.pumpWidget(buildTestWidget([]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sin mesas, los contadores deben ser 0
      expect(find.text('0'), findsWidgets);
    });
  });
}
