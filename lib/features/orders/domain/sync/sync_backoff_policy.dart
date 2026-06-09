/// Política de backoff exponencial del sync offline (ADR-0008).
///
/// `2^attempts` segundos con tope en [cap] (5 minutos por defecto), según
/// [offline-first.md](../../../../../docs/sync/offline-first.md).
class SyncBackoffPolicy {
  const SyncBackoffPolicy({this.cap = const Duration(minutes: 5)});

  /// Tope superior del backoff.
  final Duration cap;

  /// Espera antes del próximo intento para una op con [attempts] fallos.
  Duration delayFor(int attempts) {
    if (attempts <= 0) return Duration.zero;
    // Sobre 2^30 s el shift dejaría de caber con holgura; el cap manda mucho antes.
    if (attempts >= 30) return cap;
    final delay = Duration(seconds: 1 << attempts);
    return delay > cap ? cap : delay;
  }
}
