import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Modelo de línea de borrador ─────────────────────────────────────────────

/// Línea del borrador del pedido antes de confirmarlo.
///
/// Mantiene el [menuItem] original para poder leer el snapshot de precio
/// y el nombre al momento del commit.
class DraftLine {
  const DraftLine({
    required this.menuItem,
    required this.quantity,
    this.comments,
  });

  final MenuItem menuItem;
  final int quantity;
  final String? comments;

  DraftLine copyWith({int? quantity, String? comments}) {
    return DraftLine(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      comments: comments ?? this.comments,
    );
  }

  /// Subtotal de esta línea en centavos (sin floats).
  int get lineCents => menuItem.priceCents * quantity;
}

// ─── Estado del controller ────────────────────────────────────────────────────

/// Estado de la toma de pedido para una mesa.
class OrderDraftState {
  const OrderDraftState({
    required this.tableId,
    this.selectedCategory,
    this.categories = const [],
    this.itemsInCategory = const [],
    this.lines = const [],
    this.searchQuery = '',
    this.isLoadingMenu = false,
    this.isConfirming = false,
    this.menuError,
    this.confirmedOrder,
    this.existingOrderId,
    this.existingOrderTotalCents = 0,
    this.existingItemCount = 0,
  });

  /// ID de la mesa (string, calza con los IDs del grid mock).
  final String tableId;

  /// Categoría activa seleccionada (null = vista selector de categorías).
  final MenuCategory? selectedCategory;

  /// Lista de categorías activas del venue.
  final List<MenuCategory> categories;

  /// Ítems de [selectedCategory] (filtrados por [searchQuery]).
  final List<MenuItem> itemsInCategory;

  /// Líneas del borrador del pedido.
  final List<DraftLine> lines;

  /// Texto de búsqueda en la lista de ítems.
  final String searchQuery;

  /// Verdadero mientras carga categorías o ítems.
  final bool isLoadingMenu;

  /// Verdadero mientras se persiste el pedido.
  final bool isConfirming;

  /// Error al cargar menú (null si no hay error).
  final String? menuError;

  /// Pedido persistido y enviado (disponible tras confirm exitoso).
  final CustomerOrder? confirmedOrder;

  /// ID del pedido activo existente en la mesa (no null → append mode).
  final String? existingOrderId;

  /// Total actual del pedido existente en centavos (solo informativo en UI).
  final int existingOrderTotalCents;

  /// Cantidad de ítems no-cancelados del pedido existente (solo informativo).
  final int existingItemCount;

  /// Verdadero cuando se está agregando a un pedido activo (no creando uno nuevo).
  bool get isAppendMode => existingOrderId != null;

  /// Subtotal del borrador en centavos. ACID-3: NO incluye propina.
  int get subtotalCents => lines.fold(0, (acc, line) => acc + line.lineCents);

  /// Propina sugerida (10%) solo informativa. NO se persiste. No afecta totalCents.
  int get suggestedTipCents => (subtotalCents * 0.1).round();

  /// Total de referencia (subtotal + propina sugerida). Solo informativo en UI.
  int get referenceTotal => subtotalCents + suggestedTipCents;

  /// ¿Hay ítems en el borrador?
  bool get hasLines => lines.isNotEmpty;

