import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/models/transaction.dart';
import 'package:quebrado_app_flutter/models/account.dart';
import 'package:quebrado_app_flutter/models/currency_type.dart';

void main() {
  test('AppState multi-currency transactions update account balance correctly', () async {
    final appState = AppState();

    // 1. Setup a VES account with starting balance 10000.0 Bs.
    final accVES = Account(
      id: 'acc_ves_test',
      name: 'Banco VES',
      currency: CurrencyType.bsBCV,
      balance: 10000.0,
      colorHex: '#FF9500',
      icon: 'account_balance',
    );
    appState.accounts = [accVES];

    // 2. Add income of $100 USD at exchange rate of 36.5 Bs./USD.
    // Expected change: +3650.0 Bs.
    final txIncome = Transaction(
      id: 'tx_income_usd_on_ves',
      date: DateTime.now(),
      amount: 100.0,
      currency: CurrencyType.usd,
      accountId: 'acc_ves_test',
      note: 'USD income on VES account',
      type: TransactionType.income,
      exchangeRate: 36.5,
    );

    await appState.addTransaction(txIncome);

    // Verify balance is 10000 + (100 * 36.5) = 13650.0 Bs.
    expect(accVES.balance, equals(13650.0));

    // 3. Add expense of $50 USD at exchange rate of 36.5 Bs./USD.
    // Expected change: -1825.0 Bs.
    final txExpense = Transaction(
      id: 'tx_expense_usd_on_ves',
      date: DateTime.now(),
      amount: 50.0,
      currency: CurrencyType.usd,
      accountId: 'acc_ves_test',
      note: 'USD expense on VES account',
      type: TransactionType.expense,
      exchangeRate: 36.5,
    );

    await appState.addTransaction(txExpense);

    // Verify balance is 13650.0 - (50 * 36.5) = 13650.0 - 1825.0 = 11825.0 Bs.
    expect(accVES.balance, equals(11825.0));

    // 4. Update the expense to $60 USD at exchange rate of 40.0 Bs./USD.
    // Revert old expense: +1825.0 Bs. -> 13650.0 Bs.
    // Apply new expense: -2400.0 Bs. -> 11250.0 Bs.
    final updatedTxExpense = Transaction(
      id: 'tx_expense_usd_on_ves',
      date: DateTime.now(),
      amount: 60.0,
      currency: CurrencyType.usd,
      accountId: 'acc_ves_test',
      note: 'Updated USD expense on VES account',
      type: TransactionType.expense,
      exchangeRate: 40.0,
    );

    await appState.updateTransaction(txExpense, updatedTxExpense);

    // Verify balance is 11250.0 Bs.
    expect(accVES.balance, equals(11250.0));

    // 5. Delete the income transaction ($100 USD at 36.5 = 3650.0 Bs.)
    // Revert income: -3650.0 Bs. -> 11250.0 - 3650.0 = 7600.0 Bs.
    await appState.deleteTransaction(txIncome);

    // Verify balance is 7600.0 Bs.
    expect(accVES.balance, equals(7600.0));
  });

  test('AppState VES transaction on USD account converts correctly', () async {
    final appState = AppState();

    // Setup a USD account with starting balance 500.0 USD.
    final accUSD = Account(
      id: 'acc_usd_test',
      name: 'Cash USD',
      currency: CurrencyType.usd,
      balance: 500.0,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );
    appState.accounts = [accUSD];

    // Add income of 1460.0 VES at exchange rate of 36.5 VES/USD.
    // Expected change: +40.0 USD
    final txIncomeVES = Transaction(
      id: 'tx_income_ves_on_usd',
      date: DateTime.now(),
      amount: 1460.0,
      currency: CurrencyType.bsBCV,
      accountId: 'acc_usd_test',
      note: 'VES income on USD account',
      type: TransactionType.income,
      exchangeRate: 36.5,
    );

    await appState.addTransaction(txIncomeVES);

    // Verify balance is 500.0 + (1460.0 / 36.5) = 540.0 USD
    expect(accUSD.balance, equals(540.0));

    // Delete the VES income.
    await appState.deleteTransaction(txIncomeVES);

    // Verify balance is reverted to 500.0 USD
    expect(accUSD.balance, equals(500.0));
  });

  test('AppState account balance supports negative values and reverts correctly without clamping', () async {
    final appState = AppState();

    // Setup USD account with $50.0
    final accUSD = Account(
      id: 'acc_usd_negative_test',
      name: 'Cash USD',
      currency: CurrencyType.usd,
      balance: 50.0,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );
    appState.accounts = [accUSD];

    // Gasto of $100.0 USD
    final txExpenseUSD = Transaction(
      id: 'tx_expense_neg',
      date: DateTime.now(),
      amount: 100.0,
      currency: CurrencyType.usd,
      accountId: 'acc_usd_negative_test',
      note: 'Large USD expense',
      type: TransactionType.expense,
      exchangeRate: 1.0,
    );

    await appState.addTransaction(txExpenseUSD);

    // Verify balance went to negative: 50.0 - 100.0 = -50.0 USD
    expect(accUSD.balance, equals(-50.0));

    // Update / edit transaction: change account and move it to a VES account
    final accVES = Account(
      id: 'acc_ves_negative_test',
      name: 'Banco VES',
      currency: CurrencyType.bsBCV,
      balance: 1000.0,
      colorHex: '#FF9500',
      icon: 'account_balance',
    );
    appState.accounts.add(accVES);

    final txExpenseVES = Transaction(
      id: 'tx_expense_neg',
      date: DateTime.now(),
      amount: 400.0,
      currency: CurrencyType.bsBCV,
      accountId: 'acc_ves_negative_test',
      note: 'Moved to VES account',
      type: TransactionType.expense,
      exchangeRate: 40.0,
    );

    await appState.updateTransaction(txExpenseUSD, txExpenseVES);

    // USD account balance should return to $50.0 USD (since -50.0 + 100.0 = 50.0)
    expect(accUSD.balance, equals(50.0));

    // VES account balance should be 1000.0 - 400.0 = 600.0 Bs.
    expect(accVES.balance, equals(600.0));
  });
}
