import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/widgets/suite_menu_button.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

import '../helpers/pump_app.dart';
import '../helpers/pump_suite_router.dart';

/// Pantalla de rama con el ☰ en su barra, como las apps reales.
Widget? _withMenuButton(SuiteBranch branch) => branch == SuiteBranch.diario
    ? Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => SuiteMenuButton.leading(context) ??
                const SizedBox.shrink(),
          ),
          title: const Text('Diario de prueba'),
        ),
      )
    : null;

void main() {
  testWidgets('en compact el ☰ abre el menú del shell', (tester) async {
    await pumpSuiteRouter(
      tester,
      initialLocation: SuiteBranch.diario.path,
      screenFor: _withMenuButton,
    );

    expect(find.byTooltip(SuiteMenuButton.tooltip), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);

    await tester.tap(find.byTooltip(SuiteMenuButton.tooltip));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('en expanded no hay ☰: el menú es el riel', (tester) async {
    await pumpSuiteRouter(
      tester,
      initialLocation: SuiteBranch.diario.path,
      window: WindowClass.expanded,
      screenFor: _withMenuButton,
    );

    expect(find.text('Diario de prueba'), findsOneWidget);
    expect(find.byTooltip(SuiteMenuButton.tooltip), findsNothing);
  });

  testWidgets('fuera del shell no se muestra', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) =>
            SuiteMenuButton.leading(context) ?? const Text('sin menú'),
      ),
    );

    expect(find.text('sin menú'), findsOneWidget);
    expect(find.byType(SuiteMenuButton), findsNothing);
  });
}