  OrderDraftState copyWith({
    MenuCategory? selectedCategory,
    bool clearCategory = false,
    List<MenuCategory>? categories,
    List<MenuItem>? itemsInCategory,
    List<DraftLine>? lines,
    String? searchQuery,
    bool? isLoadingMenu,
    bool? isConfirming,
    String? menuError,
    bool clearMenuError = false,
    CustomerOrder? confirmedOrder,
    String? existingOrderId,
    bool clearExistingOrderId = false,
    int? existingOrderTotalCents,
    int? existingItemCount,
  }) {
    return OrderDraftState(
      tableId: tableId,
      selectedCategory:
          clearCategory ? null : selectedCategory ?? this.selectedCategory,
      categories: categories ?? this.categories,
      itemsInCategory: itemsInCategory ?? this.itemsInCategory,
      lines: lines ?? this.lines,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoadingMenu: isLoadingMenu ?? this.isLoadingMenu,
      isConfirming: isConfirming ?? this.isConfirming,
      menuError: clearMenuError ? null : menuError ?? this.menuError,
      confirmedOrder: confirmedOrder ?? this.confirmedOrder,
      existingOrderId:
          clearExistingOrderId ? null : existingOrderId ?? this.existingOrderId,
      existingOrderTotalCents:
          existingOrderTotalCents ?? this.existingOrderTotalCents,
      existingItemCount: existingItemCount ?? this.existingItemCount,
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────

/// Controller de la toma de pedido para una mesa.
///
/// Maneja el borrador en memoria: selección de categoría → lista de ítems →
/// agregar/editar/eliminar líneas → confirmar.
///
/// Al confirmar ([confirm]):
///   1. Crea el pedido en Drift (estado `open`).
///   2. Agrega cada línea como [OrderItem] (snapshot inmutable, ACID-2).
///   3. Cambia el estado a `sent`.
///   4. Encola un [PendingOp] de tipo `createOrder` para sync offline.
class OrderDraftController extends StateNotifier<OrderDraftState> {
  OrderDraftController({required String tableId, required Ref ref})
    : _ref = ref,
      super(OrderDraftState(tableId: tableId)) {
    _loadCategories();
  }

  // ─── Carga del pedido activo ───────────────────────────────────────────────

  /// Carga el pedido activo de la mesa (si existe) para entrar en append mode.
  Future<void> _loadActiveOrder() async {
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';
      final orderRepo = _ref.read(orderLocalRepositoryProvider);
      final active = await orderRepo.activeOrderForTable(
        venueId,
        state.tableId,
      );
      if (active != null) {
        final items = await orderRepo.itemsOf(active.id);
        final nonCancelledCount = items
            .where((i) => i.status.toDb() != 'cancelled')
            .fold<int>(0, (acc, i) => acc + i.quantity);
        state = state.copyWith(
          existingOrderId: active.id,
          existingOrderTotalCents: active.totalCents,
          existingItemCount: nonCancelledCount,
        );
        AppLogger.info(
          'Modo append: pedido existente ${active.id} (mesa ${state.tableId}, '
          'total ${active.totalCents} cts, $nonCancelledCount ítems).',
          tag: 'OrderDraft',
        );
      }
    } catch (e, st) {
      // No bloqueamos la pantalla si falla la carga del pedido activo.
      AppLogger.error(
        'Error cargando pedido activo de la mesa',
        error: e,
        stackTrace: st,
        tag: 'OrderDraft',
      );
    }
  }

  final Ref _ref;

  // ─── Carga de menú ─────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    state = state.copyWith(isLoadingMenu: true, clearMenuError: true);
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';
      final repo = _ref.read(menuLocalRepositoryProvider);
      final cats = await repo.categories(venueId);
      state = state.copyWith(categories: cats, isLoadingMenu: false);
      // Tras cargar el menú, detectar si la mesa tiene un pedido activo.
      await _loadActiveOrder();
    } catch (e, st) {
      AppLogger.error(
        'Error cargando categorías',
        error: e,
        stackTrace: st,
        tag: 'OrderDraft',
      );
      state = state.copyWith(
        isLoadingMenu: false,
        menuError: 'No se pudo cargar el menú: $e',
      );
    }
  }

