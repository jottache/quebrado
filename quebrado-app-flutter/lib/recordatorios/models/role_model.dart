import 'package:flutter/material.dart';

/// Modelo de Rol Vital para la gestión del tiempo de 4ta Generación (Hábito 3: Covey).
class RoleModel {
  final String id;
  final String? userId;
  final String name;
  final String? purposeStatement;
  final String colorHex;
  final String iconName;
  final int position;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoleModel({
    required this.id,
    this.userId,
    required this.name,
    this.purposeStatement,
    this.colorHex = '#3B82F6',
    this.iconName = 'person',
    int? position,
    int? orderIndex,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : position = orderIndex ?? position ?? 0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get orderIndex => position;

  static Color parseColorHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  Color get color => parseColorHex(colorHex);

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'health':
      case 'fitness':
      case 'favorite':
      case 'salud':
        return Icons.favorite_rounded;
      case 'work':
      case 'business':
      case 'trabajo':
      case 'code':
        return Icons.work_rounded;
      case 'family':
      case 'familia':
      case 'home':
        return Icons.family_restroom_rounded;
      case 'finance':
      case 'finanzas':
      case 'money':
      case 'attach_money':
        return Icons.payments_rounded;
      case 'study':
      case 'learning':
      case 'school':
      case 'desarrollo':
        return Icons.school_rounded;
      case 'spiritual':
      case 'meditation':
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'person':
      default:
        return Icons.person_rounded;
    }
  }

  RoleModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? purposeStatement,
    String? colorHex,
    String? iconName,
    int? position,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      purposeStatement: purposeStatement ?? this.purposeStatement,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      position: position ?? this.position,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'purpose_statement': purposeStatement,
      'color_hex': colorHex,
      'icon': iconName,
      'position': position,
      'archived': archived,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    return RoleModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? 'Rol sin nombre',
      purposeStatement: map['purpose_statement']?.toString(),
      colorHex: map['color_hex']?.toString() ?? '#3B82F6',
      iconName: map['icon']?.toString() ?? map['icon_name']?.toString() ?? 'person',
      position: (map['position'] as num?)?.toInt() ?? 0,
      archived: map['archived'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : DateTime.now(),
    );
  }

  /// Semillas iniciales sugeridas para nuevos usuarios basadas en el equilibrio vital
  static List<RoleModel> defaultSeedRoles() {
    return [
      RoleModel(
        id: 'role_individual',
        name: 'Individual / Salud',
        purposeStatement: 'Cuidar mi cuerpo, energía mental, descanso y paz interior.',
        colorHex: '#10B981', // Verde Esmeralda
        iconName: 'health',
        position: 0,
      ),
      RoleModel(
        id: 'role_profesional',
        name: 'Profesional / Arquitectura',
        purposeStatement: 'Construir software de excelencia, resolver problemas y liderar con rigor.',
        colorHex: '#3B82F6', // Azul
        iconName: 'work',
        position: 1,
      ),
      RoleModel(
        id: 'role_familia',
        name: 'Familia / Relaciones',
        purposeStatement: 'Nutrir la cuenta bancaria emocional de mis seres queridos con presencia y amor.',
        colorHex: '#F43F5E', // Rosa / Carmesí
        iconName: 'family',
        position: 2,
      ),
      RoleModel(
        id: 'role_finanzas',
        name: 'Finanzas / Administración',
        purposeStatement: 'Gestionar mis recursos con sobriedad, orden y visión de largo plazo.',
        colorHex: '#F59E0B', // Ámbar
        iconName: 'finance',
        position: 3,
      ),
    ];
  }

  static List<RoleModel> defaultSeeds(String userId) {
    return defaultSeedRoles().map((r) => r.copyWith(userId: userId)).toList();
  }
}
