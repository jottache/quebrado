import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_progress.dart';

import '../../helpers/pump_app.dart';

double _factor(WidgetTester tester) =>
    tester.widget<AnimatedFractionallySizedBox>(find.byType(AnimatedFractionallySizedBox)).widthFactor!;

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('mide OrtizSpace.xs de alto y ocupa el ancho en ${window.name}', (tester) async {
      await pumpApp(tester, OrtizProgressBar(value: 0.4, color: SuiteApp.finanzas.color), window: window);
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(OrtizProgressBar));
      expect(size.height, OrtizSpace.xs);
      expect(size.width, window.size.width);
    });
  }

  testWidgets('pista surfaceHigh y relleno del color pedido', (tester) async {
    await pumpApp(tester, OrtizProgressBar(value: 0.4, color: SuiteApp.finanzas.color));
    final colores = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(OrtizProgressBar), matching: find.byType(DecoratedBox)),
        )
        .map((b) => (b.decoration as BoxDecoration).color)
        .toList();
    expect(colores, [OrtizTokens.dark.surfaceHigh, SuiteApp.finanzas.color]);
    expect(_factor(tester), 0.4);
  });

  testWidgets('recorta los valores fuera de 0–1 y trata NaN como 0', (tester) async {
    await pumpApp(tester, const OrtizProgressBar(value: 1.7, color: OrtizPalette.ok));
    expect(_factor(tester), 1);
    await pumpApp(tester, const OrtizProgressBar(value: -0.3, color: OrtizPalette.ok));
    expect(_factor(tester), 0);
    await pumpApp(tester, const OrtizProgressBar(value: double.nan, color: OrtizPalette.ok));
    expect(_factor(tester), 0);
  });

  testWidgets('anuncia el porcentaje al lector de pantalla', (tester) async {
    await pumpApp(tester, const OrtizProgressBar(value: 0.25, color: OrtizPalette.ok, semanticsLabel: 'Meta'));
    expect(tester.getSemantics(find.byType(OrtizProgressBar)), matchesSemantics(label: 'Meta', value: '25 %'));
  });
}
