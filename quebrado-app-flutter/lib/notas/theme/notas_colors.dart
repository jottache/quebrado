import 'package:flutter/material.dart';

import '../../theme/ortiz_tokens.dart';
import '../../theme/suite_apps.dart';

/// Colores de Notas (spec 01, paso 6).
///
/// El primario y sus variantes salen de `SuiteAppColors.notas`; los neutrales,
/// de `OrtizPalette`. Solo quedan hex propios en los acentos de categoría, que
/// no tienen token con el mismo significado (recalibrados para fondo oscuro).
class NotasColors {
  // Máscaras para derivar fondos y bordes lavados como constantes de
  // compilación (mismo método que `SuiteAppColors`).
  static const int _rgb = 0x00FFFFFF;
  static const int _tint = SuiteAppColors.tintAlpha << 24;
  static const int _border = SuiteAppColors.borderAlpha << 24;

  // Primario: color de la app Notas.
  static const Color primary = SuiteAppColors.notas;
  static const Color primaryLight = SuiteAppColors.notasTint;
  // En oscuro la variante «fuerte» (texto o icono sobre `primaryLight`) es el
  // propio color de la app.
  static const Color primaryDark = SuiteAppColors.notas;

  // Acentos temáticos por categoría. Hex propios: no hay token con este
  // significado. Contraste sobre `OrtizPalette.bg` ≥ 4,5:1 (aptos para texto).
  static const int _acuerdosPinkArgb = 0xFFF48FB8; // 8,6:1
  static const Color acuerdosPink = Color(_acuerdosPinkArgb);
  static const Color acuerdosPinkLight =
      Color((_acuerdosPinkArgb & _rgb) | _tint);

  static const int _ideasAmberArgb = 0xFFF5C26B; // 11,7:1
  static const Color ideasAmber = Color(_ideasAmberArgb);
  static const Color ideasAmberLight = Color((_ideasAmberArgb & _rgb) | _tint);

  static const int _datosGreenArgb = 0xFF72D4A8; // 10,7:1
  static const Color datosGreen = Color(_datosGreenArgb);
  static const Color datosGreenLight = Color((_datosGreenArgb & _rgb) | _tint);

  // Superficies y bordes
  static const Color background = OrtizPalette.bg;
  static const Color cardSurface = OrtizPalette.surface;
  static const Color cardBorder = OrtizPalette.line;
  static const Color surfaceHover = OrtizPalette.surfaceHigh;

  // Textos. `textMuted` se usa en texto legible (metadatos, tareas hechas):
  // por eso es `muted` y no `faint`.
  static const Color textPrimary = OrtizPalette.fg;
  static const Color textSecondary = OrtizPalette.muted;
  static const Color textMuted = OrtizPalette.muted;

  // Callouts: fondo lavado (alpha bajo) y borde con alpha medio.
  // Info conserva el verde de «datos»; aviso usa el token `warn`; rosa, el de
  // «acuerdos».
  static const Color calloutInfoBg = datosGreenLight;
  static const Color calloutInfoBorder =
      Color((_datosGreenArgb & _rgb) | _border);

  static const Color calloutWarnBg = OrtizPalette.warnTint;
  static const Color calloutWarnBorder = OrtizPalette.warnBorder;

  static const Color calloutPinkBg = acuerdosPinkLight;
  static const Color calloutPinkBorder =
      Color((_acuerdosPinkArgb & _rgb) | _border);
}
