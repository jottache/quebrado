import 'package:flutter/material.dart';

enum HabitType {
  binary,       // Si / No (ej. tender cama, meditar)
  quantitative, // Meta numérica (ej. 2000 ml agua, 20 páginas)
  timer,        // Temporizador (ej. 15 min ejercicio)
  negative,     // Mal hábito a evitar / romper (ej. cero fumar, cero azúcar)
  counter,      // Contador infinito / libre (ej. veces que digo groserías, vasos de café)
}

extension HabitTypeExtension on HabitType {
  String get rawValue {
    switch (this) {
      case HabitType.binary:
        return 'binary';
      case HabitType.quantitative:
        return 'quantitative';
      case HabitType.timer:
        return 'timer';
      case HabitType.negative:
        return 'negative';
      case HabitType.counter:
        return 'counter';
    }
  }

  String get label {
    switch (this) {
      case HabitType.binary:
        return 'BINARIO [SI/NO]';
      case HabitType.quantitative:
        return 'CUANTITATIVO [META]';
      case HabitType.timer:
        return 'TEMPORIZADOR [CRONO]';
      case HabitType.negative:
        return 'MAL HABITO [EVITAR]';
      case HabitType.counter:
        return 'CONTADOR INFINITO';
    }
  }

  static HabitType fromString(String? val) {
    switch (val) {
      case 'quantitative':
        return HabitType.quantitative;
      case 'timer':
        return HabitType.timer;
      case 'negative':
        return HabitType.negative;
      case 'counter':
        return HabitType.counter;
      case 'binary':
      default:
        return HabitType.binary;
    }
  }
}

enum HabitFrequencyType {
  daily,
  weeklyTarget,
  customDays,
}

extension HabitFrequencyTypeExtension on HabitFrequencyType {
  String get rawValue {
    switch (this) {
      case HabitFrequencyType.daily:
        return 'daily';
      case HabitFrequencyType.weeklyTarget:
        return 'weekly_target';
      case HabitFrequencyType.customDays:
        return 'custom_days';
    }
  }

  String get label {
    switch (this) {
      case HabitFrequencyType.daily:
        return 'DIARIO';
      case HabitFrequencyType.weeklyTarget:
        return 'META SEMANAL';
      case HabitFrequencyType.customDays:
        return 'DIAS ESPECIFICOS';
    }
  }

  static HabitFrequencyType fromString(String? val) {
    switch (val) {
      case 'weekly_target':
        return HabitFrequencyType.weeklyTarget;
      case 'custom_days':
        return HabitFrequencyType.customDays;
      case 'daily':
      default:
        return HabitFrequencyType.daily;
    }
  }
}

class HabitModel {
  final String id;
  final String? userId;
  final String title;
  final String? description;
  final String icon;
  final String colorHex;
  final HabitType type;
  final bool isNegative; // TRUE = Mal hábito que queremos romper
  final double targetValue;
  final String? unit; // 'ml', 'min', 'pag', 'veces'
  final HabitFrequencyType frequencyType;
  final Map<String, dynamic> frequencyPayload;
  final String? stackGroupId;
  final String? contactId;
  final bool archived;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  HabitModel({
    required this.id,
    this.userId,
    required this.title,
    this.description,
    this.icon = 'terminal',
    this.colorHex = '#00FF66',
    this.type = HabitType.binary,
    this.isNegative = false,
    this.targetValue = 1.0,
    this.unit,
    this.frequencyType = HabitFrequencyType.daily,
    Map<String, dynamic>? frequencyPayload,
    this.stackGroupId,
    this.contactId,
    this.archived = false,
    this.position = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : frequencyPayload = frequencyPayload ?? const {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  IconData get iconData {
    switch (icon) {
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'book':
        return Icons.auto_stories_outlined;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'smoke_free':
        return Icons.smoke_free_rounded;
      case 'bed':
        return Icons.bed_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'code_off':
        return Icons.no_food_outlined;
      case 'counter':
      case 'plus_one':
        return Icons.exposure_plus_1_rounded;
      case 'chat_bubble':
        return Icons.chat_bubble_outline_rounded;
      case 'terminal':
      default:
        return Icons.terminal_rounded;
    }
  }

  HabitModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool clearDescription = false,
    String? icon,
    String? colorHex,
    HabitType? type,
    bool? isNegative,
    double? targetValue,
    String? unit,
    bool clearUnit = false,
    HabitFrequencyType? frequencyType,
    Map<String, dynamic>? frequencyPayload,
    String? stackGroupId,
    bool clearStackGroupId = false,
    String? contactId,
    bool clearContactId = false,
    bool? archived,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      isNegative: isNegative ?? this.isNegative,
      targetValue: targetValue ?? this.targetValue,
      unit: clearUnit ? null : (unit ?? this.unit),
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyPayload: frequencyPayload ?? this.frequencyPayload,
      stackGroupId: clearStackGroupId ? null : (stackGroupId ?? this.stackGroupId),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      archived: archived ?? this.archived,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.rawValue,
      'is_negative': isNegative,
      'target_value': targetValue,
      'unit': unit,
      'frequency_type': frequencyType.rawValue,
      'frequency_payload': frequencyPayload,
      'stack_group_id': stackGroupId,
      'contact_id': contactId,
      'archived': archived,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      icon: map['icon']?.toString() ?? 'terminal',
      colorHex: map['color_hex']?.toString() ?? '#00FF66',
      type: HabitTypeExtension.fromString(map['type']?.toString()),
      isNegative: map['is_negative'] == true,
      targetValue: (map['target_value'] is num) ? (map['target_value'] as num).toDouble() : 1.0,
      unit: map['unit']?.toString(),
      frequencyType: HabitFrequencyTypeExtension.fromString(map['frequency_type']?.toString()),
      frequencyPayload: (map['frequency_payload'] is Map) ? Map<String, dynamic>.from(map['frequency_payload']) : const {},
      stackGroupId: map['stack_group_id']?.toString(),
      contactId: map['contact_id']?.toString(),
      archived: map['archived'] == true,
      position: (map['position'] is num) ? (map['position'] as num).toInt() : 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
