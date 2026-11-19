// Ajuste «Cuentas predeterminadas por moneda» de Ajustes (spec 03, U1).
//
// Usa un `AppState` falso (sin SQLite ni Supabase) con cuentas inventadas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/screens/settings_screen.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/default_account_settings.dart';

import '../../helpers/pump_app.dart';

Account _account(String id, String name, CurrencyType currency) => Account(
      id: id,
      name: name,
      currency: currency,
      balance: 0,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );

/// `AppState` mínimo para la pantalla de Ajustes. Guarda la predeterminada en
/// memoria y registra cada llamada a [setDefaultAccount].
class _FakeAppState extends ChangeNotifier implements AppState {
  _FakeAppState({List<Account>? accounts, this.isDataLoaded = true})
      : accounts = accounts ?? [];

  @override
  List<Account> accounts;
  @override
  bool isDataLoaded;
  @override
  String activeProfileName = 'Personal';
  @override
  bool isFetchingHistory = false;
  @override
  String? rateFetchError;
  @override
  bool get useBiometrics => false;
  @override
  bool get usePinSecurity => false;

  final Map<CurrencyType, String> defaults = {};
  final List<(CurrencyType, String?)> calls = [];
  bool failNextSave = false;

  @override
  Account? defaultAccountFor(CurrencyType currency) {
    final id = defaults[currency];
    final account = accounts.where((a) => a.id == id).firstOrNull;
    return account?.currency == currency ? account : null;
  }

  @override
  String? defaultAccountIdFor(CurrencyType currency) => defaultAccountFor(currency)?.id;

