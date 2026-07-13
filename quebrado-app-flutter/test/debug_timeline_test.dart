import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/models/currency_type.dart';
import 'package:quebrado_app_flutter/models/transaction.dart';

void main() {
  test('debug timeline events logic', () {
    final appState = AppState();

    final payment = RecurringPayment(
      id: "1782443549321",
      name: "parcial 3",
      amount: 700.0,
      currency: CurrencyType.usd,
      frequency: SubscriptionFrequency.monthly,
      startDate: DateTime.parse("2026-07-08T00:00:00.000"),
      notificationOption: NotificationOption.none,
      icon: "briefcase",
      colorHex: "#2FA084",
      type: TransactionType.income,
    );

    appState.recurringPayments.clear();
    appState.recurringPayments.add(payment);

    appState.partialPayments.clear();

    // Print event dates generated
    final events = appState.getTimelineEvents(30);
    print("--- timeline events (30 days) ---");
    for (var event in events) {
      if (event.recurringPaymentId == payment.id) {
        print("Event: title=${event.title}, date=${event.date}, amount=${event.amount}, partialPaid=${event.partialAmountPaid}");
      }
    }

    final events90 = appState.getTimelineEvents(90);
    print("--- timeline events (90 days) ---");
    for (var event in events90) {
      if (event.recurringPaymentId == payment.id) {
        print("Event: title=${event.title}, date=${event.date}, amount=${event.amount}, partialPaid=${event.partialAmountPaid}");
      }
    }
  });
}
