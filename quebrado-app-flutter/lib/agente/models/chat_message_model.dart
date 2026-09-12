import 'package:uuid/uuid.dart';
import 'chat_artifact_model.dart';

enum MessageRole {
  user,
  model,
  system;

  String get code => name;

  static MessageRole fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'model':
      case 'assistant':
        return MessageRole.model;
      case 'system':
      default:
        return MessageRole.system;
    }
  }
}

class ChatMessageModel {
  final String id;
  final String sessionId;
  final String? userId;
  final MessageRole role;
  final String content;
  final List<Map<String, dynamic>> toolCalls;
  final List<ChatArtifactModel> artifacts;
  final bool isStreaming;
  final DateTime createdAt;

  ChatMessageModel({
    String? id,
    required this.sessionId,
    this.userId,
    required this.role,
    required this.content,
    List<Map<String, dynamic>>? toolCalls,
    List<ChatArtifactModel>? artifacts,
    this.isStreaming = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        toolCalls = toolCalls ?? [],
        artifacts = artifacts ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isModel => role == MessageRole.model;
  bool get isSystem => role == MessageRole.system;

  ChatMessageModel copyWith({
    String? id,
    String? sessionId,
    String? userId,
    MessageRole? role,
    String? content,
    List<Map<String, dynamic>>? toolCalls,
    List<ChatArtifactModel>? artifacts,
    bool? isStreaming,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      artifacts: artifacts ?? this.artifacts,
      isStreaming: isStreaming ?? this.isStreaming,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      'role': role.code,
      'content': content,
      'tool_calls': toolCalls,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {List<ChatArtifactModel>? artifacts}) {
    return ChatMessageModel(
      id: map['id']?.toString() ?? const Uuid().v4(),
      sessionId: map['session_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      role: MessageRole.fromString(map['role']?.toString()),
      content: map['content']?.toString() ?? '',
      toolCalls: (map['tool_calls'] is List)
          ? List<Map<String, dynamic>>.from(
              (map['tool_calls'] as List).whereType<Map<String, dynamic>>(),
            )
          : [],
      artifacts: artifacts ?? [],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
