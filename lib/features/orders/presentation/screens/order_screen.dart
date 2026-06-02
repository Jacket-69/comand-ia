import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/core/format.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/presentation/controllers/order_draft_controller.dart';
import 'package:comand_ia/features/orders/presentation/providers/seed_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de toma de pedido para una mesa.
///
/// Corresponde a la Vista 2 (selección de categoría) y Vista 3 (lista de ítems)
/// del Figma de COMAND-IA. Usa [OrderDraftController] para el estado en memoria.
///
/// El flujo es:
///   Vista 2: grid de 6 categorías → tap → Vista 3
///   Vista 3: lista de ítems filtrable + stepper + panel del pedido + "Enviar a Cocina"
class OrderScreen extends ConsumerWidget {
  const OrderScreen({required this.tableId, super.key});

  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Esperar el seed antes de mostrar el menú
    final seedState = ref.watch(devSeedProvider);

    return seedState.when(
      loading:
          () => Scaffold(
            appBar: _buildAppBar(context, ref, null),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, _) => Scaffold(
            appBar: _buildAppBar(context, ref, null),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar el menú',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      data: (_) => _OrderContent(tableId: tableId),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    OrderDraftState? state,
  ) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/tables'),
        tooltip: 'Volver a mesas',
      ),
      title: Text('Mesa $tableId'),
    );
  }
}

/// Widget principal que redirige entre Vista 2 y Vista 3 según la categoría activa.
class _OrderContent extends ConsumerWidget {
  const _OrderContent({required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderDraftControllerProvider(tableId));

    if (state.selectedCategory == null) {
      // Vista 2: selección de categoría
      return _CategorySelectionView(tableId: tableId, state: state);
    } else {
      // Vista 3: lista de ítems + panel de pedido
      return _ItemListView(tableId: tableId, state: state);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista 2 — Selección de Categoría
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySelectionView extends ConsumerWidget {
  const _CategorySelectionView({required this.tableId, required this.state});

  final String tableId;
  final OrderDraftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(orderDraftControllerProvider(tableId).notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tables'),
          tooltip: 'Volver a mesas',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mesas'),
            Text(
              '¿Qué van a pedir?',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Título de la sección
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Selecciona una categoría del menú',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),

          // Estado loading o error del menú
          if (state.isLoadingMenu)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.menuError != null)
            Expanded(child: _ErrorView(message: state.menuError!))
          else if (state.categories.isEmpty)
            const Expanded(child: _EmptyMenuView())
          else
            // Grid de categorías
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: state.categories.length,
                itemBuilder: (context, index) {
                  return _CategoryCard(
                    category: state.categories[index],
                    onTap: () => ctrl.selectCategory(state.categories[index]),
                  );
                },
              ),
            ),

          // Indicador si hay ítems en el borrador
          if (state.hasLines) _DraftSummaryBar(tableId: tableId, state: state),
        ],
      ),
    );
  }
}

/// Tarjeta de categoría con color temático.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final MenuCategory category;
  final VoidCallback onTap;

  Color get _color {
    switch (category.name) {
      case 'Entradas':
        return AppTheme.categoryEntradas;
      case 'Almuerzos':
        return AppTheme.categoryAlmuerzos;
      case 'Parrilladas':
        return AppTheme.categoryParrilladas;
      case 'Bebidas':
        return AppTheme.categoryBebidas;
      case 'Postres':
        return AppTheme.categoryPostres;
      case 'Café':
        return AppTheme.categoryCafe;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista 3 — Lista de ítems de la categoría + panel del pedido
// ─────────────────────────────────────────────────────────────────────────────

class _ItemListView extends ConsumerWidget {
  const _ItemListView({required this.tableId, required this.state});

  final String tableId;
  final OrderDraftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(orderDraftControllerProvider(tableId).notifier);
    final category = state.selectedCategory!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Volver a la selección de categoría
          onPressed: ctrl.clearCategory,
          tooltip: 'Cambiar categoría',
        ),
        title: Row(
          children: [
            Text(category.name),
            const SizedBox(width: 8),
            Text(
              'Mesa $tableId',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ctrl.setSearch,
            ),
          ),

          // Lista de ítems
          Expanded(
            child:
                state.isLoadingMenu
                    ? const Center(child: CircularProgressIndicator())
                    : state.menuError != null
                    ? _ErrorView(message: state.menuError!)
                    : state.itemsInCategory.isEmpty
                    ? const _EmptyItemsView()
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: state.itemsInCategory.length,
                      itemBuilder: (context, index) {
                        final item = state.itemsInCategory[index];
                        final line =
                            state.lines
                                .where((l) => l.menuItem.id == item.id)
                                .firstOrNull;
                        return _MenuItemCard(
                          item: item,
                          line: line,
                          onAdd: () => ctrl.addItem(item),
                          onIncrement: () => ctrl.incrementQty(item.id),
                          onDecrement: () => ctrl.decrementQty(item.id),
                          onRemove: () => ctrl.removeLine(item.id),
                        );
                      },
                    ),
          ),

          // Panel inferior del pedido
          if (state.hasLines || state.lines.isEmpty)
            _OrderPanel(tableId: tableId, state: state),
        ],
      ),
    );
  }
}

