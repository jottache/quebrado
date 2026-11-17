// Tokens de color de la suite OrtizApp (tema oscuro ciruela y coral).
//
// Spec 01, decisión C1. Fuente única de los colores base: las clases de color
// de cada módulo leen de aquí (pasos 4–6), nunca definen hex propios.
//
// - `OrtizPalette`: constantes de compilación, para usar en widgets `const` y
//   en otras clases de color `static const`.
// - `OrtizTokens`: la misma paleta como `ThemeExtension`, para leerla del tema
//   con `OrtizTokens.of(context)` y dejar listo un futuro tema claro (C9).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paleta base del tema oscuro. Todo valor es `const`.
abstract final class OrtizPalette {
  // Superficies.
  static const Color bg = Color(0xFF110E12); // fondo
  static const Color surface = Color(0xFF1A161B); // menú, hojas, campo del chat
  static const Color surfaceHigh = Color(0xFF241E25); // elemento activo
  static const Color line = Color(0xFF352B37); // separadores

  // Texto. `faint` es solo decorativo: no cumple contraste para leer.
  static const Color fg = Color(0xFFF1E9EE);
  static const Color muted = Color(0xFF9C8F98);
  static const Color faint = Color(0xFF655A62);

  // Acción principal y Ortiz. Como `warn`/`bad`, se guarda también como
  // entero ARGB para derivar `accentTint` en `const`.
  static const int accentArgb = 0xFFFF8466;
  static const Color accent = Color(accentArgb);
  static const Color onAccent = Color(0xFF1E0D08);

  // Estados. `warn` y `bad` se guardan también como entero ARGB para derivar
  // sus tonos en `const` (leer el ARGB de un `Color` no es constante en Dart).
  static const Color ok = Color(0xFF7CC9A6);
  static const int warnArgb = 0xFFE9B65C;
  static const int badArgb = 0xFFEF7B6E;
  static const Color warn = Color(warnArgb);
  static const Color bad = Color(badArgb);

  // Tonos derivados de estado. Mismos alphas que `SuiteAppColors.tintAlpha`
  // (0x29 ≈ 16 %, fondo lavado) y `borderAlpha` (0x73 ≈ 45 %, borde); el
  // test espejo comprueba que coinciden.
  static const int _rgb = 0x00FFFFFF;
  static const int _tint = 0x29000000;
  static const int _border = 0x73000000;
  static const Color warnTint = Color((warnArgb & _rgb) | _tint);
  static const Color warnBorder = Color((warnArgb & _rgb) | _border);
  static const Color badTint = Color((badArgb & _rgb) | _tint);
  static const Color accentTint = Color((accentArgb & _rgb) | _tint);

  // Dinero (PA-02): ingreso = ok, gasto = bad.
  static const Color income = ok;
  static const Color expense = bad;
}

/// Tokens de color como extensión del tema.
@immutable
class OrtizTokens extends ThemeExtension<OrtizTokens> {
  const OrtizTokens({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.income,
    required this.expense,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color fg;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final Color ok;
  final Color warn;
  final Color bad;
  final Color income;
  final Color expense;

  /// Tema oscuro (único por ahora).
  static const OrtizTokens dark = OrtizTokens(
    bg: OrtizPalette.bg,
    surface: OrtizPalette.surface,
    surfaceHigh: OrtizPalette.surfaceHigh,
    line: OrtizPalette.line,
    fg: OrtizPalette.fg,
    muted: OrtizPalette.muted,
    faint: OrtizPalette.faint,
    accent: OrtizPalette.accent,
    onAccent: OrtizPalette.onAccent,
    ok: OrtizPalette.ok,
    warn: OrtizPalette.warn,
    bad: OrtizPalette.bad,
    income: OrtizPalette.income,
    expense: OrtizPalette.expense,
  );

  /// Tokens del tema actual; `dark` si el tema no registra la extensión.
  static OrtizTokens of(BuildContext context) =>
      Theme.of(context).extension<OrtizTokens>() ?? dark;

  @override
  OrtizTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? line,
    Color? fg,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? onAccent,
    Color? ok,
    Color? warn,
    Color? bad,
    Color? income,
    Color? expense,
  }) {
    return OrtizTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      line: line ?? this.line,
      fg: fg ?? this.fg,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      bad: bad ?? this.bad,
      income: income ?? this.income,
      expense: expense ?? this.expense,
    );
  }

  @override
  OrtizTokens lerp(covariant ThemeExtension<OrtizTokens>? other, double t) {
    if (other is! OrtizTokens) return this;
    // Color.lerp solo devuelve null si ambos extremos son null; aquí nunca.
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OrtizTokens(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      line: mix(line, other.line),
      fg: mix(fg, other.fg),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      ok: mix(ok, other.ok),
      warn: mix(warn, other.warn),
      bad: mix(bad, other.bad),
      income: mix(income, other.income),
      expense: mix(expense, other.expense),
    );
  }
}
