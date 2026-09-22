import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../models/weekly_plan_model.dart';
import '../services/nlp_parser.dart';
import '../services/reminders_supabase_service.dart';

class RemindersState extends ChangeNotifier {
  final RemindersSupabaseService _service;
  final _uuid = const Uuid();

  List<ReminderModel> _reminders = [];
  List<RoleModel> _roles = [];
  WeeklyPlanModel? _currentWeeklyPlan;
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTagFilter;
  ReminderPriority? _selectedPriorityFilter;
  CoveyQuadrant? _selectedQuadrantFilter;
  String? _selectedRoleFilter;
  String _selectedView = 'weekly'; // 'weekly' (default), 'matrix', 'classic'
  Future<void>? _initFuture;

  RemindersState({RemindersSupabaseService? service})
      : _service = service ?? RemindersSupabaseService() {
    init();
  }

  bool get isLoading => _isLoading;
  List<ReminderModel> get allReminders => List.unmodifiable(_reminders);
  List<RoleModel> get roles => List.unmodifiable(_roles);
  WeeklyPlanModel? get currentWeeklyPlan => _currentWeeklyPlan;
  String get searchQuery => _searchQuery;
  String? get selectedTagFilter => _selectedTagFilter;
  ReminderPriority? get selectedPriorityFilter => _selectedPriorityFilter;
  CoveyQuadrant? get selectedQuadrantFilter => _selectedQuadrantFilter;
  String? get selectedRoleFilter => _selectedRoleFilter;
  String get selectedView => _selectedView;

