import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/suite_drawer.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<List<String>> pumpDrawer(WidgetTester tester, WindowClass window,
      {SuiteApp? currentApp}) async {
    final log = <String>[];
    final key = GlobalKey<ScaffoldState>();
    await pumpApp(
      tester,
      Scaffold(
        key: key,
        drawer: SuiteDrawer(
          currentApp: currentApp,
          onOpenOrtiz: () => log.add('/'),
          onOpenApp: (app) => log.add(app.route),
          onViewRecord: log.add,
          onOpenHistory: () => log.add('historial'),
          onOpenCalculator: () => log.add('calculadora'),
          onSync: () => log.add('sincronizar'),
          onOpenSettings: () => log.add('ajustes'),
        ),
        body: const SizedBox.shrink(),
      ),
      window: window,
    );
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();
    return log;
  }

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('CA-03 (${window.name}): tocar Finanzas la despliega y pliega '
        'la otra abierta', (tester) async {
      await pumpDrawer(tester, window, currentApp: SuiteApp.habitos);
      expect(find.text('Abrir Hábitos'), findsOneWidget);
      expect(find.text('Marcar hábitos de hoy'), findsOneWidget);

      await tester.tap(find.text('Finanzas'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Finanzas'), findsOneWidget);
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('Tasas del día'), findsOneWidget);
      expect(find.text('Abrir Hábitos'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra Ortiz, las 5 apps y el pie; sin app abierta en /',
      (tester) async {
    await pumpDrawer(tester, WindowClass.compact);
    expect(find.text('OrtizApp'), findsOneWidget);
    expect(find.text('Ortiz'), findsOneWidget);
    for (final app in SuiteApp.values) {
      expect(find.text(app.label), findsOneWidget);
    }
    expect(find.textContaining('Abrir '), findsNothing);
    for (final label in [
      'Conversaciones anteriores',
      'Calculadora',
      'Sincronizar',
      'Ajustes',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tocar la app abierta la pliega', (tester) async {
    await pumpDrawer(tester, WindowClass.compact);
    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva entrada'), findsOneWidget);
    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva entrada'), findsNothing);
  });

  testWidgets('«Abrir Finanzas» cierra el menú y avisa la app', (tester) async {
    final log = await pumpDrawer(tester, WindowClass.compact);
    await tester.tap(find.text('Finanzas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir Finanzas'));
    await tester.pumpAndSettle();
    expect(log, ['/finanzas']);
    expect(find.text('OrtizApp'), findsNothing);
  });

  testWidgets('el pie llama a su callback', (tester) async {
    final log = await pumpDrawer(tester, WindowClass.compact);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(log, ['ajustes']);
  });
}
