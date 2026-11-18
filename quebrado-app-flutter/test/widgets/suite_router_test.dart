import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quebrado_app_flutter/agente/agente.dart';
import 'package:quebrado_app_flutter/diario/dialogs/entry_reader_dialog.dart';
import 'package:quebrado_app_flutter/notas/dialogs/note_reader_dialog.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/screens/ortiz_home_screen.dart';
import 'package:quebrado_app_flutter/widgets/suite_actions.dart';
import 'package:quebrado_app_flutter/widgets/suite_drawer.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/transaction_detail_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/services/suite_lock.dart';
import 'package:quebrado_app_flutter/services/suite_lock_store_base.dart';
import 'package:quebrado_app_flutter/services/suite_record_lookup.dart';
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart';
import 'package:quebrado_app_flutter/widgets/suite_unlock_view.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';
import 'package:quebrado_app_flutter/habitos/habitos.dart';
import 'package:quebrado_app_flutter/notas/notas.dart';
import 'package:quebrado_app_flutter/quebrado/screens/main_screen.dart';
import 'package:quebrado_app_flutter/recordatorios/recordatorios.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

import '../helpers/pump_app.dart' show WindowClass;
import '../helpers/pump_suite_router.dart';

Transaction _mov(String id) => Transaction(
      id: id,
      date: DateTime(2026, 11, 17, 12),
      amount: 12.5,
      currency: CurrencyType.usd,
      note: 'Café de prueba',
      type: TransactionType.expense,
      exchangeRate: 1,
    );

/// AppState sin SQLite ni Supabase: movimientos y PIN los decide el test.
class _FakeAppState extends AppState {
  _FakeAppState({
    this.pin = false,
    List<Transaction> active = const [],
    this.otherBooks = const {},
  }) {
    transactions = [...active];
  }

  final bool pin;
  final Map<String, List<Transaction>> otherBooks;
  final Completer<bool> auth = Completer<bool>();
  int authCalls = 0;

  /// Lo que pasa al terminar de cargar (p. ej. avisar al candado de los ajustes).
  VoidCallback? onLoadData;

  @override
  Future<void> loadData({bool forceReload = false}) async => onLoadData?.call();

  @override
  bool get usePinSecurity => pin;

  @override
  Map<String, List<Transaction>> get transactionsByBook => otherBooks;

  @override
  List<Map<String, String>> get profiles => const [
        {'id': 'quebrado.db', 'name': 'Personal'},
        {'id': 'negocio.db', 'name': 'Negocio'},
      ];

  @override
  Future<bool> verifySecurityAuth(BuildContext context,
      {String reason = '', String title = ''}) {
    authCalls++;
    return auth.future;
  }
}

Future<GoRouter> _pumpWithApp(
  WidgetTester tester,
  _FakeAppState app, {
  SuiteLock? lock,
}) {
  addTearDown(app.dispose);
  return pumpSuiteRouter(
    tester,
    lock: lock,
    // En compact la hoja de detalle (código existente) desborda con la
    // fuente de los tests (Ahem, más ancha que la real).
    window: WindowClass.medium,
    providers: [ChangeNotifierProvider<AppState>.value(value: app)],
  );
}

/// Diario sin red con contactos y entradas dados.
class _FakeDiarioService extends DiarioSupabaseService {
  _FakeDiarioService({this.contacts = const [], this.entries = const []})
      : super.forTesting();

  final List<DiarioContact> contacts;
  final List<DiarioEntry> entries;

  @override
  bool get isReady => false;

  @override
  Future<List<DiarioContact>> getContacts() async => [...contacts];

  @override
  Future<List<DiarioEntry>> getEntries() async => [...entries];
}

/// Hábitos sin red con los hábitos dados.
class _FakeHabitosService extends HabitosSupabaseService {
  _FakeHabitosService(this.habits) : super(client: null);

  final List<HabitModel> habits;

  @override
  Future<HabitosBootstrapData> bootstrapData() async => HabitosBootstrapData(
      habits: [...habits], stacks: const [], logs: const <HabitLogModel>[]);
}

/// Recordatorios sin red con los recordatorios dados (sin semillas).
class _FakeRemindersService extends RemindersSupabaseService {
  _FakeRemindersService(this.reminders) : super(client: null);

  final List<ReminderModel> reminders;

  @override
  Future<List<ReminderModel>> fetchReminders() async => [...reminders];
}