  // Conteo rápido
  int get overdueCount => overdueReminders.length;
  int get todayCount => todayReminders.length;
  int get pendingTotalCount => _reminders.where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed).length;
  int get completedCount => completedReminders.length;

  // Lista de todas las etiquetas únicas existentes
  List<String> get allTags {
    final Set<String> set = {};
    for (final r in _reminders) {
      set.addAll(r.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  void setSelectedView(String view) {
    if (_selectedView != view) {
      _selectedView = view;
      notifyListeners();
    }
  }

  // Filtrado general por texto, tag, prioridad, cuadrante y rol
  List<ReminderModel> get _filteredList {
    return _reminders.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = r.title.toLowerCase().contains(q);
        final matchNotes = r.notes?.toLowerCase().contains(q) ?? false;
        final matchTag = r.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchTitle && !matchNotes && !matchTag) return false;
      }
      if (_selectedTagFilter != null && !r.tags.contains(_selectedTagFilter)) {
        return false;
      }
      if (_selectedPriorityFilter != null && r.priority != _selectedPriorityFilter) {
        return false;
      }
      if (_selectedQuadrantFilter != null && r.quadrant != _selectedQuadrantFilter) {
        return false;
      }
      if (_selectedRoleFilter != null && r.roleId != _selectedRoleFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // ==========================================
  // HÁBITO 3: BRÚJULA SEMANAL & GRANDES ROCAS
  // ==========================================

  /// Lunes que define el inicio de la semana actual activa
  DateTime get currentMonday {
    return _currentWeeklyPlan?.weekStartDate ?? WeeklyPlanModel.normalizeToMonday(DateTime.now());
  }

  /// Retorna las fechas de los 7 días de la semana actual (Lunes a Domingo)
  List<DateTime> get currentWeekDays {
    final monday = currentMonday;
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Grandes Rocas de la semana actual (activas o completadas)
  List<ReminderModel> get bigRocksForCurrentWeek {
    final monday = currentMonday;
    final sundayEnd = monday.add(const Duration(days: 7));

    return _reminders.where((r) {
      if (!r.isBigRock || r.isArchived) return false;
      if (r.weeklyPlanId != null && r.weeklyPlanId == _currentWeeklyPlan?.id) return true;
      if (r.dueAt != null) {
        return r.dueAt!.isAfter(monday.subtract(const Duration(seconds: 1))) &&
            r.dueAt!.isBefore(sundayEnd);
      }
      return r.scheduledDayOfWeek != null;
    }).toList();
  }

  /// Grandes Rocas asociadas a un rol específico
  List<ReminderModel> bigRocksForRole(String roleId) {
    return bigRocksForCurrentWeek.where((r) => r.roleId == roleId).toList();
  }

  /// Cuenta de Grandes Rocas para un rol
  int countBigRocksForRole(String roleId) {
    return bigRocksForRole(roleId).length;
  }

  /// Indica si un rol tiene al menos una Gran Roca definida para la semana
  bool roleHasBigRock(String roleId) {
    return countBigRocksForRole(roleId) > 0;
  }

  /// Roles desatendidos (que tienen 0 Grandes Rocas esta semana)
  List<RoleModel> get unaddressedRoles {
    return _roles.where((role) => !roleHasBigRock(role.id)).toList();
  }

  /// Busca un rol por su identificador
  RoleModel? getRoleById(String? id) {
    if (id == null) return null;
    try {
      return _roles.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // CRONOGRAMA SEMANAL (7 DÍAS FLEXIBLES)
  // ==========================================

  /// Obtiene los recordatorios agendados para un día específico de la semana (0=Lunes, ..., 6=Domingo)
  List<ReminderModel> remindersForDayOfWeek(int dayIndex) {
    final monday = currentMonday;
    final targetDay = monday.add(Duration(days: dayIndex));

    return _filteredList.where((r) {
      if (r.isCompleted || r.isArchived) return false;

      // 1. Asignado explícitamente por el planificador semanal
      if (r.scheduledDayOfWeek == dayIndex) return true;

      // 2. Coincide con la fecha dueAt dentro de la semana
      if (r.dueAt != null) {
        final local = r.dueAt!.toLocal();
        return local.year == targetDay.year &&
            local.month == targetDay.month &&
            local.day == targetDay.day;
      }

      return false;
    }).toList()
      ..sort((a, b) {
        // Primero Grandes Rocas, luego por hora o creación
        if (a.isBigRock && !b.isBigRock) return -1;
        if (!a.isBigRock && b.isBigRock) return 1;
        return (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt);
      });
  }

  /// Tareas de la semana sin día específico asignado (Bandeja Semanal)
  List<ReminderModel> get unscheduledWeeklyReminders {
    final monday = currentMonday;
    final sundayEnd = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return _filteredList.where((r) {
      if (r.isCompleted || r.isArchived) return false;

      // Si fue asignado explícitamente a un día de la semana (0 a 6), no va a la bandeja
      if (r.scheduledDayOfWeek != null && r.scheduledDayOfWeek! >= 0 && r.scheduledDayOfWeek! <= 6) {
        return false;
      }

      // Si tiene fecha límite dentro de la semana actual, aparecerá en la columna de ese día
      if (r.dueAt != null) {
        final local = r.dueAt!.toLocal();
        if (local.isAfter(monday.subtract(const Duration(seconds: 1))) && local.isBefore(sundayEnd)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) {
        if (a.isBigRock && !b.isBigRock) return -1;
        if (!a.isBigRock && b.isBigRock) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  // ==========================================
  // MATRIZ DE COVEY (2x2)
  // ==========================================

  /// Obtiene los recordatorios de un cuadrante Covey (Q1, Q2, Q3, Q4)
  List<ReminderModel> remindersForQuadrant(CoveyQuadrant quadrant) {
    return _filteredList.where((r) => r.quadrant == quadrant && !r.isCompleted && !r.isArchived).toList()
      ..sort((a, b) {
        if (a.isBigRock && !b.isBigRock) return -1;
        if (!a.isBigRock && b.isBigRock) return 1;
        return (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt);
      });
  }

  int get q1Count => remindersForQuadrant(CoveyQuadrant.q1UrgentImportant).length;
  int get q2Count => remindersForQuadrant(CoveyQuadrant.q2ImportantNotUrgent).length;
  int get q3Count => remindersForQuadrant(CoveyQuadrant.q3UrgentNotImportant).length;
  int get q4Count => remindersForQuadrant(CoveyQuadrant.q4NotUrgentNotImportant).length;

  /// Porcentaje de foco en Cuadrante II (Covey recomienda > 65-70%)
  double get q2FocusPercentage {
    final active = _reminders.where((r) => !r.isCompleted && !r.isArchived).length;
    if (active == 0) return 100.0;
    return (q2Count / active) * 100.0;
  }

  // ==========================================
  // SECCIONES DE LISTA CLÁSICA
  // ==========================================

  List<ReminderModel> get pinnedReminders {
    return _filteredList.where((r) => r.isPinned && !r.isCompleted && !r.isArchived).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  List<ReminderModel> get overdueReminders {
    return _filteredList.where((r) => r.isOverdue).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  List<ReminderModel> get todayReminders {
    return _filteredList.where((r) => r.isDueToday && !r.isOverdue).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  List<ReminderModel> get upcomingReminders {
    return _filteredList.where((r) => r.isUpcoming).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  List<ReminderModel> get noDateReminders {
    return _filteredList.where((r) => r.dueAt == null && !r.isCompleted && !r.isArchived).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ReminderModel> get snoozedReminders {
    return _filteredList.where((r) => r.isSnoozed && !r.isCompleted).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  List<ReminderModel> get completedReminders {
    return _filteredList.where((r) => r.isCompleted).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
  }

  // ==========================================
  // INICIALIZACIÓN Y CICLO DE VIDA
  // ==========================================

  Future<void> init() {
    _initFuture ??= _loadInitialData();
    return _initFuture!;
  }

  Future<void> reload() async {
    _initFuture = _loadInitialData();
    await _initFuture;
  }

  Future<void> _loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchReminders(),
        _service.fetchRoles(),
        _service.fetchOrCreateCurrentWeeklyPlan(),
      ]);

      _reminders = results[0] as List<ReminderModel>;
      _roles = results[1] as List<RoleModel>;
      _currentWeeklyPlan = results[2] as WeeklyPlanModel;
    } catch (e) {
      debugPrint('[RemindersState] Error cargando datos iniciales: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _service.subscribeToRealtime(
      onInsert: (newReminder) {
        if (!_reminders.any((r) => r.id == newReminder.id)) {
          _reminders.insert(0, newReminder);
          notifyListeners();
        }
      },
      onUpdate: (updatedReminder) {
        final index = _reminders.indexWhere((r) => r.id == updatedReminder.id);
        if (index != -1) {
          _reminders[index] = updatedReminder;
          notifyListeners();
        }
      },
      onDelete: (deletedId) {
        _reminders.removeWhere((r) => r.id == deletedId);
        notifyListeners();
      },
    );
  }

  // ==========================================
  // OPERACIONES Y MUTACIONES (HÁBITO 3)
  // ==========================================

  /// Creación rápida con procesamiento de lenguaje natural (NLP)
  Future<ReminderModel> createFromNlp(String rawInput, {bool isNagging = false}) async {
    final parsed = NlpParser.parse(rawInput);

    // Si detectó rol (@salud, @trabajo, etc.), buscar el rol que más se aproxime
    String? matchedRoleId;
    if (parsed.roleQuery != null && parsed.roleQuery!.isNotEmpty) {
      final q = parsed.roleQuery!.toLowerCase();
      try {
        final found = _roles.firstWhere(
          (r) => r.name.toLowerCase().contains(q) || q.contains(r.name.toLowerCase()),
        );
        matchedRoleId = found.id;
      } catch (_) {}
    }

    int? scheduledDay;
    if (parsed.dueAt != null) {
      // Dart: Lun=1..Dom=7 -> normalizado a 0..6
      scheduledDay = parsed.dueAt!.weekday - 1;
    }

    final newReminder = ReminderModel(
      id: _uuid.v4(),
      userId: _service.currentUserId,
      title: parsed.cleanTitle,
      priority: parsed.priority,
      status: ReminderStatus.pending,
      dueAt: parsed.dueAt,
      rrule: parsed.recurrence.rruleString,
      isNagging: isNagging,
      tags: parsed.tags,
      roleId: matchedRoleId,
      weeklyPlanId: _currentWeeklyPlan?.id,
      quadrant: parsed.quadrant,
      isBigRock: parsed.isBigRock,
      scheduledDayOfWeek: scheduledDay,
      estimatedDurationMinutes: parsed.estimatedDurationMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Actualización optimista inmediata
    _reminders.insert(0, newReminder);
    notifyListeners();

    // Guardado en backend Supabase
    await _service.saveReminder(newReminder);
    return newReminder;
  }

  /// Mover recordatorio a un día específico del cronograma flexible (0=Lunes..6=Domingo)
  Future<void> moveReminderToDay(String reminderId, int targetDayOfWeek) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) return;

    final current = _reminders[index];
    final monday = currentMonday;
    final targetDate = monday.add(Duration(days: targetDayOfWeek));

    DateTime newDue;
    if (current.dueAt != null) {
      newDue = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        current.dueAt!.hour,
        current.dueAt!.minute,
      );
    } else {
      newDue = DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
    }

    final updated = current.copyWith(
      scheduledDayOfWeek: targetDayOfWeek,
      dueAt: newDue,
      weeklyPlanId: _currentWeeklyPlan?.id,
      updatedAt: DateTime.now(),
    );

    _reminders[index] = updated;
    notifyListeners();

    await _service.scheduleReminderDay(reminderId, targetDayOfWeek, newDue);
  }

  /// Cambiar el cuadrante Covey de un recordatorio
  Future<void> moveReminderToQuadrant(String reminderId, CoveyQuadrant newQuadrant) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) return;

    final updated = _reminders[index].copyWith(
      quadrant: newQuadrant,
      updatedAt: DateTime.now(),
    );

    _reminders[index] = updated;
    notifyListeners();

    await _service.updateQuadrant(reminderId, newQuadrant);
  }

  /// Alternar bandera de Gran Roca
  Future<void> toggleBigRock(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) return;

    final newVal = !_reminders[index].isBigRock;
    final updated = _reminders[index].copyWith(
      isBigRock: newVal,
      weeklyPlanId: newVal ? (_currentWeeklyPlan?.id) : _reminders[index].weeklyPlanId,
      updatedAt: DateTime.now(),
    );

    _reminders[index] = updated;
    notifyListeners();

    await _service.toggleBigRock(reminderId, newVal);
  }

  /// Asignar o cambiar el rol de vida de un recordatorio
  Future<void> setReminderRole(String reminderId, String? roleId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) return;

    final updated = _reminders[index].copyWith(
      roleId: roleId,
      clearRoleId: roleId == null,
      updatedAt: DateTime.now(),
    );

    _reminders[index] = updated;
    notifyListeners();

    await _service.saveReminder(updated);
  }

  /// Guardar o actualizar un rol de vida
  Future<void> saveRole(RoleModel role) async {
    final index = _roles.indexWhere((r) => r.id == role.id);
    if (index != -1) {
      _roles[index] = role;
    } else {
      _roles.add(role);
    }
    notifyListeners();

    await _service.saveRole(role);
  }

  /// Eliminar un rol de vida
  Future<void> deleteRole(String roleId) async {
    _roles.removeWhere((r) => r.id == roleId);
    // Limpiar roleId en los recordatorios que lo tenían asignado
    for (int i = 0; i < _reminders.length; i++) {
      if (_reminders[i].roleId == roleId) {
        _reminders[i] = _reminders[i].copyWith(clearRoleId: true);
      }
    }
    notifyListeners();

    await _service.deleteRole(roleId);
  }

  /// Guardar notas de retrospectiva en el plan semanal
  Future<void> saveWeeklyPlanNotes(String reflectionNotes) async {
    if (_currentWeeklyPlan == null) return;

    final updatedPlan = _currentWeeklyPlan!.copyWith(
      reflectionNotes: reflectionNotes,
    );
    _currentWeeklyPlan = updatedPlan;
    notifyListeners();

    await _service.saveWeeklyPlan(updatedPlan);
  }

  /// Creación o edición personalizada
  Future<void> saveReminder(ReminderModel reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder.copyWith(updatedAt: DateTime.now());
    } else {
      _reminders.insert(0, reminder);
    }
    notifyListeners();

    await _service.saveReminder(reminder);
  }

  /// Alternar estado de completado
  Future<void> toggleCompleted(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final current = _reminders[index];
    final isDone = current.status == ReminderStatus.completed;
    final newStatus = isDone ? ReminderStatus.pending : ReminderStatus.completed;

    _reminders[index] = current.copyWith(
      status: newStatus,
      completedAt: isDone ? null : DateTime.now(),
      clearCompletedAt: isDone,
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    await _service.updateStatus(id, newStatus);

    if (!isDone && current.isRecurring) {
      final baseDate = current.dueAt ?? DateTime.now();
      final nextDue = current.recurrence.calculateNextDueDate(baseDate);

      final nextReminder = ReminderModel(
        id: _uuid.v4(),
        userId: current.userId ?? _service.currentUserId,
        title: current.title,
        notes: current.notes,
        priority: current.priority,
        status: ReminderStatus.pending,
        dueAt: nextDue,
        clientTimezone: current.clientTimezone,
        rrule: current.rrule,
        parentId: current.id,
        isNagging: current.isNagging,
        nagIntervalMinutes: current.nagIntervalMinutes,
        tags: List.from(current.tags),
        roleId: current.roleId,
        weeklyPlanId: current.weeklyPlanId,
        quadrant: current.quadrant,
        isBigRock: current.isBigRock,
        scheduledDayOfWeek: nextDue.weekday - 1,
        estimatedDurationMinutes: current.estimatedDurationMinutes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _reminders.insert(0, nextReminder);
      notifyListeners();

      await _service.saveReminder(nextReminder);
    }
  }

  Future<void> snoozeRelative(String id, Duration offset) async {
    final newDue = DateTime.now().add(offset);
    await snoozeTo(id, newDue);
  }

  Future<void> snoozeTo(String id, DateTime newDueAt) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    _reminders[index] = _reminders[index].copyWith(
      status: ReminderStatus.snoozed,
      dueAt: newDueAt,
      scheduledDayOfWeek: newDueAt.weekday - 1,
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    await _service.snoozeReminder(id, newDueAt);
  }

  Future<void> toggleNagging(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final updated = _reminders[index].copyWith(
      isNagging: !_reminders[index].isNagging,
      updatedAt: DateTime.now(),
    );
    _reminders[index] = updated;
    notifyListeners();

    await _service.saveReminder(updated);
  }

  Future<void> togglePin(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final updated = _reminders[index].copyWith(
      isPinned: !_reminders[index].isPinned,
      updatedAt: DateTime.now(),
    );
    _reminders[index] = updated;
    notifyListeners();

    await _service.saveReminder(updated);
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();

    await _service.deleteReminder(id);
  }

  Future<void> snoozeAllOverdueToTomorrow() async {
    final now = DateTime.now();
    final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);

    final overdues = List<ReminderModel>.from(overdueReminders);
    for (final r in overdues) {
      await snoozeTo(r.id, tomorrow9am);
    }
  }

  // Filtros
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedTag(String? tag) {
    _selectedTagFilter = tag;
    notifyListeners();
  }

  void setPriorityFilter(ReminderPriority? priority) {
    _selectedPriorityFilter = priority;
    notifyListeners();
  }

  void setQuadrantFilter(CoveyQuadrant? quadrant) {
    _selectedQuadrantFilter = quadrant;
    notifyListeners();
  }

  void setRoleFilter(String? roleId) {
    _selectedRoleFilter = roleId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTagFilter = null;
    _selectedPriorityFilter = null;
    _selectedQuadrantFilter = null;
    _selectedRoleFilter = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
