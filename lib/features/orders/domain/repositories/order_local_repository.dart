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

  /// Actualiza el estado de un pedido y retorna el pedido actualizado.
  ///
  /// Usar para la transición `open → sent` al confirmar el pedido desde la
  /// pantalla de toma de pedido (COMA-007). El estado `closed` es terminal
  /// y no se puede modificar (ACID-4) — hacer cumplir a nivel de repo.
  Future<CustomerOrder> updateStatus(String orderId, OrderStatus status);
}
