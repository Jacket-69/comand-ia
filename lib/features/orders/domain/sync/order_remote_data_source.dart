/// Puerto de I/O cruda contra el backend para el drenaje de sync (COMA-008).
///
/// Separa las llamadas PostgREST/Auth de la LÓGICA de drenaje
/// ([SupabaseOrderRemoteGateway]): idempotencia, clasificación de errores,
/// snapshots y adopción de timestamps. Así esa lógica se testea con un fake,
/// sin un `SupabaseClient` real ni mockear la cadena fluent de PostgREST.
///
/// Cada método propaga las excepciones del SDK (`AuthException`,
/// `PostgrestException`, errores de transporte) SIN traducir: clasificarlas en
/// recuperable/permanente es responsabilidad del gateway (ADR-0013).
abstract class OrderRemoteDataSource {
  /// uid del usuario autenticado, o null si no hay sesión.
  String? get currentUserId;

  /// True si hay una sesión Supabase activa.
  bool get hasActiveSession;

  /// Emite el estado de sesión al cambiar (login/logout/refresh): `true`
  /// cuando vuelve a haber sesión utilizable. Re-dispara el drenaje.
  Stream<bool> get sessionActiveChanges;

  /// True si la fila `app_user` del [uid] es visible bajo RLS deny-by-default
  /// (membresía activa del venue). Lanza si la consulta falla.
  Future<bool> isAppUserVisible(String uid);

  /// INSERT con upsert ignorante de duplicados (`ON CONFLICT DO NOTHING`).
  ///
  /// Idempotencia: los UUID se generan en cliente, así que un reintento tras
  /// éxito parcial es un no-op (ADR-0013).
  Future<void> upsertIgnoreDuplicates(
    String table,
    List<Map<String, dynamic>> rows,
  );

  /// `UPDATE <table> SET <values> WHERE id = <id>` retornando `id, updated_at`
  /// de las filas afectadas (lista vacía si no afectó ninguna).
  Future<List<Map<String, dynamic>>> updateByIdReturningTimestamps(
    String table,
    String id,
    Map<String, dynamic> values,
  );

  /// `SELECT <columns> FROM <table> WHERE <filterColumn> = <filterValue>`
  /// como fila única, o null si no existe.
  Future<Map<String, dynamic>?> selectMaybeSingle(
    String table,
    String columns,
    String filterColumn,
    String filterValue,
  );

  /// `SELECT id, updated_at FROM <table> WHERE <filterColumn> = <filterValue>`.
  Future<List<Map<String, dynamic>>> selectTimestamps(
    String table,
    String filterColumn,
    String filterValue,
  );
}