  @override
  Future<bool> setDefaultAccount(CurrencyType currency, String? accountId) async {
    calls.add((currency, accountId));
    // Como el real: guarda primero y solo cambia la memoria si se guardó.
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    if (accountId == null) {
      defaults.remove(currency);
    } else {
      defaults[currency] = accountId;
    }
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_FakeAppState _stateWithAccounts() => _FakeAppState(accounts: [
      _account('acc_usd_1', 'Efectivo dólares', CurrencyType.usd),
      _account('acc_bs_1', 'Banco Prueba Bs', CurrencyType.bsBCV),
      _account('acc_bs_2', 'Billetera Prueba Bs', CurrencyType.bsBCV),
    ]);

Future<void> _pumpSettings(WidgetTester tester, _FakeAppState app, WindowClass window) {
  return pumpApp(
    tester,
    const SettingsScreen(),
    providers: [ChangeNotifierProvider<AppState>.value(value: app)],
    window: window,
    wrapInScaffold: false,
  );
}

Finder _row(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'OrtizListRow'),
    );

Finder _inRow(String title, String text) =>
    find.descendant(of: _row(title), matching: find.text(text));

/// Deja que el aviso se cierre solo para no dejar timers pendientes.
Future<void> _dismissNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('Cuentas predeterminadas por moneda', () {
    for (final window in [WindowClass.compact, WindowClass.expanded]) {
      testWidgets('muestra una fila por moneda con «Sin predeterminada» (${window.name})',
          (tester) async {
        await _pumpSettings(tester, _stateWithAccounts(), window);

        expect(find.text('CUENTAS PREDETERMINADAS POR MONEDA'), findsOneWidget);
        expect(_inRow('Dólares', 'Sin predeterminada'), findsOneWidget);
        expect(_inRow('Bolívares', 'Sin predeterminada'), findsOneWidget);
        expect(_inRow('Euros', 'Aún no tienes cuentas en euros'), findsOneWidget);
        expect(
          find.textContaining('Valen solo para el libro «Personal».'),
          findsOneWidget,
        );
      });

      testWidgets('elegir una cuenta la guarda y la fila la muestra (${window.name})',
          (tester) async {
        final app = _stateWithAccounts();
        await _pumpSettings(tester, app, window);

        await tester.tap(find.text('Bolívares'));
        await tester.pumpAndSettle();

        expect(find.text('Cuenta predeterminada en Bolívares'), findsOneWidget);
        expect(find.byType(DefaultAccountSheet), findsOneWidget);
        expect(
          find.descendant(of: find.byType(DefaultAccountSheet), matching: find.text('Ninguna')),
          findsOneWidget,
        );
        expect(find.text('Billetera Prueba Bs'), findsOneWidget);
        expect(find.text('Efectivo dólares'), findsNothing, reason: 'solo cuentas de esa moneda');

        await tester.tap(find.text('Banco Prueba Bs'));
        await tester.pumpAndSettle();

        expect(app.calls, [(CurrencyType.bsBCV, 'acc_bs_1')]);
        expect(find.byType(DefaultAccountSheet), findsNothing);
        expect(_inRow('Bolívares', 'Banco Prueba Bs'), findsOneWidget);
        expect(
          find.text('Banco Prueba Bs es tu cuenta predeterminada en bolívares'),
          findsOneWidget,
        );
        await _dismissNotice(tester);
      });
    }

    testWidgets('«Ninguna» quita la predeterminada', (tester) async {
      final app = _stateWithAccounts()..defaults[CurrencyType.bsBCV] = 'acc_bs_2';
      await _pumpSettings(tester, app, WindowClass.compact);
      expect(_inRow('Bolívares', 'Billetera Prueba Bs'), findsOneWidget);

      await tester.tap(find.text('Bolívares'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ninguna'));
      await tester.pumpAndSettle();

      expect(app.calls, [(CurrencyType.bsBCV, null)]);
      expect(_inRow('Bolívares', 'Sin predeterminada'), findsOneWidget);
      expect(find.text('Sin cuenta predeterminada en bolívares'), findsOneWidget);
      await _dismissNotice(tester);
    });

    testWidgets('sin cuentas de esa moneda no abre el selector', (tester) async {
      final app = _stateWithAccounts();
      await _pumpSettings(tester, app, WindowClass.compact);

      await tester.tap(find.text('Euros'));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultAccountSheet), findsNothing);
      expect(app.calls, isEmpty);
    });

    testWidgets('sin ninguna cuenta en el libro, las tres filas quedan vacías', (tester) async {
      await _pumpSettings(tester, _FakeAppState(), WindowClass.compact);

      expect(find.text('Aún no tienes cuentas en dólares'), findsOneWidget);
      expect(find.text('Aún no tienes cuentas en bolívares'), findsOneWidget);
      expect(find.text('Aún no tienes cuentas en euros'), findsOneWidget);
    });

    testWidgets('mientras cargan las cuentas dice «Cargando…» y no abre nada', (tester) async {
      final app = _FakeAppState(accounts: [], isDataLoaded: false);
      await _pumpSettings(tester, app, WindowClass.compact);

      expect(find.text('Cargando…'), findsNWidgets(3));
      await tester.tap(find.text('Dólares'));
      await tester.pumpAndSettle();
      expect(find.byType(DefaultAccountSheet), findsNothing);
    });

    testWidgets('si falla el guardado, la fila vuelve al valor anterior y avisa', (tester) async {
      final app = _stateWithAccounts()
        ..defaults[CurrencyType.bsBCV] = 'acc_bs_2'
        ..failNextSave = true;
      await _pumpSettings(tester, app, WindowClass.compact);

      await tester.tap(find.text('Bolívares'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco Prueba Bs'));
      await tester.pumpAndSettle();

      expect(app.calls, [(CurrencyType.bsBCV, 'acc_bs_1')], reason: 'sin compensación: una sola llamada');
      expect(_inRow('Bolívares', 'Billetera Prueba Bs'), findsOneWidget);
      expect(find.text('No pude guardar el cambio. Inténtalo de nuevo.'), findsOneWidget);
      await _dismissNotice(tester);
    });

    testWidgets('cerrar el selector sin elegir no cambia nada', (tester) async {
      final app = _stateWithAccounts();
      await _pumpSettings(tester, app, WindowClass.compact);

      await tester.tap(find.text('Bolívares'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultAccountSheet), findsNothing);
      expect(app.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('al cambiar de libro muestra las cuentas del libro nuevo', (tester) async {
      final app = _stateWithAccounts()..defaults[CurrencyType.usd] = 'acc_usd_1';
      await _pumpSettings(tester, app, WindowClass.compact);
      expect(_inRow('Dólares', 'Efectivo dólares'), findsOneWidget);

      app
        ..activeProfileName = 'Negocio'
        ..accounts = [_account('acc_eur_1', 'Cuenta Prueba €', CurrencyType.eur)]
        ..defaults.clear()
        ..notifyListeners();
      await tester.pumpAndSettle();

      expect(_inRow('Dólares', 'Aún no tienes cuentas en dólares'), findsOneWidget);
      expect(_inRow('Euros', 'Sin predeterminada'), findsOneWidget);
      expect(find.textContaining('libro «Negocio»'), findsOneWidget);
    });
  });
}
