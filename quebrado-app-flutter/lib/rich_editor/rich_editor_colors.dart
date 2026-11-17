import 'package:flutter/material.dart';

import '../theme/ortiz_tokens.dart';
import '../theme/suite_apps.dart';

/// Colores del editor enriquecido (spec 01, paso 6). [accent] lo fija cada app
/// al abrir el editor (Notas, Diario…); por defecto es el acento de la suite.
/// Es estático porque las barras flotantes se dibujan en el Overlay raíz,
/// fuera del árbol del editor. Los neutrales salen de `OrtizPalette`.
class RichEditorColors {
  RichEditorColors._();

  static Color accent = OrtizPalette.accent;

  /// Fondo suave del botón activo: [accent] con el alpha de tinte de la suite.
  static Color get accentLight => accent.withAlpha(SuiteAppColors.tintAlpha);

  static const Color textPrimary = OrtizPalette.fg;
  static const Color textSecondary = OrtizPalette.muted;
  // Se usa en texto legible (etiquetas, marcadores de posición): `muted`.
  static const Color textMuted = OrtizPalette.muted;
  static const Color border = OrtizPalette.line;

  // Destacado (callout) del editor con el token `warn`: fondo lavado y borde
  // con alpha medio.
  static const Color calloutBg = OrtizPalette.warnTint;
  static const Color calloutBorder = OrtizPalette.warnBorder;

  // Iconos de la barra de formato (antes casi negro): en oscuro, `fg`.
  static const Color icon = OrtizPalette.fg;
}
