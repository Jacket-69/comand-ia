import 'package:intl/intl.dart';

/// Formateador de montos monetarios para la UI de COMAND-IA.
///
/// Los montos se almacenan siempre en centavos (int, CLP × 100).
/// La conversión a pesos CLP (÷ 100) y el formato con símbolo "$"
/// ocurren SOLO en el borde de UI. Nunca se usa double para precios.

/// Formatea un monto en centavos como pesos chilenos (CLP).
///
/// Ejemplo: [cents] = 1_500_000 → `"\$15.000"`.
/// El CLP no tiene decimales; el formateador usa 0 fracciones.
///
/// El símbolo `\$` se coloca como prefijo (convención visual chilena).
/// El separador de miles es el punto (`.`), igual que en Chile.
///
/// Parámetro:
/// - [cents]: precio en centavos (CLP × 100). Nunca un double.
String formatClp(int cents) {
  // En CLP la unidad mínima es el peso entero; los "centavos" de nuestro
  // modelo son una convención interna (×100) para evitar floats.
  final pesos = cents ~/ 100;
  // NumberFormat.decimalPattern('es_CL') usa punto como separador de miles,
  // que es el formato correcto para CLP (ej. 15.000, 1.500.000).
  // Prefijamos el símbolo '$' manualmente para calzar con los mockups Figma.
  final fmt = NumberFormat.decimalPattern('es_CL');
  return '\$${fmt.format(pesos)}';
}
