import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/core/format.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:comand_ia/features/orders/presentation/providers/kitchen_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de cierre de cuenta.
///
/// El cajero revisa el detalle del pedido, elige el método de pago,
/// fija la propina (la decide el comensal en caja) y cierra la cuenta.
/// Al cerrar, el pedido pasa a status closed y la mesa queda libre.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  /// Propina seleccionada en centavos.
  int _tipCents = 0;

  /// Porcentaje de la propina en el modo de botones rápidos.
  /// null indica modo de monto personalizado.
  double? _tipPercent = 0.10;

  final TextEditingController _customTipController = TextEditingController();
  bool _useCustomTip = false;

  /// Verdadero cuando la propina inicial (10%) ya fue calculada sobre el subtotal.
  bool _tipInitialized = false;

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  /// Recalcula [_tipCents] según el subtotal y el porcentaje seleccionado.
  void _updateTipFromPercent(int subtotalCents) {
    if (_tipPercent != null) {
      setState(() {
        _tipCents = (subtotalCents * _tipPercent!).round();
      });
    }
  }

  /// Valida y actualiza la propina personalizada desde el campo de texto.
  void _parseCustomTip() {
    final raw = _customTipController.text.trim();
    if (raw.isEmpty) {
      setState(() => _tipCents = 0);
      return;
    }
    // El cajero ingresa pesos CLP (sin decimales); convertimos × 100.
    final pesos = int.tryParse(raw.replaceAll('.', ''));
    if (pesos != null && pesos >= 0) {
      setState(() => _tipCents = pesos * 100);
    }
  }

  Future<void> _handleClose(int subtotalCents) async {
    final ctrl = ref.read(checkoutControllerProvider.notifier);
    try {
      await ctrl.close(
        orderId: widget.orderId,
        paymentMethod: _paymentMethod,
        tipCents: _tipCents,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta cerrada'),
            backgroundColor: AppTheme.primary,
          ),
        );
        context.go('/tables');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar la cuenta: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(checkoutOrderProvider(widget.orderId));
    final checkoutState = ref.watch(checkoutControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tables'),
          tooltip: 'Volver a mesas',
        ),
        title: const Text('Cobrar cuenta'),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => Center(
              child: Text(
                'Error al cargar el pedido',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado'));
          }
          // Inicializa la propina la primera vez que llega el subtotal.
          if (!_tipInitialized && _tipPercent != null) {
            _tipCents = (order.totalCents * _tipPercent!).round();
            _tipInitialized = true;
          }
          return _CheckoutBody(
            order: order,
            orderId: widget.orderId,
            paymentMethod: _paymentMethod,
            tipCents: _tipCents,
            tipPercent: _tipPercent,
            useCustomTip: _useCustomTip,
            customTipController: _customTipController,
            isClosing: checkoutState.isClosing,
            onPaymentMethodChanged: (method) {
              setState(() => _paymentMethod = method);
            },
            onTipPercentChanged: (percent, subtotal) {
              setState(() {
                _tipPercent = percent;
                _useCustomTip = false;
                _customTipController.clear();
              });
              _updateTipFromPercent(subtotal);
            },
            onCustomTipToggled: (subtotal) {
              setState(() {
                _tipPercent = null;
                _useCustomTip = true;
                _tipCents = 0;
                _customTipController.clear();
              });
            },
            onCustomTipChanged: (_) => _parseCustomTip(),
            onClose: () => _handleClose(order.totalCents),
          );
        },
      ),
    );
  }
}

// ─── Cuerpo principal ──────────────────────────────────────────────────────────

class _CheckoutBody extends ConsumerWidget {
  const _CheckoutBody({
    required this.order,
    required this.orderId,
    required this.paymentMethod,
    required this.tipCents,
    required this.tipPercent,
    required this.useCustomTip,
    required this.customTipController,
    required this.isClosing,
    required this.onPaymentMethodChanged,
    required this.onTipPercentChanged,
    required this.onCustomTipToggled,
    required this.onCustomTipChanged,
    required this.onClose,
  });

  final CustomerOrder order;
  final String orderId;
  final PaymentMethod paymentMethod;
  final int tipCents;
  final double? tipPercent;
  final bool useCustomTip;
  final TextEditingController customTipController;
  final bool isClosing;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final void Function(double percent, int subtotal) onTipPercentChanged;
  final void Function(int subtotal) onCustomTipToggled;
  final ValueChanged<String> onCustomTipChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(orderId));
    final subtotal = order.totalCents;
    final totalDisplay = subtotal + tipCents;

    return Column(
      children: [
        // ─── Contenido desplazable ────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado de mesa
                _SectionCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.table_restaurant,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mesa ${order.diningTableId}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Detalle de ítems
                _SectionCard(
                  child: itemsAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (err, _) => Text(
                          'Error al cargar ítems',
                          style: TextStyle(color: AppTheme.error),
                        ),
                    data:
                        (items) => _ItemList(items: items, subtotal: subtotal),
                  ),
                ),

                const SizedBox(height: 12),

                // Selector de método de pago
                _SectionCard(
                  child: _PaymentMethodSelector(
                    selected: paymentMethod,
                    onChanged: onPaymentMethodChanged,
                  ),
                ),

                const SizedBox(height: 12),

                // Selector de propina
                _SectionCard(
                  child: _TipSelector(
                    subtotalCents: subtotal,
                    tipCents: tipCents,
                    tipPercent: tipPercent,
                    useCustomTip: useCustomTip,
                    customTipController: customTipController,
                    onPercentChanged: onTipPercentChanged,
                    onCustomToggled: onCustomTipToggled,
                    onCustomChanged: onCustomTipChanged,
                  ),
                ),

                const SizedBox(height: 12),

                // Total a cobrar (display: subtotal + propina)
                _TotalDisplay(
                  subtotal: subtotal,
                  tipCents: tipCents,
                  total: totalDisplay,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ─── Botón de cierre fijo abajo ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ElevatedButton(
            onPressed: isClosing ? null : onClose,
            child:
                isClosing
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Cerrar cuenta'),
          ),
        ),
      ],
    );
  }
}

