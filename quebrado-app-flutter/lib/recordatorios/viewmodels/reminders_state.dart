import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../services/nlp_parser.dart';
import '../services/reminders_supabase_service.dart';

class RemindersState extends ChangeNotifier {
  final RemindersSupabaseService _service;
  final _uuid = const Uuid();

  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTagFilter;
  ReminderPriority? _selectedPriorityFilter;
  Future<void>? _initFuture;

  RemindersState({RemindersSupabaseService? service})
      : _service = service ?? RemindersSupabaseService() {
    init();
  }

  bool get isLoading => _isLoading;
  List<ReminderModel> get allReminders => List.unmodifiable(_reminders);
  String get searchQuery => _searchQuery;
  String? get selectedTagFilter => _selectedTagFilter;
  ReminderPriority? get selectedPriorityFilter => _selectedPriorityFilter;

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

  // Filtrado general por texto, tag y prioridad
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
      return true;
    }).toList();
  }

  // Recordatorios Fijados (Pinned Banner)
  List<ReminderModel> get pinnedReminders {
    return _filteredList.where((r) => r.isPinned && !r.isCompleted && !r.isArchived).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
  }

  // Secciones Inteligentes
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

  /// Inicializar de manera segura e idempotente
  Future<void> init() {
    _initFuture ??= _loadReminders();
    return _initFuture!;
  }

  /// Recargar datos frescos desde el servicio
  Future<void> reload() async {
    _initFuture = _loadReminders();
    await _initFuture;
  }

  Future<void> _loadReminders() async {
    _isLoading = true;
    notifyListeners();

    _reminders = await _service.fetchReminders();
    _isLoading = false;
    notifyListeners();

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

  /// Creación rápida con procesamiento de lenguaje natural
  Future<ReminderModel> createFromNlp(String rawInput, {bool isNagging = false}) async {
    final parsed = NlpParser.parse(rawInput);

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

  /// Alternar estado de completado (con actualización optimista y regeneración de recurrencia)
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

    // Si se marcó como completado y es un recordatorio recurrente (semanal, quincenal, mensual, etc.)
    // se programa automáticamente la siguiente ocurrencia
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _reminders.insert(0, nextReminder);
      notifyListeners();

      await _service.saveReminder(nextReminder);
    }
  }

  /// Smart Snooze: Posponer con duración relativa (+15m, +1h, etc.)
  Future<void> snoozeRelative(String id, Duration offset) async {
    final newDue = DateTime.now().add(offset);
    await snoozeTo(id, newDue);
  }

  /// Smart Snooze a un timestamp específico
  Future<void> snoozeTo(String id, DateTime newDueAt) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    _reminders[index] = _reminders[index].copyWith(
      status: ReminderStatus.snoozed,
      dueAt: newDueAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    await _service.snoozeReminder(id, newDueAt);
  }

  /// Alternar alarma persistente (nagging)
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

  /// Alternar recordatorio fijado (pin)
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

  /// Eliminar recordatorio
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();

    await _service.deleteReminder(id);
  }

  /// Posponer todos los vencidos para mañana a las 9:00 AM
  Future<void> snoozeAllOverdueToTomorrow() async {
    final now = DateTime.now();
    final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);

    final overdues = List<ReminderModel>.from(overdueReminders);
    for (final r in overdues) {
      await snoozeTo(r.id, tomorrow9am);
    }
  }

  // Filtros de búsqueda
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

  void clearFilters() {
    _searchQuery = '';
    _selectedTagFilter = null;
    _selectedPriorityFilter = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
