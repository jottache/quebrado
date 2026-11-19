import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/suite_rail.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<List<String>> pumpRail(WidgetTester tester, WindowClass window,
      {SuiteApp? selected}) async {
    final log = <String>[];
    await pumpApp(
      tester,
      Scaffold(
        body: Row(
          children: [
            SuiteRail(
              selectedApp: selected,
              onOpenOrtiz: () => log.add('/'),
              onOpenApp: (app) => log.add(app.route),
              onViewRecord: log.add,
              onSearch: () => log.add('buscar'),
              onOpenHistory: () => log.add('historial'),
              onOpenSettings: () => log.add('ajustes'),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
      window: window,
    );
    return log;
  }

  testWidgets('ancho 210 en escritorio y 240 en expanded', (tester) async {
    await pumpRail(tester, WindowClass.desktop);
    expect(tester.getSize(find.byType(SuiteRail)).width, OrtizSize.railWidth);
    await pumpRail(tester, WindowClass.expanded);
    expect(tester.getSize(find.byType(SuiteRail)).width,
        OrtizSize.railWidthExpanded);
  });

  for (final window in [WindowClass.desktop, WindowClass.expanded]) {
    testWidgets('CA-03 (${window.name}): clic en Finanzas despliega y pliega '
        'la activa', (tester) async {
      await pumpRail(tester, window, selected: SuiteApp.habitos);
      expect(find.text('Abrir Hábitos'), findsOneWidget);

      await tester.tap(find.text('Finanzas'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Finanzas'), findsOneWidget);
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('Abrir Hábitos'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin descripciones y con el pie', (tester) async {
    await pumpRail(tester, WindowClass.expanded);
    for (final app in SuiteApp.values) {
      expect(find.text(app.label), findsOneWidget);
    }
    expect(find.text('Cuentas, bolsillos y pagos'), findsNothing);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Conversaciones anteriores'), findsOneWidget);
  });

  testWidgets('al pasar el cursor aparece «Abrir {App}» y navega',
      (tester) async {
    final log = await pumpRail(tester, WindowClass.expanded);
    expect(find.byTooltip('Abrir Notas'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Notas')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Abrir Notas'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir Notas'));
    expect(log, ['/notas']);
  });
}
