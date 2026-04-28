/// Variables de entorno para COMAND-IA.
///
/// En producción se leen desde `.env` via `--dart-define` o `envied`.
/// Durante Sprint 1 usamos valores hardcodeados de desarrollo.
class Env {
  const Env._();

  /// URL del proyecto Supabase.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321',
  );

  /// Anon key del proyecto Supabase.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// DSN de Sentry para captura de excepciones.
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
}