// ─── Lista de ítems con subtotal ──────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.subtotal});

  final List<OrderItem> items;
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Sin ítems en este pedido');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Detalle',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.nameSnapshot,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${item.quantity}× ${formatClp(item.priceCentsSnapshot)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatClp(item.priceCentsSnapshot * item.quantity),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtotal',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              formatClp(subtotal),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Selector de método de pago ────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de pago',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PaymentChip(
              label: 'Efectivo',
              icon: Icons.payments_outlined,
              method: PaymentMethod.cash,
              selected: selected,
              onTap: onChanged,
            ),
            _PaymentChip(
              label: 'Tarjeta',
              icon: Icons.credit_card,
              method: PaymentMethod.card,
              selected: selected,
              onTap: onChanged,
            ),
            _PaymentChip(
              label: 'Transferencia',
              icon: Icons.account_balance_outlined,
              method: PaymentMethod.transfer,
              selected: selected,
              onTap: onChanged,
            ),
            _PaymentChip(
              label: 'Otro',
              icon: Icons.more_horiz,
              method: PaymentMethod.other,
              selected: selected,
              onTap: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final PaymentMethod method;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onTap;

  bool get _isSelected => method == selected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: _isSelected ? Colors.white : AppTheme.textSecondary,
      ),
      label: Text(label),
      selected: _isSelected,
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: _isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) => onTap(method),
    );
  }
}

// ─── Selector de propina ──────────────────────────────────────────────────────

class _TipSelector extends StatelessWidget {
  const _TipSelector({
    required this.subtotalCents,
    required this.tipCents,
    required this.tipPercent,
    required this.useCustomTip,
    required this.customTipController,
    required this.onPercentChanged,
    required this.onCustomToggled,
    required this.onCustomChanged,
  });

  final int subtotalCents;
  final int tipCents;
  final double? tipPercent;
  final bool useCustomTip;
  final TextEditingController customTipController;
  final void Function(double percent, int subtotal) onPercentChanged;
  final void Function(int subtotal) onCustomToggled;
  final ValueChanged<String> onCustomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propina (la decide el comensal)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // Botones rápidos de porcentaje
        Row(
          children: [
            _TipPercentButton(
              label: '0%',
              percent: 0.0,
              selected: tipPercent == 0.0 && !useCustomTip,
              subtotal: subtotalCents,
              onTap: onPercentChanged,
            ),
            const SizedBox(width: 8),
            _TipPercentButton(
              label: '10%',
              percent: 0.10,
              selected: tipPercent == 0.10 && !useCustomTip,
              subtotal: subtotalCents,
              onTap: onPercentChanged,
            ),
            const SizedBox(width: 8),
            _TipPercentButton(
              label: '15%',
              percent: 0.15,
              selected: tipPercent == 0.15 && !useCustomTip,
              subtotal: subtotalCents,
              onTap: onPercentChanged,
            ),
            const SizedBox(width: 8),
            // Botón de monto personalizado
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color:
                      useCustomTip ? AppTheme.primary : const Color(0xFFE0E0E0),
                  width: useCustomTip ? 2 : 1,
                ),
                foregroundColor:
                    useCustomTip ? AppTheme.primary : AppTheme.textSecondary,
              ),
              onPressed: () => onCustomToggled(subtotalCents),
              child: const Text('Otro'),
            ),
          ],
        ),

        // Campo de monto personalizado (solo visible en modo custom)
        if (useCustomTip) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customTipController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Propina en pesos CLP',
              prefixText: '\$',
              hintText: '0',
            ),
            onChanged: onCustomChanged,
          ),
        ],

        // Propina seleccionada en CLP
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Propina',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            Text(
              formatClp(tipCents),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipPercentButton extends StatelessWidget {
  const _TipPercentButton({
    required this.label,
    required this.percent,
    required this.selected,
    required this.subtotal,
    required this.onTap,
  });

  final String label;
  final double percent;
  final bool selected;
  final int subtotal;
  final void Function(double percent, int subtotal) onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppTheme.primary : null,
        side: BorderSide(
          color: selected ? AppTheme.primary : const Color(0xFFE0E0E0),
          width: selected ? 2 : 1,
        ),
        foregroundColor: selected ? Colors.white : AppTheme.textPrimary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: () => onTap(percent, subtotal),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ─── Total a cobrar ────────────────────────────────────────────────────────────

class _TotalDisplay extends StatelessWidget {
  const _TotalDisplay({
    required this.subtotal,
    required this.tipCents,
    required this.total,
  });

  final int subtotal;
  final int tipCents;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              Text(
                formatClp(subtotal),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Propina',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              Text(
                formatClp(tipCents),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total a cobrar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                formatClp(total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card de sección ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
