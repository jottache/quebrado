import 'package:uuid/uuid.dart';

enum TransactionCategoryType {
  income,
  expense;

  String get value {
    switch (this) {
      case TransactionCategoryType.income:
        return "Ingreso";
      case TransactionCategoryType.expense:
        return "Gasto";
    }
  }

  static TransactionCategoryType fromString(String val) {
    if (val == "Gasto" || val == "expense") {
      return TransactionCategoryType.expense;
    }
    return TransactionCategoryType.income;
  }
}

class TransactionCategory {
  final String id;
  String name;
  String icon;
  String colorHex;
  TransactionCategoryType type;
  int position;

  TransactionCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.type,
    this.position = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.name,
      'position': position,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'tag',
      colorHex: map['color_hex'] ?? '#8E8E93',
      type: TransactionCategoryType.fromString(map['type'] ?? 'income'),
      position: map['position'] ?? 0,
    );
  }
}
