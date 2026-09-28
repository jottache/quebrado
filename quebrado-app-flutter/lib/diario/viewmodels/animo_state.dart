import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../models/mood_tag.dart';
import '../services/animo_supabase_service.dart';
import '../../quebrado/services/db_helper.dart';

/// Persistencia local de los cambios que no llegaron a Supabase.
abstract class MoodPendingStore {
  Future<String?> read();
  Future<void> write(String value);
}

class _SettingsPendingStore implements MoodPendingStore {
  static const _key = 'animo_pending_ops';

  @override
  Future<String?> read() async {
    try {
      return await DatabaseHelper.instance.getSetting(_key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      await DatabaseHelper.instance.setSetting(_key, value);
    } catch (_) {}
  }
}

class MoodEmotionFrequency {
  final MoodEmotion emotion;
  final int count;
  const MoodEmotionFrequency(this.emotion, this.count);
}

/// Estado del módulo Ánimo (Diario). Los registros propios tienen `contactId == null`.
class AnimoState extends ChangeNotifier {
  final AnimoSupabaseService _service;
  final MoodPendingStore _pendingStore;
  final DateTime Function() _now;
  final Uuid _uuid = const Uuid();

  /// Ventana de carga inicial: suficiente para la vista anual.
  static const int loadWindowDays = 400;

  AnimoState({
    AnimoSupabaseService? service,
    MoodPendingStore? pendingStore,
    DateTime Function()? clock,
  })  : _service = service ?? AnimoSupabaseService.instance,
        _pendingStore = pendingStore ?? _SettingsPendingStore(),
        _now = clock ?? DateTime.now;

