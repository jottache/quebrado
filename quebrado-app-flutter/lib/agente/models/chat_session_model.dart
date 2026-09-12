import 'package:uuid/uuid.dart';

class ChatSessionModel {
  final String id;
  final String? userId;
  final String title;
  final bool pinned;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSessionModel({
    String? id,
    this.userId,
    this.title = 'Nueva conversación',
    this.pinned = false,
    this.messageCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ChatSessionModel copyWith({
    String? id,
    String? userId,
    String? title,
    bool? pinned,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      pinned: pinned ?? this.pinned,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'pinned': pinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ChatSessionModel.fromMap(Map<String, dynamic> map, {int messageCount = 0}) {
    return ChatSessionModel(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      title: map['title']?.toString() ?? 'Nueva conversación',
      pinned: map['pinned'] == true,
      messageCount: messageCount,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
