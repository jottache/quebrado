import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_section.dart';

import '../../helpers/pump_app.dart';

Widget _seccion({bool divided = false, bool surface = false}) => SingleChildScrollView(
      child: OrtizSection(
        title: 'Bolsillos de ahorro con un título bastante largo para probar el corte',
        trailing: TextButton(onPressed: () {}, child: const Text('Ver todo')),
        divided: divided,
        surface: surface,
        children: const [Text('Uno'), Text('Dos'), Text('Tres')],
      ),
    );

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('se muestra sin desbordes en ${window.name}', (tester) async {
      await pumpApp(tester, _seccion(divided: true), window: window);
      expect(tester.takeException(), isNull);
      expect(find.text('Ver todo'), findsOneWidget);
      expect(find.text('Tres'), findsOneWidget);
    });
  }

  testWidgets('por defecto no tiene decoración: ni fondo, ni borde, ni sombra', (tester) async {
    await pumpApp(
      tester,
      const OrtizSection(title: 'Hoy', divided: false, children: [Text('Uno'), Text('Dos')]),
    );
    Finder dentro(Type t) => find.descendant(of: find.byType(OrtizSection), matching: find.byType(t));
    for (final tipo in [DecoratedBox, Container, Card, Material, PhysicalModel, PhysicalShape]) {
      expect(dentro(tipo), findsNothing, reason: '$tipo dentro de la sección');
    }
  });

  testWidgets('el título va en muted y se marca como encabezado', (tester) async {
    await pumpApp(tester, _seccion());
    final titulo = tester.widget<Text>(find.textContaining('Bolsillos de ahorro'));
    expect(titulo.style!.color, OrtizTokens.dark.muted);
    expect(
      tester.getSemantics(find.textContaining('Bolsillos de ahorro')),
      matchesSemantics(isHeader: true, label: titulo.data),
    );
  });

  testWidgets('divided intercala un Divider entre cada par de hijos', (tester) async {
    await pumpApp(tester, _seccion(divided: true));
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('sin divided no hay separadores', (tester) async {
    await pumpApp(tester, _seccion());
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('surface pinta surfaceHigh con radio block y sin sombra ni borde', (tester) async {
    await pumpApp(tester, _seccion(surface: true));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(OrtizSection), matching: find.byType(DecoratedBox)),
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, OrtizTokens.dark.surfaceHigh);
    expect(deco.borderRadius, BorderRadius.circular(OrtizRadius.block));
    expect(deco.boxShadow, isNull);
    expect(deco.border, isNull);
  });

  testWidgets('deja OrtizSpace.xxl hasta el grupo siguiente', (tester) async {
    await pumpApp(
      tester,
      const Column(
        children: [
          OrtizSection(children: [SizedBox(key: Key('fin'), height: OrtizSpace.lg)]),
          OrtizSection(children: [SizedBox(key: Key('inicio'), height: OrtizSpace.lg)]),
        ],
      ),
    );
    final fin = tester.getBottomLeft(find.byKey(const Key('fin'))).dy;
    final inicio = tester.getTopLeft(find.byKey(const Key('inicio'))).dy;
    expect(inicio - fin, OrtizSpace.xxl);
  });
}
