import 'package:comand_ia/features/orders/domain/sync/sync_backoff_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncBackoffPolicy.delayFor', () {
    const policy = SyncBackoffPolicy();

    test('sin intentos no hay espera', () {
      expect(policy.delayFor(0), Duration.zero);
      expect(policy.delayFor(-1), Duration.zero);
    });

    test('crece exponencial 2^attempts segundos', () {
      expect(policy.delayFor(1), const Duration(seconds: 2));
      expect(policy.delayFor(2), const Duration(seconds: 4));
      expect(policy.delayFor(3), const Duration(seconds: 8));
      expect(policy.delayFor(8), const Duration(seconds: 256));
    });

    test('aplica el cap de 5 minutos (offline-first.md)', () {
      expect(policy.delayFor(9), const Duration(minutes: 5));
      expect(policy.delayFor(10), const Duration(minutes: 5));
      expect(policy.delayFor(100), const Duration(minutes: 5));
    });

    test('respeta un cap configurado distinto', () {
      const custom = SyncBackoffPolicy(cap: Duration(seconds: 10));
      expect(custom.delayFor(2), const Duration(seconds: 4));
      expect(custom.delayFor(4), const Duration(seconds: 10));
      expect(custom.delayFor(50), const Duration(seconds: 10));
    });
  });
}
