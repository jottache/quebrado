// Colores de la suite y de Quebrado (spec 01, paso 4).
//
// `AppColors` ya no define hex propios: lee los tokens de `OrtizPalette`
// (`ortiz_tokens.dart`). Se conservan todos los nombres públicos para no romper
// a sus ≈ 400 usuarios. `creationColors` (los colores que la persona elige al
// crear) también salen de los tokens; los ya guardados como hex no cambian.
import 'package:flutter/material.dart';

import 'ortiz_tokens.dart';
import 'suite_apps.dart';

abstract final class AppColors {
  // --- COLORES PRINCIPALES ---
  // PA-01: el color del libro ya no cambia el color principal de la app.
  // El acento de la suite es siempre el coral de `OrtizPalette.accent`.
  static const Color primary = OrtizPalette.accent;

  /// Segundo acento (pestañas anidadas, botones secundarios, distintivo VES).
  /// Antes era el principal aclarado; la paleta oscura tiene un único acento.
  static const Color secondary = OrtizPalette.accent;

  /// Acento de gráficos: serie de ingresos puntuales del flujo de caja, junto
  /// a `primary` (ingresos recurrentes). Se usa el token de ingreso para que
  /// la serie se distinga del coral y conserve su sentido.
  static const Color accent = OrtizPalette.income;

  static const Color background = OrtizPalette.bg;

  /// Color del libro activo. Solo lo usan el selector de libro y su indicador
  /// (PA-01). Hasta que se carga un libro vale el acento de la suite.
  static Color bookColor = OrtizPalette.accent;

  /// Guarda el color del libro activo. Mantiene la firma histórica (la llama
  /// `AppState` al cambiar de libro) pero ya no altera `primary`.
  static void updateThemeColor(Color newBookColor) {
    bookColor = newBookColor;
  }

  // --- TARJETAS ---
  static const Color cardBackground = OrtizPalette.surface;
  static const Color cardText = OrtizPalette.fg;
  static const Color cardSubtitleText = OrtizPalette.muted;
  static const Color cardBorderColor = OrtizPalette.line;
  static const double cardBorderWidth = 1.0;

  /// Color de la tarjeta en la posición [index]. Hoy todas usan el mismo fondo.
  static Color getAlternateCardColor(int index) => cardBackground;

  // --- PESTAÑAS ---
  // Pestañas principales (fuera de tarjetas).
  static const Color mainTabActiveBg = OrtizPalette.accent;
  static const Color mainTabActiveText = OrtizPalette.onAccent;
  static const Color mainTabInactiveText = OrtizPalette.muted;
  static const Color mainTabTrackBg = OrtizPalette.surfaceHigh;

  // Pestañas anidadas (dentro de tarjetas).
  static const Color nestedTabTrackBg = OrtizPalette.surfaceHigh;
  static const Color nestedTabActiveBg = secondary;
  static const Color nestedTabActiveText = OrtizPalette.onAccent;
  static const Color nestedTabInactiveText = OrtizPalette.muted;

  // --- DERIVADOS ---
  static const Color cardBorder = cardBorderColor;
  static const Color dialogBg = OrtizPalette.surface;

  // --- SEMÁNTICOS ---
  static const Color income = OrtizPalette.income;
  static const Color expense = OrtizPalette.expense;

  // --- MONEDAS (spec 05, P-39) ---
  // Color fijo por moneda en la proyección y las píldoras de moneda, para
  // reconocerlas de un vistazo. Calibrados para el tema oscuro: todos dan
  // ≥ 4,5:1 sobre `bg` (y sobre su propio tinte), y se distinguen entre sí.
  static const Color currencyUsd = Color(0xFF6FCF8E); // verde
  static const Color currencyBs = Color(0xFFE9A24F); // ámbar
  static const Color currencyEur = Color(0xFF7FAEF5); // azul

  // --- MARCAS ---
  /// Amarillo de marca de Cashea (cuotas simuladas). Es un relleno claro:
  /// el texto encima va en `OrtizPalette.onAccent`.
  static const Color casheaBrand = Color(0xFFFFE607);

  // Paleta que la persona elige al crear libros, cuentas, categorías,
  // bolsillos y pagos recurrentes (decisión de la persona, 2026-11-17).
  // Solo afecta a lo que se cree desde ahora: lo ya guardado conserva su hex
  // (los selectores muestran su color aunque no esté en esta lista).
  // Orden con significado: [0] es el color por defecto de libros y categorías
  // y [1] el de cuentas, bolsillos y pagos recurrentes.
  static final List<String> creationColors = [
    for (final c in const [
      OrtizPalette.accent, // coral
      SuiteAppColors.finanzas, // dorado
      SuiteAppColors.habitos, // cielo
      SuiteAppColors.recordatorios, // lavanda
      SuiteAppColors.diario, // rosa
      OrtizPalette.ok, // menta
      OrtizPalette.warn, // ámbar
      SuiteAppColors.notas, // crema
    ])
      _hex(c),
  ];

  /// `#RRGGBB` en mayúsculas, el formato con que se guardan los colores.
  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
