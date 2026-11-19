import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_pill.dart';

import '../../helpers/pump_app.dart';

const _t = OrtizTokens.dark;

/// Contraste del texto de la píldora en el peor caso (sobre bg y surfaceHigh).
Color _fondo(WidgetTester tester) => (tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(OrtizPill), matching: find.byType(DecoratedBox)))
        .decoration as BoxDecoration)
    .color!;

double _peorContraste(Color texto, Color fondoPildora) => [_t.bg, _t.surfaceHigh]
    .map((s) => ortizContrastRatio(texto, Color.alphaBlend(fondoPildora, s)))
    .reduce((a, b) => a < b ? a : b);

void main() {
  test('ortizContrastRatio da 21:1 entre negro y blanco y 1:1 entre iguales', () {
    expect(ortizContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(ortizContrastRatio(_t.fg, _t.fg), 1);
  });

  final colores = <String, Color>{
    for (final app in SuiteApp.values) app.name: app.color,
    'ok': _t.ok,
    'warn': _t.warn,
    'bad': _t.bad,
    'accent': _t.accent,
    'muted': _t.muted,
    'line (oscuro)': _t.line,
    'onAccent (oscuro)': _t.onAccent,
  };

  for (final e in colores.entries) {
    testWidgets('el texto de la píldora ${e.key} contrasta al menos 4,5:1', (tester) async {
      await pumpApp(tester, OrtizPill(label: 'Estado', color: e.value, icon: Icons.circle));
      final texto = tester.widget<Text>(find.text('Estado')).style!.color!;
      expect(texto, anyOf(e.value, _t.fg));
      expect(_peorContraste(texto, _fondo(tester)), greaterThanOrEqualTo(kOrtizMinTextContrast));
      expect(tester.widget<Icon>(find.byIcon(Icons.circle)).color, texto);
    });
  }

  testWidgets('un color de estado legible conserva su color en el texto', (tester) async {
    await pumpApp(tester, OrtizPill(label: 'Pagado', color: _t.ok));
    expect(tester.widget<Text>(find.text('Pagado')).style!.color, _t.ok);
  });

  testWidgets('un color sin contraste cae a fg', (tester) async {
    await pumpApp(tester, OrtizPill(label: 'Archivado', color: _t.line));
    expect(tester.widget<Text>(find.text('Archivado')).style!.color, _t.fg);
  });

  testWidgets('sin color usa el tinte de muted y un texto legible', (tester) async {
    await pumpApp(tester, const OrtizPill(label: 'USD'));
    expect(_fondo(tester), OrtizPill.backgroundFor(_t.muted));
    final texto = tester.widget<Text>(find.text('USD')).style!.color!;
    expect(_peorContraste(texto, _fondo(tester)), greaterThanOrEqualTo(kOrtizMinTextContrast));
  });

  group('variante con dotColor (franja de hoy)', () {
    BoxDecoration decoracion(WidgetTester tester, int i) => tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(OrtizPill), matching: find.byType(DecoratedBox)))
        .elementAt(i)
        .decoration as BoxDecoration;

    testWidgets('fondo surface, punto del color y texto muted legible', (tester) async {
      await pumpApp(tester, OrtizPill(label: 'Pago vencido', dotColor: SuiteApp.finanzas.color));
      expect(decoracion(tester, 0).color, _t.surface);
      final punto = decoracion(tester, 1);
      expect(punto.color, SuiteApp.finanzas.color);
      expect(punto.shape, BoxShape.circle);
      final punto0 = find.descendant(of: find.byType(OrtizPill), matching: find.byType(ExcludeSemantics));
      final caja = find.descendant(of: punto0, matching: find.byType(SizedBox));
      expect(tester.getSize(caja), const Size.square(OrtizSize.dot));
      final texto = tester.widget<Text>(find.text('Pago vencido')).style!.color!;
      expect(texto, _t.muted);
      expect(ortizContrastRatio(texto, _t.surface), greaterThanOrEqualTo(kOrtizMinTextContrast));
    });

    testWidgets('el punto no se anuncia: el lector solo oye la etiqueta', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, OrtizPill(label: 'Cumpleaños', dotColor: SuiteApp.diario.color));
      expect(find.bySemanticsLabel('Cumpleaños'), findsOneWidget);
      expect(find.descendant(of: find.byType(OrtizPill), matching: find.byType(ExcludeSemantics)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('sin dotColor no hay punto', (tester) async {
      await pumpApp(tester, const OrtizPill(label: 'USD'));
      expect(find.descendant(of: find.byType(OrtizPill), matching: find.byType(DecoratedBox)), findsOneWidget);
    });

    test('color y dotColor a la vez no se permiten', () {
      expect(() => OrtizPill(label: 'x', color: _t.ok, dotColor: _t.ok), throwsAssertionError);
    });

    testWidgets('con punto y etiqueta larga no desborda en poco espacio', (tester) async {
      await pumpApp(
        tester,
        SizedBox(width: 80, child: Row(children: [Flexible(child: OrtizPill(label: 'Pendiente de revisión', dotColor: _t.warn))])),
      );
      expect(tester.takeException(), isNull);
    });
  });

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('una etiqueta larga en poco espacio no desborda en ${window.name}', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(width: 80, child: Row(children: [Flexible(child: OrtizPill(label: 'Pendiente de revisión', icon: Icons.schedule))])),
        window: window,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
