import 'dart:convert';
import 'package:flutter/material.dart';
import 'note_block.dart';

class NoteItem {
  final String id;
  final String? userId;
  final String? categoryId;
  final String title;
  final String icon;
  final String colorHex;
  final List<NoteBlock> blocks;
  final String? contentText;
  final bool isPinned;
  final bool isArchived;
  final String? sharedTag;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    this.userId,
    this.categoryId,
    required this.title,
    String icon = '📝',
    this.colorHex = '#6366F1',
    this.blocks = const [],
    this.contentText,
    this.isPinned = false,
    this.isArchived = false,
    this.sharedTag,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? emoji,
  })  : icon = emoji ?? icon,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get emoji => icon;

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
    final difference = today.difference(entryDay).inDays;

    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final monthStr = months[updatedAt.month - 1];

    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Ayer';
    } else if (difference == -1) {
      return 'Mañana';
    } else if (updatedAt.year == now.year) {
      return '${updatedAt.day} $monthStr';
    } else {
      return '${updatedAt.day} $monthStr ${updatedAt.year}';
    }
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  /// Calcula el progreso de checklists si tiene bloques 'todo'
  ({int total, int completed}) get todoProgress {
    int total = 0;
    int completed = 0;
    void count(List<NoteBlock> list) {
      for (final b in list) {
        if (b.type == BlockType.todo) {
          total++;
          if (b.isChecked) completed++;
        }
        if (b.children.isNotEmpty) count(b.children);
      }
    }
    count(blocks);
    return (total: total, completed: completed);
  }

  bool get hasTodos => todoProgress.total > 0;

  /// Genera representación completa en Markdown
  String toMarkdown() {
    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln('# $icon $title\n');
    }
    for (final b in blocks) {
      buffer.write(b.toMarkdown());
    }
    return buffer.toString();
  }

  NoteItem copyWith({
    String? id,
    String? userId,
    String? categoryId,
    bool clearCategory = false,
    String? title,
    String? icon,
    String? emoji,
    String? colorHex,
    List<NoteBlock>? blocks,
    String? contentText,
    bool? isPinned,
    bool? isArchived,
    String? sharedTag,
    bool clearSharedTag = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      title: title ?? this.title,
      icon: emoji ?? icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      blocks: blocks ?? this.blocks,
      contentText: contentText ?? this.contentText,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      sharedTag: clearSharedTag ? null : (sharedTag ?? this.sharedTag),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'category_id': categoryId,
      'title': title,
      'icon': icon,
      'color_hex': colorHex,
      'blocks': jsonEncode(blocks.map((b) => b.toMap()).toList()),
      'content_text': contentText ?? toMarkdown(),
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'shared_tag': sharedTag,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'category_id': categoryId,
      'title': title,
      'icon': icon,
      'color_hex': colorHex,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'content_text': contentText ?? toMarkdown(),
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'shared_tag': sharedTag,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    List<NoteBlock> parsedBlocks = [];
    final rawBlocks = map['blocks'];
    if (rawBlocks is List) {
      parsedBlocks = rawBlocks
          .whereType<Map>()
          .map((b) => NoteBlock.fromMap(Map<String, dynamic>.from(b)))
          .toList();
    } else if (rawBlocks is String && rawBlocks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBlocks);
        if (decoded is List) {
          parsedBlocks = decoded
              .whereType<Map>()
              .map((b) => NoteBlock.fromMap(Map<String, dynamic>.from(b)))
              .toList();
        }
      } catch (_) {}
    }

    return NoteItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      categoryId: map['category_id']?.toString(),
      title: map['title']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '📝',
      colorHex: map['color_hex']?.toString() ?? '#6366F1',
      blocks: parsedBlocks,
      contentText: map['content_text']?.toString(),
      isPinned: map['is_pinned'] == true || map['is_pinned'] == 1,
      isArchived: map['is_archived'] == true || map['is_archived'] == 1,
      sharedTag: map['shared_tag']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
