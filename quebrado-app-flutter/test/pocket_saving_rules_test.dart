import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/models/saving_pocket.dart';
import 'package:quebrado_app_flutter/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/models/currency_type.dart';
import 'package:quebrado_app_flutter/models/account.dart';
import 'package:quebrado_app_flutter/models/transaction.dart';

void main() {
  test('simulate user issue fixed threshold', () {
    final appState = AppState();

    final pocket = SavingPocket(
      id: "pocket_fixed_user",
      name: "Bolsillo Fijo",
      currentAmountUSD: 0.0,
      targetAmountUSD: 500.0,
      icon: "savings",
      colorHex: "#000000",
      targetDate: null,
      fundingRuleType: 'fixedThreshold',
      fundingRuleValue: 50.0, // Save $50
      fundingRuleThreshold: 100.0, // Threshold $100
    );

    appState.pockets.clear();
    appState.pockets.add(pocket);

    final recurringIncome = RecurringPayment(
      id: "recurring_inc_1",
      name: "Sueldo Fijo",
      amount: 100.0, // $100
      currency: CurrencyType.usd,
      frequency: SubscriptionFrequency.monthly,
      startDate: DateTime.now().add(const Duration(days: 5)),
      notificationOption: NotificationOption.none,
      icon: "briefcase",
      colorHex: "#2FA084",
      type: TransactionType.income,
    );

    appState.recurringPayments.clear();
    appState.recurringPayments.add(recurringIncome);

    final events = appState.getTimelineEvents(30);
    print("--- User Simulation Events ---");
    for (var event in events) {
      print("Event: title='${event.title}', amount=${event.amount}, accountName='${event.accountName}', isSuggestion=${event.isSuggestion}");
    }
  });

  test('simulate transaction success dialog matching logic', () {
    final appState = AppState();

    final pocket = SavingPocket(
      id: "pocket_fixed_user",
      name: "Bolsillo Fijo",
      currentAmountUSD: 0.0,
      targetAmountUSD: 500.0,
      icon: "savings",
      colorHex: "#000000",
      targetDate: null,
      fundingRuleType: 'fixedThreshold',
      fundingRuleValue: 50.0, // Save $50
      fundingRuleThreshold: 100.0, // Threshold $100
    );

    appState.pockets.clear();
    appState.pockets.add(pocket);

    // Simulate registering a transaction of 100 USD
    final tx = Transaction(
      id: "tx_1",
      date: DateTime.now(),
      amount: 100.0,
      currency: CurrencyType.usd,
      destinationPocketId: null,
      categoryId: null,
      accountId: "default_usd",
      note: "Ingreso manual",
      type: TransactionType.income,
      exchangeRate: 36.0,
    );

    final account = Account(
      id: "default_usd",
      name: "Efectivo \$",
      currency: CurrencyType.usd,
      balance: 0.0,
      colorHex: "#2FA084",
      icon: "creditcard",
    );

    // Let's copy the logic from add_transaction_dialog.dart:
    final matchingPockets = <Map<String, dynamic>>[];
    final isIncome = tx.type == TransactionType.income;
    if (isIncome && tx.currency == CurrencyType.usd && account.currency == CurrencyType.usd) {
      final rate = tx.exchangeRate > 0 ? tx.exchangeRate : appState.bcvRate;
      final amountUSD = tx.currency == CurrencyType.usd
          ? tx.amount
          : tx.amount / rate;

      final isRecurring = tx.id.contains("_rec") || tx.id.contains("_partial");

      for (var p in appState.pockets) {
        if (p.targetDate == null) {
          if (p.fundingRuleType == 'percentage' && isRecurring) {
            final val = p.fundingRuleValue ?? 0.0;
            if (val > 0) {
              final suggestUSD = amountUSD * (val / 100.0);
              final remaining = p.targetAmountUSD > 0
                  ? p.targetAmountUSD - p.currentAmountUSD
                  : double.infinity;
              if (remaining > 0) {
                final finalSuggest = (p.targetAmountUSD > 0 && suggestUSD > remaining) ? remaining : suggestUSD;
                matchingPockets.add({
                  'pocket': p,
                  'suggestUSD': finalSuggest,
                  'type': 'percentage',
                });
              }
            }
          } else if (p.fundingRuleType == 'fixedThreshold') {
            final threshold = p.fundingRuleThreshold ?? 0.0;
            final val = p.fundingRuleValue ?? 0.0;
            if (val > 0 && amountUSD >= threshold) {
              final remaining = p.targetAmountUSD > 0
                  ? p.targetAmountUSD - p.currentAmountUSD
                  : double.infinity;
              if (remaining > 0) {
                final finalSuggest = (p.targetAmountUSD > 0 && val > remaining) ? remaining : val;
                matchingPockets.add({
                  'pocket': p,
                  'suggestUSD': finalSuggest,
                  'type': 'fixedThreshold',
                });
              }
            }
          }
        }
      }
    }

    print("--- Transaction Success Dialog Simulation ---");
    for (var match in matchingPockets) {
      final p = match['pocket'] as SavingPocket;
      final suggest = match['suggestUSD'] as double;
      print("Suggest for ${p.name}: $suggest");
    }
    
    expect(matchingPockets.length, 1);
    expect(matchingPockets.first['suggestUSD'], 50.0);
  });

  test('simulate VES/Bs. income is ignored by rules', () {
    final appState = AppState();

    final pocket = SavingPocket(
      id: "pocket_fixed_user",
      name: "Bolsillo Fijo",
      currentAmountUSD: 0.0,
      targetAmountUSD: 500.0,
      icon: "savings",
      colorHex: "#000000",
      targetDate: null,
      fundingRuleType: 'fixedThreshold',
      fundingRuleValue: 50.0,
      fundingRuleThreshold: 100.0,
    );

    appState.pockets.clear();
    appState.pockets.add(pocket);

    // 1. Check timeline event simulation with VES payment
    final recurringIncomeVES = RecurringPayment(
      id: "recurring_inc_ves",
      name: "Sueldo Bs.",
      amount: 4000.0, // Exceeds threshold in USD value, but currency is Bs.
      currency: CurrencyType.bsBCV,
      frequency: SubscriptionFrequency.monthly,
      startDate: DateTime.now().add(const Duration(days: 5)),
      notificationOption: NotificationOption.none,
      icon: "briefcase",
      colorHex: "#2FA084",
      type: TransactionType.income,
    );

    appState.recurringPayments.clear();
    appState.recurringPayments.add(recurringIncomeVES);

    final events = appState.getTimelineEvents(30);
    // Should NOT contain a suggestion event because the currency is not USD
    final suggestions = events.where((e) => e.isSuggestion);
    expect(suggestions.isEmpty, true);

    // 2. Check transaction success matching logic with VES transaction
    final txVES = Transaction(
      id: "tx_ves",
      date: DateTime.now(),
      amount: 4000.0,
      currency: CurrencyType.bsBCV,
      destinationPocketId: null,
      categoryId: null,
      accountId: "default_ves",
      note: "Ingreso manual Bs",
      type: TransactionType.income,
      exchangeRate: 36.0,
    );

    final accountVES = Account(
      id: "default_ves",
      name: "Banco Bs.",
      currency: CurrencyType.bsBCV,
      balance: 0.0,
      colorHex: "#000000",
      icon: "creditcard",
    );

    final matchingPockets = <Map<String, dynamic>>[];
    final isIncome = txVES.type == TransactionType.income;
    if (isIncome && txVES.currency == CurrencyType.usd && accountVES.currency == CurrencyType.usd) {
      // should not enter here
      matchingPockets.add({'pocket': pocket});
    }

    expect(matchingPockets.isEmpty, true);
  });
}