  /// Devuelve el estado si está registrado en el árbol (los widgets de Diario
  /// también se usan en tests y pantallas sin este provider).
  static AnimoState? maybeOf(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<AnimoState>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<MoodLog> _logs = [];
  List<MoodTag> _tags = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  /// id → registro pendiente de subir; y ids pendientes de borrar.
  final Map<String, MoodLog> _pendingUpserts = {};
  final Set<String> _pendingDeletes = {};

  List<MoodLog> get logs => List.unmodifiable(_logs);
  List<MoodTag> get tags => _tags.where((t) => !t.archived).toList();
  List<MoodTag> get allTags => List.unmodifiable(_tags);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isBackendReady => _service.isReady;
  int get pendingCount => _pendingUpserts.length + _pendingDeletes.length;
  bool isPending(String logId) => _pendingUpserts.containsKey(logId);

  MoodTag? tagById(String id) {
    for (final t in _tags) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ===========================================================================
  // CARGA
  // ===========================================================================

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _restorePending();
      final since = _now().subtract(const Duration(days: loadWindowDays));
      final results = await Future.wait([
        _service.getLogs(since: since),
        _service.getTags(),
      ]);

      final remote = results[0] as List<MoodLog>;
      final byId = {for (final l in remote) l.id: l};
      // Lo pendiente local manda sobre lo remoto.
      byId.addAll(_pendingUpserts);
      for (final id in _pendingDeletes) {
        byId.remove(id);
      }
      _logs = byId.values.toList();
      _sortLogs();
      _tags = results[1] as List<MoodTag>;
      _tags.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _hasLoaded = true;
    } catch (e) {
      debugPrint('Error cargando ánimo: $e');
      if (_tags.isEmpty) _tags = MoodTag.defaultTags();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    await syncPending();
  }

  void _sortLogs() => _logs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  // ===========================================================================
  // CRUD OPTIMISTA
  // ===========================================================================

  /// Guarda un registro. Si es un balance `daily` y ya existe uno para ese
  /// sujeto y día, lo actualiza (la BD solo permite uno).
  Future<MoodLog> addLog({
    required int valence,
    String? contactId,
    MoodPerspective? perspective,
    MoodKind kind = MoodKind.momentary,
    int? energy,
    List<String> emotions = const [],
    List<String> tagIds = const [],
    List<String> roleIds = const [],
    List<String> mentionedContactIds = const [],
    String? note,
    String? diarioEntryId,
    MoodSource source = MoodSource.manual,
    DateTime? loggedAt,
  }) async {
    final when = _clampToNow(loggedAt ?? _now());
    final normalizedContact = (contactId == null || contactId.isEmpty || contactId == 'personal') ? null : contactId;

    if (kind == MoodKind.daily) {
      final existing = dailyLogFor(when, contactId: normalizedContact);
      if (existing != null) {
        final updated = existing.copyWith(
          valence: valence,
          energy: energy,
          clearEnergy: energy == null,
          emotions: _limitEmotions(emotions),
          tagIds: tagIds,
          roleIds: roleIds,
          mentionedContactIds: mentionedContactIds,
          note: note,
          clearNote: note == null,
          perspective: perspective,
          source: source,
        );
        await updateLog(updated);
        return updated;
      }
    }

    final log = MoodLog(
      id: _uuid.v4(),
      contactId: normalizedContact,
      perspective: perspective,
      kind: kind,
      valence: valence,
      energy: energy,
      emotions: _limitEmotions(emotions),
      tagIds: tagIds,
      roleIds: roleIds,
      mentionedContactIds: mentionedContactIds,
      note: note,
      diarioEntryId: diarioEntryId,
      source: source,
      loggedAt: when,
      createdAt: _now(),
      updatedAt: _now(),
    );

    _logs.add(log);
    _sortLogs();
    notifyListeners();
    await _persist(log);
    return log;
  }

  Future<void> updateLog(MoodLog updated) async {
    final normalized = updated.copyWith(
      emotions: _limitEmotions(updated.emotions),
      loggedAt: _clampToNow(updated.loggedAt),
      updatedAt: _now(),
    );
    final index = _logs.indexWhere((l) => l.id == normalized.id);
    if (index == -1) {
      _logs.add(normalized);
    } else {
      _logs[index] = normalized;
    }
    _sortLogs();
    notifyListeners();
    await _persist(normalized);
  }

  /// Elimina y devuelve el registro borrado (para "Deshacer").
  Future<MoodLog?> deleteLog(String id) async {
    final index = _logs.indexWhere((l) => l.id == id);
    if (index == -1) return null;
    final removed = _logs.removeAt(index);
    notifyListeners();

    final wasOnlyLocal = _pendingUpserts.remove(id) != null;
    try {
      await _service.deleteLog(id);
      _pendingDeletes.remove(id);
    } catch (e) {
      debugPrint('Ánimo: borrado pendiente de sincronizar ($e)');
      if (!wasOnlyLocal) _pendingDeletes.add(id);
    }
    await _savePending();
    notifyListeners();
    return removed;
  }

  /// Reinserta un registro borrado (acción "Deshacer").
  Future<void> restoreLog(MoodLog log) async {
    _pendingDeletes.remove(log.id);
    if (_logs.any((l) => l.id == log.id)) return;
    _logs.add(log);
    _sortLogs();
    notifyListeners();
    await _persist(log);
  }

  /// Limpieza en memoria cuando se elimina un contacto (en la BD lo hace el trigger).
  void removeLogsForContact(String contactId) {
    _logs.removeWhere((l) => l.contactId == contactId);
    _pendingUpserts.removeWhere((_, l) => l.contactId == contactId);
    for (var i = 0; i < _logs.length; i++) {
      final l = _logs[i];
      if (l.mentionedContactIds.contains(contactId)) {
        _logs[i] = l.copyWith(
          mentionedContactIds: l.mentionedContactIds.where((c) => c != contactId).toList(),
          updatedAt: l.updatedAt,
        );
      }
    }
    _savePending();
    notifyListeners();
  }

  Future<void> _persist(MoodLog log) async {
    try {
      await _service.saveLog(log);
      _pendingUpserts.remove(log.id);
    } catch (e) {
      debugPrint('Ánimo: registro pendiente de sincronizar ($e)');
      _pendingUpserts[log.id] = log;
    }
    await _savePending();
    notifyListeners();
  }

  /// Reintenta subir lo pendiente. Devuelve cuántas operaciones siguen pendientes.
  Future<int> syncPending() async {
    if (_pendingUpserts.isEmpty && _pendingDeletes.isEmpty) return 0;
    if (!_service.isReady) return pendingCount;

    for (final log in List<MoodLog>.from(_pendingUpserts.values)) {
      try {
        await _service.saveLog(log);
        _pendingUpserts.remove(log.id);
      } catch (_) {}
    }
    for (final id in List<String>.from(_pendingDeletes)) {
      try {
        await _service.deleteLog(id);
        _pendingDeletes.remove(id);
      } catch (_) {}
    }
    await _savePending();
    notifyListeners();
    return pendingCount;
  }

  Future<void> _restorePending() async {
    final raw = await _pendingStore.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final m in (data['upserts'] as List? ?? [])) {
        final log = MoodLog.fromMap(Map<String, dynamic>.from(m as Map));
        _pendingUpserts.putIfAbsent(log.id, () => log);
      }
      for (final id in (data['deletes'] as List? ?? [])) {
        _pendingDeletes.add(id.toString());
      }
    } catch (e) {
      debugPrint('Ánimo: no se pudo leer la cola pendiente ($e)');
    }
  }

