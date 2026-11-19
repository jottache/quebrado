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
}
