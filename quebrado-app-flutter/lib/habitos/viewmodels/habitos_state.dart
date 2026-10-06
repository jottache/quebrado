import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/habit_model.dart';
import '../models/habit_log_model.dart';
import '../models/habit_stack_model.dart';
import '../services/habitos_supabase_service.dart';

class HabitosState extends ChangeNotifier {
  final HabitosSupabaseService _service;
  final Uuid _uuid = const Uuid();

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _activeFilter = 'all'; // 'all', 'good', 'bad', 'stacks'
  String? _selectedStackId;
  String? _selectedContactId;

  List<HabitModel> _habits = [];
  List<HabitStackModel> _stacks = [];
  List<HabitLogModel> _logs = [];

  HabitosState({HabitosSupabaseService? service})
      : _service = service ?? HabitosSupabaseService() {
    _init();
  }

  // Getters
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;
  String get selectedDateKey => _formatDate(_selectedDate);
  String get todayKey => _formatDate(DateTime.now());
  bool get isViewingToday => selectedDateKey == todayKey;

  String get activeFilter => _activeFilter;
  String? get selectedStackId => _selectedStackId;
  String? get selectedContactId => _selectedContactId;

  List<HabitModel> get habits => _habits;
  List<HabitModel> get allHabits => _habits.where((h) => !h.archived).toList();
  List<HabitStackModel> get stacks => _stacks;

  List<HabitModel> get filteredHabits {
    var list = allHabits;

    if (_activeFilter == 'good') {
      list = list.where((h) => !h.isNegative).toList();
    } else if (_activeFilter == 'bad') {
      list = list.where((h) => h.isNegative).toList();
    } else if (_activeFilter == 'stacks' && _selectedStackId != null) {
      list = list.where((h) => h.stackGroupId == _selectedStackId).toList();
    }

    if (_selectedContactId != null) {
      if (_selectedContactId == '__none__') {
        list = list.where((h) => h.contactId == null || h.contactId!.isEmpty).toList();
      } else {
        list = list.where((h) => h.contactId == _selectedContactId).toList();
      }
    }

    return list;
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    final data = await _service.bootstrapData();
    _habits = data.habits;
    _stacks = data.stacks;
    _logs = data.logs;

    _isLoading = false;
    notifyListeners();
  }

  /// Recarga completa de los datos de hábitos
  Future<void> reload() => _init();
  Future<void> loadHabits() => _init();

  // ===========================================================================
  // DATE NAVIGATION (ZERO SPINNER INSTANT CACHE)
  // ===========================================================================
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void nextDay() {
    selectDate(_selectedDate.add(const Duration(days: 1)));
  }

