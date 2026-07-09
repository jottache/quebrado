import 'package:uuid/uuid.dart';
import 'currency_type.dart';

enum TransactionType {
  income,
  expense;

  String get value {
    switch (this) {
      case TransactionType.income:
        return "Ingreso";
      case TransactionType.expense:
        return "Gasto";
    }
  }

  static TransactionType fromString(String val) {
    if (val == "Gasto" || val == "expense") {
      return TransactionType.expense;
    }
    return TransactionType.income;
  }
}

class Transaction {
  final String id;
  DateTime date;
  double amount;
  CurrencyType currency;
  String? destinationPocketId;
  String? categoryId;
  String? accountId;
  String note;
  TransactionType type;
  double exchangeRate;

  Transaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    this.destinationPocketId,
    this.categoryId,
    this.accountId,
    required this.note,
    required this.type,
    required this.exchangeRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'currency': currency.name,
      'destination_pocket_id': destinationPocketId,
      'category_id': categoryId,
      'account_id': accountId,
      'note': note,
      'type': type.name,
      'exchange_rate': exchangeRate,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? const Uuid().v4(),
      date: map['date'] is String
          ? DateTime.parse(map['date'])
          : DateTime.fromMillisecondsSinceEpoch(map['date']),
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyType.fromString(map['currency'] ?? 'usd'),
      destinationPocketId: map['destination_pocket_id'],
      categoryId: map['category_id'],
      accountId: map['account_id'],
      note: map['note'] ?? '',
      type: TransactionType.fromString(map['type'] ?? 'income'),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
    );
  }
}
