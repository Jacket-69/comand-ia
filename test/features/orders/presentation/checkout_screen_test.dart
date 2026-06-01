import 'dart:async';

import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:comand_ia/features/orders/presentation/providers/kitchen_providers.dart';
import 'package:comand_ia/features/orders/presentation/screens/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Datos de prueba ──────────────────────────────────────────────────────────

const kVenueId = 'venue-001-mock';
const kOrderId = 'order-checkout-test';

final _order = CustomerOrder(
  id: kOrderId,
  venueId: kVenueId,
  diningTableId: 'table-5',
  status: OrderStatus.sent,
  openedAt: DateTime(2026, 6, 1, 12, 0),
  totalCents: 620000, // $6.200 CLP
);

const _item1 = OrderItem(
  id: 'oi-1',
  venueId: kVenueId,
  orderId: kOrderId,
  menuItemId: 'menu-1',
  nameSnapshot: 'Empanada de Pino',
  priceCentsSnapshot: 250000,
  quantity: 2,
  status: OrderItemStatus.sent,
);

const _item2 = OrderItem(
  id: 'oi-2',
  venueId: kVenueId,
  orderId: kOrderId,
  menuItemId: 'menu-2',
  nameSnapshot: 'Bebida',
  priceCentsSnapshot: 120000,
  quantity: 1,
  status: OrderItemStatus.sent,
);

// ─── Helper ───────────────────────────────────────────────────────────────────

/// Construye CheckoutScreen con todos los providers sobreescritos.
Widget buildCheckoutWidget({
  CustomerOrder? order,
  List<OrderItem> items = const [_item1, _item2],
}) {
  final resolvedOrder = order ?? _order;
  return ProviderScope(
    overrides: [
      // Pedido fijo en memoria
      checkoutOrderProvider(
        kOrderId,
      ).overrideWith((ref) async => resolvedOrder),
      // Ítems fijos en memoria
      orderItemsProvider(kOrderId).overrideWith((ref) => Stream.value(items)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: CheckoutScreen(orderId: kOrderId),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('CheckoutScreen — renderizado del detalle', () {
    testWidgets('muestra la mesa del pedido', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mesa table-5'), findsOneWidget);
    });

    testWidgets('muestra los ítems de la cuenta', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Empanada de Pino'), findsOneWidget);
      expect(find.text('Bebida'), findsOneWidget);
    });

    testWidgets('muestra el subtotal formateado en CLP', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // totalCents = 620000 → $6.200
      expect(find.text(r'$6.200'), findsWidgets);
    });
  });

  group('CheckoutScreen — selector de método de pago', () {
    testWidgets('muestra todas las opciones de pago', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Transferencia'), findsOneWidget);
      expect(find.text('Otro'), findsWidgets); // puede aparecer en tip también
    });

    testWidgets('el chip Efectivo está seleccionado por defecto', (
      tester,
    ) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ChoiceChip seleccionado tiene color primario
      final cashChip = find.byWidgetPredicate(
        (w) => w is ChoiceChip && (w.label as Text).data == 'Efectivo',
      );
      expect(cashChip, findsOneWidget);
      final chip = tester.widget<ChoiceChip>(cashChip);
      expect(chip.selected, isTrue);
    });
  });

  group('CheckoutScreen — selector de propina', () {
    testWidgets('muestra los botones rápidos 0%, 10% y 15%', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('15%'), findsOneWidget);
    });

    testWidgets('el botón 10% está seleccionado por defecto', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Con subtotal 620000, la propina por defecto al 10% = 62000 → $620
      // El texto de propina debe reflejar ese valor
      expect(find.text(r'$620'), findsWidgets);
    });

    testWidgets(r'tap en 0% cambia la propina a $0', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('0%'));
      await tester.pump();

      expect(find.text(r'$0'), findsWidgets);
    });

    testWidgets('tap en 15% actualiza la propina', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('15%'));
      await tester.pump();

      // 620000 × 0.15 = 93000 → $930
      expect(find.text(r'$930'), findsWidgets);
    });
  });

  group('CheckoutScreen — total a cobrar', () {
    testWidgets('muestra Total a cobrar = subtotal + propina', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Subtotal 620000, propina 10% = 62000 → total 682000 → $6.820
      expect(find.text(r'$6.820'), findsOneWidget);
    });

    testWidgets('sección Total a cobrar es visible en pantalla', (
      tester,
    ) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Total a cobrar'), findsOneWidget);
    });
  });

  group('CheckoutScreen — botón de cierre', () {
    testWidgets('el botón Cerrar cuenta está presente', (tester) async {
      await tester.pumpWidget(buildCheckoutWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cerrar cuenta'), findsOneWidget);
    });
  });

  group('CheckoutScreen — estado loading y error', () {
    testWidgets('muestra indicador de carga mientras se carga el pedido', (
      tester,
    ) async {
      // Usamos un Completer que nunca completa para evitar timers pendientes.
      final completer = Completer<CustomerOrder?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkoutOrderProvider(
              kOrderId,
            ).overrideWith((ref) => completer.future),
            orderItemsProvider(
              kOrderId,
            ).overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: CheckoutScreen(orderId: kOrderId),
          ),
        ),
      );
      await tester.pump(); // primer frame
      // No esperamos el future → debe mostrar loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('muestra mensaje si el pedido no existe (null)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkoutOrderProvider(kOrderId).overrideWith((ref) async => null),
            orderItemsProvider(
              kOrderId,
            ).overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: CheckoutScreen(orderId: kOrderId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pedido no encontrado'), findsOneWidget);
    });
  });
}
