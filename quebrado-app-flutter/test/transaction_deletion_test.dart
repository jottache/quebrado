import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/models/transaction.dart';
import 'package:quebrado_app_flutter/models/account.dart';
import 'package:quebrado_app_flutter/models/saving_pocket.dart';
import 'package:quebrado_app_flutter/models/currency_type.dart';

void main() {
  test('AppState transaction deletion reverts account balances correctly', () async {
    final appState = AppState();

    // 1. Setup accounts
    final accUSD = Account(
      id: 'test_acc_usd',
      name: 'Test USD',
      currency: CurrencyType.usd,
      balance: 100.0,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );
    appState.accounts = [accUSD];

    // --- TEST INCOME DELETION ---
    // Manually register an income transaction of 50.0 (simulating addition)
    final txIncome = Transaction(
      id: 'tx_income_test',
      date: DateTime.now(),
      amount: 50.0,
      currency: CurrencyType.usd,
      accountId: 'test_acc_usd',
      note: 'Test income',
      type: TransactionType.income,
      exchangeRate: 1.0,
    );
    appState.transactions = [txIncome];
    accUSD.balance = 150.0; // 100.0 + 50.0

    // Delete income transaction
    await appState.deleteTransaction(txIncome);

    // Verify balance is reverted back to 100.0
    expect(accUSD.balance, equals(100.0));
    expect(appState.transactions, isNot(contains(txIncome)));

    // --- TEST EXPENSE DELETION ---
    // Manually register an expense transaction of 30.0
    final txExpense = Transaction(
      id: 'tx_expense_test',
      date: DateTime.now(),
      amount: 30.0,
      currency: CurrencyType.usd,
      accountId: 'test_acc_usd',
      note: 'Test expense',
      type: TransactionType.expense,
      exchangeRate: 1.0,
    );
    appState.transactions = [txExpense];
    accUSD.balance = 70.0; // 100.0 - 30.0

    // Delete expense transaction
    await appState.deleteTransaction(txExpense);

    // Verify balance is reverted back to 100.0
    expect(accUSD.balance, equals(100.0));
    expect(appState.transactions, isNot(contains(txExpense)));
  });

  test('AppState transaction deletion reverts pocket balances correctly', () async {
    final appState = AppState();

    // 1. Setup pockets
    final pocket = SavingPocket(
      id: 'test_pocket_usd',
      name: 'Test Pocket',
      targetAmountUSD: 500.0,
      currentAmountUSD: 100.0,
      colorHex: '#2FA084',
      icon: 'briefcase',
    );
    appState.pockets = [pocket];

    // --- TEST POCKET INCOME DELETION ---
    final txPocketIncome = Transaction(
      id: 'tx_pocket_inc',
      date: DateTime.now(),
      amount: 25.0,
      currency: CurrencyType.usd,
      destinationPocketId: 'test_pocket_usd',
      note: 'Add pocket money',
      type: TransactionType.income,
      exchangeRate: 1.0,
    );
    appState.transactions = [txPocketIncome];
    pocket.currentAmountUSD = 125.0; // 100.0 + 25.0

    await appState.deleteTransaction(txPocketIncome);

    // Verify pocket balance reverted to 100.0
    expect(pocket.currentAmountUSD, equals(100.0));
  });

  test('AppState transaction deletion reverts BOTH sides of currency exchange', () async {
    final appState = AppState();

    // Setup accounts
    final accUSD = Account(
      id: 'acc_usd',
      name: 'Cash USD',
      currency: CurrencyType.usd,
      balance: 100.0,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );
    final accVES = Account(
      id: 'acc_ves',
      name: 'Banco VES',
      currency: CurrencyType.bsBCV,
      balance: 1000.0,
      colorHex: '#FF9500',
      icon: 'account_balance',
    );
    appState.accounts = [accUSD, accVES];

    // Setup exchange transactions (Venta USD -> VES)
    // Suffixes and timestamp prefix simulate `exchangeCurrency` ID formatting
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final usdExp = Transaction(
      id: '${timestamp}_usd_exp',
      date: DateTime.now(),
      amount: 10.0,
      currency: CurrencyType.usd,
      accountId: 'acc_usd',
      note: 'Venta de Divisa',
      type: TransactionType.expense,
      exchangeRate: 40.0,
    );
    final vesInc = Transaction(
      id: '${timestamp}_ves_inc',
      date: DateTime.now(),
      amount: 400.0,
      currency: CurrencyType.bsBCV,
      accountId: 'acc_ves',
      note: 'Venta de Divisa',
      type: TransactionType.income,
      exchangeRate: 40.0,
    );

    // Set updated balances
    accUSD.balance = 90.0;
    accVES.balance = 1400.0;
    appState.transactions = [usdExp, vesInc];

    // Deleting the egress/usd side should automatically detect and revert/delete the ingress/ves side
    await appState.deleteTransaction(usdExp);

    // Verify both account balances are reverted
    expect(accUSD.balance, equals(100.0));
    expect(accVES.balance, equals(1000.0));

    // Verify both transactions are removed from state list
    expect(appState.transactions, isEmpty);
  });
}
