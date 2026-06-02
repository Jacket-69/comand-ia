import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_order_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_pending_op_queue.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/presentation/controllers/order_draft_controller.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Crea un ProviderContainer con la AppDatabase en memoria y repos listos.
ProviderContainer buildContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
}

/// El venueId debe coincidir con el fallback del controller cuando no hay usuario.
/// El controller usa `user?.venueId ?? 'venue-001-mock'` como fallback.
const kVenueId = 'venue-001-mock';

const _cat = MenuCategory(
  id: 'cat-1',
  venueId: kVenueId,
  name: 'Almuerzos',
  sortOrder: 1,
);

const _item1 = MenuItem(
  id: 'item-1',
  venueId: kVenueId,
  categoryId: 'cat-1',
  name: 'Hamburguesa Clásica',
  description: 'Hamburguesa clásica de vacuno',
  priceCents: 1500000, // $15.000 CLP
);

const _item2 = MenuItem(
  id: 'item-2',
  venueId: kVenueId,
  categoryId: 'cat-1',
  name: 'Bebida',
  description: 'Bebida refrescante',
  priceCents: 180000, // $1.800 CLP
);

// ─── Seed de prueba ───────────────────────────────────────────────────────────

/// Siembra el menú mínimo necesario para los tests de controller.
Future<void> seedTestMenu(ProviderContainer container) async {
  final menuRepo = container.read(menuLocalRepositoryProvider);
  await menuRepo.cacheCategories([_cat]);
  await menuRepo.cacheItems([_item1, _item2]);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = buildContainer(db);
    await seedTestMenu(container);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  OrderDraftController makeCtrl(String tableId) =>
      container.read(orderDraftControllerProvider(tableId).notifier);

  group('DraftLine', () {
    test('lineCents es priceCents × quantity (sin floats)', () {
      const line = DraftLine(menuItem: _item1, quantity: 3);
      expect(line.lineCents, _item1.priceCents * 3);
      expect(line.lineCents, isA<int>());
    });
  });

  group('OrderDraftState', () {
    test('subtotalCents suma las líneas en centavos (sin propina)', () {
      final state = OrderDraftState(
        tableId: '1',
        lines: const [
          DraftLine(menuItem: _item1, quantity: 2),
          DraftLine(menuItem: _item2, quantity: 1),
        ],
      );
      // 1500000×2 + 180000×1 = 3180000
      expect(state.subtotalCents, 3180000);
      expect(state.subtotalCents, isA<int>());
    });

    test('suggestedTipCents es 10% del subtotal (solo informativo)', () {
      final state = OrderDraftState(
        tableId: '1',
        lines: const [DraftLine(menuItem: _item1, quantity: 1)],
      );
      expect(state.suggestedTipCents, (1500000 * 0.1).round());
    });

    test('referenceTotal = subtotal + propina sugerida (solo informativo)', () {
      final state = OrderDraftState(
        tableId: '1',
        lines: const [DraftLine(menuItem: _item1, quantity: 1)],
      );
      expect(
        state.referenceTotal,
        state.subtotalCents + state.suggestedTipCents,
      );
    });
  });

  group('OrderDraftController.addItem', () {
    test('agrega un ítem nuevo al borrador', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1);
      expect(ctrl.state.lines.length, 1);
      expect(ctrl.state.lines.first.menuItem.id, _item1.id);
      expect(ctrl.state.lines.first.quantity, 1);
    });

    test('incrementa cantidad si el ítem ya está en el borrador', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1);
      ctrl.addItem(_item1);
      expect(ctrl.state.lines.length, 1);
      expect(ctrl.state.lines.first.quantity, 2);
    });

    test('subtotalCents se actualiza al agregar ítems', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1); // 1500000
      ctrl.addItem(_item2); // 180000
      expect(ctrl.state.subtotalCents, 1680000);
    });
  });

  group('OrderDraftController.incrementQty / decrementQty', () {
    test('incrementQty aumenta la cantidad', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1);
      ctrl.incrementQty(_item1.id);
      expect(ctrl.state.lines.first.quantity, 2);
    });

    test('decrementQty reduce la cantidad', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1);
      ctrl.addItem(_item1); // qty=2
      ctrl.decrementQty(_item1.id);
      expect(ctrl.state.lines.first.quantity, 1);
    });

    test('decrementQty elimina la línea cuando qty llega a 0', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1); // qty=1
      ctrl.decrementQty(_item1.id); // qty → 0 → elimina
      expect(ctrl.state.lines, isEmpty);
    });
  });

  group('OrderDraftController.removeLine', () {
    test('elimina la línea del borrador', () {
      final ctrl = makeCtrl('1');
      ctrl.addItem(_item1);
      ctrl.addItem(_item2);
      ctrl.removeLine(_item1.id);
      expect(ctrl.state.lines.length, 1);
      expect(ctrl.state.lines.first.menuItem.id, _item2.id);
    });
  });

  group('OrderDraftController.confirm (modo nuevo)', () {
    test('persiste pedido en Drift con status sent', () async {
      final ctrl = makeCtrl('2');
      ctrl.addItem(_item1);
      ctrl.addItem(_item2);

      final confirmed = await ctrl.confirm();

      expect(confirmed.status, OrderStatus.sent);
      expect(confirmed.diningTableId, '2');

      // Verificar en BD
      final orderRepo = DriftOrderLocalRepository(db);
      final fromDb = await orderRepo.orderById(confirmed.id);
      expect(fromDb, isNotNull);
      expect(fromDb!.status, OrderStatus.sent);
    });

    test('ítems persistidos con snapshots inmutables (ACID-2)', () async {
      final ctrl = makeCtrl('3');
      ctrl.addItem(_item1);

      final confirmed = await ctrl.confirm();

      final orderRepo = DriftOrderLocalRepository(db);
      final items = await orderRepo.itemsOf(confirmed.id);
      expect(items.length, 1);
      expect(items.first.nameSnapshot, _item1.name);
      expect(items.first.priceCentsSnapshot, _item1.priceCents);
      expect(items.first.priceCentsSnapshot, isA<int>());
    });

    test('totalCents del pedido NO incluye propina (ACID-3)', () async {
      final ctrl = makeCtrl('4');
      ctrl.addItem(_item1); // 1500000
      ctrl.addItem(_item2); // 180000

      final confirmed = await ctrl.confirm();

      // Total = suma de ítems únicamente — SIN propina
      expect(confirmed.totalCents, 1680000);
      expect(confirmed.totalCents, isNot(greaterThan(1680000)));
    });

    test('encola pending_op de tipo createOrder (ACID-7)', () async {
      final ctrl = makeCtrl('5');
      ctrl.addItem(_item1);

      final confirmed = await ctrl.confirm();

      final opQueue = DriftPendingOpQueue(db);
      final ops = await opQueue.peek(confirmed.venueId);
      expect(ops.isNotEmpty, isTrue);
      expect(ops.first.opType.toDb(), 'create_order');
    });

    test('lanza StateError si el borrador está vacío', () async {
      final ctrl = makeCtrl('6');
      await expectLater(ctrl.confirm(), throwsA(isA<StateError>()));
    });

    test('limpia líneas del borrador tras confirmar (Fix #2)', () async {
      final ctrl = makeCtrl('20');
      ctrl.addItem(_item1);
      ctrl.addItem(_item2);
      expect(ctrl.state.lines.length, 2);

      await ctrl.confirm();

      // El borrador debe quedar limpio
      expect(ctrl.state.lines, isEmpty);
    });

    test('entra en append mode tras confirmar el primer pedido', () async {
      final ctrl = makeCtrl('21');
      ctrl.addItem(_item1);

      final confirmed = await ctrl.confirm();

      expect(ctrl.state.isAppendMode, isTrue);
      expect(ctrl.state.existingOrderId, confirmed.id);
    });
  });

  group('OrderDraftController.confirm (append mode)', () {
    test('agrega ítems al pedido existente sin crear uno nuevo', () async {
      // Crear pedido inicial directamente en el repo
      final orderRepo = DriftOrderLocalRepository(db);
      final existing = await orderRepo.createOrder(
        venueId: kVenueId,
        diningTableId: 'table-30',
      );
      await orderRepo.addItem(orderId: existing.id, menuItem: _item1);
      await orderRepo.updateStatus(existing.id, OrderStatus.sent);

      // El controller carga el pedido activo de la mesa al inicializar.
      // Se espera a que termine _loadCategories + _loadActiveOrder.
      final ctrl = makeCtrl('table-30');
      // Dar tiempo al controller para cargar el menú y el pedido activo.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ctrl.state.isAppendMode, isTrue);
      expect(ctrl.state.existingOrderId, existing.id);

      // Agrega un ítem nuevo en el borrador
      ctrl.addItem(_item2);
      await ctrl.confirm();

      // El borrador debe quedar limpio (Fix #2)
      expect(ctrl.state.lines, isEmpty);

      // El pedido debe tener 2 ítems en total
      final items = await orderRepo.itemsOf(existing.id);
      expect(items.length, 2);
    });

    test(
      'encola updateOrderItem por cada ítem agregado en append mode',
      () async {
        final orderRepo = DriftOrderLocalRepository(db);
        final existing = await orderRepo.createOrder(
          venueId: kVenueId,
          diningTableId: 'table-31',
        );
        await orderRepo.addItem(orderId: existing.id, menuItem: _item1);
        await orderRepo.updateStatus(existing.id, OrderStatus.sent);

        final ctrl = makeCtrl('table-31');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        ctrl.addItem(_item2);
        await ctrl.confirm();

        final opQueue = DriftPendingOpQueue(db);
        final ops = await opQueue.peek(kVenueId);
        // Debe haber al menos un op de tipo update_order_item
        expect(
          ops.any((op) => op.opType.toDb() == 'update_order_item'),
          isTrue,
        );
      },
    );
  });

  group('OrderDraftController.selectCategory', () {
    test('carga ítems de la categoría seleccionada', () async {
      final ctrl = makeCtrl('1');
      await ctrl.selectCategory(_cat);
      expect(ctrl.state.selectedCategory, _cat);
      expect(ctrl.state.itemsInCategory.isNotEmpty, isTrue);
    });
  });

  group('OrderDraftController.clearCategory', () {
    test('limpia la categoría activa', () async {
      final ctrl = makeCtrl('1');
      await ctrl.selectCategory(_cat);
      ctrl.clearCategory();
      expect(ctrl.state.selectedCategory, isNull);
    });
  });

  group('OrderDraftController.setSearch', () {
    test('filtra ítems por nombre', () async {
      final ctrl = makeCtrl('1');
      await ctrl.selectCategory(_cat);
      await ctrl.setSearch('Hamb');
      expect(ctrl.state.itemsInCategory.length, 1);
      expect(ctrl.state.itemsInCategory.first.id, _item1.id);
    });

    test('query vacío muestra todos los ítems', () async {
      final ctrl = makeCtrl('1');
      await ctrl.selectCategory(_cat);
      await ctrl.setSearch('Hamb');
      await ctrl.setSearch('');
      expect(ctrl.state.itemsInCategory.length, 2);
    });
  });
}
