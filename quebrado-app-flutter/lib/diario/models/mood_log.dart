import 'mood_catalog.dart';

enum MoodKind { momentary, daily }

/// Quién reporta el ánimo: yo mismo, o mi percepción de un contacto.
enum MoodPerspective { self, observed, told }

enum MoodSource { manual, checkin, agent, diarioEntry }

extension MoodKindX on MoodKind {
  String get dbValue => this == MoodKind.daily ? 'daily' : 'momentary';
  static MoodKind parse(String? v) => v == 'daily' ? MoodKind.daily : MoodKind.momentary;
}

extension MoodPerspectiveX on MoodPerspective {
  String get dbValue => name;
  String get label {
    switch (this) {
      case MoodPerspective.self:
        return 'Yo';
      case MoodPerspective.observed:
        return 'Lo noté yo';
      case MoodPerspective.told:
        return 'Me lo contó';
    }
  }

  static MoodPerspective parse(String? v) {
    switch (v) {
      case 'observed':
        return MoodPerspective.observed;
      case 'told':
        return MoodPerspective.told;
      default:
        return MoodPerspective.self;
    }
  }
}

extension MoodSourceX on MoodSource {
  String get dbValue => this == MoodSource.diarioEntry ? 'diario_entry' : name;
  static MoodSource parse(String? v) {
    switch (v) {
      case 'checkin':
        return MoodSource.checkin;
      case 'agent':
        return MoodSource.agent;
      case 'diario_entry':
        return MoodSource.diarioEntry;
      default:
        return MoodSource.manual;
    }
  }
}

/// Registro de ánimo. `contactId == null` → registro propio.
class MoodLog {
  final String id;
  final String? userId;
  final String? contactId;
  final MoodPerspective perspective;
  final MoodKind kind;
  final int valence;
  final int? energy;
  final List<String> emotions;
  final List<String> tagIds;
  final List<String> roleIds;
  final List<String> mentionedContactIds;
  final String? note;
  final String? diarioEntryId;
  final MoodSource source;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MoodLog({
    required this.id,
    this.userId,
    this.contactId,
    MoodPerspective? perspective,
    this.kind = MoodKind.momentary,
    required int valence,
    int? energy,
    List<String>? emotions,
    List<String>? tagIds,
    List<String>? roleIds,
    List<String>? mentionedContactIds,
    this.note,
    this.diarioEntryId,
    this.source = MoodSource.manual,
    DateTime? loggedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : perspective = _normalizePerspective(contactId, perspective),
        valence = valence.clamp(MoodCatalog.minValence, MoodCatalog.maxValence),
        energy = energy?.clamp(1, 5),
        emotions = List.unmodifiable(emotions ?? const []),
        tagIds = List.unmodifiable(tagIds ?? const []),
        roleIds = List.unmodifiable(roleIds ?? const []),
        mentionedContactIds = List.unmodifiable(mentionedContactIds ?? const []),
        loggedAt = loggedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Mantiene la regla del CHECK de la BD: propio ⇔ 'self'; contacto ⇔ 'observed' | 'told'.
  static MoodPerspective _normalizePerspective(String? contactId, MoodPerspective? p) {
    final isSelf = contactId == null || contactId.isEmpty;
    if (isSelf) return MoodPerspective.self;
    if (p == null || p == MoodPerspective.self) return MoodPerspective.observed;
    return p;
  }

  bool get isSelf => contactId == null || contactId!.isEmpty;
  bool get isDaily => kind == MoodKind.daily;
  MoodValenceMeta get valenceMeta => MoodCatalog.valenceMeta(valence);

  /// Fecha local (yyyy-MM-dd) usada para agrupar por día.
  String get logDateKey => dateKey(loggedAt);

  static String dateKey(DateTime date) {
    final d = date.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  MoodLog copyWith({
    String? contactId,
    bool clearContact = false,
    MoodPerspective? perspective,
    MoodKind? kind,
    int? valence,
    int? energy,
    bool clearEnergy = false,
    List<String>? emotions,
    List<String>? tagIds,
    List<String>? roleIds,
    List<String>? mentionedContactIds,
    String? note,
    bool clearNote = false,
    String? diarioEntryId,
    bool clearDiarioEntry = false,
    MoodSource? source,
    DateTime? loggedAt,
    DateTime? updatedAt,
  }) {
    return MoodLog(
      id: id,
      userId: userId,
      contactId: clearContact ? null : (contactId ?? this.contactId),
      perspective: perspective ?? this.perspective,
      kind: kind ?? this.kind,
      valence: valence ?? this.valence,
      energy: clearEnergy ? null : (energy ?? this.energy),
      emotions: emotions ?? this.emotions,
      tagIds: tagIds ?? this.tagIds,
      roleIds: roleIds ?? this.roleIds,
      mentionedContactIds: mentionedContactIds ?? this.mentionedContactIds,
      note: clearNote ? null : (note ?? this.note),
      diarioEntryId: clearDiarioEntry ? null : (diarioEntryId ?? this.diarioEntryId),
      source: source ?? this.source,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return [];
  }

  factory MoodLog.fromMap(Map<String, dynamic> map) {
    final contact = map['contact_id']?.toString();
    return MoodLog(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      contactId: (contact == null || contact.isEmpty) ? null : contact,
      perspective: MoodPerspectiveX.parse(map['perspective']?.toString()),
      kind: MoodKindX.parse(map['kind']?.toString()),
      valence: (map['valence'] as num?)?.toInt() ?? 0,
      energy: (map['energy'] as num?)?.toInt(),
      emotions: _stringList(map['emotions']),
      tagIds: _stringList(map['tag_ids']),
      roleIds: _stringList(map['role_ids']),
      mentionedContactIds: _stringList(map['mentioned_contact_ids']),
      note: map['note']?.toString(),
      diarioEntryId: map['diario_entry_id']?.toString(),
      source: MoodSourceX.parse(map['source']?.toString()),
      loggedAt: DateTime.tryParse(map['logged_at']?.toString() ?? '')?.toLocal(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '')?.toLocal(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'contact_id': isSelf ? null : contactId,
      'perspective': perspective.dbValue,
      'kind': kind.dbValue,
      'valence': valence,
      'energy': energy,
      'emotions': emotions,
      'tag_ids': tagIds,
      'role_ids': roleIds,
      'mentioned_contact_ids': mentionedContactIds,
      'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      'diario_entry_id': diarioEntryId,
      'source': source.dbValue,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'log_date': logDateKey,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
