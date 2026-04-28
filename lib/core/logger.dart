import 'dart:developer' as developer;

/// Logger centralizado del proyecto.
///
/// Reemplaza `print` en toda la app. En producción,
/// los logs se envían a Sentry vía breadcrumbs.
class AppLogger {
  const AppLogger._();

  /// Log de información general.
  static void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'COMAND-IA');
  }

  /// Log de advertencia.
  static void warning(String message, {String? tag}) {
    developer.log('⚠️ $message', name: tag ?? 'COMAND-IA');
  }

  /// Log de error con stack trace opcional.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    developer.log(
      '❌ $message',
      name: tag ?? 'COMAND-IA',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
