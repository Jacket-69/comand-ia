import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/core/format.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/presentation/providers/tables_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Estado visual de una mesa del local.
enum TableStatus {
  /// Libre — lista para recibir clientes.
  available,

  /// Con una orden activa.
  withOrder,
}

/// Estado del pedido asociado a la mesa (indicador de punto).
enum OrderIndicator {
  /// Sin indicador.
  none,

  /// Pedido activo (verde).
  active,

  /// Esperando pedido (rojo).
  waiting,

  /// Listo para servir (amarillo).
  readyToServe,
}

/// Modelo de datos visual de una mesa para el grid.
class TableData {
  const TableData({
    required this.id,
    required this.number,
    required this.status,
    this.indicator = OrderIndicator.none,
    this.orderTotal = 0,
    this.orderId,
  });

  final String id;
  final int number;
  final TableStatus status;
  final OrderIndicator indicator;

  /// Total del pedido en centavos (0 si libre).
  final int orderTotal;

  /// UUID del pedido activo (null si la mesa está libre).
  final String? orderId;
}

/// Convierte un [TableView] al modelo visual [TableData] usado por el grid.
///
/// Mapeo de estados:
/// - isFree → available, sin indicador.
/// - ready  → withOrder, indicador readyToServe (punto amarillo).
/// - open/sent/preparing → withOrder, indicador según estado:
///     open → waiting (rojo, aún no enviado a cocina).
///     sent/preparing → active (verde, en curso en cocina).
TableData _toTableData(TableView view) {
  final table = view.table;
  // El número visible se extrae de sortOrder (1-based) o parseando label.
  final number =
      table.sortOrder > 0 ? table.sortOrder : int.tryParse(table.id) ?? 0;

  if (view.isFree) {
    return TableData(
      id: table.id,
      number: number,
      status: TableStatus.available,
    );
  }

  final indicator = switch (view.orderStatus) {
    OrderStatus.ready => OrderIndicator.readyToServe,
    OrderStatus.open => OrderIndicator.waiting,
    OrderStatus.sent || OrderStatus.preparing => OrderIndicator.active,
    // closed/cancelled no deberían llegar (el provider filtra no-cerrados),
    // pero si llegasen los mostramos como sin indicador.
    _ => OrderIndicator.none,
  };

  return TableData(
    id: table.id,
    number: number,
    status: TableStatus.withOrder,
    indicator: indicator,
    orderTotal: view.totalCents,
    orderId: view.orderId,
  );
}

/// Pantalla principal del garzón: grid de mesas del local.
///
/// Corresponde a la Vista 1 del Figma.
/// Muestra mesas en grid con colores según estado y
/// puntos indicadores del estado del pedido.
class TableGridScreen extends ConsumerWidget {
  const TableGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tablesAsync = ref.watch(tablesViewProvider);
    final size = MediaQuery.sizeOf(context);
    final crossAxisCount =
        size.width > 900
            ? 5
            : size.width > 600
            ? 4
            : 3;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona una Mesa'),
            if (user != null)
              Text(
                'Hola, ${user.displayName} 👋',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notificaciones',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: AppTheme.error),
                        SizedBox(width: 8),
                        Text('Cerrar sesión'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: tablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => Center(
              child: Text(
                'Error al cargar las mesas',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
        data: (views) {
          final tables = views.map(_toTableData).toList();
          final freeCount =
              tables.where((t) => t.status == TableStatus.available).length;
          final withOrderCount =
              tables.where((t) => t.status == TableStatus.withOrder).length;

          return Column(
            children: [
              // ─── Stats bar ─────────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBadge(
                      count: freeCount,
                      label: 'Libres',
                      color: AppTheme.tableAvailable,
                    ),
                    _StatBadge(
                      count: withOrderCount,
                      label: 'Con Orden',
                      color: AppTheme.tableWithOrder,
                    ),
                  ],
                ),
              ),

              // ─── Grid de mesas ─────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    return _TableCard(table: tables[index]);
                  },
                ),
              ),

              // ─── Leyenda ───────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(
                      color: AppTheme.dotWithOrder,
                      label: 'Con Pedido',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: AppTheme.dotWaitingOrder,
                      label: 'Esperando',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(color: AppTheme.dotReadyToServe, label: 'Listo'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Componentes internos ────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});

  final TableData table;

  Color get _backgroundColor {
    switch (table.status) {
      case TableStatus.available:
        return AppTheme.tableAvailable;
      case TableStatus.withOrder:
        return AppTheme.tableWithOrder;
    }
  }

  Color? get _indicatorColor {
    switch (table.indicator) {
      case OrderIndicator.none:
        return null;
      case OrderIndicator.active:
        return AppTheme.dotWithOrder;
      case OrderIndicator.waiting:
        return AppTheme.dotWaitingOrder;
      case OrderIndicator.readyToServe:
        return AppTheme.dotReadyToServe;
    }
  }

  String get _statusLabel {
    switch (table.status) {
      case TableStatus.available:
        return 'Libre';
      case TableStatus.withOrder:
        return 'Con orden';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Mesa con pedido activo → cobrar cuenta; mesa libre → nueva toma.
          if (table.status == TableStatus.withOrder && table.orderId != null) {
            context.go('/checkout/${table.orderId}');
          } else {
            context.go('/order/${table.id}');
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            boxShadow: [
              BoxShadow(
                color: _backgroundColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Indicador de punto
              if (_indicatorColor != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _indicatorColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),

              // Contenido
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${table.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Total del pedido formateado a CLP (solo borde de UI)
                    if (table.orderTotal > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatClp(table.orderTotal),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