  /// Selecciona una categoría y carga sus ítems.
  Future<void> selectCategory(MenuCategory category) async {
    state = state.copyWith(
      selectedCategory: category,
      itemsInCategory: [],
      searchQuery: '',
      isLoadingMenu: true,
      clearMenuError: true,
    );
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';
      final repo = _ref.read(menuLocalRepositoryProvider);
      final items = await repo.itemsByCategory(venueId, category.id);
      state = state.copyWith(
        itemsInCategory: _applySearch(items, state.searchQuery),
        isLoadingMenu: false,
      );
    } catch (e, st) {
      AppLogger.error(
        'Error cargando ítems',
        error: e,
        stackTrace: st,
        tag: 'OrderDraft',
      );
      state = state.copyWith(
        isLoadingMenu: false,
        menuError: 'No se pudo cargar los ítems: $e',
      );
    }
  }

  /// Vuelve a la selección de categorías (limpia la categoría activa).
  void clearCategory() {
    state = state.copyWith(
      clearCategory: true,
      itemsInCategory: [],
      searchQuery: '',
    );
  }

  // ─── Búsqueda ──────────────────────────────────────────────────────────────

  /// Filtra los ítems de la categoría activa por nombre.
  Future<void> setSearch(String query) async {
    state = state.copyWith(searchQuery: query);
    if (state.selectedCategory == null) return;
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';
      final repo = _ref.read(menuLocalRepositoryProvider);
      final items = await repo.itemsByCategory(
        venueId,
        state.selectedCategory!.id,
      );
      state = state.copyWith(itemsInCategory: _applySearch(items, query));
    } catch (e, st) {
      AppLogger.error(
        'Error en búsqueda',
        error: e,
        stackTrace: st,
        tag: 'OrderDraft',
      );
    }
  }

  // ─── Gestión del borrador ──────────────────────────────────────────────────

  /// Agrega un ítem al borrador o incrementa su cantidad si ya existe.
  void addItem(MenuItem menuItem) {
    final existingIndex = state.lines.indexWhere(
      (l) => l.menuItem.id == menuItem.id,
    );
    if (existingIndex >= 0) {
      final updated = List<DraftLine>.from(state.lines);
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + 1,
      );
      state = state.copyWith(lines: updated);
    } else {
      state = state.copyWith(
        lines: [...state.lines, DraftLine(menuItem: menuItem, quantity: 1)],
      );
    }
  }

  /// Incrementa la cantidad de una línea del borrador.
  void incrementQty(String menuItemId) {
    final updated =
        state.lines.map((l) {
          if (l.menuItem.id == menuItemId) {
            return l.copyWith(quantity: l.quantity + 1);
          }
          return l;
        }).toList();
    state = state.copyWith(lines: updated);
  }

  /// Decrementa la cantidad de una línea del borrador.
  /// Si la cantidad llega a 0, la línea se elimina.
  void decrementQty(String menuItemId) {
    final updated = <DraftLine>[];
    for (final l in state.lines) {
      if (l.menuItem.id == menuItemId) {
        if (l.quantity > 1) {
          updated.add(l.copyWith(quantity: l.quantity - 1));
        }
        // quantity == 1 → eliminar (no agregar)
      } else {
        updated.add(l);
      }
    }
    state = state.copyWith(lines: updated);
  }

  /// Elimina una línea del borrador completamente.
  void removeLine(String menuItemId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.menuItem.id != menuItemId).toList(),
    );
  }

  // ─── Confirmación ──────────────────────────────────────────────────────────

  /// Persiste el borrador como pedido enviado a cocina.
  ///
  /// Append mode ([isAppendMode] == true): agrega los ítems del borrador al
  /// pedido activo existente y encola un [PendingOpType.updateOrderItem] por
  /// cada línea. Luego re-deriva el estado del pedido.
  ///
  /// Modo nuevo ([isAppendMode] == false): flujo clásico COMA-007:
  ///   1. `createOrder` en Drift (estado `open`, totalCents = 0).
  ///   2. Por cada línea: `addItem` (snapshot inmutable ACID-2; recalcula ACID-3).
  ///   3. `updateStatus` → `sent`.
  ///   4. Encola `PendingOpType.createOrder` (offline-first ACID-7).
  ///
  /// En ambos casos: limpia el borrador (lines = [], categoría) tras éxito (Fix #2).
  ///
  /// Retorna el [CustomerOrder] resultante, o lanza excepción si falla.
  Future<CustomerOrder> confirm() async {
    if (!state.hasLines) {
      throw StateError('No hay ítems en el borrador para confirmar.');
    }

    state = state.copyWith(isConfirming: true, clearMenuError: true);

    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';
      final orderRepo = _ref.read(orderLocalRepositoryProvider);
      final opQueue = _ref.read(pendingOpQueueProvider);

      // Captura las líneas actuales antes de limpiar el borrador.
      final linesToCommit = List<DraftLine>.from(state.lines);

      CustomerOrder resultOrder;

      if (state.isAppendMode) {
        // ── Append mode: agregar ítems al pedido existente ──────────────────
        final orderId = state.existingOrderId!;

        for (final line in linesToCommit) {
          // Agrega ítem al pedido existente (snapshot inmutable ACID-2;
          // _recalculateTotal actualiza totalCents ACID-3).
          await orderRepo.addItem(
            orderId: orderId,
            menuItem: line.menuItem,
            quantity: line.quantity,
            comments: line.comments,
          );

          // Encola updateOrderItem para sync offline (ACID-7).
          await opQueue.enqueue(
            venueId: venueId,
            opType: PendingOpType.updateOrderItem,
            payload: {
              'order_id': orderId,
              'venue_id': venueId,
              'menu_item_id': line.menuItem.id,
              'name_snapshot': line.menuItem.name,
              'price_cents_snapshot': line.menuItem.priceCents,
              'quantity': line.quantity,
              'status': 'sent',
              if (line.comments != null) 'comments': line.comments,
            },
          );
        }

        // Re-deriva el estado del pedido desde sus ítems (recién agregados
        // entran como sent, lo que puede cambiar el estado global).
        await orderRepo.recomputeOrderStatus(orderId);

        // Refresca los contadores del pedido existente en el estado.
        final refreshed = await orderRepo.orderById(orderId);
        final allItems = await orderRepo.itemsOf(orderId);
        final nonCancelledCount = allItems
            .where((i) => i.status.toDb() != 'cancelled')
            .fold<int>(0, (acc, i) => acc + i.quantity);

        resultOrder = refreshed!;

        AppLogger.info(
          'Ítems agregados al pedido $orderId (mesa ${state.tableId}, '
          'total ${resultOrder.totalCents} cts).',
          tag: 'OrderDraft',
        );

        // Limpia el borrador y actualiza los contadores del pedido activo (Fix #2).
        state = state.copyWith(
          isConfirming: false,
          confirmedOrder: resultOrder,
          lines: [],
          clearCategory: true,
          existingOrderTotalCents: resultOrder.totalCents,
          existingItemCount: nonCancelledCount,
        );
      } else {
        // ── Modo nuevo: crear pedido desde cero ─────────────────────────────

        // 1. Crear pedido (estado open, total = 0)
        final order = await orderRepo.createOrder(
          venueId: venueId,
          diningTableId: state.tableId,
          openedBy: user?.id,
        );

        // 2. Agregar cada línea (snapshot inmutable ACID-2; recalcula ACID-3)
        for (final line in linesToCommit) {
          await orderRepo.addItem(
            orderId: order.id,
            menuItem: line.menuItem,
            quantity: line.quantity,
            comments: line.comments,
          );
        }

        // 3. Cambiar estado a `sent` (COMA-007)
        final sentOrder = await orderRepo.updateStatus(
          order.id,
          OrderStatus.sent,
        );

        // 4. Encolar para sync offline (ACID-7)
        await opQueue.enqueue(
          venueId: venueId,
          opType: PendingOpType.createOrder,
          payload: {
            'order_id': sentOrder.id,
            'dining_table_id': state.tableId,
            'venue_id': venueId,
            'opened_by': user?.id,
            'opened_at': sentOrder.openedAt.toIso8601String(),
            'total_cents': sentOrder.totalCents,
            'items':
                linesToCommit
                    .map(
                      (l) => {
                        'menu_item_id': l.menuItem.id,
                        'name_snapshot': l.menuItem.name,
                        'price_cents_snapshot': l.menuItem.priceCents,
                        'quantity': l.quantity,
                        if (l.comments != null) 'comments': l.comments,
                      },
                    )
                    .toList(),
          },
        );

        resultOrder = sentOrder;

        AppLogger.info(
          'Pedido ${sentOrder.id} creado (mesa ${state.tableId}, total ${sentOrder.totalCents} cts).',
          tag: 'OrderDraft',
        );

        // Limpia el borrador y entra en append mode para la misma sesión (Fix #2).
        // Al confirmar por primera vez, el nuevo pedido pasa a ser el existingOrderId.
        final allItems = await orderRepo.itemsOf(sentOrder.id);
        final nonCancelledCount = allItems
            .where((i) => i.status.toDb() != 'cancelled')
            .fold<int>(0, (acc, i) => acc + i.quantity);

        state = state.copyWith(
          isConfirming: false,
          confirmedOrder: resultOrder,
          lines: [],
          clearCategory: true,
          existingOrderId: sentOrder.id,
          existingOrderTotalCents: sentOrder.totalCents,
          existingItemCount: nonCancelledCount,
        );
      }

      return resultOrder;
    } catch (e, st) {
      AppLogger.error(
        'Error al confirmar pedido',
        error: e,
        stackTrace: st,
        tag: 'OrderDraft',
      );
      state = state.copyWith(isConfirming: false);
      rethrow;
    }
  }

  // ─── Helpers privados ──────────────────────────────────────────────────────

  List<MenuItem> _applySearch(List<MenuItem> items, String query) {
    if (query.isEmpty) return items;
    final lq = query.toLowerCase();
    return items.where((item) => item.name.toLowerCase().contains(lq)).toList();
  }
}

// ─── Factory provider ─────────────────────────────────────────────────────────

/// Provider parametrizado por [tableId] que crea un [OrderDraftController]
/// aislado por mesa.
///
/// Usar con `ref.watch(orderDraftControllerProvider('3'))`.
final orderDraftControllerProvider =
    StateNotifierProvider.family<OrderDraftController, OrderDraftState, String>(
      (ref, tableId) => OrderDraftController(tableId: tableId, ref: ref),
    );
