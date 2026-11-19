import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_list_row.dart';

import '../../helpers/pump_app.dart';

BoxDecoration _decoracion(WidgetTester tester) =>
    tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration;

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('se muestra sin desbordes con textos largos en ${window.name}', (tester) async {
      await pumpApp(
        tester,
        OrtizListRow(
          dotColor: SuiteApp.diario.color,
          leading: const Icon(Icons.book),
          title: 'Un título muy largo ' * 12,
          subtitle: 'Un subtítulo todavía más largo ' * 12,
          trailing: const Text('\$1234.56'),
          onTap: () {},
        ),
        window: window,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('\$1234.56'), findsOneWidget);
    });
  }

  testWidgets('dotColor pinta un punto redondo de OrtizSize.dot con ese color', (tester) async {
    await pumpApp(tester, OrtizListRow(dotColor: SuiteApp.habitos.color, title: 'Leer'));
    final punto = find.descendant(
      of: find.byType(OrtizListRow),
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).color == SuiteApp.habitos.color),
    );
    expect(punto, findsOneWidget);
    expect(tester.getSize(punto), const Size.square(OrtizSize.dot));
  });

  testWidgets('el objetivo táctil mide al menos OrtizSize.minTouch de alto', (tester) async {
    await pumpApp(tester, OrtizListRow(title: 'Corta', onTap: () {}));
    expect(tester.getSize(find.byType(OrtizListRow)).height, greaterThanOrEqualTo(OrtizSize.minTouch));
  });

  testWidgets('al tocarla llama a onTap', (tester) async {
    var toques = 0;
    await pumpApp(tester, OrtizListRow(title: 'Café', onTap: () => toques++));
    await tester.tap(find.text('Café'));
    expect(toques, 1);
  });

  testWidgets('en reposo es transparente y seleccionada va sobre surfaceHigh', (tester) async {
    await pumpApp(tester, const OrtizListRow(title: 'Reposo'));
    expect(_decoracion(tester).color, Colors.transparent);

    await pumpApp(tester, const OrtizListRow(title: 'Activa', selected: true));
    expect(_decoracion(tester).color, OrtizTokens.dark.surfaceHigh);
    expect(tester.getSemantics(find.byType(OrtizListRow)), matchesSemantics(isSelected: true, hasSelectedState: true, label: 'Activa'));
  });

  testWidgets('con foco de teclado muestra el anillo fg de OrtizStroke.focus', (tester) async {
    await pumpApp(tester, OrtizListRow(title: 'Foco', onTap: () {}));
    expect(_decoracion(tester).border, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final borde = _decoracion(tester).border! as Border;
    expect(borde.top.color, OrtizTokens.dark.fg);
    expect(borde.top.width, OrtizStroke.focus);
    expect(_decoracion(tester).color, OrtizTokens.dark.surface);
  });

  testWidgets('con autofocus la fila toma el foco al aparecer y sin él no', (tester) async {
    await pumpApp(
      tester,
      Column(children: [
        OrtizListRow(title: 'Ninguna', onTap: () {}),
        OrtizListRow(title: 'Vigente', selected: true, autofocus: true, onTap: () {}),
      ]),
    );
    await tester.pump();

    final enfocada = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(of: find.byWidget(enfocada.widget), matching: find.byType(OrtizListRow)).evaluate().single.widget,
      isA<OrtizListRow>().having((r) => r.title, 'title', 'Vigente'),
    );
  });

  testWidgets('sin onTap no es un botón', (tester) async {
    await pumpApp(tester, const OrtizListRow(title: 'Solo lectura'));
    expect(
      tester.getSemantics(find.byType(OrtizListRow)),
      isNot(matchesSemantics(isButton: true, label: 'Solo lectura')),
    );
  });
}
