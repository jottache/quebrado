import 'package:uuid/uuid.dart';

enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  todo,
  bulletList,
  numberedList,
  toggle,
  callout,
  divider;

  static BlockType fromString(String val) {
    return BlockType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => BlockType.paragraph,
    );
  }
}

class NoteBlock {
  final String id;
  final BlockType type;
  final String content;
  final bool isChecked;
  final List<NoteBlock> children;
  final String? calloutIcon;
  final String? calloutColor;

  static String generateId() => const Uuid().v4();

  NoteBlock({
    String? id,
    required this.type,
    this.content = '',
    this.isChecked = false,
    this.children = const [],
    this.calloutIcon,
    this.calloutColor,
  }) : id = id ?? const Uuid().v4();

  NoteBlock copyWith({
    String? id,
    BlockType? type,
    String? content,
    bool? isChecked,
    List<NoteBlock>? children,
    String? calloutIcon,
    String? calloutColor,
  }) {
    return NoteBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      isChecked: isChecked ?? this.isChecked,
      children: children ?? this.children,
      calloutIcon: calloutIcon ?? this.calloutIcon,
      calloutColor: calloutColor ?? this.calloutColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'is_checked': isChecked,
      'children': children.map((c) => c.toMap()).toList(),
      if (calloutIcon != null) 'callout_icon': calloutIcon,
      if (calloutColor != null) 'callout_color': calloutColor,
    };
  }

  factory NoteBlock.fromMap(Map<String, dynamic> map) {
    final rawChildren = map['children'];
    List<NoteBlock> parsedChildren = [];
    if (rawChildren is List) {
      parsedChildren = rawChildren
          .whereType<Map>()
          .map((c) => NoteBlock.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    }

    return NoteBlock(
      id: map['id']?.toString() ?? const Uuid().v4(),
      type: BlockType.fromString(map['type']?.toString() ?? 'paragraph'),
      content: map['content']?.toString() ?? '',
      isChecked: map['is_checked'] == true || map['is_checked'] == 1,
      children: parsedChildren,
      calloutIcon: map['callout_icon']?.toString(),
      calloutColor: map['callout_color']?.toString(),
    );
  }

  /// Convierte el bloque a texto Markdown limpio
  String toMarkdown({int indentLevel = 0}) {
    final indent = '  ' * indentLevel;
    switch (type) {
      case BlockType.heading1:
        return '# $content\n';
      case BlockType.heading2:
        return '## $content\n';
      case BlockType.heading3:
        return '### $content\n';
      case BlockType.todo:
        final mark = isChecked ? 'x' : ' ';
        return '$indent- [$mark] $content\n';
      case BlockType.bulletList:
        return '$indent- $content\n';
      case BlockType.numberedList:
        return '${indent}1. $content\n';
      case BlockType.callout:
        final icon = calloutIcon ?? '💡';
        return '> $icon $content\n';
      case BlockType.toggle:
        final childMd = children.map((c) => c.toMarkdown(indentLevel: indentLevel + 1)).join();
        return '$indent<details><summary>$content</summary>\n$childMd$indent</details>\n';
      case BlockType.divider:
        return '---\n';
      case BlockType.paragraph:
        return '$content\n';
    }
  }
}
