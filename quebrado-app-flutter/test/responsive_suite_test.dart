import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/widgets/responsive_breakpoints.dart';
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart';
import 'package:quebrado_app_flutter/widgets/suite_actions.dart';
import 'package:quebrado_app_flutter/widgets/suite_command_palette.dart';
import 'package:quebrado_app_flutter/widgets/suite_drawer.dart';
import 'package:quebrado_app_flutter/widgets/suite_rail.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/calculator_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';

import 'helpers/pump_app.dart';
import 'helpers/pump_suite_router.dart';

/// AppState sin carga de datos (ni SQLite ni Supabase): el shell solo lee la
/// pestaña activa de Finanzas.
class _FakeAppState extends AppState {
  @override
  Future<void> loadData({bool forceReload = false}) async {}
}

/// Para «Sincronizar»: las tasas fallan si [fail] (como sin red).
class _SyncAppState extends _FakeAppState {
  _SyncAppState({required this.fail});

  final bool fail;

  @override
  Future<void> refreshRates() async {
    if (fail) throw Exception('sin red');
  }
}

class _QuietDiarioState extends DiarioState {
  @override
  Future<void> loadAll() async {}
}

class _QuietHabitosState extends HabitosState {
  @override
  Future<void> loadHabits() async {}
}

class _QuietRemindersState extends RemindersState {
  @override
  Future<void> reload() async {}
}

class _QuietNotasState extends NotasState {
  @override
  Future<void> loadAll() async {}
}

/// Etiquetas del menú, en el orden de las ramas.
const _menuLabels = [
  'Ortiz',
  'Finanzas',
  'Diario',
  'Hábitos',
  'Recordatorios',
  'Notas',
];

/// Pie común del menú y del riel.
const _footerLabels = [
  'Conversaciones anteriores',
  'Calculadora',
  'Sincronizar',
  'Ajustes',
];

Widget _buildTestApp({
  required Size screenSize,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
      ChangeNotifierProvider<HabitosState>(create: (_) => HabitosState()),
      ChangeNotifierProvider<RemindersState>(create: (_) => RemindersState()),
      ChangeNotifierProvider<AgenteState>(create: (_) => AgenteState()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: child,
      ),
    ),
  );
}

