import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_artifact_model.dart';

class AgenteSupabaseService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _client != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Obtiene todas las sesiones de chat del usuario ordenadas por fecha reciente
  Future<List<ChatSessionModel>> getSessions() async {
    final client = _client;
    if (client == null) return [];
    try {
      final res = await client
          .from('chat_sessions')
          .select('*, chat_messages(count)')
          .order('updated_at', ascending: false);

      return (res as List).map((row) {
        final countList = row['chat_messages'] as List?;
        final count = (countList != null && countList.isNotEmpty)
            ? (countList.first['count'] as int? ?? 0)
            : 0;
        return ChatSessionModel.fromMap(row, messageCount: count);
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo sesiones de chat en Supabase: $e');
      return [];
    }
  }

  /// Crea o actualiza una sesión de chat
  Future<ChatSessionModel?> saveSession(ChatSessionModel session) async {
    final client = _client;
    if (client == null) return session;
    try {
      final map = session.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;

      await client.from('chat_sessions').upsert(map);
      return session;
    } catch (e) {
      debugPrint('Error guardando sesión de chat en Supabase: $e');
      return session;
    }
  }

  /// Elimina una sesión y sus mensajes en cascada
  Future<bool> deleteSession(String sessionId) async {
    final client = _client;
    if (client == null) return true;
    try {
      await client.from('chat_sessions').delete().eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('Error eliminando sesión de chat en Supabase: $e');
      return false;
    }
  }

  /// Obtiene los mensajes de una sesión con sus artefactos
  Future<List<ChatMessageModel>> getMessages(String sessionId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final msgRes = await client
          .from('chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final artRes = await client
          .from('chat_artifacts')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final artifacts = (artRes as List)
          .map((r) => ChatArtifactModel.fromMap(r))
          .toList();

      return (msgRes as List).map((row) {
        final msgId = row['id']?.toString();
        final msgArtifacts = artifacts.where((a) => a.messageId == msgId).toList();
        return ChatMessageModel.fromMap(row, artifacts: msgArtifacts);
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo mensajes en Supabase: $e');
      return [];
    }
  }

  /// Guarda un mensaje de chat
  Future<ChatMessageModel> saveMessage(ChatMessageModel message) async {
    final client = _client;
    if (client == null) return message;
    try {
      final map = message.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;

      await client.from('chat_messages').upsert(map);

      // Guardar artefactos asociados
      for (final art in message.artifacts) {
        await saveArtifact(art);
      }
      return message;
    } catch (e) {
      debugPrint('Error guardando mensaje en Supabase: $e');
      return message;
    }
  }

  /// Guarda un artefacto
  Future<ChatArtifactModel> saveArtifact(ChatArtifactModel artifact) async {
    final client = _client;
    if (client == null) return artifact;
    try {
      final map = artifact.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;

      await client.from('chat_artifacts').upsert(map);
      return artifact;
    } catch (e) {
      debugPrint('Error guardando artefacto en Supabase: $e');
      return artifact;
    }
  }

  /// Obtiene todos los artefactos guardados para la galería de artefactos
  Future<List<ChatArtifactModel>> getAllArtifacts() async {
    final client = _client;
    if (client == null) return [];
    try {
      final res = await client
          .from('chat_artifacts')
          .select()
          .order('created_at', ascending: false);

      return (res as List).map((r) => ChatArtifactModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error obteniendo todos los artefactos en Supabase: $e');
      return [];
    }
  }
}
