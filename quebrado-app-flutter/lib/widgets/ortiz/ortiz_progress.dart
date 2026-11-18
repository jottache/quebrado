// Barra de progreso fina (spec 05): la usan los bolsillos, cuyo color va como
// punto + barra y no como fondo (PA-02).
import 'package:flutter/material.dart';

import '../../theme/ortiz_motion.dart';
import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';

/// Barra de `OrtizSpace.xs` de alto, extremos redondos, pista `surfaceHigh`.
/// [value] va de 0 a 1 (se recorta; `NaN` cuenta como 0). Anima el cambio en
/// `OrtizMotion.base` (cero con reducir movimiento).
class OrtizProgressBar extends StatelessWidget {
  const OrtizProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.semanticsLabel,
  });

  final double value;
  final Color color;

  /// Qué mide la barra (p. ej. «Meta del bolsillo»); el lector añade el %.
  final String? semanticsLabel;

  double get _clamped => value.isNaN ? 0 : value.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final radius = BorderRadius.circular(OrtizRadius.pill);
    final percent = (_clamped * 100).round();

    return Semantics(
      label: semanticsLabel,
      value: '$percent %',
      child: SizedBox(
        height: OrtizSpace.xs,
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.surfaceHigh, borderRadius: radius),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: OrtizMotion.of(context, OrtizMotion.base),
              curve: OrtizMotion.ease,
              widthFactor: _clamped,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
