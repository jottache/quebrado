// Píldora de estado o moneda (spec 05).
//
// Fondo = el color con el alpha de tinte de la suite (≈ 16 %); texto = el mismo color si alcanza 4,5:1 sobre ese fondo, o
// `fg` si no. El contraste se mide contra el peor caso de las superficies
// donde puede ir la píldora (`bg` y `surfaceHigh`).
import 'package:flutter/material.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';

/// Contraste mínimo de texto normal (WCAG AA).
const double kOrtizMinTextContrast = 4.5;

/// Relación de contraste WCAG entre dos colores opacos.
double ortizContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Etiqueta corta de estado o moneda. Sin [color], usa `muted`.
class OrtizPill extends StatelessWidget {
  const OrtizPill({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  // Alpha de tinte de la suite (el mismo de los `xxxTint`), leído de un tono
  // ya derivado para no repetir el número.
  static final double _tintOpacity = OrtizPalette.accentTint.a;

  /// Fondo de la píldora para [color] (translúcido).
  static Color backgroundFor(Color color) =>
      color.withValues(alpha: _tintOpacity);

  /// Color de texto e icono: [color] si contrasta ≥ 4,5:1 con el fondo de la
  /// píldora sobre `bg` y sobre `surfaceHigh`; si no, `fg`.
  static Color foregroundFor(Color color, OrtizTokens t) {
    final tint = backgroundFor(color);
    final worst = [t.bg, t.surfaceHigh]
        .map((s) => ortizContrastRatio(color, Color.alphaBlend(tint, s)))
        .reduce((a, b) => a < b ? a : b);
    return worst >= kOrtizMinTextContrast ? color : t.fg;
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final base = color ?? t.muted;
    final fg = foregroundFor(base, t);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundFor(base),
        borderRadius: BorderRadius.circular(OrtizRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrtizSpace.sm,
          vertical: OrtizSpace.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: OrtizIconSize.xs, color: fg),
              const SizedBox(width: OrtizSpace.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OrtizType.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
