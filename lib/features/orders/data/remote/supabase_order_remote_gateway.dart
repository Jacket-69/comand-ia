import 'dart:convert';

import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_data_source.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_apply_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lógica de drenaje de la cola FIFO hacia el backend (COMA-008).
///
/// Implementa [OrderRemoteGateway] sobre un [OrderRemoteDataSource] (la I/O
/// cruda: PostgREST/Auth). Aquí vive lo que importa testear: idempotencia,
/// clasificación recuperable/permanente, respeto de snapshots y adopción de
/// timestamps (LWW). Al depender del puerto y no de `SupabaseClient`, todo
/// esto se ejercita con un fake sin tocar la red.
///
/// Idempotencia: los INSERT usan upsert con `ignoreDuplicates` (los UUID se
/// generan en cliente), y el cierre verifica el estado remoto antes de
/// escribir. Un reintento tras éxito parcial retorna [SyncApplied], no error.
///
/// Campos gestionados por el servidor que JAMÁS se envían: `total_cents`
/// (trigger `compute_order_total`, ACID-3) y `updated_at` (trigger
/// `set_updated_at`, fuente de verdad del LWW — ADR-0008).
class SupabaseOrderRemoteGateway implements OrderRemoteGateway {
  const SupabaseOrderRemoteGateway(this._data);

  final OrderRemoteDataSource _data;

  @override
  Future<bool> ensureReady() async {
    final uid = _data.currentUserId;
    if (uid == null || !_data.hasActiveSession) return false;
    try {
      // Con RLS deny-by-default, app_user solo es visible para miembros
      // activos del venue (current_venue_id() retorna NULL si is_active es
      // FALSE). Si no vemos nuestra propia fila, ningún write va a pasar:
      // mejor no drenar y no quemar attempts de ops que no tienen la culpa.
      return await _data.isAppUserVisible(uid);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get readyChanges => _data.sessionActiveChanges;

  @override
  Future<SyncApplyResult> apply(PendingOp op) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(op.payload) as Map<String, dynamic>;
    } on FormatException catch (e) {
      // Un payload corrupto jamás se arregla reintentando.
      return SyncRejected('payload JSON inválido: ${e.message}');
    }

    try {
      return switch (op.opType) {
        PendingOpType.createOrder => await _applyCreateOrder(payload),
        PendingOpType.addOrderItem => await _applyAddOrderItem(payload),
        PendingOpType.updateOrderItem => await _applyUpdateOrderItem(payload),
        PendingOpType.closeOrder => await _applyCloseOrder(payload),
        PendingOpType.updateOrderStatus => await _applyUpdateOrderStatus(
          payload,
        ),
      };
    } catch (e) {
      return classifyError(e);
    }
  }

  // ─── Operaciones ────────────────────────────────────────────────────────────

  Future<SyncApplyResult> _applyCreateOrder(Map<String, dynamic> p) async {
    final orderId = p['order_id'] as String;

    await _data.upsertIgnoreDuplicates('customer_order', [orderInsertRow(p)]);

    final items = itemInsertRows(p);
    if (items.isNotEmpty) {
      await _data.upsertIgnoreDuplicates('order_item', items);
    }

    return _collectOrderTimestamps(orderId);
  }

  Future<SyncApplyResult> _applyAddOrderItem(Map<String, dynamic> p) async {
    await _data.upsertIgnoreDuplicates('order_item', [singleItemInsertRow(p)]);

    final itemId = p['order_item_id'] as String?;
    final orderId = p['order_id'] as String?;
    if (itemId == null || orderId == null) {
      // Sin ids no hay timestamps que adoptar; la escritura ya quedó hecha.
      return const SyncApplied();
    }
    return SyncApplied(
      orderTimestamps: await _timestampsOf('customer_order', 'id', orderId),
      itemTimestamps: await _timestampsOf('order_item', 'id', itemId),
    );
  }

