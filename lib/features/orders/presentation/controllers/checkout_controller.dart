import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Provider de pedido ───────────────────────────────────────────────────────

/// FutureProvider que carga un pedido por ID desde el repositorio local.
///
/// Parametrizado por orderId. Usado en CheckoutScreen para mostrar
/// el encabezado y el total del pedido a cobrar.
final checkoutOrderProvider = FutureProvider.family<CustomerOrder?, String>((
  ref,
  orderId,
) async {
  final repo = ref.watch(orderLocalRepositoryProvider);
  return repo.orderById(orderId);
});

// ─── Estado del CheckoutController ────────────────────────────────────────────

/// Estado de la pantalla de cierre de cuenta.
class CheckoutState {
  const CheckoutState({
    this.isClosing = false,
    this.error,
    this.closed = false,
  });

  /// Verdadero mientras se ejecuta el cierre.
  final bool isClosing;

  /// Error capturado (null si no hay error).
  final Object? error;

  /// Verdadero cuando el pedido fue cerrado exitosamente.
  final bool closed;

  CheckoutState copyWith({bool? isClosing, Object? error, bool? closed}) {
    return CheckoutState(
      isClosing: isClosing ?? this.isClosing,
      error: error ?? this.error,
      closed: closed ?? this.closed,
    );
  }
}

// ─── CheckoutController ────────────────────────────────────────────────────────

/// Controller del cierre de cuenta.
///
/// Cierra el pedido en Drift y encola el [PendingOp] correspondiente
/// para sincronización offline (ACID-7). No toca [CustomerOrder.totalCents]
/// ni mezcla la propina en él (ACID-3).
class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController(this._ref) : super(const CheckoutState());

  final Ref _ref;

  /// Cierra el pedido con el método de pago y propina elegidos por el comensal.
  ///
  /// Flujo:
  ///   1. Llama [OrderLocalRepository.closeOrder] (status closed + closedAt +
  ///      paymentMethod + tipCents). El totalCents no se modifica (ACID-3).
  ///   2. Encola [PendingOpType.closeOrder] con el payload de sync.
  ///   3. Loggea con tag 'Checkout'; captura y relanza errores.
  Future<void> close({
    required String orderId,
    required PaymentMethod paymentMethod,
    required int tipCents,
  }) async {
    state = state.copyWith(isClosing: true);
    try {
      final user = _ref.read(currentUserProvider);
      final venueId = user?.venueId ?? 'venue-001-mock';

      final orderRepo = _ref.read(orderLocalRepositoryProvider);
      final opQueue = _ref.read(pendingOpQueueProvider);

      // 1. Cerrar en Drift (ACID-4: lanza StateError si ya está cerrado)
      final closed = await orderRepo.closeOrder(
        orderId: orderId,
        paymentMethod: paymentMethod,
        tipCents: tipCents,
      );

      // 2. Encolar operación para sync offline (ACID-7). Sin total_cents:
      //    lo recalcula el trigger del servidor (ACID-3).
      await opQueue.enqueue(
        venueId: venueId,
        opType: PendingOpType.closeOrder,
        payload: {
          'order_id': closed.id,
          'venue_id': venueId,
          'payment_method': paymentMethod.toDb(),
          'tip_cents': tipCents,
          'closed_at': closed.closedAt!.toIso8601String(),
        },
      );

      AppLogger.info(
        'Pedido $orderId cerrado '
        '(método: ${paymentMethod.toDb()}, propina: $tipCents cts, '
        'total: ${closed.totalCents} cts).',
        tag: 'Checkout',
      );

      state = state.copyWith(isClosing: false, closed: true);
    } catch (e, st) {
      AppLogger.error(
        'Error al cerrar pedido $orderId',
        error: e,
        stackTrace: st,
        tag: 'Checkout',
      );
      state = CheckoutState(isClosing: false, error: e);
      rethrow;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Provider del [CheckoutController].
final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, CheckoutState>(
      (ref) => CheckoutController(ref),
    );
