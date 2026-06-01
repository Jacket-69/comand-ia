import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/presentation/providers/kitchen_providers.dart';
import 'package:comand_ia/features/orders/presentation/screens/kitchen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tarjeta de pedido en el KDS.
///
/// Muestra el encabezado del pedido (mesa, estado, hora) y
/// la lista de ítems con sus controles de avance de estado.
/// Diseñada para pantalla tablet de cocina: elementos táctiles grandes.
class KdsOrderCard extends ConsumerWidget {
  const KdsOrderCard({
    required this.order,
    required this.isAdvancing,
    super.key,
  });

  final CustomerOrder order;

  /// Verdadero mientras el controller está procesando un avance.
  /// Deshabilita todos los botones de avance mientras se procesa.
  final bool isAdvancing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(order.id));
    final statusColor = orderStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Encabezado ────────────────────────────────────────────────
          _OrderCardHeader(order: order, statusColor: statusColor),

          const Divider(height: 1),

          // ─── Ítems del pedido ──────────────────────────────────────────
          itemsAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error al cargar ítems: $e',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sin ítems',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return _OrderItemsList(items: items, isAdvancing: isAdvancing);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Encabezado de tarjeta ────────────────────────────────────────────────────

class _OrderCardHeader extends StatelessWidget {
  const _OrderCardHeader({required this.order, required this.statusColor});

  final CustomerOrder order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    // Hora de apertura formateada HH:mm
    final hour = order.openedAt.hour.toString().padLeft(2, '0');
    final minute = order.openedAt.minute.toString().padLeft(2, '0');
    final timeLabel = '$hour:$minute';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icono de mesa
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Icon(Icons.table_restaurant, color: statusColor, size: 28),
          ),
          const SizedBox(width: 12),

          // Mesa e identificador del pedido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesa ${order.diningTableId}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Desde $timeLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Chip de estado del pedido
          _StatusChip(
            label: orderStatusLabel(order.status),
            color: statusColor,
          ),
        ],
      ),
    );
  }
}

// ─── Lista de ítems ───────────────────────────────────────────────────────────

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({required this.items, required this.isAdvancing});

  final List<OrderItem> items;
  final bool isAdvancing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (final item in items)
            _OrderItemRow(item: item, isAdvancing: isAdvancing),
        ],
      ),
    );
  }
}

// ─── Fila de ítem ─────────────────────────────────────────────────────────────

class _OrderItemRow extends ConsumerWidget {
  const _OrderItemRow({required this.item, required this.isAdvancing});

  final OrderItem item;

  /// Deshabilita el botón mientras el controller procesa cualquier avance.
  final bool isAdvancing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = item.status == OrderItemStatus.ready;
    final isCancelled = item.status == OrderItemStatus.cancelled;
    final itemColor = itemStatusColor(item.status);
    final canAdvance = !isReady && !isCancelled && !isAdvancing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cantidad
          SizedBox(
            width: 36,
            child: Text(
              '${item.quantity}×',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // Nombre e comentarios
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameSnapshot,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        isCancelled
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.comments != null && item.comments!.isNotEmpty)
                  Text(
                    item.comments!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warning,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Chip de estado del ítem
          _StatusChip(
            label: itemStatusLabel(item.status),
            color: itemColor,
            compact: true,
          ),

          const SizedBox(width: 8),

          // Botón de avance — visible siempre; ✓ si ya está listo
          SizedBox(
            width: 52,
            height: 52,
            child:
                isReady
                    ? Icon(
                      Icons.check_circle,
                      color: AppTheme.kdsReady,
                      size: 36,
                    )
                    : isCancelled
                    ? const SizedBox.shrink()
                    : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAdvance ? itemColor : AppTheme.textSecondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusSmall,
                          ),
                        ),
                      ),
                      onPressed:
                          canAdvance
                              ? () => ref
                                  .read(kitchenControllerProvider.notifier)
                                  .advanceItem(item)
                              : null,
                      child: const Icon(Icons.arrow_forward, size: 22),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de estado reutilizable ──────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;

  /// Si es true, usa padding más reducido (para chips de ítem).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }
}
