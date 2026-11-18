import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_empty_state.dart';

import '../../helpers/pump_app.dart';

final _mensaje = 'Cuando registres un gasto o un ingreso aparecerá aquí, ordenado por fecha. ' * 3;

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('muestra icono, título, mensaje y acción sin desbordes en ${window.name}', (tester) async {
      await pumpApp(
        tester,
        OrtizEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Aún no hay movimientos',
          message: _mensaje,
          action: FilledButton(onPressed: () {}, child: const Text('Registrar')),
        ),
        window: window,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Aún no hay movimientos'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
      expect(tester.getSize(find.text(_mensaje)).width, lessThanOrEqualTo(OrtizSize.readableWidth));
    });
  }

  testWidgets('el icono usa OrtizIconSize.xxl en muted y el mensaje va en muted', (tester) async {
    await pumpApp(tester, const OrtizEmptyState(icon: Icons.inbox_outlined, title: 'Vacío', message: 'Nada'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
    expect(icon.size, OrtizIconSize.xxl);
    expect(icon.color, OrtizTokens.dark.muted);
    expect(tester.widget<Text>(find.text('Nada')).style!.color, OrtizTokens.dark.muted);
    expect(tester.widget<Text>(find.text('Vacío')).style!.color, OrtizTokens.dark.fg);
  });

  testWidgets('sin mensaje ni acción solo muestra el título', (tester) async {
    await pumpApp(tester, const OrtizEmptyState(icon: Icons.search_off, title: 'Sin resultados'));
    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
