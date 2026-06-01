import 'package:comand_ia/app/router.dart';
import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/presentation/providers/kitchen_providers.dart';
import 'package:comand_ia/features/orders/presentation/widgets/kds_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Pantalla KDS (Kitchen Display System) de cocina.
///
/// Muestra los pedidos activos (sent, preparing, ready) ordenados por
/// antigüedad (más viejos primero). Cada tarjeta lista los ítems del pedido
/// con su estado y un botón para avanzarlos al siguiente estado.
///
/// Diseñada para tablet de cocina: fuentes grandes, botones amplios.
class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);
    final kitchenState = ref.watch(kitchenControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.tables),
          tooltip: 'Volver a mesas',
        ),
        title: const Text('Cocina'),
        actions: [
          // Indicador visual si hay una operación en curso
          if (kitchenState.isAdvancing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _KdsErrorView(message: '$error'),
        data: (orders) {
          if (orders.isEmpty) {
            return const _KdsEmptyView();
          }

          // Ordena por antigüedad: más viejos primero
          final sorted = [...orders]
            ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final order = sorted[index];
              return KdsOrderCard(
                order: order,
                isAdvancing: kitchenState.isAdvancing,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Estados vacío / error ────────────────────────────────────────────────────

class _KdsEmptyView extends StatelessWidget {
  const _KdsEmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Sin pedidos en cocina',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Todo al día — no hay pedidos activos.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _KdsErrorView extends StatelessWidget {
  const _KdsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar los pedidos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers de presentación ──────────────────────────────────────────────────

/// Etiqueta legible del estado del pedido para la UI.
String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.sent => 'Enviado',
  OrderStatus.preparing => 'Preparando',
  OrderStatus.ready => 'Listo',
  OrderStatus.open => 'Abierto',
  OrderStatus.closed => 'Cerrado',
  OrderStatus.cancelled => 'Cancelado',
};

/// Color asociado al estado del pedido (tokens KDS de AppTheme).
Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.sent => AppTheme.kdsPending,
  OrderStatus.preparing => AppTheme.kdsPreparing,
  OrderStatus.ready => AppTheme.kdsReady,
  OrderStatus.open => AppTheme.textSecondary,
  OrderStatus.closed => AppTheme.textSecondary,
  OrderStatus.cancelled => AppTheme.error,
};

/// Etiqueta legible del estado del ítem para la UI.
String itemStatusLabel(OrderItemStatus status) => switch (status) {
  OrderItemStatus.sent => 'Enviado',
  OrderItemStatus.preparing => 'Preparando',
  OrderItemStatus.ready => 'Listo',
  OrderItemStatus.cancelled => 'Cancelado',
};

/// Color asociado al estado del ítem (tokens KDS de AppTheme).
Color itemStatusColor(OrderItemStatus status) => switch (status) {
  OrderItemStatus.sent => AppTheme.kdsPending,
  OrderItemStatus.preparing => AppTheme.kdsPreparing,
  OrderItemStatus.ready => AppTheme.kdsReady,
  OrderItemStatus.cancelled => AppTheme.textSecondary,
};
