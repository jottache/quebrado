import 'package:flutter/material.dart';

class NoteCategory {
  final String id;
  final String? userId;
  final String name;
  final String icon;
  final String colorHex;
  final int sortOrder;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteCategory({
    required this.id,
    this.userId,
    required this.name,
    this.icon = 'folder_outlined',
    this.colorHex = '#6366F1',
    this.sortOrder = 0,
    this.isSystem = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const String generalCategoryId = 'c0000000-0000-0000-0000-000000000001';
  static const String acuerdosCategoryId = 'c0000000-0000-0000-0000-000000000002';
  static const String ideasCategoryId = 'c0000000-0000-0000-0000-000000000003';
  static const String direccionesCategoryId = 'c0000000-0000-0000-0000-000000000004';

  static List<NoteCategory> defaultCategories() {
    return [
      NoteCategory(
        id: generalCategoryId,
        name: 'General',
        icon: '📝',
        colorHex: '#6366F1',
        sortOrder: 0,
        isSystem: true,
      ),
      NoteCategory(
        id: acuerdosCategoryId,
        name: 'Acuerdos de Pareja',
        icon: '💍',
        colorHex: '#EC4899',
        sortOrder: 1,
        isSystem: false,
      ),
      NoteCategory(
        id: ideasCategoryId,
        name: 'Ideas & Proyectos',
        icon: '💡',
        colorHex: '#F59E0B',
        sortOrder: 2,
        isSystem: false,
      ),
      NoteCategory(
        id: direccionesCategoryId,
        name: 'Direcciones & Datos Útiles',
        icon: '📍',
        colorHex: '#10B981',
        sortOrder: 3,
        isSystem: false,
      ),
    ];
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  NoteCategory copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    String? colorHex,
    int? sortOrder,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'is_system': isSystem ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'is_system': isSystem,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteCategory.fromMap(Map<String, dynamic> map) {
    return NoteCategory(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? 'Sin categoría',
      icon: map['icon']?.toString() ?? '📁',
      colorHex: map['color_hex']?.toString() ?? '#6366F1',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isSystem: map['is_system'] == true || map['is_system'] == 1,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
