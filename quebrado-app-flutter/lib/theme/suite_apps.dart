// Catálogo de mini-apps de la suite y su color (spec 01).
//
// Cada app tiene UNA sola variable de color: su entero ARGB `xxxArgb`. Los
// tonos derivados (`tint`, `border`) se calculan con operaciones de bits sobre
// ese entero, que sí son constantes de compilación. Así las clases de color de
// los módulos (`DiarioColors`, …) pueden seguir usándose en widgets `const`.
// Para recolorear una app basta con cambiar su `xxxArgb`.
import 'package:flutter/material.dart';

/// Colores por app como constantes de compilación.
///
/// Usa estas constantes (no `SuiteApp.x.color`) donde haga falta `const`:
/// leer un campo de un valor de enum no es una expresión constante en Dart.
abstract final class SuiteAppColors {
  // Máscaras de derivación: conservan el RGB y fijan el alpha.
  static const int _rgb = 0x00FFFFFF;
  static const int tintAlpha = 0x29; // ≈ 16 %: fondo suave
  static const int borderAlpha = 0x73; // ≈ 45 %: borde o separador con color
  static const int _tint = tintAlpha << 24;
  static const int _border = borderAlpha << 24;

  // Finanzas (Quebrado).
  static const int finanzasArgb = 0xFFE7C06A;
  static const Color finanzas = Color(finanzasArgb);
  static const Color finanzasTint = Color((finanzasArgb & _rgb) | _tint);
  static const Color finanzasBorder = Color((finanzasArgb & _rgb) | _border);

  // Diario.
  static const int diarioArgb = 0xFFEE8FA6;
  static const Color diario = Color(diarioArgb);
  static const Color diarioTint = Color((diarioArgb & _rgb) | _tint);
  static const Color diarioBorder = Color((diarioArgb & _rgb) | _border);

  // Hábitos.
  static const int habitosArgb = 0xFF6FC3DF;
  static const Color habitos = Color(habitosArgb);
  static const Color habitosTint = Color((habitosArgb & _rgb) | _tint);
  static const Color habitosBorder = Color((habitosArgb & _rgb) | _border);

  // Recordatorios.
  static const int recordatoriosArgb = 0xFFA99BFF;
  static const Color recordatorios = Color(recordatoriosArgb);
  static const Color recordatoriosTint =
      Color((recordatoriosArgb & _rgb) | _tint);
  static const Color recordatoriosBorder =
      Color((recordatoriosArgb & _rgb) | _border);

  // Notas.
  static const int notasArgb = 0xFFE9D8A6;
  static const Color notas = Color(notasArgb);
  static const Color notasTint = Color((notasArgb & _rgb) | _tint);
  static const Color notasBorder = Color((notasArgb & _rgb) | _border);
}

/// Mini-apps de la suite: nombre visible, ruta, icono y color.
enum SuiteApp {
  finanzas(
    label: 'Finanzas',
    route: '/finanzas',
    icon: Icons.account_balance_wallet_rounded,
    color: SuiteAppColors.finanzas,
    tint: SuiteAppColors.finanzasTint,
    border: SuiteAppColors.finanzasBorder,
  ),
  diario(
    label: 'Diario',
    route: '/diario',
    icon: Icons.auto_stories_rounded,
    color: SuiteAppColors.diario,
    tint: SuiteAppColors.diarioTint,
    border: SuiteAppColors.diarioBorder,
  ),
  habitos(
    label: 'Hábitos',
    route: '/habitos',
    icon: Icons.local_fire_department_rounded,
    color: SuiteAppColors.habitos,
    tint: SuiteAppColors.habitosTint,
    border: SuiteAppColors.habitosBorder,
  ),
  recordatorios(
    label: 'Recordatorios',
    route: '/recordatorios',
    icon: Icons.check_circle_outline_rounded,
    color: SuiteAppColors.recordatorios,
    tint: SuiteAppColors.recordatoriosTint,
    border: SuiteAppColors.recordatoriosBorder,
  ),
  notas(
    label: 'Notas',
    route: '/notas',
    icon: Icons.edit_note_rounded,
    color: SuiteAppColors.notas,
    tint: SuiteAppColors.notasTint,
    border: SuiteAppColors.notasBorder,
  );

  const SuiteApp({
    required this.label,
    required this.route,
    required this.icon,
    required this.color,
    required this.tint,
    required this.border,
  });

  /// Nombre visible en español.
  final String label;

  /// Ruta de navegación (empieza por `/`).
  final String route;

  /// Icono del menú (el mismo del sidebar de la suite).
  final IconData icon;

  /// Color de la app (única fuente: `SuiteAppColors.xxxArgb`).
  final Color color;

  /// Fondo suave derivado de [color] (alpha `SuiteAppColors.tintAlpha`).
  final Color tint;

  /// Borde derivado de [color] (alpha `SuiteAppColors.borderAlpha`).
  final Color border;
}
