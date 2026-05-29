import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_menu_local_repository.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:comand_ia/features/orders/presentation/providers/seed_provider.dart';
import 'package:comand_ia/features/orders/presentation/screens/order_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Debe coincidir con el fallback del controller: `user?.venueId ?? 'venue-001-mock'`.
const kVenueId = 'venue-001-mock';
const kTableId = '7';

const _cat1 = MenuCategory(
  id: 'wcat-1',
  venueId: kVenueId,
  name: 'Entradas',
  sortOrder: 1,
);

const _cat2 = MenuCategory(
  id: 'wcat-2',
  venueId: kVenueId,
  name: 'Bebidas',
  sortOrder: 2,
);

const _item1 = MenuItem(
  id: 'witem-1',
  venueId: kVenueId,
  categoryId: 'wcat-1',
  name: 'Ceviche de Reineta',
  priceCents: 450000,
);

const _item2 = MenuItem(
  id: 'witem-2',
  venueId: kVenueId,
  categoryId: 'wcat-1',
  name: 'Empanada de Pino',
  priceCents: 280000,
);

/// Construye el widget bajo prueba con los overrides de DB en memoria.
Widget buildTestWidget(AppDatabase db) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // Seed no-op en tests (la DB ya tiene datos sembrados en setUp)
      devSeedProvider.overrideWith((ref) async {}),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: OrderScreen(tableId: kTableId),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final menuRepo = DriftMenuLocalRepository(db);
    await menuRepo.cacheCategories([_cat1, _cat2]);
    await menuRepo.cacheItems([_item1, _item2]);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Vista 2: muestra las categorías del menú', (tester) async {
    await tester.pumpWidget(buildTestWidget(db));
    await tester.pump(); // render inicial
    await tester.pump(const Duration(milliseconds: 100)); // async providers

    // Verifica que aparecen las categorías sembradas
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
  });

  testWidgets('Vista 2: toca una categoría y navega a la lista de ítems', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Toca la categoría Entradas
    await tester.tap(find.text('Entradas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Debe mostrar los ítems de la categoría
    expect(find.text('Ceviche de Reineta'), findsOneWidget);
    expect(find.text('Empanada de Pino'), findsOneWidget);
  });

  testWidgets('Vista 3: agregar ítem actualiza el subtotal en el panel', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Navegar a la categoría Entradas
    await tester.tap(find.text('Entradas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Añadir Ceviche (450000 centavos = $4.500)
    // Buscar el botón + del ítem
    final addButtons = find.byIcon(Icons.add_circle);
    expect(addButtons, findsWidgets);
    await tester.tap(addButtons.first);
    await tester.pump();

    // El panel debería mostrar el subtotal
    expect(find.text(r'$4.500'), findsWidgets);
  });

  testWidgets('Vista 3: estado empty si la categoría no tiene ítems', (
    tester,
  ) async {
    // Crear una categoría sin ítems
    final emptyDb = AppDatabase.forTesting(NativeDatabase.memory());
    final menuRepo = DriftMenuLocalRepository(emptyDb);
    final emptyCategory = const MenuCategory(
      id: 'empty-cat',
      venueId: kVenueId,
      name: 'Sin Ítems',
      sortOrder: 99,
    );
    await menuRepo.cacheCategories([emptyCategory]);
    // No se siembran ítems para esta categoría

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(emptyDb),
          devSeedProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: OrderScreen(tableId: '9'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Sin Ítems'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No hay ítems en esta categoría'), findsOneWidget);

    await emptyDb.close();
  });

  testWidgets('Vista 2: estado empty si no hay categorías en el menú', (
    tester,
  ) async {
    final emptyDb = AppDatabase.forTesting(NativeDatabase.memory());
    // No se siembra nada

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(emptyDb),
          devSeedProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: OrderScreen(tableId: '10'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No hay categorías disponibles'), findsOneWidget);

    await emptyDb.close();
  });
}