/// ViewModels de Diario, Hábitos, Recordatorios y Notas sin Supabase, con un
/// registro de cada tipo (contacto `c1`, entrada `e1`, hábito `h1`,
/// recordatorio `r1` y una nota creada en memoria, [noteId]).
class _SuiteData {
  _SuiteData()
      : diario = DiarioState(
          service: _FakeDiarioService(
            contacts: [DiarioContact(id: 'c1', name: 'Ana Prueba')],
            entries: [
              DiarioEntry(
                id: 'e1',
                contactId: 'c1',
                categoryId: 'cat_gustos',
                title: 'Cena de prueba',
                contentText: 'Le gusta la pasta',
              ),
            ],
          ),
        ),
        habitos = HabitosState(
            service: _FakeHabitosService([HabitModel(id: 'h1', title: 'Leer')])),
        reminders = RemindersState(
            service: _FakeRemindersService(
                [ReminderModel(id: 'r1', title: 'Llamar al banco')])),
        notas = NotasState();

  final DiarioState diario;
  final HabitosState habitos;
  final RemindersState reminders;
  final NotasState notas;
  late final String noteId;

  Future<void> prepare() async {
    noteId = (await notas.createNote(
            title: 'Nota de prueba', contentText: 'Texto de prueba'))
        .id;
  }

  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider<DiarioState>.value(value: diario),
        ChangeNotifierProvider<HabitosState>.value(value: habitos),
        ChangeNotifierProvider<RemindersState>.value(value: reminders),
        ChangeNotifierProvider<NotasState>.value(value: notas),
      ];

  void dispose() {
    diario.dispose();
    habitos.dispose();
    reminders.dispose();
    notas.dispose();
  }
}