/// Tarjeta de ítem del menú con stepper o botón +.
class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.line,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final MenuItem item;
  final DraftLine? line;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen del plato a la izquierda con bordes redondeados
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  item.imageUrl != null
                      ? Image.network(
                        item.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                      : Container(
                        width: 80,
                        height: 80,
                        color: AppTheme.surface,
                        child: const Icon(
                          Icons.restaurant,
                          color: AppTheme.textSecondary,
                          size: 32,
                        ),
                      ),
            ),
            const SizedBox(width: 12),

            // Información central: Nombre, Descripción y Precio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatClp(item.priceCents),
                    style: const TextStyle(
                      color: AppTheme.primary, // Verde
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Botón de acción a la derecha (Botón circular azul o stepper completo)
            if (line == null || line!.quantity == 0)
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary, // Azul
                  minimumSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: onAdd,
                tooltip: 'Agregar ${item.name}',
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    onPressed: onDecrement,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${line!.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    onPressed: onIncrement,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Panel inferior con resumen del pedido y botones de acción.
///
/// En append mode muestra:
///   - Banner con el total y cuenta del pedido activo.
///   - Botón primario "Agregar a cocina" (solo si hay líneas en el borrador).
///
/// El cobro se inicia desde la hoja de acciones de la mesa (grid), no desde aquí.
/// En modo nuevo muestra el flujo clásico con "Enviar a Cocina".
class _OrderPanel extends ConsumerWidget {
  const _OrderPanel({required this.tableId, required this.state});

  final String tableId;
  final OrderDraftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(orderDraftControllerProvider(tableId).notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner del pedido activo (solo append mode)
          if (state.isAppendMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pedido actual · ${state.existingItemCount} ítems',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    formatClp(state.existingOrderTotalCents),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Líneas del borrador
          if (state.hasLines)
            ...state.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.menuItem.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${line.quantity}×  ${formatClp(line.menuItem.priceCents)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (state.hasLines) ...[
            const Divider(),

            // Conteo de ítems del borrador
            Text(
              '${state.lines.fold(0, (acc, l) => acc + l.quantity)} ítems nuevos',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),

            // Propina sugerida (solo informativa — NO se persiste)
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Propina sugerida (10%)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  formatClp(state.suggestedTipCents),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatClp(state.referenceTotal),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else if (!state.isAppendMode) ...[
            const Divider(),
          ],

          // Botón principal: "Agregar a cocina" o "Enviar a Cocina"
          ElevatedButton(
            onPressed:
                state.isConfirming || !state.hasLines
                    ? null
                    : () async {
                      final isAppend = state.isAppendMode;
                      try {
                        await ctrl.confirm();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isAppend
                                    ? 'Ítems agregados al pedido'
                                    : 'Pedido enviado a cocina',
                              ),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                          context.go('/tables');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al enviar el pedido: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
            child:
                state.isConfirming
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      state.isAppendMode
                          ? 'Agregar a cocina'
                          : 'Enviar a Cocina',
                    ),
          ),
        ],
      ),
    );
  }
}

/// Barra flotante en la vista de categorías que indica hay ítems en el borrador.
class _DraftSummaryBar extends ConsumerWidget {
  const _DraftSummaryBar({required this.tableId, required this.state});

  final String tableId;
  final OrderDraftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.lines.fold(0, (acc, l) => acc + l.quantity)} ítem(s) en el pedido',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            formatClp(state.subtotalCents),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estados vacíos y de error
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMenuView extends StatelessWidget {
  const _EmptyMenuView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.restaurant_menu,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay categorías disponibles',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyItemsView extends StatelessWidget {
  const _EmptyItemsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No hay ítems en esta categoría',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el menú',
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
