import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart';
import 'package:quebrado_app_flutter/widgets/suite_command_palette.dart';
import 'package:quebrado_app_flutter/widgets/suite_drawer.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';
import 'package:quebrado_app_flutter/widgets/suite_shortcuts.dart';

import '../helpers/pump_app.dart';
import '../helpers/pump_suite_router.dart';

const _chatKey = ValueKey('campo chat');
const _otherKey = ValueKey('otro campo');

/// Inicio falso: registra el foco del chat del shell en un campo y tiene otro
/// campo cualquiera.
class _FakeHome extends StatelessWidget {
  const _FakeHome();

  @override
  Widget build(BuildContext context) {
    final scope = SuiteShellScope.maybeOf(context)!;
    return Scaffold(
      body: Column(
        children: [
          TextField(key: _chatKey, focusNode: scope.chatFocusNode),
          const TextField(key: _otherKey),
          TextButton(onPressed: scope.openMenu, child: const Text('menú')),
        ],
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  WindowClass window = WindowClass.expanded,
  String initialLocation = SuiteRoutes.home,
}) =>
    pumpSuiteRouter(
      tester,
      window: window,
      initialLocation: initialLocation,
      screenFor: (b) => b == SuiteBranch.inicio ? const _FakeHome() : null,
    );

Future<void> _ctrlK(WidgetTester tester,
    {LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

bool _hasFocus(WidgetTester tester, Key key) {
  final field = tester.widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)));
  return field.focusNode.hasFocus;
}

void main() {
  group('Ctrl/⌘+K', () {
    testWidgets('Ctrl+K abre la paleta y otro Ctrl+K la cierra', (tester) async {
      await _pump(tester);
      expect(find.byType(SuiteCommandPalette), findsNothing);

      await _ctrlK(tester);
      expect(find.byType(SuiteCommandPalette), findsOneWidget);

      await _ctrlK(tester);
      expect(find.byType(SuiteCommandPalette), findsNothing);
    });

    testWidgets('⌘+K abre la paleta en compact', (tester) async {
      await _pump(tester, window: WindowClass.compact);
      await _ctrlK(tester, modifier: LogicalKeyboardKey.metaLeft);
      expect(find.byType(SuiteCommandPalette), findsOneWidget);
    });

    testWidgets('Ctrl+K también funciona con el foco en un campo', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_otherKey));
      await tester.pump();

      await _ctrlK(tester);
      expect(find.byType(SuiteCommandPalette), findsOneWidget);
    });
  });

  group('/', () {
    testWidgets('fuera de un campo, lleva el foco al campo del chat registrado',
        (tester) async {
      await _pump(tester);
      expect(_hasFocus(tester, _chatKey), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(_hasFocus(tester, _chatKey), isTrue);
    });

    testWidgets('dentro de un campo de texto no mueve el foco', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_otherKey));
      await tester.pump();
      expect(suiteFocusIsInTextField(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(_hasFocus(tester, _otherKey), isTrue);
      expect(_hasFocus(tester, _chatKey), isFalse);
    });

    testWidgets('fuera del inicio no hace nada', (tester) async {
      await _pump(tester, initialLocation: SuiteBranch.notas.path);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(find.text('pantalla notas'), findsOneWidget);
      expect(suiteFocusIsInTextField(), isFalse);
    });
  });

  group('Esc', () {
    testWidgets('cierra el menú ☰ abierto', (tester) async {
      await _pump(tester, window: WindowClass.compact);
      await tester.tap(find.text('menú'));
      await tester.pumpAndSettle();
      expect(find.byType(SuiteDrawer), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SuiteDrawer), findsNothing);
    });

    testWidgets('cierra la paleta', (tester) async {
      await _pump(tester);
      await _ctrlK(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SuiteCommandPalette), findsNothing);
    });

    testWidgets('quita el foco del campo del chat', (tester) async {
      await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();
      expect(_hasFocus(tester, _chatKey), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_hasFocus(tester, _chatKey), isFalse);
    });
  });
}
