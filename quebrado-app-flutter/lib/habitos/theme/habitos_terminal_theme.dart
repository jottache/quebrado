import 'package:flutter/material.dart';

import '../../theme/ortiz_tokens.dart';
import '../../theme/suite_apps.dart';

/// Colores de Hábitos sobre el tema oscuro de la suite (spec 01, paso 5).
///
/// El primario sale de `SuiteAppColors.habitos` (CA-03) y los neutrales de
/// `OrtizPalette`; no hay hex propios salvo los fondos lavados de los estados,
/// documentados abajo. Todo es `const` para los widgets `const`.
class HabitosColors {
  // Primario de la app.
  static const Color primary = SuiteAppColors.habitos;

  /// Antes era un tono más oscuro para leer sobre fondo claro. Sobre el fondo
  /// oscuro lo legible es el propio color de la app.
  static const Color primaryDark = SuiteAppColors.habitos;

  /// Fondo suave de chips y selección.
  static const Color primaryLight = SuiteAppColors.habitosTint;
  static const Color primaryBorder = SuiteAppColors.habitosBorder;

  // Fondos y superficies.
  static const Color background = OrtizPalette.bg;
  static const Color surface = OrtizPalette.surface;
  static const Color surfaceHover = OrtizPalette.surfaceHigh;
  static const Color cardBorder = OrtizPalette.line;

  // Texto.
  static const Color textPrimary = OrtizPalette.fg;
  static const Color textSecondary = OrtizPalette.muted;

  /// Se usa en textos que hay que leer (pistas de campos), por eso es `muted`
  /// y no `faint` (que solo es decorativo, CA-04).
  static const Color textMuted = OrtizPalette.muted;

  // Estados.
  /// Rachas: ámbar de aviso de la suite.
  static const Color amber = OrtizPalette.warn;

  /// Fondo lavado del ámbar de rachas.
  static const Color amberLight = OrtizPalette.warnTint;

  /// Recaídas y borrar: rojo de error de la suite.
  static const Color rose = OrtizPalette.bad;

  /// Fondo lavado del rojo de recaídas.
  static const Color roseLight = OrtizPalette.badTint;

  // Aliases ergonómicos / retrocompatibles
  static const Color green = primary;
  static const Color red = rose;
  static const Color cyan = primary;
  static const Color dimGreen = primaryLight;
  static const Color borderMuted = cardBorder;
  static const Color borderSubtle = cardBorder;
  static const Color borderActive = primary;
  static const Color windowBackground = surface;
  static const Color cardBackground = surface;
  static const Color textLight = textPrimary;
  static const Color textGreen = primary;
  static const Color textAmber = amber;
}

class HabitosStyles {
  /// Tipografía limpia y moderna estándar
  static TextStyle title({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w800,
    Color color = HabitosColors.textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
      height: 1.2,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle badge({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
    Color color = HabitosColors.primary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  // Compatibilidad
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle prompt({double fontSize = 13}) => badge(fontSize: fontSize);
  static TextStyle heading({double fontSize = 16}) => title(fontSize: fontSize);
  static TextStyle dim({double fontSize = 11}) => caption(fontSize: fontSize);
}
