import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment_partial.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';

// Spec 05 (CA-07): se elimina la confirmación deslizante. Las operaciones de
// dinero se confirman siempre con el botón normal, sin ningún ajuste previo.
/// AppState cuyo guardado de la cuenta predeterminada falla.
class _DefaultSaveFails extends AppState {
  @override
  Future<void> saveDefaultAccountSetting(String key, String value) async =>
      throw Exception('sin conexión');
}

void main() {
  setUp(() => AppState.debugLocalDbIsSourceOfTruth = false);
  tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

  test('AppState ya no expone el ajuste de confirmación deslizante', () {
    final dynamic app = AppState();

    expect(() => app.useSlideToConfirm, throwsNoSuchMethodError);
    expect(() => app.setUseSlideToConfirm(true), throwsNoSuchMethodError);
  });

  group('ajustes leídos de Supabase (rutas.md §10, P-04)', () {
    test('carga usePinSecurity igual que useBiometrics', () async {
      final app = AppState();
      await app.loadData();

      app.applyRemoteSettings({'usePinSecurity': 'true', 'useBiometrics': 'false'});
      expect(app.usePinSecurity, isTrue);
      expect(app.useBiometrics, isFalse);

      app.applyRemoteSettings({'usePinSecurity': 'false', 'useBiometrics': 'true'});
      expect(app.usePinSecurity, isFalse);
      expect(app.useBiometrics, isTrue);
    });

    test('securitySettingsConfirmed solo si los ajustes traen la seguridad (A1)', () {
      final app = AppState();
      expect(app.securitySettingsConfirmed, isFalse);

      app.applyRemoteSettings({});
      expect(app.securitySettingsConfirmed, isFalse, reason: 'loadSettings devuelve {} si falla');

      app.applyRemoteSettings({'usePinSecurity': 'false'});
      expect(app.securitySettingsConfirmed, isTrue);
    });

    test('una clave ausente conserva el valor que había', () async {
      final app = AppState();
      await app.loadData();
      app.applyRemoteSettings({'usePinSecurity': 'true'});

      app.applyRemoteSettings({'bcvRate': '50.5'});

      expect(app.usePinSecurity, isTrue);
      expect(app.bcvRate, 50.5);
    });
  });

  group('verifySecurityAuth (spec 02, P-04 revisada: PIN una vez al día)', () {
    // Sin `loadData` ni E/S: los ajustes se fijan con `applyRemoteSettings` y
    // el PIN con `debugSecurityPinLoader` (con E/S real el test se colgaba).
    Future<bool?> pedirPin(WidgetTester tester, AppState app, {required String teclear}) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => resultado = await app.verifySecurityAuth(context),
            child: const Text('confirmar'),
          ),
        ),
      ));
      await tester.tap(find.text('confirmar'));
      await tester.pumpAndSettle();
      for (final d in teclear.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('PIN correcto: devuelve true y avisa', (tester) async {
      final app = AppState()..debugSecurityPinLoader = () async => '2580';
      app.applyRemoteSettings({'usePinSecurity': 'true', 'useBiometrics': 'false'});
      var avisos = 0;
      app.onSecurityVerified = () => avisos++;

      expect(await pedirPin(tester, app, teclear: '2580'), isTrue);
      expect(avisos, 1);
    });

    testWidgets('el diálogo usa el título que se le pasa (A8)', (tester) async {
      final app = AppState()..debugSecurityPinLoader = () async => '2580';
      app.applyRemoteSettings({'usePinSecurity': 'true', 'useBiometrics': 'false'});

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => app.verifySecurityAuth(context, title: 'Desbloquear'),
            child: const Text('confirmar'),
          ),
        ),
      ));
      await tester.tap(find.text('confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Desbloquear'), findsOneWidget);
      expect(find.text('Confirmar Transacción'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });

    testWidgets('con la suite ya desbloqueada hoy no vuelve a pedir el PIN', (tester) async {
      final app = AppState()..debugSecurityPinLoader = () async => '2580';
      app.applyRemoteSettings({'usePinSecurity': 'true', 'useBiometrics': 'false'});
      app.isSessionUnlocked = () => true;

      late Future<bool> resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => resultado = app.verifySecurityAuth(context),
            child: const Text('confirmar'),
          ),
        ),
      ));
      await tester.tap(find.text('confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(await resultado, isTrue);
    });

    testWidgets('sin PIN ni biometría activados no avisa (no hubo verificación)', (tester) async {
      final app = AppState();
      app.applyRemoteSettings({'usePinSecurity': 'false', 'useBiometrics': 'false'});
      var avisos = 0;
      app.onSecurityVerified = () => avisos++;

      late Future<bool> resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => resultado = app.verifySecurityAuth(context),
            child: const Text('confirmar'),
          ),
        ),
      ));
      await tester.tap(find.text('confirmar'));
      await tester.pumpAndSettle();

      expect(await resultado, isTrue);
      expect(avisos, 0);
    });
  });

  test('activar el PIN o la biometría desde dentro cuenta como verificado hoy; desactivar no', () async {
    final app = AppState();
    var avisos = 0;
    app.onSecurityVerified = () => avisos++;
    // La SQLite de tests es compartida (P-14): se deja todo en false al final.
    addTearDown(() async {
      app.onSecurityVerified = null;
      await app.setUsePinSecurity(false);
      await app.setUseBiometrics(false);
    });

    await app.setUsePinSecurity(true);
    expect(avisos, 1);
    expect(app.securitySettingsConfirmed, isTrue);
    await app.setUsePinSecurity(false);
    expect(avisos, 1);

    await app.setUseBiometrics(true);
    expect(avisos, 2);
    await app.setUseBiometrics(false);
    expect(avisos, 2);
  });

  test('transactionsByBook es de solo lectura', () async {
    final app = AppState();
    await app.loadData();

    expect(() => app.transactionsByBook['libro_x.db'] = [], throwsUnsupportedError);
  });

  test('confirmar un pago recurrente registra el movimiento y lo marca confirmado sin el ajuste', () async {
    final app = AppState();
    await app.loadData();

    // Ids únicos: la SQLite de pruebas es compartida y persistente.
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final accountId = 'acc_ca07_$suffix';
    final paymentId = 'pago_ca07_$suffix';
    final today = DateTime.now();

    final account = Account(id: accountId, name: 'Efectivo', currency: CurrencyType.usd, balance: 100, colorHex: '#2FA084', icon: 'creditcard');
    app.accounts = [account];
    final payment = RecurringPayment(
      id: paymentId,
      name: 'Internet',
      amount: 25,
      currency: CurrencyType.usd,
      frequency: SubscriptionFrequency.monthly,
      startDate: DateTime(today.year, today.month, today.day),
      notificationOption: NotificationOption.none,
      icon: 'wifi',
      colorHex: '#2FA084',
      type: TransactionType.expense,
      accountId: accountId,
      totalInstallments: 1,
    );
    // La confirmación local tiene claves foráneas a la cuenta y al pago.
    await DatabaseHelper.instance.insertAccount(account);
    await DatabaseHelper.instance.insertRecurringPayment(payment);
    addTearDown(() async {
      for (final t in app.transactions.where((t) => t.accountId == accountId).toList()) {
        await DatabaseHelper.instance.deleteTransaction(t.id);
      }
      await DatabaseHelper.instance.deleteRecurringPayment(paymentId);
      await DatabaseHelper.instance.deleteAccount(accountId);
    });

    final completed = await app.confirmRecurringPayment(payment: payment, actualAmount: 25);

    expect(completed, isTrue, reason: 'la única cuota queda confirmada');
    expect(app.getConfirmedCountForPayment(paymentId), 1);
    expect(app.accounts.single.balance, closeTo(75, 0.001));
    expect(
      app.transactions.where((t) => t.accountId == accountId && t.note == 'Confirmado: Internet'),
      hasLength(1),
    );
  });

  test('confirmar un pago recurrente entrega el movimiento registrado solo si el monto es mayor que cero', () async {
    final app = AppState();
    await app.loadData();

    // Ids únicos: la SQLite de pruebas es compartida y persistente.
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final accountId = 'acc_cb_$suffix';
    final today = DateTime.now();
    final account = Account(id: accountId, name: 'Banco', currency: CurrencyType.usd, balance: 100, colorHex: '#2FA084', icon: 'creditcard');
    app.accounts = [account];
    RecurringPayment pago(String id) => RecurringPayment(
          id: id,
          name: 'Gimnasio',
          amount: 30,
          currency: CurrencyType.usd,
          frequency: SubscriptionFrequency.monthly,
          startDate: DateTime(today.year, today.month, today.day),
          notificationOption: NotificationOption.none,
          icon: 'wifi',
          colorHex: '#2FA084',
          type: TransactionType.expense,
          accountId: accountId,
        );
    final conMonto = pago('pago_cb_a_$suffix');
    final sinMonto = pago('pago_cb_b_$suffix');
    await DatabaseHelper.instance.insertAccount(account);
    await DatabaseHelper.instance.insertRecurringPayment(conMonto);
    await DatabaseHelper.instance.insertRecurringPayment(sinMonto);
    addTearDown(() async {
      for (final t in app.transactions.where((t) => t.accountId == accountId).toList()) {
        await DatabaseHelper.instance.deleteTransaction(t.id);
      }
      await DatabaseHelper.instance.deleteRecurringPayment(conMonto.id);
      await DatabaseHelper.instance.deleteRecurringPayment(sinMonto.id);
      await DatabaseHelper.instance.deleteAccount(accountId);
    });

    final recorded = <Transaction>[];
    await app.confirmRecurringPayment(payment: conMonto, actualAmount: 30, onTransactionRecorded: recorded.add);
    expect(recorded, hasLength(1));
    expect(recorded.single.amount, 30);
    expect(recorded.single.accountId, accountId);
    expect(app.transactions.any((t) => t.id == recorded.single.id), isTrue);

    await app.confirmRecurringPayment(payment: sinMonto, actualAmount: 0, onTransactionRecorded: recorded.add);
    expect(recorded, hasLength(1), reason: 'con saldo existente (monto 0) no se registra movimiento');
  });

  group('cuenta predeterminada por moneda (spec 03, PA-01)', () {
    Account cuenta(String id, CurrencyType currency) =>
        Account(id: id, name: 'Cuenta $id', currency: currency, balance: 0, colorHex: '#2FA084', icon: 'creditcard');

    String clave(AppState app, CurrencyType c) => AppState.defaultAccountSettingKey(app.activeDbName, c);

    /// La SQLite de tests es compartida (P-14): se quitan las predeterminadas al final.
    void limpiarAlFinal(AppState app) {
      addTearDown(() async {
        for (final c in CurrencyType.values) {
          await DatabaseHelper.instance.setSetting(clave(app, c), '');
        }
      });
    }

    test('la clave lleva el libro y el nombre de la moneda', () {
      expect(AppState.defaultAccountSettingKey('quebrado.db', CurrencyType.bsBCV), 'default_account:quebrado.db:bsBCV');
    });

    test('fija, lee y quita la predeterminada de una moneda, y la guarda en SQLite', () async {
      final app = AppState();
      await app.loadData();
      limpiarAlFinal(app);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final usd = cuenta('acc_def_usd_$suffix', CurrencyType.usd);
      final ves = cuenta('acc_def_ves_$suffix', CurrencyType.bsBCV);
      app.accounts = [usd, ves];
      var avisos = 0;
      app.addListener(() => avisos++);

      expect(await app.setDefaultAccount(CurrencyType.bsBCV, ves.id), isTrue);

      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), ves.id);
      expect(app.defaultAccountFor(CurrencyType.bsBCV), same(ves));
      expect(app.defaultAccountIdFor(CurrencyType.usd), isNull, reason: 'cada moneda tiene la suya');
      expect(app.defaultAccountIdFor(CurrencyType.eur), isNull);
      expect(await DatabaseHelper.instance.getSetting(clave(app, CurrencyType.bsBCV)), ves.id);
      expect(avisos, 1);

      await app.setDefaultAccount(CurrencyType.bsBCV, null);

      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNull);
      expect(await DatabaseHelper.instance.getSetting(clave(app, CurrencyType.bsBCV)), '');
      expect(avisos, 2);
    });

    test('si falla el guardado devuelve false y no cambia la memoria ni avisa', () async {
      final app = _DefaultSaveFails();
      await app.loadData();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ves = cuenta('acc_def_falla_$suffix', CurrencyType.bsBCV);
      app.accounts = [ves];
      var avisos = 0;
      app.addListener(() => avisos++);

      final ok = await app.setDefaultAccount(CurrencyType.bsBCV, ves.id);

      expect(ok, isFalse);
      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNull);
      expect(avisos, 0);
    });

    test('rechaza una cuenta de otra moneda o que no está en el libro activo', () async {
      final app = AppState();
      await app.loadData();
      limpiarAlFinal(app);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final usd = cuenta('acc_def_rx_$suffix', CurrencyType.usd);
      app.accounts = [usd];

      await expectLater(app.setDefaultAccount(CurrencyType.bsBCV, usd.id), throwsArgumentError);
      await expectLater(app.setDefaultAccount(CurrencyType.usd, 'no_existe_$suffix'), throwsArgumentError);

      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNull);
      expect(app.defaultAccountIdFor(CurrencyType.usd), isNull);
    });

    test('devuelve null si la cuenta guardada ya no existe o cambió de moneda', () async {
      final app = AppState();
      await app.loadData();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final id = 'acc_def_cambio_$suffix';
      app.applyRemoteSettings({clave(app, CurrencyType.usd): id});

      app.accounts = [cuenta(id, CurrencyType.usd)];
      expect(app.defaultAccountIdFor(CurrencyType.usd), id);

      app.accounts = [cuenta(id, CurrencyType.eur)];
      expect(app.defaultAccountFor(CurrencyType.usd), isNull, reason: 'la cuenta ya no es en dólares');

      app.accounts = [];
      expect(app.defaultAccountIdFor(CurrencyType.usd), isNull, reason: 'la cuenta ya no existe');
    });

    test('lee de los ajustes de Supabase solo las claves del libro activo', () async {
      final app = AppState();
      await app.loadData();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ves = cuenta('acc_def_sp_$suffix', CurrencyType.bsBCV);
      final usd = cuenta('acc_def_sp_usd_$suffix', CurrencyType.usd);
      app.accounts = [ves, usd];

      app.applyRemoteSettings({
        clave(app, CurrencyType.bsBCV): ves.id,
        AppState.defaultAccountSettingKey('otro_libro.db', CurrencyType.usd): usd.id,
        'default_account:mal_formada': usd.id,
        'default_account:${app.activeDbName}:yen': usd.id,
      });

      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), ves.id);
      expect(app.defaultAccountIdFor(CurrencyType.usd), isNull, reason: 'esa clave es de otro libro');

      app.applyRemoteSettings({clave(app, CurrencyType.bsBCV): ''});
      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNull, reason: "'' significa ninguna");
    });

    test('borrar la cuenta predeterminada deja su moneda sin predeterminada', () async {
      final app = AppState();
      await app.loadData();
      limpiarAlFinal(app);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final usd = cuenta('acc_def_del_usd_$suffix', CurrencyType.usd);
      final ves = cuenta('acc_def_del_ves_$suffix', CurrencyType.bsBCV);
      await DatabaseHelper.instance.insertAccount(usd);
      await DatabaseHelper.instance.insertAccount(ves);
      addTearDown(() async {
        await DatabaseHelper.instance.deleteAccount(usd.id);
        await DatabaseHelper.instance.deleteAccount(ves.id);
      });
      app.accounts = await DatabaseHelper.instance.getAccounts();
      await app.setDefaultAccount(CurrencyType.usd, usd.id);
      await app.setDefaultAccount(CurrencyType.bsBCV, ves.id);

      await app.deleteAccount(ves.id);

      expect(app.accounts.any((a) => a.id == ves.id), isFalse);
      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNull);
      expect(await DatabaseHelper.instance.getSetting(clave(app, CurrencyType.bsBCV)), '');
      expect(app.defaultAccountIdFor(CurrencyType.usd), usd.id, reason: 'la de otra moneda no cambia');
      expect(await DatabaseHelper.instance.getSetting(clave(app, CurrencyType.usd)), usd.id);
    });

    test('cada libro tiene su predeterminada y se recarga de SQLite al cambiar de libro', () async {
      final app = AppState();
      await app.loadData();
      final original = app.activeDbName;
      limpiarAlFinal(app);

      await app.createProfile('Libro predeterminada test', '#1F6F5F');
      final libro = app.activeDbName;
      addTearDown(() async {
        if (app.activeDbName != original) await app.switchProfile(original);
        await app.deleteProfile(libro);
      });
      await app.addAccount(name: 'Banco test', currency: CurrencyType.bsBCV, initialBalance: 0, colorHex: '#2FA084', icon: 'creditcard');
      final ves = app.accounts.lastWhere((a) => a.name == 'Banco test');
      await app.setDefaultAccount(CurrencyType.bsBCV, ves.id);

      await app.switchProfile(original);
      expect(app.defaultAccountIdFor(CurrencyType.bsBCV), isNot(ves.id), reason: 'el otro libro no la comparte');

      // Instancia nueva: no tiene nada en memoria, debe leerlo de la SQLite del libro.
      final otra = AppState();
      await otra.loadData();
      expect(otra.activeDbName, original);
      await otra.switchProfile(libro);
      expect(otra.defaultAccountIdFor(CurrencyType.bsBCV), ves.id);
      await otra.switchProfile(original);
    });
  });

  group('deshacer pagos recurrentes (spec 03, payRecurringPayment)', () {
    Future<({AppState app, Account account, RecurringPayment payment})> preparar(String tag) async {
      final app = AppState();
      await app.loadData();
      // Ids únicos: la SQLite de pruebas es compartida y persistente.
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final today = DateTime.now();
      final account = Account(id: 'acc_${tag}_$suffix', name: 'Banco', currency: CurrencyType.usd, balance: 100, colorHex: '#2FA084', icon: 'creditcard');
      final payment = RecurringPayment(
        id: 'pago_${tag}_$suffix',
        name: 'Agua',
        amount: 40,
        currency: CurrencyType.usd,
        frequency: SubscriptionFrequency.monthly,
        startDate: DateTime(today.year, today.month, today.day),
        notificationOption: NotificationOption.none,
        icon: 'wifi',
        colorHex: '#2FA084',
        type: TransactionType.expense,
        accountId: account.id,
      );
      app.accounts = [account];
      await DatabaseHelper.instance.insertAccount(account);
      await DatabaseHelper.instance.insertRecurringPayment(payment);
      addTearDown(() async {
        for (final p in (await DatabaseHelper.instance.getAllPartials()).where((p) => p['recurring_payment_id'] == payment.id)) {
          await DatabaseHelper.instance.deletePartial(p['id'] as String);
        }
        await DatabaseHelper.instance.deleteConfirmation(payment.id, _fecha(today));
        for (final t in app.transactions.where((t) => t.accountId == account.id).toList()) {
          await DatabaseHelper.instance.deleteTransaction(t.id);
        }
        await DatabaseHelper.instance.deleteRecurringPayment(payment.id);
        await DatabaseHelper.instance.deleteAccount(account.id);
      });
      return (app: app, account: account, payment: payment);
    }

    test('undoRecurringConfirmation quita la confirmación pero no el movimiento', () async {
      final (:app, :account, :payment) = await preparar('undo');
      final today = DateTime.now();
      final recorded = <Transaction>[];
      await app.confirmRecurringPayment(payment: payment, actualAmount: 40, occurrenceDate: today, onTransactionRecorded: recorded.add);
      expect(app.getConfirmedCountForPayment(payment.id), 1);
      var avisos = 0;
      app.addListener(() => avisos++);

      await app.undoRecurringConfirmation(payment.id, today);

      expect(app.getConfirmedCountForPayment(payment.id), 0);
      final guardadas = await DatabaseHelper.instance.getAllConfirmations();
      expect(guardadas.where((c) => c['recurring_payment_id'] == payment.id), isEmpty);
      expect(app.transactions.any((t) => t.id == recorded.single.id), isTrue, reason: 'el movimiento lo borra deleteTransaction aparte');
      expect(avisos, greaterThan(0));
      expect(account.id, recorded.single.accountId);
    });

    test('registerPartialPayment entrega el movimiento y el parcial, y deletePartialPayment borra solo el parcial', () async {
      final (:app, :account, :payment) = await preparar('parcial');
      final today = DateTime.now();
      Transaction? tx;
      RecurringPaymentPartial? parcial;

      await app.registerPartialPayment(
        payment: payment,
        partialAmount: 15,
        occurrenceDate: today,
        onRecorded: (t, p) {
          tx = t;
          parcial = p;
        },
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 15);
      expect(tx!.accountId, account.id);
      expect(parcial!.transactionId, tx!.id);
      expect(parcial!.amount, 15);
      expect(parcial!.recurringPaymentId, payment.id);
      expect(parcial!.occurrenceDate, _fecha(today));
      expect(app.partialPayments.any((p) => p.id == parcial!.id), isTrue);
      expect(app.transactions.any((t) => t.id == tx!.id), isTrue);
      var avisos = 0;
      app.addListener(() => avisos++);

      await app.deletePartialPayment(parcial!.id);

      expect(app.partialPayments.any((p) => p.id == parcial!.id), isFalse);
      final guardados = await DatabaseHelper.instance.getAllPartials();
      expect(guardados.any((p) => p['id'] == parcial!.id), isFalse);
      expect(app.transactions.any((t) => t.id == tx!.id), isTrue, reason: 'el movimiento lo borra deleteTransaction aparte');
      expect(avisos, greaterThan(0));
    });

    test('confirmRecurringPayment fecha el movimiento con transactionDate y, sin ella, hoy', () async {
      final (:app, :account, :payment) = await preparar('fecha_conf');
      final today = DateTime.now();
      final ayer = DateTime(today.year, today.month, today.day - 1, 9, 30);
      final recorded = <Transaction>[];

      await app.confirmRecurringPayment(
        payment: payment,
        actualAmount: 40,
        occurrenceDate: today,
        transactionDate: ayer,
        onTransactionRecorded: recorded.add,
      );

      final guardado = app.transactions.singleWhere((t) => t.id == recorded.single.id);
      expect(guardado.date, ayer);
      expect(app.getConfirmedCountForPayment(payment.id), 1, reason: 'la cuota sigue siendo la de su fecha');
      expect(account.id, guardado.accountId);

      await app.undoRecurringConfirmation(payment.id, today);
      await app.confirmRecurringPayment(payment: payment, actualAmount: 40, occurrenceDate: today, onTransactionRecorded: recorded.add);
      expect(_fecha(recorded.last.date), _fecha(DateTime.now()));
    });

    test('registerPartialPayment fecha el movimiento con transactionDate y, sin ella, hoy', () async {
      final (:app, account: _, :payment) = await preparar('fecha_parcial');
      final today = DateTime.now();
      final ayer = DateTime(today.year, today.month, today.day - 1, 9, 30);
      final txs = <Transaction>[];
      final parciales = <RecurringPaymentPartial>[];

      await app.registerPartialPayment(
        payment: payment,
        partialAmount: 10,
        occurrenceDate: today,
        transactionDate: ayer,
        onRecorded: (t, p) {
          txs.add(t);
          parciales.add(p);
        },
      );

      expect(app.transactions.singleWhere((t) => t.id == txs.single.id).date, ayer);
      expect(parciales.single.occurrenceDate, _fecha(today), reason: 'el parcial sigue siendo de la cuota');

      await app.registerPartialPayment(
        payment: payment,
        partialAmount: 10,
        occurrenceDate: today,
        onRecorded: (t, p) => txs.add(t),
      );
      expect(_fecha(txs.last.date), _fecha(DateTime.now()));
    });
  });
}

String _fecha(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
