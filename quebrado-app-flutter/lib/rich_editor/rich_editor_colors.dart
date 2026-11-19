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

  // Código en línea (`code`): antes gris claro con texto rosa (P-28); en
  // oscuro, el fondo del elemento activo y el texto principal.
  static const Color inlineCodeBg = OrtizPalette.surfaceHigh;
  static const Color inlineCodeFg = OrtizPalette.fg;

  // Paleta de color de texto y de fondo del selector de la barra de formato.
  // Se guardan como dato (hex en el documento): cambiarlos alteraría el
  // aspecto de documentos ya guardados, por eso conservan sus valores.
  static const List<(String, Color)> textPalette = [
    ('Gris', Color(0xFF787774)),
    ('Marrón', Color(0xFF9F6B53)),
    ('Naranja', Color(0xFFD9730D)),
    ('Amarillo', Color(0xFFCB912F)),
    ('Verde', Color(0xFF448361)),
    ('Azul', Color(0xFF337EA9)),
    ('Morado', Color(0xFF9065B0)),
    ('Rosado', Color(0xFFC14C8A)),
    ('Rojo', Color(0xFFD44C47)),
  ];
  static const List<(String, Color)> backgroundPalette = [
    ('Gris', Color(0xFFF1F1EF)),
    ('Marrón', Color(0xFFF4EEEE)),
    ('Naranja', Color(0xFFFBECDD)),
    ('Amarillo', Color(0xFFFBF3DB)),
    ('Verde', Color(0xFFEDF3EC)),
    ('Azul', Color(0xFFE7F3F8)),
    ('Morado', Color(0xFFF6F3F9)),
    ('Rosado', Color(0xFFFAF1F5)),
    ('Rojo', Color(0xFFFDEBEC)),
  ];

  /// Borde de las muestras de color del selector.
  static const Color swatchBorder = OrtizPalette.line;
}
