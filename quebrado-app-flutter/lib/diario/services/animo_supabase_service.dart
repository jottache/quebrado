import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mood_log.dart';
import '../models/mood_tag.dart';

/// Acceso a Supabase del módulo Ánimo (tablas `mood_logs` y `mood_tags`, migración 013).
/// A diferencia de los otros servicios, los métodos de escritura lanzan la excepción
/// para que `AnimoState` pueda encolar el registro y reintentarlo.
class AnimoSupabaseService {
  static final AnimoSupabaseService instance = AnimoSupabaseService._init();
  AnimoSupabaseService._init();

  @visibleForTesting
  AnimoSupabaseService.forTesting();

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  String? get _currentUserId => client?.auth.currentUser?.id;

  // ===========================================================================
  // REGISTROS DE ÁNIMO
  // ===========================================================================

  Future<List<MoodLog>> getLogs({DateTime? since}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('mood_logs').select();
      if (since != null) {
        query = query.gte('logged_at', since.toUtc().toIso8601String());
      }
      final List response = await query.order('logged_at', ascending: false);
      return response.map((row) => MoodLog.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Info: No se pudieron cargar los registros de ánimo ($e)');
      return [];
    }
  }

  Future<void> saveLog(MoodLog log) async {
    if (!isReady) throw StateError('Supabase no está configurado');
    final map = log.toSupabaseMap();
    final userId = _currentUserId;
    if (userId != null) map['user_id'] = userId;
    await client!.from('mood_logs').upsert(map, onConflict: 'id');
  }

  Future<void> deleteLog(String id) async {
    if (!isReady) throw StateError('Supabase no está configurado');
    await client!.from('mood_logs').delete().eq('id', id);
  }

  // ===========================================================================
  // ETIQUETAS
  // ===========================================================================

  Future<List<MoodTag>> getTags() async {
    if (!isReady) return MoodTag.defaultTags();
    try {
      final List response = await client!.from('mood_tags').select().order('sort_order', ascending: true);
      if (response.isEmpty) return MoodTag.defaultTags();
      return response.map((row) => MoodTag.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Info: Usando etiquetas de ánimo locales ($e)');
      return MoodTag.defaultTags();
    }
  }

  Future<void> saveTag(MoodTag tag) async {
    if (!isReady) return;
    try {
      final map = tag.toSupabaseMap();
      final userId = _currentUserId;
      if (userId != null && !tag.isSystem) map['user_id'] = userId;
      await client!.from('mood_tags').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando etiqueta de ánimo en Supabase: $e');
    }
  }
}
