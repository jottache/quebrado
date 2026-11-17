import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/responsive_sheet_helper.dart';

import '../helpers/pump_app.dart';

/// Botón que abre una hoja responsive con un texto fijo.
Widget _opener() => Builder(
      builder: (context) => TextButton(
        onPressed: () => showResponsiveSheet<void>(
          context: context,
          builder: (_) => const Text('contenido de la hoja'),
        ),
        child: const Text('abrir'),
      ),
    );

/// Busca la caja decorada del panel lateral de escritorio (la que tiene radio de hoja).
BoxDecoration? _panelDecoration(WidgetTester tester) {
  for (final container in tester.widgetList<Container>(find.byType(Container))) {
    final deco = container.decoration;
    if (deco is BoxDecoration &&
        deco.borderRadius ==
            const BorderRadius.only(
              topLeft: Radius.circular(OrtizRadius.sheet),
              bottomLeft: Radius.circular(OrtizRadius.sheet),
            )) {
      return deco;
    }
  }
  return null;
}

void main() {
  testWidgets('en escritorio el panel lateral usa la superficie oscura del tema (spec 01)',
      (tester) async {
    await pumpApp(tester, _opener(), window: WindowClass.expanded);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('contenido de la hoja'), findsOneWidget);
    final deco = _panelDecoration(tester);
    expect(deco, isNotNull, reason: 'no se encontró el panel lateral de escritorio');
    expect(deco!.color, OrtizPalette.surface);
  });

  testWidgets('en compact abre una hoja inferior, no el panel lateral', (tester) async {
    await pumpApp(tester, _opener(), window: WindowClass.compact);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('contenido de la hoja'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(_panelDecoration(tester), isNull);
  });
}
