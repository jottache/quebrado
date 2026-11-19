// Monto con cifras tabulares (spec 05): JetBrains Mono, `OrtizType.amount`.
//
// Formato por defecto: el de `quebrado/widgets/helpers.dart` (2 decimales,
// punto decimal, sin separador de miles; un símbolo con letras, como «Bs.»,
// lleva espacio). Esos helpers dependen de `CurrencyType` de Quebrado, así
// que este componente compartido no los importa: Quebrado puede pasarlos tal
// cual en [OrtizAmount.format] (`format: formatUSD`).
import 'package:flutter/material.dart';

import '../../theme/ortiz_motion.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';

final RegExp _letter = RegExp(r'[A-Za-z]');

/// `"$1234.56"`, `"€1234.56"`, `"Bs. 1234.56"`; negativo con el signo
/// delante del símbolo (`"-$5.00"`) y sin `-0.00`.
String formatOrtizAmount(double value, String currencySymbol) {
  final digits = value.abs().toStringAsFixed(2);
  final isZero = double.parse(digits) == 0;
  final sign = value < 0 && !isZero ? '-' : '';
  final space = _letter.hasMatch(currencySymbol) ? ' ' : '';
  return '$sign$currencySymbol$space$digits';
}

/// Monto de dinero. Color por defecto `fg`; ingreso/gasto con
/// `color: t.income` / `t.expense`. Para el monto grande, `style:
/// OrtizType.amountLg`.
///
/// Con [animate], cuenta desde 0 (y, si cambia [value], desde el valor
/// anterior) en `OrtizMotion.slow`; con reducir movimiento muestra el valor
/// final al instante. Los lectores de pantalla oyen solo el valor final.
///
/// Si no cabe, se reduce (nunca se corta: un monto oculto es un fallo grave).
class OrtizAmount extends StatelessWidget {
  const OrtizAmount({
    super.key,
    required this.value,
    required this.currencySymbol,
    this.style,
    this.animate = false,
    this.color,
    this.format,
  });

  final double value;
  final String currencySymbol;
  final TextStyle? style;
  final bool animate;
  final Color? color;

  /// Formateador propio (p. ej. `formatUSD` de Quebrado). Si es null, usa
  /// [formatOrtizAmount] con [currencySymbol].
  final String Function(double value)? format;

  String _text(double v) => format?.call(v) ?? formatOrtizAmount(v, currencySymbol);

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final base = style ?? OrtizType.amount;
    final effective = base.copyWith(color: color ?? base.color ?? t.fg);

    Widget label(double v) => Text(
          _text(v),
          maxLines: 1,
          softWrap: false,
          style: effective,
        );

    final Widget child;
    if (!animate) {
      child = label(value);
    } else {
      child = Semantics(
        label: _text(value),
        excludeSemantics: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: OrtizMotion.of(context, OrtizMotion.slow),
          curve: OrtizMotion.ease,
          builder: (context, v, _) => label(v),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}
