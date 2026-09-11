import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../../services/supabase_config.dart';

class RemindersSupabaseService {
  final SupabaseClient? _client;
  final _uuid = const Uuid();
  RealtimeChannel? _realtimeChannel;

  RemindersSupabaseService({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? Supabase.instance.client : null);

  bool get isRemoteAvailable => _client != null && SupabaseConfig.isConfigured;

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Carga inicial de recordatorios
  Future<List<ReminderModel>> fetchReminders() async {
    if (!isRemoteAvailable) {
      debugPrint('[Reminders] Supabase no configurado, usando datos locales');
      return _generateDefaultSeedReminders();
    }

    try {
      final response = await _client!
          .from('reminders')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => ReminderModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (list.isEmpty) {
        debugPrint('[Reminders] Base de datos vacía, insertando semillas iniciales');
        final seeds = _generateDefaultSeedReminders();
        for (final r in seeds) {
          await saveReminder(r);
        }
        return seeds;
      }

      return list;
    } catch (e) {
      debugPrint('[Reminders] Error al obtener recordatorios de Supabase: $e');
      return _generateDefaultSeedReminders();
    }
  }

  /// Guardar o actualizar un recordatorio
  Future<bool> saveReminder(ReminderModel reminder) async {
    if (!isRemoteAvailable) return true;

    try {
      final data = reminder.toMap();
      if (currentUserId != null) {
        data['user_id'] = currentUserId;
      }
      await _client!.from('reminders').upsert(data);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al guardar recordatorio: $e');
      return false;
    }
  }

  /// Eliminar recordatorio
  Future<bool> deleteReminder(String id) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('reminders').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al eliminar recordatorio: $e');
      return false;
    }
  }

  /// Actualizar estado rápidamente
  Future<bool> updateStatus(String id, ReminderStatus status) async {
    if (!isRemoteAvailable) return true;

    try {
      final updates = <String, dynamic>{
        'status': status.code,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (status == ReminderStatus.completed) {
        updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
      } else {
        updates['completed_at'] = null;
      }

      await _client!.from('reminders').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al actualizar estado: $e');
      return false;
    }
  }

  /// Posponer (Snooze) con nueva fecha
  Future<bool> snoozeReminder(String id, DateTime newDueAt) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('reminders').update({
        'status': ReminderStatus.snoozed.code,
        'due_at': newDueAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al posponer recordatorio: $e');
      return false;
    }
  }

  /// Suscribirse a cambios en tiempo real en la tabla `reminders`
  void subscribeToRealtime({
    required Function(ReminderModel reminder) onInsert,
    required Function(ReminderModel reminder) onUpdate,
    required Function(String id) onDelete,
  }) {
    if (!isRemoteAvailable) return;

    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _client!
          .channel('public:reminders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reminders',
            callback: (payload) {
              final eventType = payload.eventType;
              if (eventType == PostgresChangeEvent.insert && payload.newRecord.isNotEmpty) {
                final model = ReminderModel.fromMap(payload.newRecord);
                onInsert(model);
              } else if (eventType == PostgresChangeEvent.update && payload.newRecord.isNotEmpty) {
                final model = ReminderModel.fromMap(payload.newRecord);
                onUpdate(model);
              } else if (eventType == PostgresChangeEvent.delete && payload.oldRecord.isNotEmpty) {
                final id = payload.oldRecord['id']?.toString();
                if (id != null) onDelete(id);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[Reminders] Error al suscribir a Supabase Realtime: $e');
    }
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
  }

  /// Datos iniciales amigables de bienvenida para el usuario
  List<ReminderModel> _generateDefaultSeedReminders() {
    final now = DateTime.now();

    return [
      ReminderModel(
        id: _uuid.v4(),
        title: 'Revisar balance mensual en Quebrado',
        notes: 'Verificar ahorros en bolsillos y gastos categorizados del mes',
        priority: ReminderPriority.p1Urgent,
        status: ReminderStatus.pending,
        dueAt: DateTime(now.year, now.month, now.day, 18, 0),
        isNagging: true,
        tags: ['finanzas', 'mensual'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Llamar a mamá por su cumpleaños',
        notes: 'Revisar en Diario Jottache las notas de su comida preferida',
        priority: ReminderPriority.p2High,
        status: ReminderStatus.pending,
        dueAt: DateTime(now.year, now.month, now.day, 20, 30),
        tags: ['familia', 'cumpleaños'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Completar racha de lectura de 20 páginas',
        notes: 'Marcar registro diario en la app de Hábitos',
        priority: ReminderPriority.p3Medium,
        status: ReminderStatus.pending,
        dueAt: DateTime(now.year, now.month, now.day + 1, 9, 0),
        tags: ['habitos', 'lectura'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Respaldar base de datos local de la Super App',
        priority: ReminderPriority.p4Low,
        status: ReminderStatus.completed,
        completedAt: now.subtract(const Duration(hours: 2)),
        tags: ['sistema'],
      ),
    ];
  }
}