  Future<SyncApplyResult> _applyUpdateOrderItem(Map<String, dynamic> p) async {
    final itemId = p['order_item_id'] as String?;
    final status = p['status'] as String?;
    if (itemId == null || status == null) {
      return const SyncRejected(
        'update_order_item requiere order_item_id y status',
      );
    }

    final updated = await _data.updateByIdReturningTimestamps(
      'order_item',
      itemId,
      {'status': status},
    );

    if (updated.isEmpty) {
      // ensureReady garantizó visibilidad RLS del propio venue: 0 filas
      // significa que el ítem no existe en remoto (su create_order anterior
      // en la FIFO falló en forma permanente). Reintentar no lo crea.
      return SyncRejected('order_item $itemId no existe en remoto');
    }

    final orderId = p['order_id'] as String?;
    return SyncApplied(
      // El total del pedido lo recalculó el trigger; adopta también su LWW.
      orderTimestamps:
          orderId == null
              ? const {}
              : await _timestampsOf('customer_order', 'id', orderId),
      itemTimestamps: _parseTimestamps(updated),
    );
  }

  Future<SyncApplyResult> _applyCloseOrder(Map<String, dynamic> p) async {
    final orderId = p['order_id'] as String;

    final current = await _data.selectMaybeSingle(
      'customer_order',
      'id, status, updated_at',
      'id',
      orderId,
    );

    if (current == null) {
      return SyncRejected('customer_order $orderId no existe en remoto');
    }
    if (current['status'] == 'closed') {
      // Reintento tras éxito parcial (o cierre desde otro dispositivo):
      // la op ya está aplicada; idempotencia sobre estado terminal (ACID-4).
      return SyncApplied(orderTimestamps: _parseTimestamps([current]));
    }

    // ACID-4 exige un solo UPDATE con status + payment_method + tip_cents:
    // el trigger validate_customer_order anula payment_method/closed_at si
    // status no es 'closed', y bloquea todo UPDATE posterior al cierre.
    final updated = await _data
        .updateByIdReturningTimestamps('customer_order', orderId, {
          'status': 'closed',
          'payment_method': p['payment_method'],
          'tip_cents': p['tip_cents'],
          if (p['closed_at'] != null)
            'closed_at': utcIso(p['closed_at'] as String),
        });

    if (updated.isEmpty) {
      // Carrera improbable (otro dispositivo cerró entre el SELECT y el
      // UPDATE): el próximo intento verá status closed y resolverá Applied.
      return const SyncUnavailable('cierre afectó 0 filas; reintentar');
    }
    return SyncApplied(orderTimestamps: _parseTimestamps(updated));
  }

  Future<SyncApplyResult> _applyUpdateOrderStatus(
    Map<String, dynamic> p,
  ) async {
    final orderId = p['order_id'] as String?;
    final status = p['status'] as String?;
    if (orderId == null || status == null) {
      return const SyncRejected(
        'update_order_status requiere order_id y status',
      );
    }

    final updated = await _data.updateByIdReturningTimestamps(
      'customer_order',
      orderId,
      {'status': status},
    );

    if (updated.isEmpty) {
      return SyncRejected('customer_order $orderId no existe en remoto');
    }
    return SyncApplied(orderTimestamps: _parseTimestamps(updated));
  }

  // ─── Constructores de filas (públicos para tests unitarios) ────────────────

  /// Fila de `customer_order` para el INSERT de `create_order`.
  ///
  /// Nunca incluye `total_cents` ni `updated_at` (server-managed).
  static Map<String, dynamic> orderInsertRow(Map<String, dynamic> p) => {
    'id': p['order_id'],
    'venue_id': p['venue_id'],
    'dining_table_id': p['dining_table_id'],
    if (p['status'] != null) 'status': p['status'],
    if (p['opened_by'] != null) 'opened_by': p['opened_by'],
    if (p['opened_at'] != null) 'opened_at': utcIso(p['opened_at'] as String),
  };

  /// Filas de `order_item` para el INSERT masivo de `create_order`.
  ///
  /// ACID-2: los snapshots capturados offline viajan tal cual; el trigger
  /// remoto los respeta desde la migración 0003.
  static List<Map<String, dynamic>> itemInsertRows(Map<String, dynamic> p) {
    final rawItems = p['items'] as List<dynamic>? ?? const [];
    return rawItems.map((raw) {
      final m = raw as Map<String, dynamic>;
      return <String, dynamic>{
        if (m['order_item_id'] != null) 'id': m['order_item_id'],
        'venue_id': p['venue_id'],
        'order_id': p['order_id'],
        'menu_item_id': m['menu_item_id'],
        'name_snapshot': m['name_snapshot'],
        'price_cents_snapshot': m['price_cents_snapshot'],
        if (m['quantity'] != null) 'quantity': m['quantity'],
        if (m['comments'] != null) 'comments': m['comments'],
        if (m['status'] != null) 'status': m['status'],
      };
    }).toList();
  }

