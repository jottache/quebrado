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
  static const double xs = 4; // icono ↔ texto, chips apretados
  static const double sm = 8; // entre elementos de una misma fila
  static const double md = 12; // entre filas de un grupo
  static const double lg = 16; // margen de pantalla, padding de bloque
  static const double xl = 20; // padding de hoja y diálogo
  static const double xxl = 24; // entre grupos (sustituye a las tarjetas)
  static const double xxxl = 32; // entre secciones grandes

  /// La escala completa, de menor a mayor.
  static const List<double> scale = [xs, sm, md, lg, xl, xxl, xxxl];
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
