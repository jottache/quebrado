import 'package:flutter/material.dart';

import '../../theme/ortiz_tokens.dart';
import '../../theme/suite_apps.dart';

/// Colores de Recordatorios sobre el tema oscuro de la suite (spec 01, paso 5).
///
/// El primario sale de `SuiteAppColors.recordatorios` (CA-03) y los neutrales
/// y estados de `OrtizPalette`; las prioridades también, sin hex propios.
/// Todo es `const` para los widgets `const`.
class RemindersColors {
  // Primario de la app.
  static const Color primary = SuiteAppColors.recordatorios;

  /// Fondo suave de chips y selección.
  static const Color primaryLight = SuiteAppColors.recordatoriosTint;

  /// Antes era un tono más oscuro para leer sobre fondo claro. Sobre el fondo
  /// oscuro lo legible es el propio color de la app.
  static const Color primaryDark = SuiteAppColors.recordatorios;
  static const Color primaryBorder = SuiteAppColors.recordatoriosBorder;

  // Fondos y superficies.
  static const Color background = OrtizPalette.bg;
  static const Color cardSurface = OrtizPalette.surface;
  static const Color cardBorder = OrtizPalette.line;

  // Texto.
  static const Color textPrimary = OrtizPalette.fg;
  static const Color textSecondary = OrtizPalette.muted;

  /// Se usa en textos que hay que leer (fechas, metadatos), por eso es `muted`
  /// y no `faint` (que solo es decorativo, CA-04).
  static const Color textMuted = OrtizPalette.muted;

  // Prioridades.
  /// P1 urgente: rojo de error de la suite.
  static const Color urgent = OrtizPalette.bad;

  /// P2 alta: el ámbar de aviso de la suite (≈ 10,3:1 sobre `bg`).
  static const Color high = OrtizPalette.warn;

  /// P3 media: el color de la app (≈ 8,1:1 sobre `bg`).
  static const Color medium = SuiteAppColors.recordatorios;

  /// P4 baja: gris neutro, el mismo `muted` del texto secundario.
  static const Color low = OrtizPalette.muted;

  // Estados.
  static const Color overdue = OrtizPalette.bad; // Vencido
  static const Color snoozed = OrtizPalette.warn; // Pospuesto
  static const Color completed = OrtizPalette.ok; // Completado

  // Cuadrantes de Covey (spec 05). Se usan como texto e indicador: los cuatro
  // superan 4,5:1 sobre `bg`. El fondo suave y el borde de cada cuadrante se
  // derivan de estos con `SuiteAppColors.tintAlpha`/`borderAlpha`.
  /// C1 Urgente e importante (crisis): rojo de la suite.
  static const Color quadrantUrgentImportant = OrtizPalette.bad;

  /// C2 Importante, no urgente (el foco): verde de la suite.
  static const Color quadrantImportantNotUrgent = OrtizPalette.ok;

  /// C3 Urgente, no importante (interrupciones): ámbar de la suite.
  static const Color quadrantUrgentNotImportant = OrtizPalette.warn;

  /// C4 Ni urgente ni importante (desperdicio): gris `muted`.
  static const Color quadrantNotUrgentNotImportant = OrtizPalette.muted;

  // Roles vitales.
  /// Color de un rol cuyo `color_hex` no se puede leer. Es el mismo azul del
  /// `colorHex` por defecto de `RoleModel` ('#3B82F6', dato guardado), que
  /// sobre `bg` da ≈ 5,2:1.
  static const Color roleDefault = Color(0xFF3B82F6);
}
