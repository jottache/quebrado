import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/widgets/suite_unlock_view.dart';

import '../helpers/pump_app.dart';

class _FakeAppState extends Fake implements AppState {
  _FakeAppState(this.results);

  /// Resultado de cada llamada, en orden.
  final List<bool> results;
  final List<String> reasons = [];
  final List<String> titles = [];

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<bool> verifySecurityAuth(BuildContext context, {String reason = '', String title = ''}) async {
    reasons.add(reason);
    titles.add(title);
    return results[reasons.length - 1];
  }
}

// rutas.md §10, P-04 revisada: el PIN se pide al entrar a la app, una vez al día.
void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('pide el PIN al abrir con el título «Desbloquear» y avisa al confirmar (${window.name})',
        (tester) async {
      final app = _FakeAppState([true]);
      var unlocked = 0;

      await pumpApp(
        tester,
        SuiteUnlockView(onUnlocked: () => unlocked++),
        providers: [ChangeNotifierProvider<AppState>.value(value: app)],
        window: window,
      );
      await tester.pump();
      await tester.pump();

      expect(app.reasons, ['Ingresa tu PIN para entrar a Ortiz']);
      expect(app.titles, ['Desbloquear']);
      expect(unlocked, 1);
    });

    testWidgets('si cancela se queda bloqueado y puede reintentar (${window.name})', (tester) async {
      final app = _FakeAppState([false, true]);
      var unlocked = 0;

      await pumpApp(
        tester,
        SuiteUnlockView(onUnlocked: () => unlocked++),
        providers: [ChangeNotifierProvider<AppState>.value(value: app)],
        window: window,
      );
      await tester.pump();
      await tester.pump();

      expect(unlocked, 0);
      expect(find.text('Ortiz está bloqueado'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
      await tester.pump();
      await tester.pump();

      expect(app.reasons, hasLength(2));
      expect(unlocked, 1);
    });
  }
}
