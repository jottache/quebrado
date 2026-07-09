import 'package:flutter_test/flutter_test.dart';
import '../lib/models/account.dart';
import '../lib/models/currency_type.dart';
import '../lib/models/saving_pocket.dart';
import '../lib/models/transaction.dart';
import '../lib/models/transaction_category.dart';
import '../lib/viewmodels/app_state.dart';

void main() {
  group('Manual Income Savings Suggestions', () {
    late AppState appState;

    setUp(() {
      appState = AppState();

      // Setup Accounts
      appState.accounts = [
        Account(
          id: 'acc_usd',
          name: 'USD Account',
          currency: CurrencyType.usd,
          balance: 1000.0,
          colorHex: '#ffffff',
          icon: 'creditcard',
        ),
      ];

      // Setup Pockets
      appState.pockets = [
        SavingPocket(
          id: 'p1',
          name: '10% Saver',
          icon: 'savings',
          colorHex: '#000000',
          targetAmountUSD: 0,
          currentAmountUSD: 0,
          fundingRuleType: 'percentage',
          fundingRuleValue: 10.0,
        ),
        SavingPocket(
          id: 'p2',
          name: 'Fixed 50 Threshold 200',
          icon: 'savings',
          colorHex: '#000000',
          targetAmountUSD: 0,
          currentAmountUSD: 0,
          fundingRuleType: 'fixedThreshold',
          fundingRuleThreshold: 200.0,
          fundingRuleValue: 50.0,
        ),
      ];
    });

    test('Generates suggestion for single manual income', () {
      final today = DateTime.now();
      appState.transactions = [
        Transaction(
          id: 't1',
          date: today,
          amount: 100.0,
          currency: CurrencyType.usd,
          note: 'Manual Income',
          type: TransactionType.income,
          exchangeRate: 1.0,
          accountId: 'acc_usd',
          categoryId: 'cat_income',
        ),
      ];

      final events = appState.getTimelineEvents(30);

      // We expect 1 suggestion for p1 (10% of 100 = 10)
      // p2 threshold is 200, so it shouldn't trigger
      final p1Suggestions = events.where((e) => e.isSuggestion && e.pocketId == 'p1').toList();
      final p2Suggestions = events.where((e) => e.isSuggestion && e.pocketId == 'p2').toList();

      expect(p1Suggestions.length, 1);
      expect(p1Suggestions.first.amount, 10.0);
      expect(p1Suggestions.first.associatedTransactionIds, ['t1']);
      expect(p2Suggestions.isEmpty, true);
    });

    test('Consolidates multiple manual incomes on the same day', () {
      final today = DateTime.now();
      appState.transactions = [
        Transaction(
          id: 't1',
          date: today,
          amount: 100.0,
          currency: CurrencyType.usd,
          note: 'Manual Income 1',
          type: TransactionType.income,
          exchangeRate: 1.0,
          accountId: 'acc_usd',
          categoryId: 'cat_income',
        ),
        Transaction(
          id: 't2',
          date: today,
          amount: 300.0,
          currency: CurrencyType.usd,
          note: 'Manual Income 2',
          type: TransactionType.income,
          exchangeRate: 1.0,
          accountId: 'acc_usd',
          categoryId: 'cat_income',
        ),
      ];

      final events = appState.getTimelineEvents(30);

      // p1: 10% of 100 + 10% of 300 = 10 + 30 = 40
      final p1Suggestions = events.where((e) => e.isSuggestion && e.pocketId == 'p1').toList();
      expect(p1Suggestions.length, 1, reason: "Should be consolidated into one event");
      expect(p1Suggestions.first.amount, 40.0);
      expect(p1Suggestions.first.associatedTransactionIds?.contains('t1'), true);
      expect(p1Suggestions.first.associatedTransactionIds?.contains('t2'), true);

      // p2: t1 is 100 (<200) -> no, t2 is 300 (>=200) -> yes (50)
      final p2Suggestions = events.where((e) => e.isSuggestion && e.pocketId == 'p2').toList();
      expect(p2Suggestions.length, 1);
      expect(p2Suggestions.first.amount, 50.0);
      expect(p2Suggestions.first.associatedTransactionIds, ['t2']);
    });
  });
}
