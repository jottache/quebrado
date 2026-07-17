import 'package:uuid/uuid.dart';
import 'currency_type.dart';
import 'transaction.dart';

enum SubscriptionFrequency {
  monthly,
  biweekly,
  weekly,
  yearly,
  fifteenDays,
  threeMonths,
  custom,
  once;

  String get value {
    switch (this) {
      case SubscriptionFrequency.monthly:
        return "Mensual";
      case SubscriptionFrequency.biweekly:
        return "Cada 14 días";
      case SubscriptionFrequency.weekly:
        return "Semanal";
      case SubscriptionFrequency.yearly:
        return "Anual";
      case SubscriptionFrequency.fifteenDays:
        return "Quincenal";
      case SubscriptionFrequency.threeMonths:
        return "Cada 3 meses";
      case SubscriptionFrequency.custom:
        return "Personalizado";
      case SubscriptionFrequency.once:
        return "Pago único";
    }
  }

  static SubscriptionFrequency fromString(String val) {
    for (var element in SubscriptionFrequency.values) {
      if (element.value == val || element.name == val) {
        return element;
      }
    }
    return SubscriptionFrequency.monthly;
  }
}

enum NotificationOption {
  fiveDaysBefore,
  oneDayBefore,
  none;

  String get value {
    switch (this) {
      case NotificationOption.fiveDaysBefore:
        return "5 días antes";
      case NotificationOption.oneDayBefore:
        return "1 día antes";
      case NotificationOption.none:
        return "Sin notificación";
    }
  }

  static NotificationOption fromString(String val) {
    for (var element in NotificationOption.values) {
      if (element.value == val || element.name == val) {
        return element;
      }
    }
    return NotificationOption.none;
  }
}

class RecurringPayment {
  final String id;
  String name;
  double amount;
  CurrencyType currency;
  SubscriptionFrequency frequency;
  DateTime startDate;
  NotificationOption notificationOption;
  String icon;
  String colorHex;
  TransactionType type;
  String? accountId;
  String? pocketId;
  int? totalInstallments; // Null means infinite
  int? customDays;
  bool isVariable;
  double? maxAmount;

  RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.startDate,
    required this.notificationOption,
    required this.icon,
    required this.colorHex,
    required this.type,
    this.accountId,
    this.pocketId,
    this.totalInstallments,
    this.customDays,
    this.isVariable = false,
    this.maxAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'currency': currency.name,
      'frequency': frequency.name,
      'start_date': startDate.toIso8601String(),
      'notification_option': notificationOption.name,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.name,
      'account_id': accountId,
      'pocket_id': pocketId,
      'total_installments': totalInstallments,
      'custom_days': customDays,
      'is_variable': isVariable ? 1 : 0,
      'max_amount': maxAmount,
    };
  }

  factory RecurringPayment.fromMap(Map<String, dynamic> map) {
    return RecurringPayment(
      id: map['id'] ?? Uuid().v4(),
      name: map['name'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyType.fromString(map['currency'] ?? 'usd'),
      frequency: SubscriptionFrequency.fromString(map['frequency'] ?? 'monthly'),
      startDate: map['start_date'] is String
          ? DateTime.parse(map['start_date'])
          : DateTime.fromMillisecondsSinceEpoch(map['start_date']),
      notificationOption: NotificationOption.fromString(map['notification_option'] ?? 'none'),
      icon: map['icon'] ?? 'creditcard',
      colorHex: map['color_hex'] ?? '#FF9F0A',
      type: TransactionType.fromString(map['type'] ?? 'expense'),
      accountId: map['account_id'],
      pocketId: map['pocket_id'],
      totalInstallments: map['total_installments'],
      customDays: map['custom_days'],
      isVariable: (map['is_variable'] ?? 0) == 1,
      maxAmount: map['max_amount'] != null ? (map['max_amount'] as num).toDouble() : null,
    );
  }
}

class PendingOccurrence {
  final RecurringPayment payment;
  final DateTime occurrenceDate;
  final double partialAmountPaid;

  PendingOccurrence({
    required this.payment,
    required this.occurrenceDate,
    this.partialAmountPaid = 0.0,
  });

  double get remainingAmount => payment.amount - partialAmountPaid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingOccurrence &&
        other.payment.id == payment.id &&
        other.occurrenceDate.year == occurrenceDate.year &&
        other.occurrenceDate.month == occurrenceDate.month &&
        other.occurrenceDate.day == occurrenceDate.day;
  }

  @override
  int get hashCode => payment.id.hashCode ^
      occurrenceDate.year.hashCode ^
      occurrenceDate.month.hashCode ^
      occurrenceDate.day.hashCode;
}
