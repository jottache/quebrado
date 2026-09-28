/// Etiqueta de contexto para un registro de ánimo (actividad, social, salud...).
/// Las de sistema (`mtag_*`) se siembran en `supabase/013_animo_schema.sql`
/// y se replican aquí como respaldo offline.
class MoodTag {
  final String id;
  final String? userId;
  final String name;
  final String emoji;
  final String groupKey;
  final String colorHex;
  final int sortOrder;
  final bool isSystem;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  MoodTag({
    required this.id,
    this.userId,
    required this.name,
    this.emoji = '🏷️',
    this.groupKey = 'otro',
    this.colorHex = '#6366F1',
    this.sortOrder = 0,
    this.isSystem = false,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const Map<String, String> groupLabels = {
    'actividad': 'Actividad',
    'social': 'Social',
    'salud': 'Salud',
    'lugar': 'Lugar',
    'finanzas': 'Finanzas',
    'clima': 'Clima',
    'otro': 'Otro',
  };

  static String groupLabel(String key) => groupLabels[key] ?? 'Otro';

  static List<MoodTag> defaultTags() {
    MoodTag t(String id, String name, String emoji, String group, String color, int order) => MoodTag(
          id: id,
          name: name,
          emoji: emoji,
          groupKey: group,
          colorHex: color,
          sortOrder: order,
          isSystem: true,
        );

    return [
      t('mtag_trabajo', 'Trabajo', '💼', 'actividad', '#3B82F6', 0),
      t('mtag_ejercicio', 'Ejercicio', '🏃', 'actividad', '#10B981', 1),
      t('mtag_lectura', 'Lectura', '📚', 'actividad', '#8B5CF6', 2),
      t('mtag_estudio', 'Estudio', '🎓', 'actividad', '#6366F1', 3),
      t('mtag_descanso', 'Descanso', '🛋️', 'actividad', '#14B8A6', 4),
      t('mtag_hogar', 'Tareas del hogar', '🧹', 'actividad', '#F59E0B', 5),
      t('mtag_hobby', 'Hobby', '🎨', 'actividad', '#EC4899', 6),
      t('mtag_pantallas', 'Mucha pantalla', '📱', 'actividad', '#64748B', 7),
      t('mtag_familia', 'Familia', '👨‍👩‍👧', 'social', '#F97316', 10),
      t('mtag_pareja', 'Pareja', '❤️', 'social', '#EF4444', 11),
      t('mtag_amigos', 'Amigos', '🧑‍🤝‍🧑', 'social', '#F59E0B', 12),
      t('mtag_solo', 'Tiempo a solas', '🧘', 'social', '#14B8A6', 13),
      t('mtag_reunion', 'Reuniones', '🗣️', 'social', '#3B82F6', 14),
      t('mtag_conflicto', 'Discusión', '⚡', 'social', '#DC2626', 15),
      t('mtag_dormi_bien', 'Dormí bien', '😴', 'salud', '#22C55E', 20),
      t('mtag_dormi_mal', 'Dormí mal', '🥱', 'salud', '#A855F7', 21),
      t('mtag_comi_bien', 'Comí sano', '🥗', 'salud', '#16A34A', 22),
      t('mtag_comida_chatarra', 'Comida chatarra', '🍔', 'salud', '#EA580C', 23),
      t('mtag_enfermo', 'Enfermo / Dolor', '🤒', 'salud', '#DC2626', 24),
      t('mtag_alcohol', 'Alcohol', '🍷', 'salud', '#9F1239', 25),
      t('mtag_cafeina', 'Mucha cafeína', '☕', 'salud', '#78350F', 26),
      t('mtag_casa', 'Casa', '🏠', 'lugar', '#0EA5E9', 30),
      t('mtag_oficina', 'Oficina', '🏢', 'lugar', '#475569', 31),
      t('mtag_viaje', 'Calle / Viaje', '🚗', 'lugar', '#F59E0B', 32),
      t('mtag_naturaleza', 'Naturaleza', '🌳', 'lugar', '#15803D', 33),
      t('mtag_estres_dinero', 'Preocupación por dinero', '💸', 'finanzas', '#B91C1C', 40),
      t('mtag_logro_dinero', 'Logro financiero', '💰', 'finanzas', '#15803D', 41),
      t('mtag_soleado', 'Soleado', '☀️', 'clima', '#FACC15', 50),
      t('mtag_lluvia', 'Lluvia', '🌧️', 'clima', '#60A5FA', 51),
    ];
  }

  MoodTag copyWith({
    String? name,
    String? emoji,
    String? groupKey,
    String? colorHex,
    int? sortOrder,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return MoodTag(
      id: id,
      userId: userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      groupKey: groupKey ?? this.groupKey,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory MoodTag.fromMap(Map<String, dynamic> map) {
    return MoodTag(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '🏷️',
      groupKey: map['group_key']?.toString() ?? 'otro',
      colorHex: map['color_hex']?.toString() ?? '#6366F1',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isSystem: map['is_system'] == true,
      archived: map['archived'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'emoji': emoji,
      'group_key': groupKey,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'is_system': isSystem,
      'archived': archived,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
