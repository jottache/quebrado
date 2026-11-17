// Fila realista de `diario_contacts` tal como la devuelve PostgREST
// (columnas de supabase/004_diario_jottache_schema.sql: DATE como 'YYYY-MM-DD',
// TIMESTAMPTZ en ISO con zona, BOOLEAN como bool).
// Sobrescribe solo lo que le importa al test: diarioContactRow(id: 'c2', isFavorite: true).
Map<String, dynamic> diarioContactRow({
  String id = 'c1',
  String name = 'Ana Pérez',
  String? nickname = 'Anita',
  String? relationship = 'Amiga',
  String? avatarUrl,
  String? avatarColor = '#1F6F5F',
  String? birthdate = '1990-05-14',
  String? phone = '04121234567',
  String? notes,
  bool isFavorite = false,
  String? userId = '00000000-0000-0000-0000-000000000001',
  String createdAt = '2026-01-10T12:00:00+00:00',
  String updatedAt = '2026-01-10T12:00:00+00:00',
}) =>
    {
      'id': id,
      'name': name,
      'nickname': nickname,
      'relationship': relationship,
      'avatar_url': avatarUrl,
      'avatar_color': avatarColor,
      'birthdate': birthdate,
      'phone': phone,
      'notes': notes,
      'is_favorite': isFavorite,
      'user_id': userId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
