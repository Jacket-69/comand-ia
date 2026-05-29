import 'package:comand_ia/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatClp', () {
    test('cero centavos → \$0', () {
      expect(formatClp(0), '\$0');
    });

    test('150000 centavos (\$1.500 CLP) formatea correctamente', () {
      expect(formatClp(150000), '\$1.500');
    });

    test('1500000 centavos (\$15.000 CLP) formatea correctamente', () {
      expect(formatClp(1500000), '\$15.000');
    });

    test('100 centavos (\$1 CLP) formatea correctamente', () {
      expect(formatClp(100), '\$1');
    });

    test('5500000 centavos (\$55.000 CLP) formatea correctamente', () {
      expect(formatClp(5500000), '\$55.000');
    });

    test('1000000 centavos (\$10.000 CLP) formatea correctamente', () {
      expect(formatClp(1000000), '\$10.000');
    });

    test('retorna String (nunca double)', () {
      final result = formatClp(1500000);
      expect(result, isA<String>());
    });
  });
}
