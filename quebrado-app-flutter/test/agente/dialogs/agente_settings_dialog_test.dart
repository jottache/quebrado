import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/dialogs/agente_settings_dialog.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

import '../../helpers/pump_app.dart';

Future<AgenteState> _pump(WidgetTester tester, WindowClass window) async {
  final state = AgenteState(autoInit: false);
  await pumpApp(
    tester,
    const Scaffold(body: AgenteSettingsDialog()),
    providers: [ChangeNotifierProvider<AgenteState>.value(value: state)],
    window: window,
  );
  return state;
}

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('«Resumen del día» edita la instrucción y la guarda (${window.name})', (tester) async {
      final state = await _pump(tester, window);

      await tester.tap(find.text('Resumen del día'));
      await tester.pumpAndSettle();

      // El editor abre con el texto actual (el de por defecto) y sin alias.
      final field = find.byType(TextFormField);
      expect(field, findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, kDailyBriefingDefaultInstruction);
      expect(find.text('ALIAS / ETIQUETA CORTA (OPCIONAL)'), findsNothing);

      await tester.enterText(field, 'Habla corto.');
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(state.dailyBriefingInstruction, 'Habla corto.');
      expect(state.quickPrompts, isEmpty);
      expect(find.text('Instrucción del resumen guardada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el encabezado «INSTRUCCIONES DE ORTIZ» usa el estilo caption en muted, sin ajustes a mano',
      (tester) async {
    await _pump(tester, WindowClass.compact);

    final style = tester.widget<Text>(find.text('INSTRUCCIONES DE ORTIZ')).style!;
    expect(style.fontSize, OrtizType.caption.fontSize);
    expect(style.fontWeight, OrtizType.caption.fontWeight);
    expect(style.letterSpacing, OrtizType.caption.letterSpacing);
    expect(style.color, OrtizPalette.muted);
  });

  testWidgets('«Restaurar texto original» vuelve al texto por defecto', (tester) async {
    final state = await _pump(tester, WindowClass.compact);
    await state.saveDailyBriefingInstruction('Texto propio.', persist: false);

    await tester.tap(find.text('Resumen del día'));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(field).controller!.text, 'Texto propio.');

    await tester.tap(find.text('Restaurar texto original'));
    await tester.pump();
    expect(tester.widget<TextFormField>(field).controller!.text, kDailyBriefingDefaultInstruction);

    await tester.tap(find.text('Guardar Cambios'));
    await tester.pumpAndSettle();
    expect(state.dailyBriefingPrompt, isNull);
    expect(state.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);
  });
}
