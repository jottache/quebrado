class DiarioEntry {
  final String id;
  final String contactId;
  final String categoryId;
  final String? templateId;
  final String entryType; // 'simple_text', 'list_item', 'template_instance'
  final String title;
  final String? contentText;
  final String? photoUrl;
  final Map<String, dynamic> contentData;
  final List<String> mentionedContactIds;
  final List<String> mentionedNoteIds;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiarioEntry({
    required this.id,
    required this.contactId,
    required this.categoryId,
    this.templateId,
    this.entryType = 'simple_text',
    required this.title,
    this.contentText,
    this.photoUrl,
    Map<String, dynamic>? contentData,
    List<String>? mentionedContactIds,
    List<String>? mentionedNoteIds,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : contentData = contentData ?? {},
        mentionedContactIds = mentionedContactIds ?? [],
        mentionedNoteIds = mentionedNoteIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isTemplateInstance => entryType == 'template_instance' && templateId != null;
  bool get isPersonal => contactId == 'personal' || contactId.isEmpty;
  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;
  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasMentions => mentionedContactIds.isNotEmpty || mentionedNoteIds.isNotEmpty;
  bool get hasContactMentions => mentionedContactIds.isNotEmpty;
  bool get hasNoteMentions => mentionedNoteIds.isNotEmpty;

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final difference = today.difference(entryDay).inDays;

    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final monthStr = months[createdAt.month - 1];

    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Ayer';
    } else if (difference == -1) {
      return 'Mañana';
    } else if (createdAt.year == now.year) {
      return '${createdAt.day} $monthStr';
    } else {
      return '${createdAt.day} $monthStr ${createdAt.year}';
    }
  }

  String get formattedFullDate {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${createdAt.day} de ${months[createdAt.month - 1]} de ${createdAt.year}';
  }

  DiarioEntry copyWith({
    String? id,
    String? contactId,
    String? categoryId,
    String? templateId,
    bool clearTemplate = false,
    String? entryType,
    String? title,
    String? contentText,
    bool clearContentText = false,
    String? photoUrl,
    bool clearPhoto = false,
    Map<String, dynamic>? contentData,
    List<String>? mentionedContactIds,
    List<String>? mentionedNoteIds,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiarioEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      categoryId: categoryId ?? this.categoryId,
      templateId: clearTemplate ? null : (templateId ?? this.templateId),
      entryType: entryType ?? this.entryType,
      title: title ?? this.title,
      contentText: clearContentText ? null : (contentText ?? this.contentText),
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      contentData: contentData ?? this.contentData,
      mentionedContactIds: mentionedContactIds ?? this.mentionedContactIds,
      mentionedNoteIds: mentionedNoteIds ?? this.mentionedNoteIds,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final data = Map<String, dynamic>.from(contentData);
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      data['photo_url'] = photoUrl;
    } else {
      data.remove('photo_url');
    }

    if (mentionedContactIds.isNotEmpty) {
      data['mentioned_contact_ids'] = mentionedContactIds;
    } else {
      data.remove('mentioned_contact_ids');
    }

    if (mentionedNoteIds.isNotEmpty) {
      data['mentioned_note_ids'] = mentionedNoteIds;
    } else {
      data.remove('mentioned_note_ids');
    }

    return {
      'id': id,
      'contact_id': contactId,
      'category_id': categoryId,
      'template_id': templateId,
      'entry_type': entryType,
      'title': title,
      'content_text': contentText,
      'content_data': data,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DiarioEntry.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedData = {};
    if (map['content_data'] is Map) {
      parsedData = Map<String, dynamic>.from(map['content_data']);
    }

    final photo = map['photo_url']?.toString() ??
        parsedData['photo_url']?.toString() ??
        parsedData['photo_path']?.toString();

    parsedData.remove('photo_url');
    parsedData.remove('photo_path');

    final rawMentions = map['mentioned_contact_ids'] ?? parsedData['mentioned_contact_ids'];
    List<String> parsedMentions = [];
    if (rawMentions is List) {
      parsedMentions = rawMentions.map((e) => e.toString()).toList();
    }
    parsedData.remove('mentioned_contact_ids');

    final rawNoteMentions = map['mentioned_note_ids'] ?? parsedData['mentioned_note_ids'];
    List<String> parsedNoteMentions = [];
    if (rawNoteMentions is List) {
      parsedNoteMentions = rawNoteMentions.map((e) => e.toString()).toList();
    }
    parsedData.remove('mentioned_note_ids');

    return DiarioEntry(
      id: map['id']?.toString() ?? '',
      contactId: map['contact_id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      templateId: map['template_id']?.toString(),
      entryType: map['entry_type']?.toString() ?? 'simple_text',
      title: map['title']?.toString() ?? '',
      contentText: map['content_text']?.toString(),
      photoUrl: photo,
      contentData: parsedData,
      mentionedContactIds: parsedMentions,
      mentionedNoteIds: parsedNoteMentions,
      isPinned: map['is_pinned'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
