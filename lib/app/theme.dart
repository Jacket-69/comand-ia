import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema global de COMAND-IA.
///
/// Design tokens extraídos de los mockups Figma:
/// - Verde primario: #4CAF50 (mesas libres, acciones confirmar)
/// - Naranja: #FF9800 (mesas con orden, alertas)
/// - Rojo: #F44336 (pendientes, errores)
/// - Gris: #9E9E9E (mesas reservadas, deshabilitados)
/// - Azul: #4285F4 (categorías, links, entradas)
/// - Púrpura: #9C27B0 (bebidas, accent)
/// - Rosa: #E91E63 (postres)
class AppTheme {
  const AppTheme._();

  // ─── Colores base ───────────────────────────────────────────────
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primaryLight = Color(0xFFC8E6C9);

  static const Color secondary = Color(0xFF2196F3);

  static const Color accent = Color(0xFF9C27B0);

  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);

  static const Color surface = Color(0xFFF5F5F5);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBackground = Colors.white;

  // ─── Colores de estado de mesa ──────────────────────────────────
  static const Color tableAvailable = Color(0xFF4CAF50);
  static const Color tableWithOrder = Color(0xFFFF9800);
  static const Color tableReserved = Color(0xFF9E9E9E);

  // ─── Indicadores de punto (estado de pedido) ────────────────────
  static const Color dotWithOrder = Color(0xFF4CAF50);
  static const Color dotWaitingOrder = Color(0xFFF44336);
  static const Color dotReadyToServe = Color(0xFFFFB300);

  // ─── Colores de categoría del menú ──────────────────────────────
  static const Color categoryEntradas = Color(0xFF4285F4);
  static const Color categoryAlmuerzos = Color(0xFFFF9800);
  static const Color categoryParrilladas = Color(0xFFD32F2F);
  static const Color categoryBebidas = Color(0xFF9C27B0);
  static const Color categoryPostres = Color(0xFFE91E63);
  static const Color categoryCafe = Color(0xFFE65100);

  // ─── KDS columnas ───────────────────────────────────────────────
  static const Color kdsPending = Color(0xFFF44336);
  static const Color kdsPreparing = Color(0xFFFF9800);
  static const Color kdsReady = Color(0xFF4CAF50);

  // ─── Texto ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;

  // ─── Bordes ─────────────────────────────────────────────────────
  static const double borderRadius = 12;
  static const double borderRadiusLarge = 16;
  static const double borderRadiusSmall = 8;

  /// ThemeData completo para MaterialApp.
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: surface,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );
  }
}