  Future<void> _savePending() async {
    final payload = jsonEncode({
      'upserts': _pendingUpserts.values.map((l) => l.toSupabaseMap()).toList(),
      'deletes': _pendingDeletes.toList(),
    });
    await _pendingStore.write(payload);
  }

  DateTime _clampToNow(DateTime date) {
    final now = _now();
    return date.isAfter(now) ? now : date;
  }

  List<String> _limitEmotions(List<String> emotions) =>
      emotions.toSet().take(MoodCatalog.maxEmotionsPerLog).toList();

  // ===========================================================================
  // ETIQUETAS
  // ===========================================================================

  Future<MoodTag> addTag({required String name, String emoji = '🏷️', String groupKey = 'otro'}) async {
    final existing = _tags.where((t) => t.name.toLowerCase() == name.trim().toLowerCase());
    if (existing.isNotEmpty) return existing.first;

    final tag = MoodTag(
      id: _uuid.v4(),
      name: name.trim(),
      emoji: emoji,
      groupKey: groupKey,
      sortOrder: _tags.isEmpty ? 0 : _tags.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
    );
    _tags.add(tag);
    notifyListeners();
    await _service.saveTag(tag);
    return tag;
  }

  // ===========================================================================
  // CONSULTAS
  // ===========================================================================

  bool _matchesSubject(MoodLog l, String? contactId) =>
      contactId == null ? l.isSelf : l.contactId == contactId;

  /// Registros de un sujeto (null = yo), opcionalmente entre fechas (inclusive por día).
  List<MoodLog> logsFor({String? contactId, DateTime? from, DateTime? to}) {
    final fromKey = from != null ? MoodLog.dateKey(from) : null;
    final toKey = to != null ? MoodLog.dateKey(to) : null;
    return _logs.where((l) {
      if (!_matchesSubject(l, contactId)) return false;
      final key = l.logDateKey;
      if (fromKey != null && key.compareTo(fromKey) < 0) return false;
      if (toKey != null && key.compareTo(toKey) > 0) return false;
      return true;
    }).toList();
  }

  List<MoodLog> logsOnDate(DateTime date, {String? contactId}) {
    final key = MoodLog.dateKey(date);
    return _logs.where((l) => _matchesSubject(l, contactId) && l.logDateKey == key).toList();
  }

  List<MoodLog> todaySelfLogs() => logsOnDate(_now());

  bool get hasSelfLogToday => todaySelfLogs().isNotEmpty;

