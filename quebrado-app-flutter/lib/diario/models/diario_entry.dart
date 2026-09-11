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
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : contentData = contentData ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isTemplateInstance => entryType == 'template_instance' && templateId != null;
  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  DiarioEntry copyWith({
    String? id,
    String? contactId,
    String? categoryId,
    String? templateId,
    String? entryType,
    String? title,
    String? contentText,
    String? photoUrl,
    bool clearPhoto = false,
    Map<String, dynamic>? contentData,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiarioEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      categoryId: categoryId ?? this.categoryId,
      templateId: templateId ?? this.templateId,
      entryType: entryType ?? this.entryType,
      title: title ?? this.title,
      contentText: contentText ?? this.contentText,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      contentData: contentData ?? this.contentData,
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

    return {
      'id': id,
      'contact_id': contactId,
      'category_id': categoryId,
      'template_id': templateId,
      'entry_type': entryType,
      'title': title,
      'content_text': contentText,
      'photo_url': photoUrl,
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
