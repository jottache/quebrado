import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_notice.dart';

import '../../helpers/pump_app.dart';

Widget _boton({String? actionLabel, VoidCallback? onAction, bool success = false}) => Builder(
      builder: (context) => TextButton(
        onPressed: () => showOrtizNotice(
          context,
          'Movimiento guardado',
          actionLabel: actionLabel,
          onAction: onAction,
          success: success,
        ),
        child: const Text('Mostrar'),
      ),
    );

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('muestra el mensaje y la acción en ${window.name}', (tester) async {
      var deshecho = 0;
      await pumpApp(tester, _boton(actionLabel: 'Deshacer', onAction: () => deshecho++), window: window);
      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Movimiento guardado'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      expect(deshecho, 1);
    });
  }

  testWidgets('es flotante y se cierra solo aunque tenga acción', (tester) async {
    await pumpApp(tester, _boton(actionLabel: 'Ver', onAction: () {}));
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.persist, isFalse);
    expect(Theme.of(tester.element(find.byType(SnackBar))).snackBarTheme.behavior, SnackBarBehavior.floating);
  });

  testWidgets('sin acción no pinta botón', (tester) async {
    await pumpApp(tester, _boton());
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('success antepone el check en onAccent sobre ok', (tester) async {
    await pumpApp(tester, _boton(success: true));
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.color, OrtizTokens.dark.onAccent);
    final circulo = find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(DecoratedBox));
    expect((tester.widget<DecoratedBox>(circulo.first).decoration as BoxDecoration).color, OrtizTokens.dark.ok);
  });

  testWidgets('sin success no hay check', (tester) async {
    await pumpApp(tester, _boton());
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('un segundo aviso sustituye al anterior', (tester) async {
    await pumpApp(tester, _boton());
    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('sin ScaffoldMessenger devuelve null y no falla', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(showOrtizNotice(ctx, 'Hola'), isNull);
  });

  testWidgets('OrtizSuccessMark suelto pinta el check onAccent sobre ok y dice «Hecho»', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const Center(child: OrtizSuccessMark()));
    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.color, OrtizTokens.dark.onAccent);
    final circulo = find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(DecoratedBox));
    expect((tester.widget<DecoratedBox>(circulo.first).decoration as BoxDecoration).color, OrtizTokens.dark.ok);
    expect(find.bySemanticsLabel('Hecho'), findsOneWidget);
    semantics.dispose();
  });
}
