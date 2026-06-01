import 'dart:async';

import 'package:comand_ia/features/auth/presentation/controllers/auth_controller.dart';
import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── View model ───────────────────────────────────────────────────────────────

/// Vista de una mesa para el grid: combina la mesa con su pedido vivo actual.
///
/// Si [orderStatus] es null, la mesa está libre (sin pedido activo).
class TableView {
  const TableView({
    required this.table,
    this.orderStatus,
    this.orderId,
    this.totalCents = 0,
  });

  /// Datos de la mesa.
  final DiningTable table;

  /// Estado del pedido vivo más reciente (null = mesa libre).
  final OrderStatus? orderStatus;

  /// UUID del pedido vivo (null = mesa libre).
  final String? orderId;

  /// Total del pedido en centavos (0 si no hay pedido).
  final int totalCents;

  /// Verdadero si la mesa no tiene pedido activo.
  bool get isFree => orderStatus == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableView &&
          table == other.table &&
          orderStatus == other.orderStatus &&
          orderId == other.orderId &&
          totalCents == other.totalCents;

  @override
  int get hashCode =>
      table.hashCode ^
      orderStatus.hashCode ^
      orderId.hashCode ^
      totalCents.hashCode;
}

// ─── Helper interno ───────────────────────────────────────────────────────────

/// Combina listas de mesas y pedidos en una lista de [TableView].
///
/// Por cada mesa activa, busca el pedido vivo más reciente (si lo hay)
/// y produce un [TableView] con su status y total. Orden por sortOrder.
List<TableView> _combine(List<DiningTable> tables, List<CustomerOrder> orders) {
  // Índice: diningTableId → pedido más reciente (por openedAt) no cerrado.
  final Map<String, CustomerOrder> orderByTable = {};
  for (final order in orders) {
    final existing = orderByTable[order.diningTableId];
    if (existing == null || order.openedAt.isAfter(existing.openedAt)) {
      orderByTable[order.diningTableId] = order;
    }
  }

  return tables.map((table) {
    final order = orderByTable[table.id];
    return TableView(
      table: table,
      orderStatus: order?.status,
      orderId: order?.id,
      totalCents: order?.totalCents ?? 0,
    );
  }).toList();
}

// ─── Provider combinado ───────────────────────────────────────────────────────

/// Stream de vistas de mesa para el grid.
///
/// Combina mesas activas (active == true, orden sortOrder asc) con pedidos
/// no cerrados del venue actual. Emite una nueva lista cada vez que cambia
/// cualquiera de los dos streams reactivos de Drift.
final tablesViewProvider = StreamProvider<List<TableView>>((ref) {
  final user = ref.watch(currentUserProvider);
  final venueId = user?.venueId ?? 'venue-001-mock';

  final tableRepo = ref.watch(diningTableLocalRepositoryProvider);
  final orderRepo = ref.watch(orderLocalRepositoryProvider);

  // Mantiene los últimos valores conocidos de cada stream.
  List<DiningTable>? lastTables;
  List<CustomerOrder>? lastOrders;

  final controller = StreamController<List<TableView>>();

  // Emite si ambos valores ya están disponibles.
  void tryEmit() {
    final t = lastTables;
    final o = lastOrders;
    if (t != null && o != null) {
      controller.add(_combine(t, o));
    }
  }

  final subTables = tableRepo
      .watchTables(venueId)
      .listen(
        (tables) {
          lastTables = tables;
          tryEmit();
        },
        onError: controller.addError,
        onDone: controller.close,
      );

  final subOrders = orderRepo.watchNonClosedOrders(venueId).listen((orders) {
    lastOrders = orders;
    tryEmit();
  }, onError: controller.addError);

  ref.onDispose(() {
    subTables.cancel();
    subOrders.cancel();
    controller.close();
  });

  return controller.stream;
});
