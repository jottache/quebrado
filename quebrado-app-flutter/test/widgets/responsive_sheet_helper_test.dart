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

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('devuelve a quien la abrió el valor con que se cierra la hoja (${window.name})',
        (tester) async {
      late Future<String?> result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showResponsiveSheet<String>(
              context: context,
              builder: (sheetContext) => Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop('guardado-1'),
                    child: const Text('guardar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('cerrar'),
                  ),
                ],
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
        window: window,
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();
      expect(await result, 'guardado-1');
      expect(find.text('guardar'), findsNothing);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cerrar'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.text('cerrar'), findsNothing);
    });
  }

  /// Abre una hoja con la barrita de arrastre pedida.
  Widget openerWithHandle() => Builder(
        builder: (context) => TextButton(
          onPressed: () => showResponsiveSheet<void>(
            context: context,
            backgroundColor: null,
            showDragHandle: true,
            builder: (_) => const Text('contenido de la hoja'),
          ),
          child: const Text('abrir'),
        ),
      );

  testWidgets('en compact, showDragHandle pinta la barrita del tema sobre la superficie',
      (tester) async {
    await pumpApp(tester, openerWithHandle(), window: WindowClass.compact);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(find.bySemanticsLabel(RegExp('arrastre|Dismiss|drag', caseSensitive: false)),
        findsWidgets);
    // Sin color propio, la hoja usa la superficie del tema.
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first,
    );
    expect(material.color, OrtizTokens.dark.surface);
  });

  testWidgets('sin showDragHandle la hoja compact no lleva barrita', (tester) async {
    await pumpApp(tester, _opener(), window: WindowClass.compact);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle, isFalse);
  });

  testWidgets('en escritorio el panel lateral no lleva barrita aunque se pida', (tester) async {
    await pumpApp(tester, openerWithHandle(), window: WindowClass.expanded);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('contenido de la hoja'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(_panelDecoration(tester), isNotNull);
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
