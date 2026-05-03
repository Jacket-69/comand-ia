import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Estado de una mesa del local.
enum TableStatus {
  /// Libre — lista para recibir clientes.
  available,

  /// Con una orden activa.
  withOrder,

  /// Reservada — no disponible.
  reserved,
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

/// Modelo de datos de una mesa.
class TableData {
  const TableData({
    required this.id,
    required this.number,
    required this.status,
    this.indicator = OrderIndicator.none,
    this.guestCount = 0,
    this.orderTotal = 0,
  });

  final String id;
  final int number;
  final TableStatus status;
  final OrderIndicator indicator;
  final int guestCount;
  final double orderTotal;
}

/// Datos mock de las 20 mesas del local.
final mockTables = [
  const TableData(
    id: '1',
    number: 1,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.active,
    guestCount: 4,
    orderTotal: 32500,
  ),
  const TableData(id: '2', number: 2, status: TableStatus.available),
  const TableData(
    id: '3',
    number: 3,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.waiting,
    guestCount: 2,
    orderTotal: 18000,
  ),
  const TableData(id: '4', number: 4, status: TableStatus.available),
  const TableData(id: '5', number: 5, status: TableStatus.reserved),
  const TableData(
    id: '6',
    number: 6,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.readyToServe,
    guestCount: 6,
    orderTotal: 54000,
  ),
  const TableData(id: '7', number: 7, status: TableStatus.available),
  const TableData(id: '8', number: 8, status: TableStatus.available),
  const TableData(
    id: '9',
    number: 9,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.active,
    guestCount: 3,
    orderTotal: 27000,
  ),
  const TableData(id: '10', number: 10, status: TableStatus.available),
  const TableData(id: '11', number: 11, status: TableStatus.reserved),
  const TableData(id: '12', number: 12, status: TableStatus.available),
  const TableData(
    id: '13',
    number: 13,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.waiting,
    guestCount: 2,
    orderTotal: 15000,
  ),
  const TableData(id: '14', number: 14, status: TableStatus.available),
  const TableData(
    id: '15',
    number: 15,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.readyToServe,
    guestCount: 5,
    orderTotal: 42000,
  ),
  const TableData(id: '16', number: 16, status: TableStatus.available),
  const TableData(id: '17', number: 17, status: TableStatus.available),
  const TableData(id: '18', number: 18, status: TableStatus.reserved),
  const TableData(id: '19', number: 19, status: TableStatus.available),
  const TableData(
    id: '20',
    number: 20,
    status: TableStatus.withOrder,
    indicator: OrderIndicator.active,
    guestCount: 4,
    orderTotal: 38000,
  ),
];

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
      body: Column(
        children: [
          // ─── Stats bar ─────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  count:
                      mockTables
                          .where((t) => t.status == TableStatus.available)
                          .length,
                  label: 'Libres',
                  color: AppTheme.tableAvailable,
                ),
                _StatBadge(
                  count:
                      mockTables
                          .where((t) => t.status == TableStatus.withOrder)
                          .length,
                  label: 'Con Orden',
                  color: AppTheme.tableWithOrder,
                ),
                _StatBadge(
                  count:
                      mockTables
                          .where((t) => t.status == TableStatus.reserved)
                          .length,
                  label: 'Reservadas',
                  color: AppTheme.tableReserved,
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
              itemCount: mockTables.length,
              itemBuilder: (context, index) {
                return _TableCard(table: mockTables[index]);
              },
            ),
          ),

          // ─── Leyenda ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppTheme.dotWithOrder, label: 'Con Pedido'),
                const SizedBox(width: 16),
                _LegendDot(color: AppTheme.dotWaitingOrder, label: 'Esperando'),
                const SizedBox(width: 16),
                _LegendDot(color: AppTheme.dotReadyToServe, label: 'Listo'),
              ],
            ),
          ),
        ],
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
      case TableStatus.reserved:
        return AppTheme.tableReserved;
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
      case TableStatus.reserved:
        return 'Reservada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.go('/order/${table.id}');
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
                    if (table.guestCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${table.guestCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
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
