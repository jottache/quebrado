import 'package:flutter/material.dart';

import '../../theme/ortiz_tokens.dart';

/// Colores del Agente (spec 01, paso 6).
///
/// El Agente es Ortiz, cuya identidad es el acento de la suite: el primario
/// sale de `OrtizPalette.accent` y los neutrales de `OrtizPalette`. Solo
/// quedan hex propios en los estados «pensando» y «herramienta», que no tienen
/// token con el mismo significado (recalibrados para fondo oscuro).
class AgenteColors {
  // Primario: acento de la suite (Ortiz).
  static const Color primary = OrtizPalette.accent;
  // Fondo de elemento activo o destacado (avatares, chips, cabeceras): el
  // acento lavado, para que se lea como «de Ortiz» y no como gris neutro.
  static const Color primaryLight = OrtizPalette.accentTint;
  // Texto o icono sobre `primaryLight`: en oscuro es el propio acento.
  static const Color primaryDark = OrtizPalette.accent;

  // Neutral & Surfaces
  static const Color background = OrtizPalette.bg;
  static const Color surface = OrtizPalette.surface;
  static const Color cardBorder = OrtizPalette.line;

  // Message bubbles: usuario sobre `surfaceHigh`; bot sobre `surface`.
  static const Color userBubble = OrtizPalette.surfaceHigh;
  static const Color userText = OrtizPalette.fg;
  static const Color botBubble = OrtizPalette.surface;
  static const Color botText = OrtizPalette.fg;

  // Artifact Accents
  static const Color artifactBg = OrtizPalette.surface;
  static const Color artifactBorder = OrtizPalette.line;
  static const Color artifactHeader = OrtizPalette.fg;

  // Status Colors. `thinking` y `toolExec` son hex propios (no hay token con
  // ese significado); se usan como texto, así que su contraste sobre
  // `OrtizPalette.bg` es ≥ 4,5:1.
  static const Color thinking = Color(0xFFC3A6FF); // violeta, 9,3:1
  static const Color toolExec = Color(0xFF6EC8F0); // celeste, 10,2:1
  static const Color success = OrtizPalette.ok;
  static const Color error = OrtizPalette.bad;
}
