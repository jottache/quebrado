import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/helpers.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_amount.dart';

import '../../helpers/pump_app.dart';

Widget _reducido(Widget child) => Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: true),
        child: child,
      ),
    );

void main() {
  group('formatOrtizAmount', () {
    test('sigue el formato de helpers.dart: 2 decimales y símbolo pegado', () {
      expect(formatOrtizAmount(1234.5, '\$'), formatUSD(1234.5));
      expect(formatOrtizAmount(7, '€'), '€7.00');
    });

    test('un símbolo con letras lleva espacio, como formatBs', () {
      expect(formatOrtizAmount(10, 'Bs.'), formatBs(10));
    });

    test('el negativo lleva el signo delante del símbolo y no hay -0.00', () {
      expect(formatOrtizAmount(-5, '\$'), '-\$5.00');
      expect(formatOrtizAmount(-0.001, '\$'), '\$0.00');
    });
  });

  testWidgets('usa OrtizType.amount (cifras tabulares) y fg por defecto', (tester) async {
    await pumpApp(tester, const OrtizAmount(value: 12, currencySymbol: '\$'));
    final style = tester.widget<Text>(find.text('\$12.00')).style!;
    expect(style.fontFamily, OrtizType.fontMono);
    expect(style.fontFeatures, OrtizType.amount.fontFeatures);
    expect(style.color, OrtizTokens.dark.fg);
  });

  testWidgets('respeta el color y el estilo grande', (tester) async {
    await pumpApp(
      tester,
      OrtizAmount(value: 3, currencySymbol: '\$', color: OrtizTokens.dark.expense, style: OrtizType.amountLg),
    );
    final style = tester.widget<Text>(find.text('\$3.00')).style!;
    expect(style.color, OrtizTokens.dark.expense);
    expect(style.fontSize, OrtizType.amountLg.fontSize);
  });

  testWidgets('usa el formateador propio si se pasa', (tester) async {
    await pumpApp(tester, const OrtizAmount(value: 2, currencySymbol: 'Bs.', format: formatRate));
    expect(find.text(formatRate(2)), findsOneWidget);
  });

  testWidgets('con animate y disableAnimations muestra el valor final al instante', (tester) async {
    await pumpApp(
      tester,
      _reducido(const OrtizAmount(value: 1234.5, currencySymbol: '\$', animate: true)),
      settle: false,
    );
    expect(find.text('\$1234.50'), findsOneWidget);
  });

  testWidgets('con animate cuenta desde 0 hasta el valor final', (tester) async {
    await pumpApp(
      tester,
      const OrtizAmount(value: 1234.5, currencySymbol: '\$', animate: true),
      settle: false,
    );
    expect(find.text('\$0.00'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('\$1234.50'), findsOneWidget);
    expect(find.bySemanticsLabel('\$1234.50'), findsOneWidget);
  });

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('un monto enorme en poco espacio se reduce sin desbordar en ${window.name}', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 60,
          child: OrtizAmount(value: -987654321.99, currencySymbol: 'Bs.', style: OrtizType.amountLg),
        ),
        window: window,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('-Bs. 987654321.99'), findsOneWidget);
    });
  }
}