  /// Fila de `order_item` para el INSERT de `add_order_item` (append mode).
  static Map<String, dynamic> singleItemInsertRow(Map<String, dynamic> p) => {
    if (p['order_item_id'] != null) 'id': p['order_item_id'],
    'venue_id': p['venue_id'],
    'order_id': p['order_id'],
    'menu_item_id': p['menu_item_id'],
    'name_snapshot': p['name_snapshot'],
    'price_cents_snapshot': p['price_cents_snapshot'],
    if (p['quantity'] != null) 'quantity': p['quantity'],
    if (p['comments'] != null) 'comments': p['comments'],
    if (p['status'] != null) 'status': p['status'],
  };

  /// Normaliza un timestamp ISO local a UTC (los payloads offline guardan
  /// hora local del dispositivo; Postgres espera timestamptz inequívoco).
  static String utcIso(String iso) =>
      DateTime.parse(iso).toUtc().toIso8601String();

  /// Clasifica un error del SDK en recuperable o permanente.
  ///
  /// Sigue la tabla de errores de contracts.md. Ante un código desconocido se
  /// clasifica recuperable: nunca se descartan datos por un error no
  /// identificado (el backoff cap + banner degradado avisan al owner).
  static SyncApplyResult classifyError(Object e) {
    if (e is AuthException) {
      return SyncUnavailable('auth: ${e.message}');
    }
    if (e is PostgrestException) {
      final code = e.code ?? '';
      // Datos inválidos contra el estado remoto: NOT NULL (23502), FK (23503),
      // CHECK (23514), formato (22P02) o invariante de trigger (P0001, p.ej.
      // pedido cerrado — ACID-4). Reintentar jamás los arregla.
      const permanentCodes = {'23502', '23503', '23514', '22P02', 'P0001'};
      if (permanentCodes.contains(code)) {
        return SyncRejected('$code: ${e.message}');
      }
      if (code == '23505') {
        // Con ignoreDuplicates no debería ocurrir; si ocurre, la fila ya
        // existe → la op ya estaba aplicada. Se descarta con diagnóstico.
        return SyncRejected('23505: fila ya existente (op ya aplicada)');
      }
      if (code == '42501') {
        // contracts.md: RLS bloqueó → verificar sesión. La membresía puede
        // reactivarse; los datos no se descartan.
        return const SyncUnavailable(
          '42501: RLS bloqueó la escritura; verificar sesión o membresía',
        );
      }
      return SyncUnavailable('${e.code}: ${e.message}');
    }
    // Red caída, timeouts, errores de transporte del SDK.
    return SyncUnavailable(e.toString());
  }

  // ─── Helpers privados ───────────────────────────────────────────────────────

  Future<SyncApplyResult> _collectOrderTimestamps(String orderId) async {
    final orderRows = await _timestampsOf('customer_order', 'id', orderId);
    if (orderRows.isEmpty) {
      // Tras ensureReady la RLS no oculta filas del propio venue: si el
      // pedido no es visible tras el upsert, el payload apunta a otro venue.
      return SyncRejected(
        'customer_order $orderId no visible tras insert (¿venue ajeno?)',
      );
    }
    final itemTimestamps = await _timestampsOf(
      'order_item',
      'order_id',
      orderId,
    );
    return SyncApplied(
      orderTimestamps: orderRows,
      itemTimestamps: itemTimestamps,
    );
  }

  Future<Map<String, DateTime>> _timestampsOf(
    String table,
    String column,
    String value,
  ) async {
    final rows = await _data.selectTimestamps(table, column, value);
    return _parseTimestamps(rows);
  }

  static Map<String, DateTime> _parseTimestamps(
    List<Map<String, dynamic>> rows,
  ) {
    return {
      for (final row in rows)
        if (row['updated_at'] != null)
          row['id'] as String: DateTime.parse(row['updated_at'] as String),
    };
  }
}
