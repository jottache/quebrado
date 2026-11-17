import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_category.dart';
import '../models/note_item.dart';

class NotasSupabaseService {
  static final NotasSupabaseService instance = NotasSupabaseService._init();
  NotasSupabaseService._init();

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  // ===========================================================================
  // CATEGORÍAS
  // ===========================================================================

  List<NoteCategory> getDefaultCategories() => NoteCategory.defaultCategories();

  Future<List<NoteCategory>> getCategories() async {
    if (!isReady) return getDefaultCategories();

    try {
      final List response = await client!
          .from('note_categories')
          .select()
          .order('sort_order', ascending: true);

      if (response.isEmpty) {
        // Inicializar categorías por defecto para el usuario si es la primera vez
        final defaults = getDefaultCategories();
        for (final cat in defaults) {
          await saveCategory(cat);
        }
        return defaults;
      }

      return response
          .map((row) => NoteCategory.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando categorías de notas locales/reserva ($e)');
      return getDefaultCategories();
    }
  }

  Future<void> saveCategory(NoteCategory category) async {
    if (!isReady) return;
    try {
      final map = category.toSupabaseMap();
      final user = client?.auth.currentUser;
      if (user != null) {
        map['user_id'] = user.id;
      }
      await client!.from('note_categories').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando categoría de nota en Supabase: $e');
    }
  }

  /// Elimina una categoría reasignando previamente todas las notas asociadas
  /// hacia la categoría de respaldo 'defaultCategoryId' (nunca se pierden notas)
  Future<void> deleteCategory(String categoryId, {required String defaultCategoryId}) async {
    if (!isReady) return;
    try {
      // 1. Reasignar notas hacia la categoría por defecto
      await client!
          .from('notas')
          .update({'category_id': defaultCategoryId})
          .eq('category_id', categoryId);

      // 2. Eliminar la categoría (las de sistema no deben poder borrarse)
      await client!
          .from('note_categories')
          .delete()
          .eq('id', categoryId)
          .eq('is_system', false);
    } catch (e) {
      debugPrint('Error eliminando categoría de nota en Supabase: $e');
    }
  }

  // ===========================================================================
  // NOTAS & ACUERDOS
  // ===========================================================================

  Future<List<NoteItem>> getNotes() async {
    if (!isReady) return [];
    try {
      final List response = await client!
          .from('notas')
          .select()
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);

      return response
          .map((row) => NoteItem.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando lista vacía/local de notas ($e)');
      return [];
    }
  }

  /// true si la columna `document` (migración 016) todavía no existe en Supabase.
  bool _documentColumnMissing = false;

  Future<void> saveNote(NoteItem note) async {
    if (!isReady) return;
    final map = note.toSupabaseMap();
    final user = client?.auth.currentUser;
    if (user != null) {
      map['user_id'] = user.id;
    }
    if (_documentColumnMissing) map.remove('document');

    try {
      await client!.from('notas').upsert(map, onConflict: 'id');
    } on PostgrestException catch (e) {
      // Sin la migración 016 no existe `document`: se guarda igual en el formato anterior
      // (blocks + content_text) para no perder la nota.
      final missingColumn = map.containsKey('document') &&
          (e.code == 'PGRST204' || e.message.contains('document'));
      if (!missingColumn) {
        debugPrint('Error guardando nota en Supabase: $e');
        return;
      }
      _documentColumnMissing = true;
      debugPrint('Notas: falta la columna "document" (ejecuta supabase/016_notas_documento_enriquecido.sql). Guardando sin formato enriquecido.');
      map.remove('document');
      try {
        await client!.from('notas').upsert(map, onConflict: 'id');
      } catch (e2) {
        debugPrint('Error guardando nota en Supabase: $e2');
      }
    } catch (e) {
      debugPrint('Error guardando nota en Supabase: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    if (!isReady) return;
    try {
      await client!.from('notas').delete().eq('id', noteId);
    } catch (e) {
      debugPrint('Error eliminando nota en Supabase: $e');
    }
  }
}
