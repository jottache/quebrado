import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';

// Spec 05 (CA-07): se elimina la confirmación deslizante. Las operaciones de
// dinero se confirman siempre con el botón normal, sin ningún ajuste previo.
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
}
