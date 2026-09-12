import 'package:uuid/uuid.dart';

enum ArtifactType {
  financialSummary,
  calculation,
  contactCard,
  reminderList,
  habitReport,
  table,
  note;

  String get code {
    switch (this) {
      case ArtifactType.financialSummary:
        return 'financial_summary';
      case ArtifactType.calculation:
        return 'calculation';
      case ArtifactType.contactCard:
        return 'contact_card';
      case ArtifactType.reminderList:
        return 'reminder_list';
      case ArtifactType.habitReport:
        return 'habit_report';
      case ArtifactType.table:
        return 'table';
      case ArtifactType.note:
        return 'note';
    }
  }

  String get label {
    switch (this) {
      case ArtifactType.financialSummary:
        return 'Resumen Financiero';
      case ArtifactType.calculation:
        return 'Cálculo Monetario';
      case ArtifactType.contactCard:
        return 'Ficha de Contacto';
      case ArtifactType.reminderList:
        return 'Lista de Tareas';
      case ArtifactType.habitReport:
        return 'Reporte de Hábitos';
      case ArtifactType.table:
        return 'Tabla Comparativa';
      case ArtifactType.note:
        return 'Nota / Resumen';
    }
  }

  static ArtifactType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'financial_summary':
      case 'financial':
        return ArtifactType.financialSummary;
      case 'calculation':
      case 'calc':
        return ArtifactType.calculation;
      case 'contact_card':
      case 'contact':
        return ArtifactType.contactCard;
      case 'reminder_list':
      case 'reminders':
        return ArtifactType.reminderList;
      case 'habit_report':
      case 'habits':
        return ArtifactType.habitReport;
      case 'table':
        return ArtifactType.table;
      case 'note':
      default:
        return ArtifactType.note;
    }
  }
}

class ChatArtifactModel {
  final String id;
  final String sessionId;
  final String? messageId;
  final String? userId;
  final ArtifactType type;
  final String title;
  final String content;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  ChatArtifactModel({
    String? id,
    required this.sessionId,
    this.messageId,
    this.userId,
    required this.type,
    required this.title,
    required this.content,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        metadata = metadata ?? {},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      'type': type.code,
      'title': title,
      'content': content,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatArtifactModel.fromMap(Map<String, dynamic> map) {
    return ChatArtifactModel(
      id: map['id']?.toString() ?? const Uuid().v4(),
      sessionId: map['session_id']?.toString() ?? '',
      messageId: map['message_id']?.toString(),
      userId: map['user_id']?.toString(),
      type: ArtifactType.fromString(map['type']?.toString()),
      title: map['title']?.toString() ?? 'Artefacto',
      content: map['content']?.toString() ?? '',
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata']) : {},
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
