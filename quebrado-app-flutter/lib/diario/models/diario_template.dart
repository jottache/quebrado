import 'package:flutter/material.dart';
import '../theme/diario_colors.dart';

enum TemplateFieldType {
  text,
  multiline,
  number,
  select,
  date,
  boolean,
}

extension TemplateFieldTypeExtension on TemplateFieldType {
  String get rawValue {
    switch (this) {
      case TemplateFieldType.text:
        return 'text';
      case TemplateFieldType.multiline:
        return 'multiline';
      case TemplateFieldType.number:
        return 'number';
      case TemplateFieldType.select:
        return 'select';
      case TemplateFieldType.date:
        return 'date';
      case TemplateFieldType.boolean:
        return 'boolean';
    }
  }

  static TemplateFieldType fromString(String? value) {
    switch (value) {
      case 'multiline':
        return TemplateFieldType.multiline;
      case 'number':
        return TemplateFieldType.number;
      case 'select':
        return TemplateFieldType.select;
      case 'date':
        return TemplateFieldType.date;
      case 'boolean':
        return TemplateFieldType.boolean;
      case 'text':
      default:
        return TemplateFieldType.text;
    }
  }
}

class TemplateField {
  final String key;
  final String label;
  final TemplateFieldType type;
  final bool required;
  final String? placeholder;
  final List<String> options;

  TemplateField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder,
    this.options = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'type': type.rawValue,
      'required': required,
      'placeholder': placeholder,
      'options': options,
    };
  }

  factory TemplateField.fromMap(Map<String, dynamic> map) {
    final List<String> parsedOptions = [];
    if (map['options'] is List) {
      for (var opt in map['options']) {
        parsedOptions.add(opt.toString());
      }
    }

    return TemplateField(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: TemplateFieldTypeExtension.fromString(map['type']?.toString()),
      required: map['required'] == true,
      placeholder: map['placeholder']?.toString(),
      options: parsedOptions,
    );
  }
}

class DiarioTemplate {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String colorHex;
  final List<TemplateField> fields;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiarioTemplate({
    required this.id,
    required this.name,
    this.description,
    this.icon = 'extension',
    this.colorHex = '#1F6F5F',
    required this.fields,
    this.isSystem = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => DiarioColors.primary;

  IconData get iconData {
    switch (icon) {
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'straighten':
        return Icons.straighten_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'extension':
      default:
        return Icons.extension_rounded;
    }
  }

  DiarioTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? colorHex,
    List<TemplateField>? fields,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiarioTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      fields: fields ?? this.fields,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color_hex': colorHex,
      'schema': {
        'fields': fields.map((f) => f.toMap()).toList(),
      },
      'is_system': isSystem,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DiarioTemplate.fromMap(Map<String, dynamic> map) {
    final List<TemplateField> parsedFields = [];
    final schema = map['schema'];
    if (schema is Map && schema['fields'] is List) {
      for (var f in schema['fields']) {
        if (f is Map<String, dynamic>) {
          parsedFields.add(TemplateField.fromMap(f));
        } else if (f is Map) {
          parsedFields.add(TemplateField.fromMap(Map<String, dynamic>.from(f)));
        }
      }
    }

    return DiarioTemplate(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      icon: map['icon']?.toString() ?? 'extension',
      colorHex: map['color_hex']?.toString() ?? '#1F6F5F',
      fields: parsedFields,
      isSystem: map['is_system'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
