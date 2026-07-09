import 'package:uuid/uuid.dart';
import 'currency_type.dart';

class Account {
  final String id;
  String name;
  CurrencyType currency;
  double balance;
  String colorHex;
  String icon;

  Account({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.colorHex,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currency': currency.name,
      'balance': balance,
      'color_hex': colorHex,
      'icon': icon,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      currency: CurrencyType.fromString(map['currency'] ?? 'usd'),
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      colorHex: map['color_hex'] ?? '#007AFF',
      icon: map['icon'] ?? 'creditcard',
    );
  }
}
