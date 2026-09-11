import 'package:uuid/uuid.dart';

class RecurringPaymentPartial {
  final String id;
  final String recurringPaymentId;
  final String occurrenceDate;
  final double amount;
  final String transactionId;

  RecurringPaymentPartial({
    required this.id,
    required this.recurringPaymentId,
    required this.occurrenceDate,
    required this.amount,
    required this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurring_payment_id': recurringPaymentId,
      'occurrence_date': occurrenceDate,
      'amount': amount,
      'transaction_id': transactionId,
    };
  }

  factory RecurringPaymentPartial.fromMap(Map<String, dynamic> map) {
    return RecurringPaymentPartial(
      id: map['id'] ?? Uuid().v4(),
      recurringPaymentId: map['recurring_payment_id'] ?? '',
      occurrenceDate: map['occurrence_date'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      transactionId: map['transaction_id'] ?? '',
    );
  }
}
