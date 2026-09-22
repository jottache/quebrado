import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../models/weekly_plan_model.dart';
import '../../services/supabase_config.dart';

class RemindersSupabaseService {
  final SupabaseClient? _client;
  final _uuid = const Uuid();
  RealtimeChannel? _remindersChannel;
  RealtimeChannel? _rolesChannel;
  RealtimeChannel? _plansChannel;

  RemindersSupabaseService({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? Supabase.instance.client : null);

  bool get isRemoteAvailable => _client != null && SupabaseConfig.isConfigured;

  String? get currentUserId => _client?.auth.currentUser?.id;

  // ==========================================
  // RECORDATORIOS (REMINDERS)
  // ==========================================

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

  /// Reasignar día programado de la semana y fecha para el cronograma flexible
  Future<bool> scheduleReminderDay(String id, int dayOfWeek, DateTime newDueAt) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('reminders').update({
        'scheduled_day_of_week': dayOfWeek,
        'due_at': newDueAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al mover recordatorio de día: $e');
      return false;
    }
  }

  /// Cambiar cuadrante Covey (Q1-Q4)
  Future<bool> updateQuadrant(String id, CoveyQuadrant quadrant) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('reminders').update({
        'quadrant': quadrant.code,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al actualizar cuadrante: $e');
      return false;
    }
  }

  /// Conmutar bandera de Gran Roca (Big Rock)
  Future<bool> toggleBigRock(String id, bool isBigRock) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('reminders').update({
        'is_big_rock': isBigRock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al actualizar Big Rock: $e');
      return false;
    }
  }

  // ==========================================
  // ROLES DE VIDA (ROLES)
  // ==========================================

  /// Obtiene los roles de vida del usuario
  Future<List<RoleModel>> fetchRoles() async {
    final effectiveUserId = currentUserId ?? 'local-user';
    if (!isRemoteAvailable) {
      return RoleModel.defaultSeeds(effectiveUserId);
    }

    try {
      final response = await _client!
          .from('roles')
          .select()
          .order('order_index', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => RoleModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (list.isEmpty) {
        debugPrint('[Reminders] No hay roles configurados, creando semillas por defecto');
        final seeds = RoleModel.defaultSeeds(effectiveUserId);
        for (final r in seeds) {
          await saveRole(r);
        }
        return seeds;
      }

      return list;
    } catch (e) {
      debugPrint('[Reminders] Error al obtener roles de Supabase: $e');
      return RoleModel.defaultSeeds(effectiveUserId);
    }
  }

  /// Guardar o actualizar un rol
  Future<bool> saveRole(RoleModel role) async {
    if (!isRemoteAvailable) return true;

    try {
      final data = role.toMap();
      if (currentUserId != null) {
        data['user_id'] = currentUserId;
      }
      await _client!.from('roles').upsert(data);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al guardar rol: $e');
      return false;
    }
  }

  /// Eliminar un rol
  Future<bool> deleteRole(String id) async {
    if (!isRemoteAvailable) return true;

    try {
      await _client!.from('roles').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al eliminar rol: $e');
      return false;
    }
  }

  // ==========================================
  // PLAN SEMANAL (WEEKLY PLANS)
  // ==========================================

  /// Obtiene el plan de la semana actual o lo crea si no existe
  Future<WeeklyPlanModel> fetchOrCreateCurrentWeeklyPlan() async {
    final effectiveUserId = currentUserId ?? 'local-user';
    final monday = WeeklyPlanModel.normalizeToMonday(DateTime.now());
    final mondayStr = DateFormat('yyyy-MM-dd').format(monday);

    if (!isRemoteAvailable) {
      return WeeklyPlanModel(
        id: 'local-week-$mondayStr',
        userId: effectiveUserId,
        weekStartDate: monday,
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client!
          .from('weekly_plans')
          .select()
          .eq('week_start_date', mondayStr)
          .maybeSingle();

      if (response != null) {
        return WeeklyPlanModel.fromMap(Map<String, dynamic>.from(response));
      }

      // Si no existe, creamos el plan semanal inicial
      final newPlan = WeeklyPlanModel(
        id: _uuid.v4(),
        userId: effectiveUserId,
        weekStartDate: monday,
        createdAt: DateTime.now(),
      );
      await saveWeeklyPlan(newPlan);
      return newPlan;
    } catch (e) {
      debugPrint('[Reminders] Error al obtener/crear plan semanal: $e');
      return WeeklyPlanModel(
        id: _uuid.v4(),
        userId: effectiveUserId,
        weekStartDate: monday,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Guardar o actualizar plan semanal
  Future<bool> saveWeeklyPlan(WeeklyPlanModel plan) async {
    if (!isRemoteAvailable) return true;

    try {
      final data = plan.toMap();
      if (currentUserId != null) {
        data['user_id'] = currentUserId;
      }
      await _client!.from('weekly_plans').upsert(data);
      return true;
    } catch (e) {
      debugPrint('[Reminders] Error al guardar plan semanal: $e');
      return false;
    }
  }

  // ==========================================
  // REALTIME
  // ==========================================

  /// Suscribirse a cambios en tiempo real en recordatorios
  void subscribeToRealtime({
    required Function(ReminderModel reminder) onInsert,
    required Function(ReminderModel reminder) onUpdate,
    required Function(String id) onDelete,
  }) {
    if (!isRemoteAvailable) return;

    try {
      _remindersChannel?.unsubscribe();
      _remindersChannel = _client!
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
    _remindersChannel?.unsubscribe();
    _rolesChannel?.unsubscribe();
    _plansChannel?.unsubscribe();
  }

  /// Datos iniciales amigables de bienvenida para el usuario con Cuadrante II y Grandes Rocas
  List<ReminderModel> _generateDefaultSeedReminders() {
    final now = DateTime.now();
    final monday = WeeklyPlanModel.normalizeToMonday(now);

    return [
      ReminderModel(
        id: _uuid.v4(),
        title: 'Planificar semana con el Cuadrante II',
        notes: 'Identificar las 1-3 Grandes Rocas para cada rol vital antes de llenar la agenda con arena.',
        priority: ReminderPriority.p1Urgent,
        status: ReminderStatus.pending,
        isPinned: true,
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: true,
        scheduledDayOfWeek: 0, // Lunes
        estimatedDurationMinutes: 45,
        dueAt: DateTime(monday.year, monday.month, monday.day, 9, 0),
        tags: ['planificacion', 'covey', 'q2'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Sesión de ejercicio cardiovascular y estiramiento',
        notes: 'Cuidar la dimensión física y renovar la energía para toda la semana.',
        priority: ReminderPriority.p2High,
        status: ReminderStatus.pending,
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: true,
        scheduledDayOfWeek: 1, // Martes
        estimatedDurationMinutes: 60,
        dueAt: DateTime(monday.year, monday.month, monday.day + 1, 7, 0),
        tags: ['salud', 'ejercicio'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Cena familiar sin pantallas ni interrupciones',
        notes: 'Conversar con la familia, escuchar activamente y nutrir la cuenta bancaria emocional.',
        priority: ReminderPriority.p2High,
        status: ReminderStatus.pending,
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: true,
        scheduledDayOfWeek: 4, // Viernes
        estimatedDurationMinutes: 90,
        dueAt: DateTime(monday.year, monday.month, monday.day + 4, 20, 0),
        tags: ['familia', 'relaciones'],
      ),
      ReminderModel(
        id: _uuid.v4(),
        title: 'Revisión y optimización de arquitectura de software',
        notes: 'Prevenir deuda técnica y documentar decisiones críticas de los módulos principales.',
        priority: ReminderPriority.p3Medium,
        status: ReminderStatus.pending,
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: false,
        scheduledDayOfWeek: 2, // Miércoles
        estimatedDurationMinutes: 120,
        dueAt: DateTime(monday.year, monday.month, monday.day + 2, 11, 0),
        tags: ['profesional', 'arquitectura'],
      ),
    ];
  }
}