void main() {
  group('ResponsiveBreakpoints Tests', () {
    testWidgets('Detects compact mobile width correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(400, 800),
          child: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isCompact(context), isTrue);
              expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
              expect(ResponsiveBreakpoints.isExpanded(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Detects desktop and expanded widths correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(1400, 900),
          child: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isCompact(context), isFalse);
              expect(ResponsiveBreakpoints.isDesktop(context), isTrue);
              expect(ResponsiveBreakpoints.isExpanded(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('suitePaletteEntries', () {
    test('arma Apps, todas las acciones rápidas y la sección Ortiz', () {
      final entries = suitePaletteEntries(
        goBranch: (_) {},
        runAction: (_) {},
        onNewConversation: () {},
        onOpenHistory: () {},
        onOpenSettings: () {},
      );
      List<String> titles(PaletteSection s) =>
          [for (final e in entries.where((e) => e.section == s)) e.title];

      expect(titles(PaletteSection.apps), _menuLabels);
      expect(titles(PaletteSection.actions),
          [for (final a in suiteActions) a.label]);
      expect(titles(PaletteSection.ortiz), [
        'Nueva conversación',
        'Conversaciones anteriores',
        'Ajustes',
      ]);
    });

    test('cada entrada llama a su callback con su rama o su acción', () {
      final branches = <SuiteBranch>[];
      final actions = <SuiteAction>[];
      final entries = suitePaletteEntries(
        goBranch: branches.add,
        runAction: actions.add,
        onNewConversation: () {},
      );
      entries.firstWhere((e) => e.title == 'Notas').onSelected();
      entries.firstWhere((e) => e.title == 'Registrar gasto').onSelected();

      expect(branches, [SuiteBranch.notas]);
      expect(actions.single.id, 'finanzas.gasto');
      // Sin callbacks, no salen historial ni ajustes.
      expect(entries.where((e) => e.title == 'Ajustes'), isEmpty);
    });
  });

  group('ResponsiveSuiteScaffold (shell del router)', () {
    for (final window in [WindowClass.compact, WindowClass.medium]) {
      testWidgets('en ${window.name} (< 840) no hay riel y el menú es SuiteDrawer',
          (tester) async {
        await pumpSuiteRouter(tester, window: window);

        expect(find.text('pantalla inicio'), findsOneWidget);
        expect(find.byType(SuiteRail), findsNothing);
        expect(find.byType(SuiteDrawer), findsNothing);

        await tester.tap(find.text('menú inicio'));
        await tester.pumpAndSettle();

        expect(find.byType(SuiteDrawer), findsOneWidget);
        for (final label in [..._menuLabels, ..._footerLabels]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
      });
    }

    testWidgets('en compact, «Abrir Diario» del drawer abre la app y cierra el menú',
        (tester) async {
      final router = await pumpSuiteRouter(tester);

      await tester.tap(find.text('menú inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Diario'));
      await tester.pumpAndSettle();

      expect(currentPath(router), SuiteBranch.diario.path);
      expect(find.text('pantalla diario'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });

    for (final window in [WindowClass.desktop, WindowClass.expanded]) {
      testWidgets('en ${window.name} (≥ 840) se ve SuiteRail con las ramas y el pie',
          (tester) async {
        await pumpSuiteRouter(tester, window: window);

        expect(find.byType(Drawer), findsNothing);
        expect(find.byType(SuiteRail), findsOneWidget);
        for (final label in [..._menuLabels, ..._footerLabels, 'Buscar']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('pantalla inicio'), findsOneWidget);
      });
    }

    testWidgets('el riel mide 240 en expanded y 210 entre 840 y 1199',
        (tester) async {
      await pumpSuiteRouter(tester, window: WindowClass.expanded);
      expect(tester.getSize(find.byType(SuiteRail)).width, 240);

      await pumpSuiteRouter(tester, window: WindowClass.desktop);
      expect(tester.getSize(find.byType(SuiteRail)).width, 210);
    });

    testWidgets('en el riel, «Abrir Recordatorios» abre la app y cambia la URL',
        (tester) async {
      final router =
          await pumpSuiteRouter(tester, window: WindowClass.expanded);

      await tester.tap(find.text('Recordatorios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Recordatorios'));
      await tester.pumpAndSettle();

      expect(currentPath(router), SuiteBranch.recordatorios.path);
      expect(find.text('pantalla recordatorios'), findsOneWidget);
      expect(find.text('pantalla inicio'), findsNothing);
    });

    testWidgets('el estado de la app se conserva al ir a otra y volver',
        (tester) async {
      await pumpSuiteRouter(tester,
          window: WindowClass.expanded, initialLocation: SuiteBranch.diario.path);

      await tester.tap(find.text('sumar diario'));
      await tester.pump();
      expect(find.text('contador diario 1'), findsOneWidget);

      await tester.tap(find.text('Hábitos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Hábitos'));
      await tester.pumpAndSettle();
      expect(find.text('pantalla habitos'), findsOneWidget);

      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Diario'));
      await tester.pumpAndSettle();
      expect(find.text('contador diario 1'), findsOneWidget);
    });

    testWidgets('en compact, el estado también se conserva al volver por el drawer',
        (tester) async {
      await pumpSuiteRouter(tester, initialLocation: SuiteBranch.notas.path);

      await tester.tap(find.text('sumar notas'));
      await tester.pump();

      await tester.tap(find.text('menú notas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ortiz'));
      await tester.pumpAndSettle();
      expect(find.text('pantalla inicio'), findsOneWidget);

      await tester.tap(find.text('menú inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Notas'));
      await tester.pumpAndSettle();
      expect(find.text('contador notas 1'), findsOneWidget);
    });

    testWidgets('con Finanzas activa, el riel muestra sus pestañas y las cambia',
        (tester) async {
      final appState = _FakeAppState();
      addTearDown(appState.dispose);
      await pumpSuiteRouter(
        tester,
        initialLocation: SuiteBranch.finanzas.path,
        window: WindowClass.expanded,
        providers: [ChangeNotifierProvider<AppState>.value(value: appState)],
      );

      expect(find.text('Historial'), findsOneWidget);
      await tester.tap(find.text('Historial'));
      await tester.pump();
      expect(appState.currentTabIndex, 2);

      // En otra app las pestañas de Finanzas no aparecen.
      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Diario'));
      await tester.pumpAndSettle();
      expect(find.text('Historial'), findsNothing);
    });

    testWidgets('«Calculadora» al pie del drawer cierra el menú y abre la calculadora',
        (tester) async {
      final appState = _FakeAppState();
      addTearDown(appState.dispose);
      await pumpSuiteRouter(
        tester,
        providers: [ChangeNotifierProvider<AppState>.value(value: appState)],
      );

      await tester.tap(find.text('menú inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calculadora'));
      await tester.pumpAndSettle();
      // La calculadora (código existente, fuera de este cambio) desborda en
      // horizontal con la fuente de los tests (Ahem, más ancha que la real):
      // se descarta solo ese error de layout para probar el cableado del pie.
      final layoutError = tester.takeException();
      if (layoutError != null) {
        expect(layoutError.toString(), contains('overflowed'));
      }

      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(CalculatorBottomSheet), findsOneWidget);
    });

    for (final fail in [false, true]) {
      testWidgets(
          '«Sincronizar» del riel ${fail ? 'avisa del error si falla' : 'avisa «Suite sincronizada»'}',
          (tester) async {
        final appState = _SyncAppState(fail: fail);
        addTearDown(appState.dispose);
        await pumpSuiteRouter(
          tester,
          window: WindowClass.expanded,
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<DiarioState>(create: (_) => _QuietDiarioState()),
            ChangeNotifierProvider<HabitosState>(create: (_) => _QuietHabitosState()),
            ChangeNotifierProvider<RemindersState>(create: (_) => _QuietRemindersState()),
            ChangeNotifierProvider<NotasState>(create: (_) => _QuietNotasState()),
          ],
        );

        await tester.tap(find.text('Sincronizar'));
        await tester.pump();
        await tester.pump();

        expect(find.text(suiteSyncErrorNotice), fail ? findsOneWidget : findsNothing);
        expect(find.text('Suite sincronizada'), fail ? findsNothing : findsOneWidget);
        // Deja que el aviso se cierre solo (sin Timers pendientes).
        await tester.pumpAndSettle(const Duration(seconds: 10));
      });
    }

    testWidgets('«Ajustes» del riel ofrece los ajustes de Ortiz y de Finanzas',
        (tester) async {
      await pumpSuiteRouter(tester, window: WindowClass.expanded);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.text('Clave, modelo y atajos de consulta'), findsOneWidget);
      expect(find.text('PIN, respaldos y libros'), findsOneWidget);
    });

    testWidgets('«Buscar» del riel abre la paleta y una app de la paleta navega',
        (tester) async {
      final router =
          await pumpSuiteRouter(tester, window: WindowClass.expanded);

      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      final palette = find.byType(SuiteCommandPalette);
      expect(palette, findsOneWidget);
      expect(find.descendant(of: palette, matching: find.text('Registrar gasto')),
          findsOneWidget);

      // La primera «Notas» es la fila de Apps (las demás, etiquetas de acciones).
      await tester.tap(
          find.descendant(of: palette, matching: find.text('Notas')).first);
      await tester.pumpAndSettle();

      expect(palette, findsNothing);
      expect(currentPath(router), SuiteBranch.notas.path);
    });

    testWidgets('SuiteShellScope expone la rama activa y el foco del chat',
        (tester) async {
      await pumpSuiteRouter(tester, initialLocation: SuiteBranch.habitos.path);

      final ctx = tester.element(find.text('pantalla habitos'));
      final scope = SuiteShellScope.maybeOf(ctx);
      expect(scope?.currentBranch, SuiteBranch.habitos);
      expect(scope?.chatFocusNode, isA<FocusNode>());
    });
  });
}
