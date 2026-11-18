// Espaciado y radios de la suite OrtizApp (spec 01, paso 7).
//
// Escala única para separaciones (`SizedBox`, `EdgeInsets`, `gap`) y radios de
// esquina. Todo es `const`, así que sirve en widgets `const`:
//
//   const SizedBox(height: OrtizSpace.lg)
//   const EdgeInsets.all(OrtizSpace.lg)
//   BorderRadius.circular(OrtizRadius.block)
//
// `OrtizTheme` toma sus radios de aquí; las pantallas, también. Ningún valor
// suelto (14, 10, 6…) en código nuevo: si falta uno, se pide al design system.
import 'package:flutter/painting.dart';

/// Escala de espaciado en píxeles lógicos: 4 · 8 · 12 · 16 · 20 · 24 · 32.
abstract final class OrtizSpace {
  static const double xxs = 2; // separación mínima (ajustes finos, badges)
  static const double xs = 4; // icono ↔ texto, chips apretados
  static const double sm = 8; // entre elementos de una misma fila
  static const double md = 12; // entre filas de un grupo
  static const double lg = 16; // margen de pantalla, padding de bloque
  static const double xl = 20; // padding de hoja y diálogo
  static const double xxl = 24; // entre grupos (sustituye a las tarjetas)
  static const double xxxl = 32; // entre secciones grandes

  /// La escala completa, de menor a mayor.
  static const List<double> scale = [xxs, xs, sm, md, lg, xl, xxl, xxxl];
}

/// Tamaños de icono: 12 · 16 · 20 · 24 · 32 · 48.
abstract final class OrtizIconSize {
  static const double xs = 12; // dentro de chips y badges
  static const double sm = 16; // junto a texto pequeño
  static const double md = 20; // listas y filas (por defecto)
  static const double lg = 24; // acciones de barra
  static const double xl = 32; // estados vacíos pequeños, avatares
  static const double xxl = 48; // estados vacíos e ilustraciones

  /// La escala completa, de menor a mayor.
  static const List<double> scale = [xs, sm, md, lg, xl, xxl];
}

/// Grosores de línea: separadores y anillo de foco de teclado.
abstract final class OrtizStroke {
  static const double hairline = 1; // `Divider`, bordes de campo en reposo
  static const double focus = 2; // anillo de foco visible (web/escritorio)
}

/// Medidas fijas de componentes que no son espacio ni icono.
abstract final class OrtizSize {
  /// Punto de color de app, bolsillo o categoría (`OrtizListRow.dotColor`).
  static const double dot = 8;

  /// Objetivo táctil mínimo (= `kMinInteractiveDimension` de Material).
  static const double minTouch = 48;

  /// Ancho máximo de un texto centrado (estado vacío) en ventanas anchas.
  static const double readableWidth = 420;

  // --- Shell de la suite (spec 02, docs/design/ortiz-home.md) ---
  /// Riel de apps fijo a la izquierda (≥ 840) / en ventanas expandidas.
  static const double railWidth = 210;
  static const double railWidthExpanded = 240;

  /// Panel «Hoy» a la derecha del inicio (se muestra desde 1200 px).
  static const double todayPanelWidth = 320;
  static const double todayPanelWidthExpanded = 380;

  /// Columna de lectura del chat de Ortiz.
  static const double chatMaxWidth = 720;

  /// Paleta de comandos (`Ctrl/⌘+K`).
  static const double paletteMaxWidth = 560;

  /// Cara de Ortiz en el saludo del chat vacío.
  static const double faceHero = 96;
}

/// Radios de esquina por tipo de elemento.
abstract final class OrtizRadius {
  static const double chip = 8; // chips, tooltips, etiquetas
  static const double field = 12; // campos de texto y snackbars
  static const double menu = 12; // menús emergentes
  static const double block = 16; // bloque agrupado (y `Card` mientras exista)
  static const double dialog = 20; // diálogos
  static const double sheet = 22; // hojas inferiores y panel lateral
  static const double pill = 999; // botones y píldoras (extremos redondos)

  /// Forma de los botones y del FAB: píldora que se adapta a cualquier alto.
  static const OutlinedBorder pillShape = StadiumBorder();
}
