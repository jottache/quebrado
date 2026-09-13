import 'package:uuid/uuid.dart';

class AgentePromptModel {
  final String id;
  final String text;
  final String? label;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => (label != null && label!.trim().isNotEmpty) ? label! : text;

  AgentePromptModel({
    required this.id,
    required this.text,
    this.label,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'label': label,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AgentePromptModel.fromMap(Map<String, dynamic> map) {
    return AgentePromptModel(
      id: map['id']?.toString() ?? const Uuid().v4(),
      text: map['text']?.toString() ?? '',
      label: map['label']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AgentePromptModel copyWith({
    String? id,
    String? text,
    String? label,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentePromptModel(
      id: id ?? this.id,
      text: text ?? this.text,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
