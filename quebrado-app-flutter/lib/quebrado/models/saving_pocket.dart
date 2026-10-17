import 'package:uuid/uuid.dart';

class SavingPocket {
  final String id;
  String name;
  double currentAmountUSD;
  double targetAmountUSD;
  String icon;
  String colorHex;
  String? description;
  String? imageUrl;
  DateTime? targetDate;
  int priority;
  String fundingRuleType; // 'none', 'percentage', 'fixedThreshold'
  double? fundingRuleValue;
  double? fundingRuleThreshold;
  /// Fecha de creación (columna created_at de Supabase). No se envía en toMap: la BD la asigna.
  DateTime? createdAt;

  SavingPocket({
    required this.id,
    required this.name,
    required this.currentAmountUSD,
    required this.targetAmountUSD,
    required this.icon,
    required this.colorHex,
    this.description,
    this.imageUrl,
    this.targetDate,
    this.priority = 1,
    this.fundingRuleType = 'none',
    this.fundingRuleValue,
    this.fundingRuleThreshold,
    this.createdAt,
  });

  /// Día en que empezó el plan de ahorro: created_at, o el id si es un timestamp en ms
  /// (así se generan los ids en la app). Null si no se puede saber.
  DateTime? get planStartDate {
    final created = createdAt ?? _dateFromTimestampId(id);
    if (created == null) return null;
    final local = created.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? _dateFromTimestampId(String id) {
    final ms = int.tryParse(id);
    // Rango razonable: 2020-01-01 .. 2100-01-01
    if (ms == null || ms < 1577836800000 || ms > 4102444800000) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  double get progress {
    if (targetAmountUSD <= 0) return 0.0;
    return (currentAmountUSD / targetAmountUSD).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'current_amount_usd': currentAmountUSD,
      'target_amount_usd': targetAmountUSD,
      'icon': icon,
      'color_hex': colorHex,
      'description': description,
      'image_url': imageUrl,
      'target_date': targetDate?.toIso8601String(),
      'priority': priority,
      'funding_rule_type': fundingRuleType,
      'funding_rule_value': fundingRuleValue,
      'funding_rule_threshold': fundingRuleThreshold,
    };
  }

  factory SavingPocket.fromMap(Map<String, dynamic> map) {
    return SavingPocket(
      id: map['id'] ?? Uuid().v4(),
      name: map['name'] ?? '',
      currentAmountUSD: (map['current_amount_usd'] as num).toDouble(),
      targetAmountUSD: (map['target_amount_usd'] as num).toDouble(),
      icon: map['icon'] ?? 'star',
      colorHex: map['color_hex'] ?? '#FF9F0A',
      description: map['description'],
      imageUrl: map['image_url'],
      targetDate: map['target_date'] != null ? DateTime.tryParse(map['target_date']) : null,
      priority: map['priority'] != null ? (map['priority'] as num).toInt() : 1,
      fundingRuleType: map['funding_rule_type'] ?? 'none',
      fundingRuleValue: map['funding_rule_value'] != null ? (map['funding_rule_value'] as num).toDouble() : null,
      fundingRuleThreshold: map['funding_rule_threshold'] != null ? (map['funding_rule_threshold'] as num).toDouble() : null,
      createdAt: map['created_at'] is String ? DateTime.tryParse(map['created_at']) : null,
    );
  }
}
