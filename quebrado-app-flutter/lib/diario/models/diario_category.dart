import 'package:flutter/material.dart';
import '../theme/diario_colors.dart';

class DiarioCategory {
  final String id;
  final String? contactId; // null = global category, otherwise contact-specific
  final String? parentId;  // null = root category, otherwise subcategory
  final String name;
  final String icon;
  final String colorHex;
  final int sortOrder;
  final DateTime createdAt;

  DiarioCategory({
    required this.id,
    this.contactId,
    this.parentId,
    required this.name,
    this.icon = 'folder_outlined',
    this.colorHex = '#1F6F5F',
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isGlobal => contactId == null;
  bool get isRoot => parentId == null;

  Color get color => DiarioColors.primary;

  IconData get iconData {
    switch (icon) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'thumb_up':
        return Icons.thumb_up_alt_rounded;
      case 'thumb_down':
        return Icons.thumb_down_alt_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'straighten':
        return Icons.straighten_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'book':
        return Icons.auto_stories_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'folder_outlined':
      default:
        return Icons.folder_open_rounded;
    }
  }

  DiarioCategory copyWith({
    String? id,
    String? contactId,
    String? parentId,
    String? name,
    String? icon,
    String? colorHex,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return DiarioCategory(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'parent_id': parentId,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DiarioCategory.fromMap(Map<String, dynamic> map) {
    return DiarioCategory(
      id: map['id']?.toString() ?? '',
      contactId: map['contact_id']?.toString(),
      parentId: map['parent_id']?.toString(),
      name: map['name']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'folder_outlined',
      colorHex: map['color_hex']?.toString() ?? '#1F6F5F',
      sortOrder: (map['sort_order'] is num) ? (map['sort_order'] as num).toInt() : 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