  double? get todaySelfValence => dayValence(_now());

  MoodLog? latestFor(String? contactId) {
    for (final l in _logs) {
      if (_matchesSubject(l, contactId)) return l;
    }
    return null;
  }

  MoodLog? dailyLogFor(DateTime date, {String? contactId}) {
    final key = MoodLog.dateKey(date);
    for (final l in _logs) {
      if (l.isDaily && _matchesSubject(l, contactId) && l.logDateKey == key) return l;
    }
    return null;
  }

  MoodLog? logForEntry(String diarioEntryId) {
    for (final l in _logs) {
      if (l.diarioEntryId == diarioEntryId) return l;
    }
    return null;
  }

  /// Valor del día: el balance `daily` si existe; si no, el promedio de los momentáneos.
  double? dayValence(DateTime date, {String? contactId}) {
    final dayLogs = logsOnDate(date, contactId: contactId);
    if (dayLogs.isEmpty) return null;
    for (final l in dayLogs) {
      if (l.isDaily) return l.valence.toDouble();
    }
    return dayLogs.map((l) => l.valence).reduce((a, b) => a + b) / dayLogs.length;
  }

  /// Serie diaria (yyyy-MM-dd → valor) de los últimos [days] días, solo días con datos.
  Map<String, double> dailySeries({String? contactId, required int days}) {
    final today = _dateOnly(_now());
    final from = today.subtract(Duration(days: days - 1));
    final fromKey = MoodLog.dateKey(from);

    final byDay = <String, List<MoodLog>>{};
    for (final l in _logs) {
      if (!_matchesSubject(l, contactId)) continue;
      final key = l.logDateKey;
      if (key.compareTo(fromKey) < 0) continue;
      byDay.putIfAbsent(key, () => []).add(l);
    }

    final result = <String, double>{};
    final keys = byDay.keys.toList()..sort();
    for (final key in keys) {
      final dayLogs = byDay[key]!;
      final daily = dayLogs.where((l) => l.isDaily);
      result[key] = daily.isNotEmpty
          ? daily.first.valence.toDouble()
          : dayLogs.map((l) => l.valence).reduce((a, b) => a + b) / dayLogs.length;
    }
    return result;
  }

  /// Promedio de los valores diarios de los últimos [days] días (null sin datos).
  double? averageValence({String? contactId, int days = 7}) {
    final series = dailySeries(contactId: contactId, days: days);
    if (series.isEmpty) return null;
    return series.values.reduce((a, b) => a + b) / series.length;
  }

  /// Días consecutivos con al menos un registro propio, contando desde hoy
  /// (o desde ayer si hoy todavía no hay registro).
  int get selfLoggingStreak {
    final days = _logs.where((l) => l.isSelf).map((l) => l.logDateKey).toSet();
    if (days.isEmpty) return 0;

    var cursor = _dateOnly(_now());
    if (!days.contains(MoodLog.dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(MoodLog.dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Cantidad de días distintos con registro propio.
  int get selfLoggedDaysCount => _logs.where((l) => l.isSelf).map((l) => l.logDateKey).toSet().length;

  List<MoodEmotionFrequency> topEmotions({int days = 30, String? contactId, int limit = 8}) {
    final fromKey = MoodLog.dateKey(_dateOnly(_now()).subtract(Duration(days: days - 1)));
    final counts = <String, int>{};
    for (final l in _logs) {
      if (!_matchesSubject(l, contactId)) continue;
      if (l.logDateKey.compareTo(fromKey) < 0) continue;
      for (final e in l.emotions) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }
    final result = <MoodEmotionFrequency>[];
    counts.forEach((key, count) {
      final emotion = MoodCatalog.emotionByKey(key);
      if (emotion != null) result.add(MoodEmotionFrequency(emotion, count));
    });
    result.sort((a, b) => b.count.compareTo(a.count));
    return result.take(limit).toList();
  }

  static DateTime _dateOnly(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }
}
