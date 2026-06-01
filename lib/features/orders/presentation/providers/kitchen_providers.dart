import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Streams reactivos ────────────────────────────────────────────────────────

/// Stream de pedidos activos (sent, preparing, ready) del venue actual.
///
/// Alimenta la pantalla KDS de cocina. Resuelve venueId desde el usuario
/// autenticado; fallback 'venue-001-mock' mientras no hay auth real.
final kitchenOrdersProvider = StreamProvider<List<CustomerOrder>>((ref) {
  final user = ref.watch(currentUserProvider);
  final venueId = user?.venueId ?? 'venue-001-mock';
  final repo = ref.watch(orderLocalRepositoryProvider);
  return repo.watchActiveOrders(venueId);
});

/// Stream de ítems de un pedido específico, ordenados por id asc.
///
/// Parametrizado por orderId. Útil para la tarjeta de cada pedido en el KDS.
final orderItemsProvider = StreamProvider.family<List<OrderItem>, String>((
  ref,
  orderId,
) {
  final repo = ref.watch(orderLocalRepositoryProvider);
  return repo.watchItems(orderId);
});

// ─── Estado del KitchenController ────────────────────────────────────────────

/// Estado del KDS: solo rastrea la última operación en curso y errores.
class KitchenState {
  const KitchenState({this.isAdvancing = false, this.lastError});

  /// Verdadero mientras se avanza un ítem.
  final bool isAdvancing;

  /// Último error capturado (null si todo ok).
  final Object? lastError;

  KitchenState copyWith({bool? isAdvancing, Object? lastError}) {
    return KitchenState(
      isAdvancing: isAdvancing ?? this.isAdvancing,
      lastError: lastError ?? this.lastError,
    );
  }
}

// ─── KitchenController ────────────────────────────────────────────────────────

/// Controller del KDS de cocina.
///
/// Gestiona el avance del estado de ítems (sent → preparing → ready)
/// y encola el [PendingOp] correspondiente para sync offline.
class KitchenController extends StateNotifier<KitchenState> {
  KitchenController(this._ref) : super(const KitchenState());

  final Ref _ref;

  /// Avanza el estado de un ítem al siguiente: sent → preparing → ready.
  ///
  /// Si el ítem ya está en ready, no hace nada.
  /// Encola [PendingOpType.updateOrderItem] para sync offline.
  /// Loggea con tag 'Kitchen'. Captura y re-lanza errores.
  Future<void> advanceItem(OrderItem item) async {
    final next = _nextStatus(item.status);
    if (next == null) return; // ya en ready, no avanzar

    state = state.copyWith(isAdvancing: true);
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';

      final orderRepo = _ref.read(orderLocalRepositoryProvider);
      final opQueue = _ref.read(pendingOpQueueProvider);

      await orderRepo.updateItemStatus(item.id, next);

      await opQueue.enqueue(
        venueId: venueId,
        opType: PendingOpType.updateOrderItem,
        payload: {
          'order_item_id': item.id,
          'order_id': item.orderId,
          'venue_id': venueId,
          'status': next.toDb(),
        },
      );

      AppLogger.info(
        'Ítem ${item.id} avanzado a ${next.toDb()} (pedido ${item.orderId}).',
        tag: 'Kitchen',
      );

      state = state.copyWith(isAdvancing: false);
    } catch (e, st) {
      AppLogger.error(
        'Error al avanzar ítem ${item.id}',
        error: e,
        stackTrace: st,
        tag: 'Kitchen',
      );
      state = KitchenState(isAdvancing: false, lastError: e);
      rethrow;
    }
  }

  // ─── Helpers privados ──────────────────────────────────────────────────────

  /// Retorna el siguiente status en la secuencia KDS, o null si ya es ready.
  OrderItemStatus? _nextStatus(OrderItemStatus current) => switch (current) {
    OrderItemStatus.sent => OrderItemStatus.preparing,
    OrderItemStatus.preparing => OrderItemStatus.ready,
    OrderItemStatus.ready => null,
    OrderItemStatus.cancelled => null,
  };
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Provider del [KitchenController].
final kitchenControllerProvider =
    StateNotifierProvider<KitchenController, KitchenState>(
      (ref) => KitchenController(ref),
    );