void main() {
  group('SuiteRoutes y SuiteBranch', () {
    test('cada rama de app usa el path de su SuiteApp y el inicio es /', () {
      expect(SuiteBranch.inicio.path, '/');
      for (final app in SuiteApp.values) {
        expect(SuiteBranch.forApp(app).path, app.route);
        expect(SuiteRoutes.app(app), app.route);
      }
      // Una rama por app más el inicio, en el orden del shell.
      expect(SuiteBranch.values.first, SuiteBranch.inicio);
      expect(SuiteBranch.values.length, SuiteApp.values.length + 1);
    });

    test('los paths de detalle cuelgan de su app y codifican el id', () {
      expect(SuiteRoutes.movimiento('a b/1'), '/finanzas/movimientos/a%20b%2F1');
      expect(SuiteRoutes.pagos, '/finanzas/pagos');
      expect(SuiteRoutes.entrada('e1'), '/diario/entradas/e1');
      expect(SuiteRoutes.animo, '/diario/animo');
      expect(SuiteRoutes.habito('h1'), '/habitos/h1');
      expect(SuiteRoutes.recordatorio('r1'), '/recordatorios/r1');
      expect(SuiteRoutes.nota('n1'), '/notas/n1');
    });

    test('la pantalla raíz de cada rama es la de su app', () {
      expect(suiteBranchScreen(SuiteBranch.inicio), isA<SuiteOrtizHome>());
      expect(suiteBranchScreen(SuiteBranch.finanzas), isA<MainScreen>());
      expect(suiteBranchScreen(SuiteBranch.diario), isA<DiarioHomeScreen>());
      expect(suiteBranchScreen(SuiteBranch.habitos), isA<HabitosHomeScreen>());
      expect(
        suiteBranchScreen(SuiteBranch.recordatorios),
        isA<RemindersHomeScreen>(),
      );
      expect(suiteBranchScreen(SuiteBranch.notas), isA<NotasHomeScreen>());
    });
  });

  group('buildSuiteRouter', () {
    for (final branch in SuiteBranch.values) {
      testWidgets('abrir ${branch.path} muestra la pantalla de ${branch.name}',
          (tester) async {
        final router =
            await pumpSuiteRouter(tester, initialLocation: branch.path);

        expect(currentPath(router), branch.path);
        expect(find.text(SuiteStubScreen.labelOf(branch)), findsOneWidget);
        for (final other in SuiteBranch.values.where((b) => b != branch)) {
          expect(find.text(SuiteStubScreen.labelOf(other)), findsNothing);
        }
      });
    }

    testWidgets('sin URL abre el inicio', (tester) async {
      final router = await pumpSuiteRouter(tester);

      expect(currentPath(router), '/');
      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
        findsOneWidget,
      );
    });

    testWidgets('go a una app desde otra cambia la URL y la pantalla',
        (tester) async {
      final router = await pumpSuiteRouter(tester);

      router.go(SuiteApp.diario.route);
      await tester.pumpAndSettle();

      expect(currentPath(router), '/diario');
      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.diario)),
        findsOneWidget,
      );
      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
        findsNothing,
      );
    });

    testWidgets('una URL desconocida al arrancar lleva a / con el aviso',
        (tester) async {
      final router = await pumpSuiteRouter(tester, initialLocation: '/xyz');
      await tester.pump();

      expect(currentPath(router), '/');
      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
        findsOneWidget,
      );
      expect(find.text(suitePaginaNoExiste), findsOneWidget);
      await letNoticeExpire(tester);
    });

    testWidgets('ir a una URL desconocida desde una app lleva a / con el aviso',
        (tester) async {
      final router =
          await pumpSuiteRouter(tester, initialLocation: SuiteApp.notas.route);

      router.go('/xyz');
      await tester.pumpAndSettle();

      expect(currentPath(router), '/');
      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
        findsOneWidget,
      );
      expect(find.text(suitePaginaNoExiste), findsOneWidget);
      await letNoticeExpire(tester);
    });

    testWidgets('una URL válida no muestra el aviso', (tester) async {
      await pumpSuiteRouter(tester, initialLocation: SuiteApp.habitos.route);
      await tester.pump();

      expect(find.text(suitePaginaNoExiste), findsNothing);
    });

    testWidgets('cada rama conserva su estado al cambiar de app y volver',
        (tester) async {
      final router =
          await pumpSuiteRouter(tester, initialLocation: SuiteApp.diario.route);

      await tester.tap(find.text('sumar diario'));
      await tester.tap(find.text('sumar diario'));
      await tester.pump();
      expect(find.text('contador diario 2'), findsOneWidget);

      router.go(SuiteApp.habitos.route);
      await tester.pumpAndSettle();
      expect(find.text('contador diario 2'), findsNothing);

      router.go(SuiteApp.diario.route);
      await tester.pumpAndSettle();
      expect(find.text('contador diario 2'), findsOneWidget);
    });

    testWidgets('las rutas distinguen mayúsculas: /Diario no existe',
        (tester) async {
      final router = await pumpSuiteRouter(tester, initialLocation: '/Diario');
      await tester.pump();

      expect(currentPath(router), '/');
      expect(find.text(suitePaginaNoExiste), findsOneWidget);
      await letNoticeExpire(tester);
    });

    testWidgets('las ramas se construyen la primera vez que se visitan',
        (tester) async {
      await pumpSuiteRouter(tester);

      expect(
        find.text(SuiteStubScreen.labelOf(SuiteBranch.finanzas),
            skipOffstage: false),
        findsNothing,
      );
    });
  });

  testWidgets('el aviso usa el ScaffoldMessenger global', (tester) async {
    await pumpSuiteRouter(tester, initialLocation: '/no/existe');
    await tester.pump();

    expect(suiteMessengerKey.currentState, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(suiteMessengerKey),
        matching: find.text(suitePaginaNoExiste),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    await letNoticeExpire(tester);
  });

  group('rutas de detalle (CA-05, P-01/P-03)', () {
    test('contacto y desbloquear tienen su path', () {
      expect(SuiteRoutes.contacto('c 1'), '/diario/contactos/c%201');
      expect(SuiteRoutes.desbloquear('/finanzas/movimientos/m1'),
          '/desbloquear?siguiente=%2Ffinanzas%2Fmovimientos%2Fm1');
    });

    testWidgets('«Ver» de un movimiento abre su detalle sobre el Historial',
        (tester) async {
      final app = _FakeAppState(active: [_mov('m1')]);
      final router = await _pumpWithApp(tester, app);

      router.go(SuiteRoutes.movimiento('m1'));
      await tester.pumpAndSettle();

      expect(currentPath(router), '/finanzas/movimientos/m1');
      expect(find.byType(TransactionDetailBottomSheet), findsOneWidget);
      expect(app.currentTabIndex, 2);

      // Cerrar el detalle deja la URL en Finanzas.
      router.pop();
      await tester.pumpAndSettle();
      expect(currentPath(router), '/finanzas');
      expect(find.byType(TransactionDetailBottomSheet), findsNothing);
    });

    testWidgets('un movimiento de otro libro avisa en cuál y no cambia de libro',
        (tester) async {
      final app = _FakeAppState(otherBooks: {
        'negocio.db': [_mov('m2')],
      });
      final router = await _pumpWithApp(tester, app);

      router.go(SuiteRoutes.movimiento('m2'));
      await tester.pumpAndSettle();

      expect(currentPath(router), '/finanzas');
      expect(find.text('Ese movimiento está en el libro Negocio'), findsOneWidget);
      expect(find.byType(TransactionDetailBottomSheet), findsNothing);
      expect(app.activeDbName, 'quebrado.db');
      await letNoticeExpire(tester);
    });

    testWidgets('un movimiento que no existe avisa y abre la raíz de Finanzas',
        (tester) async {
      final router = await _pumpWithApp(tester, _FakeAppState());

      router.go(SuiteRoutes.movimiento('nada'));
      await tester.pumpAndSettle();

      expect(currentPath(router), '/finanzas');
      expect(find.text(SuiteRecordMissing.notice), findsOneWidget);
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.finanzas)),
          findsOneWidget);
      await letNoticeExpire(tester);
    });
  });

  group('rutas de detalle de Diario, Hábitos, Recordatorios y Notas (P-02/P-03)',
      () {
    final cases = <({
      String name,
      String Function(_SuiteData data) path,
      String missing,
      SuiteApp app,
      Finder Function(_SuiteData data) view,
    })>[
      (
        name: 'una entrada del Diario',
        path: (_) => SuiteRoutes.entrada('e1'),
        missing: SuiteRoutes.entrada('nada'),
        app: SuiteApp.diario,
        view: (_) => find.byType(EntryReaderDialog),
      ),
      (
        name: 'un contacto del Diario',
        path: (_) => SuiteRoutes.contacto('c1'),
        missing: SuiteRoutes.contacto('nada'),
        app: SuiteApp.diario,
        view: (_) => find.byType(ContactDetailScreen),
      ),
      (
        name: 'un hábito',
        path: (_) => SuiteRoutes.habito('h1'),
        missing: SuiteRoutes.habito('nada'),
        app: SuiteApp.habitos,
        view: (_) => find.byType(HabitDetailCliDialog),
      ),
      (
        name: 'un recordatorio (resaltado en la lista)',
        path: (_) => SuiteRoutes.recordatorio('r1'),
        missing: SuiteRoutes.recordatorio('nada'),
        app: SuiteApp.recordatorios,
        view: (_) => find.text('recordatorio resaltado r1'),
      ),
      (
        name: 'una nota',
        path: (data) => SuiteRoutes.nota(data.noteId),
        missing: SuiteRoutes.nota('nada'),
        app: SuiteApp.notas,
        view: (_) => find.byType(NoteReaderDialog),
      ),
    ];

    Future<(GoRouter, _SuiteData)> pumpWithData(WidgetTester tester) async {
      final data = _SuiteData();
      addTearDown(data.dispose);
      await data.prepare();
      final router = await pumpSuiteRouter(
        tester,
        window: WindowClass.expanded,
        providers: data.providers,
      );
      return (router, data);
    }

    for (final c in cases) {
      testWidgets('${c.name} que existe abre su detalle', (tester) async {
        final (router, data) = await pumpWithData(tester);
        final path = c.path(data);

        router.go(path);
        await tester.pumpAndSettle();

        expect(currentPath(router), path);
        expect(c.view(data), findsOneWidget);
        expect(find.text(SuiteRecordMissing.notice), findsNothing);
      });

      testWidgets('${c.name} que no existe avisa y abre la raíz de su app',
          (tester) async {
        final (router, data) = await pumpWithData(tester);

        router.go(c.missing);
        await tester.pumpAndSettle();

        expect(currentPath(router), c.app.route);
        expect(find.text(SuiteRecordMissing.notice), findsOneWidget);
        expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.forApp(c.app))),
            findsOneWidget);
        expect(c.view(data), findsNothing);
        await letNoticeExpire(tester);
      });
    }
  });

  testWidgets('CA-06: /diario abre el Diario y Atrás del navegador vuelve',
      (tester) async {
    final updates = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        updates.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null));
    final router = await pumpSuiteRouter(tester);

    router.go(SuiteApp.diario.route);
    await tester.pumpAndSettle();
    expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.diario)),
        findsOneWidget);
    // `go` crea una entrada nueva en el historial (no la reemplaza).
    final diarioEntry = updates.lastWhere(
        (c) => c.method == 'routeInformationUpdated');
    expect((diarioEntry.arguments as Map)['uri'].toString(), '/diario');
    expect((diarioEntry.arguments as Map)['replace'], isFalse);

    // Atrás del navegador: el motor devuelve la URL anterior.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('pushRouteInformation', {'location': '/', 'state': null}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(currentPath(router), '/');
    expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
        findsOneWidget);
  });

  group('PIN una vez al día al entrar a la app (CA-07, P-04 revisada)', () {
    // Candado en memoria con la seguridad ya leída (como lo deja `main.dart`).
    SuiteLock lockFor({required bool pin}) {
      final lock = SuiteLock(store: MemorySuiteLockStore())
        ..updateSecurity(enabled: pin, confirmed: true);
      addTearDown(lock.dispose);
      return lock;
    }

    test('siguiente solo acepta rutas internas', () {
      expect(SuiteRoutes.safeNext('/finanzas/movimientos/m1'),
          '/finanzas/movimientos/m1');
      expect(SuiteRoutes.safeNext('/diario'), '/diario');
      expect(SuiteRoutes.safeNext('https://evil.example/x'), '/');
      expect(SuiteRoutes.safeNext('//evil.example/x'), '/');
      expect(SuiteRoutes.safeNext('/desbloquear?siguiente=/x'), '/');
      expect(SuiteRoutes.safeNext('diario'), '/');
      expect(SuiteRoutes.safeNext(null), '/');
    });

    testWidgets('con PIN activo, al arrancar pide el PIN antes del inicio',
        (tester) async {
      final lock = lockFor(pin: true);
      final app = _FakeAppState(pin: true);
      final router = await _pumpWithApp(tester, app, lock: lock);

      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.byType(SuiteUnlockView), findsOneWidget);
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
          findsNothing);
      expect(app.authCalls, 1);

      app.auth.complete(true);
      await tester.pumpAndSettle();

      expect(lock.isUnlocked, isTrue);
      expect(currentPath(router), '/');
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
          findsOneWidget);
    });

    testWidgets('un enlace directo pide el PIN y luego abre el movimiento',
        (tester) async {
      final lock = lockFor(pin: true);
      final app = _FakeAppState(pin: true, active: [_mov('m1')]);
      final router = await _pumpWithApp(tester, app, lock: lock);

      router.go(SuiteRoutes.movimiento('m1'));
      await tester.pumpAndSettle();
      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.byType(TransactionDetailBottomSheet), findsNothing);

      app.auth.complete(true);
      await tester.pumpAndSettle();

      expect(currentPath(router), '/finanzas/movimientos/m1');
      expect(find.byType(TransactionDetailBottomSheet), findsOneWidget);
    });

    testWidgets('tras desbloquear, todas las apps abren sin volver a pedirlo',
        (tester) async {
      final lock = lockFor(pin: true)..unlock();
      final app = _FakeAppState(pin: true);
      final router = await _pumpWithApp(tester, app, lock: lock);

      for (final branch in SuiteBranch.values) {
        router.go(branch.path);
        await tester.pumpAndSettle();
        expect(currentPath(router), branch.path);
      }
      expect(app.authCalls, 0);
    });

    testWidgets('cancelar el PIN deja la app bloqueada', (tester) async {
      final lock = lockFor(pin: true);
      final app = _FakeAppState(pin: true);
      final router = await _pumpWithApp(tester, app, lock: lock);

      app.auth.complete(false);
      await tester.pumpAndSettle();

      expect(lock.isUnlocked, isFalse);
      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.text('Ortiz está bloqueado'), findsOneWidget);

      // Ni el menú ni una URL saltan el candado.
      router.go(SuiteApp.diario.route);
      await tester.pumpAndSettle();
      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.diario)),
          findsNothing);
    });

    testWidgets('con la app bloqueada, goBranch (menú ☰ y riel) no salta el candado',
        (tester) async {
      final lock = lockFor(pin: false);
      final router = await _pumpWithApp(tester, _FakeAppState(), lock: lock);
      final scope = SuiteShellScope.maybeOf(tester
          .element(find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio))))!;

      // Se activa la seguridad sin desbloquear (p. ej. otro dispositivo).
      lock.updateSecurity(enabled: true, confirmed: true);
      await tester.pumpAndSettle();
      expect(currentPath(router), SuiteRoutes.desbloquearPath);

      scope.goBranch(SuiteBranch.finanzas);
      await tester.pumpAndSettle();

      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.finanzas)),
          findsNothing);
    });

    testWidgets('un siguiente externo se ignora: tras el PIN abre el inicio',
        (tester) async {
      final lock = lockFor(pin: true);
      final app = _FakeAppState(pin: true);
      final router = await _pumpWithApp(tester, app, lock: lock);

      router.go('/desbloquear?siguiente=https://evil.example/x');
      await tester.pumpAndSettle();
      app.auth.complete(true);
      await tester.pumpAndSettle();

      expect(currentPath(router), '/');
    });

    testWidgets('/desbloquear sin seguridad lleva al destino', (tester) async {
      final router =
          await _pumpWithApp(tester, _FakeAppState(), lock: lockFor(pin: false));

      router.go(SuiteRoutes.desbloquear('/diario'));
      await tester.pumpAndSettle();

      expect(currentPath(router), '/diario');
    });

    testWidgets('sin PIN ni biometría todo abre directo', (tester) async {
      final app = _FakeAppState();
      final router =
          await _pumpWithApp(tester, app, lock: lockFor(pin: false));

      router.go(SuiteApp.finanzas.route);
      await tester.pumpAndSettle();

      expect(currentPath(router), '/finanzas');
      expect(find.byType(SuiteUnlockView), findsNothing);
      expect(app.authCalls, 0);
    });

    testWidgets('primera vez en el navegador: espera a los ajustes antes de abrir (A1)',
        (tester) async {
      final lock = SuiteLock(store: MemorySuiteLockStore());
      addTearDown(lock.dispose);
      final app = _FakeAppState(pin: true)
        ..onLoadData = () => lock.updateSecurity(enabled: true, confirmed: true);
      final router = await _pumpWithApp(tester, app, lock: lock);

      expect(currentPath(router), SuiteRoutes.desbloquearPath);
      expect(find.text(SuiteStubScreen.labelOf(SuiteBranch.inicio)),
          findsNothing);
    });
  });

  group('SuiteOrtizHome (inicio de Ortiz)', () {
    late AgenteState agente;

    setUp(() => agente = AgenteState(autoInit: false));
    tearDown(() => agente.dispose());

    Future<void> pumpHome(WidgetTester tester, WindowClass window) async {
      await pumpSuiteRouter(
        tester,
        window: window,
        providers: [ChangeNotifierProvider<AgenteState>.value(value: agente)],
        // Sin animaciones: el flote de la cara del saludo no termina nunca.
        screenFor: (branch) => branch == SuiteBranch.inicio
            ? Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: const SuiteOrtizHome(),
                ),
              )
            : null,
      );
    }

    for (final window in [WindowClass.compact, WindowClass.expanded]) {
      testWidgets('en ${window.name} muestra los chips del catálogo',
          (tester) async {
        await pumpHome(tester, window);
        expect(find.byType(OrtizHomeScreen), findsOneWidget);
        for (final action in suiteChipActions) {
          expect(find.widgetWithText(ActionChip, action.label), findsOneWidget);
        }
      });

      testWidgets('en ${window.name} el campo usa el foco del shell',
          (tester) async {
        await pumpHome(tester, window);
        final scope =
            SuiteShellScope.maybeOf(tester.element(find.byType(OrtizHomeScreen)))!;
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode, same(scope.chatFocusNode));
      });
    }

    testWidgets('en compact el ☰ de la barra abre el menú del shell',
        (tester) async {
      await pumpHome(tester, WindowClass.compact);
      expect(find.byType(SuiteDrawer), findsNothing);
      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      expect(find.byType(SuiteDrawer), findsOneWidget);
    });

    testWidgets('la cara de la barra refleja el ánimo de Ortiz',
        (tester) async {
      await pumpHome(tester, WindowClass.compact);
      OrtizFace barFace() => tester.widget<OrtizFace>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(OrtizFace)));
      expect(barFace().mood, OrtizMood.idle);

      agente.celebrate();
      await tester.pump();
      expect(barFace().mood, OrtizMood.happy);

      await tester.pump(AgenteState.celebrateDuration);
      await tester.pumpAndSettle();
      expect(barFace().mood, OrtizMood.idle);
    });
  });
}
