import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/presentation/providers/kitchen_providers.dart';
import 'package:comand_ia/features/orders/presentation/screens/kitchen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Datos de prueba ──────────────────────────────────────────────────────────

const kVenueId = 'venue-001-mock';

final _order1 = CustomerOrder(
  id: 'order-1',
  venueId: kVenueId,
  diningTableId: '5',
  status: OrderStatus.sent,
  openedAt: DateTime(2026, 6, 1, 12, 0),
  totalCents: 450000,
);

final _order2 = CustomerOrder(
  id: 'order-2',
  venueId: kVenueId,
  diningTableId: '8',
  status: OrderStatus.preparing,
  openedAt: DateTime(2026, 6, 1, 12, 30),
  totalCents: 280000,
);

const _item1 = OrderItem(
  id: 'item-1',
  venueId: kVenueId,
  orderId: 'order-1',
  menuItemId: 'menu-1',
  nameSnapshot: 'Ceviche de Reineta',
  priceCentsSnapshot: 450000,
  quantity: 2,
  status: OrderItemStatus.sent,
  comments: 'sin cebolla',
);

const _item2 = OrderItem(
  id: 'item-2',
  venueId: kVenueId,
  orderId: 'order-1',
  menuItemId: 'menu-2',
  nameSnapshot: 'Empanada de Pino',
  priceCentsSnapshot: 280000,
  quantity: 1,
  status: OrderItemStatus.ready,
);

const _item3 = OrderItem(
  id: 'item-3',
  venueId: kVenueId,
  orderId: 'order-2',
  menuItemId: 'menu-3',
  nameSnapshot: 'Lomo a la Plancha',
  priceCentsSnapshot: 890000,
  quantity: 3,
  status: OrderItemStatus.preparing,
);

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Construye la KitchenScreen con providers sobreescritos.
///
/// [orders] es la lista de pedidos que entregará [kitchenOrdersProvider].
/// [itemsByOrderId] mapea orderId → lista de ítems para [orderItemsProvider].
Widget buildKitchenWidget({
  required List<CustomerOrder> orders,
  Map<String, List<OrderItem>> itemsByOrderId = const {},
}) {
  return ProviderScope(
    overrides: [
      kitchenOrdersProvider.overrideWith((ref) => Stream.value(orders)),
      // Sobreescribe cada family con los ítems correspondientes
      for (final entry in itemsByOrderId.entries)
        orderItemsProvider(
          entry.key,
        ).overrideWith((ref) => Stream.value(entry.value)),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const KitchenScreen()),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('KitchenScreen — estado vacío', () {
    testWidgets('muestra mensaje amable si no hay pedidos activos', (
      tester,
    ) async {
      await tester.pumpWidget(buildKitchenWidget(orders: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sin pedidos en cocina'), findsOneWidget);
    });
  });

  group('KitchenScreen — pedidos activos', () {
    testWidgets('renderiza una tarjeta por pedido', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1, _order2],
          itemsByOrderId: {
            'order-1': [_item1, _item2],
            'order-2': [_item3],
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe aparecer una tarjeta por mesa
      expect(find.text('Mesa 5'), findsOneWidget);
      expect(find.text('Mesa 8'), findsOneWidget);
    });

    testWidgets('muestra los ítems de cada pedido', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1, _order2],
          itemsByOrderId: {
            'order-1': [_item1, _item2],
            'order-2': [_item3],
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ceviche de Reineta'), findsOneWidget);
      expect(find.text('Empanada de Pino'), findsOneWidget);
      expect(find.text('Lomo a la Plancha'), findsOneWidget);
    });

    testWidgets('muestra comentario del ítem si existe', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1],
          itemsByOrderId: {
            'order-1': [_item1],
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('sin cebolla'), findsOneWidget);
    });

    testWidgets('muestra checkmark para ítem ya en ready', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1],
          itemsByOrderId: {
            'order-1': [_item2], // _item2 tiene status ready
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('botón Avanzar aparece para ítems no-ready', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1],
          itemsByOrderId: {
            'order-1': [_item1], // sent → puede avanzar
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El ícono del botón de avance debe estar presente
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('muestra chips de estado por pedido', (tester) async {
      await tester.pumpWidget(
        buildKitchenWidget(
          orders: [_order1, _order2],
          itemsByOrderId: {
            'order-1': [_item1],
            'order-2': [_item3],
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // _order1 → sent → "Enviado"; _order2 → preparing → "Preparando"
      expect(find.text('Enviado'), findsWidgets);
      expect(find.text('Preparando'), findsWidgets);
    });
  });

  group('KitchenScreen — estado de error', () {
    testWidgets('muestra mensaje de error si el stream falla', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kitchenOrdersProvider.overrideWith(
              (ref) => Stream.error(Exception('falla de DB')),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const KitchenScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Error al cargar los pedidos'), findsOneWidget);
    });
  });
}