  void previousDay() {
    selectDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  void selectToday() {
    selectDate(DateTime.now());
  }

  void setFilter(String filter, {String? stackId}) {
    _activeFilter = filter;
    _selectedStackId = stackId;
    notifyListeners();
  }

  void setContactFilter(String? contactId) {
    if (_selectedContactId == contactId) {
      _selectedContactId = null;
    } else {
      _selectedContactId = contactId;
    }
    notifyListeners();
  }

  // ===========================================================================
  // LOGS & QUERIES IN-MEMORY
  // ===========================================================================
  HabitLogModel? getLog(String habitId, [String? dateKey]) {
    final targetDate = dateKey ?? selectedDateKey;
    try {
      return _logs.firstWhere((l) => l.habitId == habitId && l.logDate == targetDate);
    } catch (_) {
      return null;
    }
  }

  bool isCompleted(String habitId, [String? dateKey]) {
    final log = getLog(habitId, dateKey);
    return log?.completed ?? false;
  }

  double getValue(String habitId, [String? dateKey]) {
    final log = getLog(habitId, dateKey);
    return log?.value ?? 0.0;
  }

  HabitModel? _habitById(String habitId) {
    for (final h in _habits) {
      if (h.id == habitId) return h;
    }
    return null;
  }

  // ===========================================================================
  // MALOS HÁBITOS: RECAÍDAS
  // Un día es de recaída si su registro tiene completed == false. Por compatibilidad
  // con registros antiguos, un contador negativo con valor > 0 también lo es
  // (antes el +1 lo marcaba como "cumplido").
  // ===========================================================================

  bool isRelapseLog(HabitModel habit, HabitLogModel? log) {
    if (!habit.isNegative || log == null) return false;
    if (!log.completed) return true;
    return habit.type == HabitType.counter && log.value > 0;
  }

  bool isRelapseDay(String habitId, [String? dateKey]) {
    final habit = _habitById(habitId);
    if (habit == null) return false;
    return isRelapseLog(habit, getLog(habitId, dateKey));
  }

  /// Veces que se recayó ese día (mínimo 1 si hubo recaída; los registros antiguos
  /// guardaban 0 al reportar la recaída y el número exacto se perdió).
  int getRelapseCount(String habitId, [String? dateKey]) {
    final habit = _habitById(habitId);
    if (habit == null) return 0;
    final log = getLog(habitId, dateKey);
    if (!isRelapseLog(habit, log)) return 0;
    return log!.value < 1 ? 1 : log.value.round();
  }

  /// ¿El día cuenta como logrado? Buenos hábitos: completado. Malos hábitos: sin recaída
  /// (solo desde que existe el hábito y hasta hoy).
  bool isSuccessfulDay(HabitModel habit, DateTime date) {
    final key = _formatDate(date);
    if (!habit.isNegative) return isCompleted(habit.id, key);
    final day = DateTime(date.year, date.month, date.day);
    final created = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    final now = DateTime.now();
    if (day.isBefore(created) || day.isAfter(DateTime(now.year, now.month, now.day))) return false;
    return !isRelapseLog(habit, getLog(habit.id, key));
  }

  /// Estado de cada día de los últimos [days] días (el último es hoy).
  List<HabitDayStatus> getDayStatuses(String habitId, {required int days}) {
    final habit = _habitById(habitId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <HabitDayStatus>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
      final key = _formatDate(date);
      final log = getLog(habitId, key);
      HabitDayKind kind;
      if (habit == null) {
        kind = HabitDayKind.none;
      } else if (date.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) {
        kind = HabitDayKind.beforeCreation;
      } else if (habit.isNegative) {
        kind = isRelapseLog(habit, log) ? HabitDayKind.relapse : HabitDayKind.clean;
      } else if (log?.completed ?? false) {
        kind = HabitDayKind.completed;
      } else if ((log?.value ?? 0) > 0) {
        kind = HabitDayKind.partial;
      } else {
        kind = HabitDayKind.none;
      }
      result.add(HabitDayStatus(
        date: date,
        dateKey: key,
        kind: kind,
        value: log?.value ?? 0,
        relapseCount: kind == HabitDayKind.relapse ? getRelapseCount(habitId, key) : 0,
      ));
    }
    return result;
  }

  /// Resumen de un rango (30, 90, 180, 365 días) contando solo días desde la creación.
  HabitRangeStats getRangeStats(String habitId, {required int days}) {
    final statuses = getDayStatuses(habitId, days: days)
        .where((s) => s.kind != HabitDayKind.beforeCreation)
        .toList();
    final relapses = statuses.where((s) => s.kind == HabitDayKind.relapse).toList();
    final successDays = statuses.where((s) => s.kind == HabitDayKind.completed || s.kind == HabitDayKind.clean).length;
    return HabitRangeStats(
      trackedDays: statuses.length,
      successDays: successDays,
      relapseDays: relapses.length,
      relapseCount: relapses.fold(0, (sum, s) => sum + s.relapseCount),
      totalValue: statuses.fold(0.0, (sum, s) => sum + s.value),
    );
  }

  /// Porcentaje de cumplimiento del día seleccionado (0.0 a 1.0)
  double getDailyCompletionRate(DateTime date) {
    final key = _formatDate(date);
    final active = allHabits;
    if (active.isEmpty) return 0.0;

    int completedCount = 0;
    for (final h in active) {
      if (isSuccessfulDay(h, date)) {
        completedCount++;
      }
    }
    return completedCount / active.length;
  }

  double get selectedDayCompletionRate => getDailyCompletionRate(_selectedDate);
  double get todayCompletionRate => getDailyCompletionRate(DateTime.now());

  int get selectedDayCompletedCount {
    return allHabits.where((h) => isSuccessfulDay(h, _selectedDate)).length;
  }

  int get todayCompletedCount {
    final now = DateTime.now();
    return allHabits.where((h) => isSuccessfulDay(h, now)).length;
  }

  int get bestCurrentStreak {
    int maxStreak = 0;
    for (final h in allHabits) {
      final s = h.isNegative ? calculateCleanDays(h.id) : calculateCurrentStreak(h.id);
      if (s > maxStreak) maxStreak = s;
    }
    return maxStreak;
  }

  // ===========================================================================
  // STREAKS & RESILIENCE CALCULATION (CLIENT-SIDE)
  // ===========================================================================
  /// Racha actual (días consecutivos cumplidos hacia atrás desde hoy)
  int calculateCurrentStreak(String habitId) {
    int streak = 0;
    var checkDate = DateTime.now();

    // Si hoy no se ha completado, verificamos si ayer sí se cumplió para no romperla aún
    final todayKeyStr = _formatDate(checkDate);
    if (!isCompleted(habitId, todayKeyStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final key = _formatDate(checkDate);
      if (isCompleted(habitId, key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Días limpios invicto para malos hábitos (días desde la última recaída)
  int calculateCleanDays(String habitId) {
    final habit = _habitById(habitId);
    if (habit == null) return 0;
    final created = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    int days = 0;

    // Desde hoy hacia atrás hasta la última recaída (o hasta que se creó el hábito)
    while (!checkDate.isBefore(created) && days <= 365) {
      if (isRelapseLog(habit, getLog(habitId, _formatDate(checkDate)))) break;
      days++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    return days;
  }

  /// Score de Resiliencia (%) en los últimos [days] días. Malos hábitos: días sin recaída.
  /// Solo cuenta días desde la creación del hábito.
  double calculateResilienceScore(String habitId, {int days = 30}) {
    final stats = getRangeStats(habitId, days: days);
    if (stats.trackedDays == 0) return 0.0;
    return stats.successRate * 100.0;
  }

  /// Datos diarios para el Heatmap estilo GitHub (últimos X días)
  Map<String, double> getHeatmapData({int daysBack = 84}) { // 12 semanas = 84 días
    final Map<String, double> data = {};
    final now = DateTime.now();

    for (int i = daysBack; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final k = _formatDate(d);
      data[k] = getDailyCompletionRate(d);
    }

    return data;
  }

  /// Tasa de éxito por día de la semana (Lunes a Domingo)
  Map<int, double> getDayOfWeekSuccessRates() {
    final Map<int, int> totalPerDay = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final Map<int, int> successPerDay = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final d = now.subtract(Duration(days: i));
      final weekday = d.weekday; // 1 = Monday, 7 = Sunday
      final rate = getDailyCompletionRate(d);

      totalPerDay[weekday] = (totalPerDay[weekday] ?? 0) + 1;
      if (rate >= 0.70) {
        successPerDay[weekday] = (successPerDay[weekday] ?? 0) + 1;
      }
    }

    final Map<int, double> result = {};
    for (int i = 1; i <= 7; i++) {
      final total = totalPerDay[i] ?? 1;
      final success = successPerDay[i] ?? 0;
      result[i] = total > 0 ? (success / total) : 0.0;
    }

    return result;
  }

  // ===========================================================================
  // OPTIMISTIC MUTATIONS (IN-MEMORY FIRST + BACKGROUND SYNC)
  // ===========================================================================
  Future<void> toggleHabitCompletion(String habitId) async {
    HapticFeedback.lightImpact();

    final dateKey = selectedDateKey;
    final habit = _habits.firstWhere((h) => h.id == habitId);

    // Si es un contador infinito, presionar el check suma 1 toque
    if (habit.type == HabitType.counter) {
      await incrementCounter(habitId, delta: 1.0, dateStr: dateKey);
      return;
    }

    final existingLog = getLog(habitId, dateKey);
    final newCompleted = !(existingLog?.completed ?? false);
    final double newValue = newCompleted ? habit.targetValue : 0.0;

    final updatedLog = (existingLog ?? HabitLogModel(
      id: _uuid.v4(),
      habitId: habitId,
      logDate: dateKey,
    )).copyWith(
      completed: newCompleted,
      value: newValue,
      updatedAt: DateTime.now(),
    );

    _upsertLogInMemory(updatedLog);
    notifyListeners();

    // Sincronización asíncrona no bloqueante
    await _service.saveHabitLog(updatedLog);
  }

  Future<void> incrementCounter(String habitId, {double delta = 1.0, String? dateStr}) async {
    await updateHabitValue(habitId, delta, dateStr);
  }

  Future<void> updateHabitValue(String habitId, double delta, [String? targetDateKey]) async {
    HapticFeedback.selectionClick();

    final dateKey = targetDateKey ?? selectedDateKey;
    final habit = _habits.firstWhere((h) => h.id == habitId);
    final existingLog = getLog(habitId, dateKey);

    // Malos hábitos: el valor es el número de recaídas del día; 0 = día limpio.
    if (habit.isNegative) {
      final current = getRelapseCount(habitId, dateKey).toDouble();
      final next = (current + delta) < 0 ? 0.0 : (current + delta);
      final updated = (existingLog ?? HabitLogModel(
        id: _uuid.v4(),
        habitId: habitId,
        logDate: dateKey,
      )).copyWith(
        value: next,
        completed: next == 0,
        updatedAt: DateTime.now(),
      );
      _upsertLogInMemory(updated);
      notifyListeners();
      await _service.saveHabitLog(updated);
      return;
    }

    final currentValue = existingLog?.value ?? 0.0;
    final double newValue;
    if (habit.type == HabitType.counter) {
      newValue = (currentValue + delta) < 0 ? 0.0 : (currentValue + delta);
    } else {
      newValue = (currentValue + delta).clamp(0.0, habit.targetValue * 2);
    }
    final newCompleted = habit.type == HabitType.counter ? (newValue > 0) : (newValue >= habit.targetValue);

    final updatedLog = (existingLog ?? HabitLogModel(
      id: _uuid.v4(),
      habitId: habitId,
      logDate: dateKey,
    )).copyWith(
      value: newValue,
      completed: newCompleted,
      updatedAt: DateTime.now(),
    );

    _upsertLogInMemory(updatedLog);
    notifyListeners();

    await _service.saveHabitLog(updatedLog);
  }

  /// Registra una recaída más ese día (suma 1 al contador de recaídas; antes lo ponía en 0).
  Future<void> reportRelapse(String habitId, {String? reason, String? dateKey}) async {
    HapticFeedback.heavyImpact();

    final key = dateKey ?? selectedDateKey;
    final existingLog = getLog(habitId, key);
    final previous = getRelapseCount(habitId, key);

    final updatedLog = (existingLog ?? HabitLogModel(
      id: _uuid.v4(),
      habitId: habitId,
      logDate: key,
    )).copyWith(
      completed: false,
      value: (previous + 1).toDouble(),
      notes: reason ?? existingLog?.notes ?? 'Recaída reportada en terminal',
      updatedAt: DateTime.now(),
    );

    _upsertLogInMemory(updatedLog);
    notifyListeners();

    await _service.saveHabitLog(updatedLog);
  }

  /// Retorna la lista de hábitos asociados a un contacto específico de Diario
  List<HabitModel> getHabitsForContact(String contactId) {
    return _habits.where((h) => !h.archived && h.contactId == contactId).toList();
  }

  /// Asocia o desvincula un hábito con un contacto de Diario
  Future<void> linkHabitToContact(String habitId, String? contactId) async {
    final idx = _habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;
    final updated = _habits[idx].copyWith(
      contactId: contactId,
      clearContactId: contactId == null || contactId.isEmpty,
      updatedAt: DateTime.now(),
    );
    _habits[idx] = updated;
    notifyListeners();
    await _service.saveHabit(updated);
  }

  Future<void> addHabit({
    required String title,
    String? description,
    String icon = 'terminal',
    String colorHex = '#00FF66',
    HabitType type = HabitType.binary,
    bool isNegative = false,
    double targetValue = 1.0,
    String? unit,
    String? stackGroupId,
    String? contactId,
  }) async {
    final habit = HabitModel(
      id: _uuid.v4(),
      title: title.trim(),
      description: description?.trim(),
      icon: icon,
      colorHex: colorHex,
      type: type,
      isNegative: isNegative,
      targetValue: targetValue,
      unit: unit?.trim(),
      stackGroupId: stackGroupId,
      contactId: contactId,
      position: _habits.length + 1,
    );

    _habits.add(habit);
    notifyListeners();

    await _service.saveHabit(habit);
  }

  Future<void> updateHabit(HabitModel habit) async {
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx != -1) {
      _habits[idx] = habit;
      notifyListeners();
      await _service.saveHabit(habit);
    }
  }

  Future<void> deleteHabit(String habitId) async {
    _habits.removeWhere((h) => h.id == habitId);
    _logs.removeWhere((l) => l.habitId == habitId);
    notifyListeners();

    await _service.deleteHabit(habitId);
  }

  Future<void> addStack(String name, String timeOfDay) async {
    final stack = HabitStackModel(
      id: _uuid.v4(),
      name: name.toUpperCase().trim(),
      timeOfDay: timeOfDay,
      position: _stacks.length + 1,
    );

    _stacks.add(stack);
    notifyListeners();

    await _service.saveHabitStack(stack);
  }

  void _upsertLogInMemory(HabitLogModel log) {
    final idx = _logs.indexWhere((l) => l.habitId == log.habitId && l.logDate == log.logDate);
    if (idx != -1) {
      _logs[idx] = log;
    } else {
      _logs.add(log);
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

enum HabitDayKind { beforeCreation, none, partial, completed, clean, relapse }

class HabitDayStatus {
  final DateTime date;
  final String dateKey;
  final HabitDayKind kind;
  final double value;
  final int relapseCount;

  const HabitDayStatus({
    required this.date,
    required this.dateKey,
    required this.kind,
    required this.value,
    required this.relapseCount,
  });
}

class HabitRangeStats {
  final int trackedDays;
  final int successDays;
  final int relapseDays;
  final int relapseCount;
  final double totalValue;

  const HabitRangeStats({
    required this.trackedDays,
    required this.successDays,
    required this.relapseDays,
    required this.relapseCount,
    required this.totalValue,
  });

  double get successRate => trackedDays == 0 ? 0 : successDays / trackedDays;
}
