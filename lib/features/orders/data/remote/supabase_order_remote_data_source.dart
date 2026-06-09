import 'package:comand_ia/features/orders/domain/sync/order_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementación Supabase del [OrderRemoteDataSource] (COMA-008).
///
/// Traducción fina a PostgREST/Auth, sin lógica de decisión: escribe directo
/// sobre `customer_order` / `order_item` con la RLS del usuario autenticado
/// (contracts.md: BaaS-only, sin RPC de sync). Toda la idempotencia, la
/// clasificación de errores y la adopción de timestamps viven en
/// [SupabaseOrderRemoteGateway], que consume este puerto.
class SupabaseOrderRemoteDataSource implements OrderRemoteDataSource {
  const SupabaseOrderRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  bool get hasActiveSession => _client.auth.currentSession != null;

  @override
  Stream<bool> get sessionActiveChanges => _client.auth.onAuthStateChange.map(
    (_) => _client.auth.currentSession != null,
  );

  @override
  Future<bool> isAppUserVisible(String uid) async {
    final row =
        await _client
            .from('app_user')
            .select('venue_id')
            .eq('id', uid)
            .maybeSingle();
    return row != null;
  }

  @override
  Future<void> upsertIgnoreDuplicates(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    await _client.from(table).upsert(rows, ignoreDuplicates: true);
  }

  @override
  Future<List<Map<String, dynamic>>> updateByIdReturningTimestamps(
    String table,
    String id,
    Map<String, dynamic> values,
  ) async {
    return _client
        .from(table)
        .update(values)
        .eq('id', id)
        .select('id, updated_at');
  }

  @override
  Future<Map<String, dynamic>?> selectMaybeSingle(
    String table,
    String columns,
    String filterColumn,
    String filterValue,
  ) async {
    return _client
        .from(table)
        .select(columns)
        .eq(filterColumn, filterValue)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> selectTimestamps(
    String table,
    String filterColumn,
    String filterValue,
  ) async {
    return _client
        .from(table)
        .select('id, updated_at')
        .eq(filterColumn, filterValue);
  }
}
