import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';

/// Contrato de acceso local (Drift) a pedidos.
///
/// La implementación concreta es [DriftOrderLocalRepository] en data/.
/// Este archivo no importa Flutter ni Drift — solo entidades de dominio.
abstract class OrderLocalRepository {
  /// Crea un pedido nuevo en estado [OrderStatus.open].
  ///
  /// Genera el UUID en cliente (compartido luego con Supabase al sincronizar).
  /// El [totalCents] inicial es 0 — se recalcula al agregar ítems (ACID-3).
  Future<CustomerOrder> createOrder({
    required String venueId,
    required String diningTableId,
    String? openedBy,
  });

  /// Agrega un ítem al pedido y recalcula [CustomerOrder.totalCents].
  ///
  /// Fija [OrderItem.nameSnapshot] y [OrderItem.priceCentsSnapshot] desde
  /// [menuItem] en el momento del INSERT — inmutables (ACID-2).
  ///
  /// Recalcula totalCents = SUM(priceCentsSnapshot × quantity) de ítems
  /// con status != cancelled (espejo del trigger Postgres compute_order_total).
  Future<OrderItem> addItem({
    required String orderId,
    required MenuItem menuItem,
    int quantity = 1,
    String? comments,
  });

  /// Retorna el pedido por ID, o null si no existe.
  Future<CustomerOrder?> orderById(String id);

  /// Retorna todos los ítems de un pedido.
  Future<List<OrderItem>> itemsOf(String orderId);

  /// Stream reactivo de pedidos abiertos de un venue, ordenados por apertura.
  Stream<List<CustomerOrder>> watchOpenOrders(String venueId);

  /// Stream reactivo de pedidos activos (sent, preparing, ready) de un venue.
  ///
  /// Alimenta el KDS de cocina. Excluye open, closed y cancelled.
  /// Ordenados por openedAt asc para servir en el mismo orden de llegada.
  Stream<List<CustomerOrder>> watchActiveOrders(String venueId);

  /// Stream reactivo de pedidos no cerrados (open, sent, preparing, ready).
  ///
  /// Alimenta el grid de mesas. Excluye closed y cancelled.
  /// Ordenados por openedAt asc.
  Stream<List<CustomerOrder>> watchNonClosedOrders(String venueId);

  /// Stream reactivo de ítems de un pedido, ordenados por id asc.
  ///
  /// Reactivo: emite cada vez que cambia un ítem del pedido.
  Stream<List<OrderItem>> watchItems(String orderId);

  /// Actualiza el estado de un ítem y re-deriva el estado del pedido padre.
  ///
  /// Regla de derivación (ignora ítems cancelled):
  /// - sin ítems no-cancelados → no cambia el status del pedido.
  /// - todos los no-cancelados en ready → pedido ready.
  /// - alguno en preparing o ready (pero no todos ready) → pedido preparing.
  /// - todos en sent → pedido sent.
  ///
  /// Lanza [ArgumentError] si el ítem no existe.
  /// Lanza [StateError] si el pedido padre está cerrado (ACID-4).
  Future<OrderItem> updateItemStatus(String itemId, OrderItemStatus status);

  /// Actualiza el estado de un pedido y retorna el pedido actualizado.
  ///
  /// Usar para la transición `open → sent` al confirmar el pedido desde la
  /// pantalla de toma de pedido (COMA-007). El estado `closed` es terminal
  /// y no se puede modificar (ACID-4) — hacer cumplir a nivel de repo.
  Future<CustomerOrder> updateStatus(String orderId, OrderStatus status);
}
