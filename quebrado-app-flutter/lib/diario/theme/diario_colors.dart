import 'package:flutter/material.dart';

import '../../theme/ortiz_tokens.dart';
import '../../theme/suite_apps.dart';

/// Paleta del Diario sobre el tema oscuro de la suite (spec 01, paso 5).
///
/// No define hex propios para el primario: lo lee de `SuiteAppColors.diario`
/// (CA-03), así que cambiar `SuiteAppColors.diarioArgb` recolorea el primario,
/// su tinte y su borde sin tocar este archivo (CA-02). Los neutrales leen de
/// `OrtizPalette`. Todo es `const` para poder usarse en widgets `const`.
class DiarioColors {
  // Primario de la app.
  static const Color primary = SuiteAppColors.diario;

  /// Antes era un verde más oscuro para texto e iconos sobre fondo claro.
  /// Sobre el fondo oscuro lo legible es el propio color de la app.
  static const Color primaryDark = SuiteAppColors.diario;

  /// Fondo suave de chips, selección y avatares.
  static const Color primaryLight = SuiteAppColors.diarioTint;

  /// Borde o separador con el color de la app.
  static const Color primaryBorder = SuiteAppColors.diarioBorder;
  static Color get primaryGlow => primary.withValues(alpha: 0.18);

  // Secundario y acentos: todos apuntan al primario (minimalismo de un color).
  static const Color accent = primary;
  static const Color secondary = primary;
  static const Color secondaryLight = SuiteAppColors.diarioTint;

  // Fondos y superficies.
  static const Color background = OrtizPalette.bg;
  static const Color surface = OrtizPalette.surface;
  static const Color surfaceHover = OrtizPalette.surfaceHigh;
  static const Color cardBorder = OrtizPalette.line;

  // Alias semánticos que a propósito apuntan al primario.
  static const Color amber = primary;

  /// Era un gris neutro (no un ámbar): se mantiene neutro.
  static const Color amberLight = OrtizPalette.surfaceHigh;

  static const Color emerald = primary;
  static const Color emeraldLight = SuiteAppColors.diarioTint;

  // Solo rojo para acciones destructivas (p. ej. borrar).
  static const Color rose = OrtizPalette.bad;

  /// Fondo lavado del rojo de borrar.
  static const Color roseLight = OrtizPalette.badTint;

  static const Color purple = primary;
  static const Color purpleLight = SuiteAppColors.diarioTint;

  static const Color blue = primary;
  static const Color blueLight = SuiteAppColors.diarioTint;

  static const Color cyan = primary;
  static const Color cyanLight = SuiteAppColors.diarioTint;

  // Texto.
  static const Color textPrimary = OrtizPalette.fg;
  static const Color textSecondary = OrtizPalette.muted;

  /// Se usa en textos que hay que leer (fechas, etiquetas, «Sin registros»),
  /// por eso es `muted` y no `faint` (que solo es decorativo, CA-04).
  static const Color textMuted = OrtizPalette.muted;

  // Avatares.
  static const Color avatarBackground = SuiteAppColors.diarioTint;
  static const Color avatarText = primary;

  static Color getAvatarColor(String seed) {
    return primary;
  }
}
