/// Ejecutor de escritura de Recordatorios: `createReminder` (spec 03,
/// `docs/design/ortiz-registra.md` §2.2).
///
/// - `title` y `dueAt` (fecha **y** hora ISO 8601) son obligatorios: sin
///   fecha se pregunta (`missing: [dueAt]`), nunca «ahora + 2 h».
/// - Una fecha en el pasado sale como tarjeta (`past_date`).
/// - Recordatorios no programa notificaciones locales en la app: deshacer
///   solo borra el recordatorio (no hay nada que cancelar).
library;

import 'package:uuid/uuid.dart';

import '../../../quebrado/widgets/helpers.dart' show formatDate;
import '../../../recordatorios/models/reminder_model.dart';
import '../../../recordatorios/viewmodels/reminders_state.dart';
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'ortiz_resolver.dart' show norm;
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

/// Motivos (`reasons`) propios de Recordatorios.
abstract final class RemindersWriteReason {
  static const pastDate = 'past_date';
}

class RemindersWriteTools implements WriteToolHandler {
  final RemindersState _reminders;
  final Uuid _uuid;

  RemindersWriteTools(this._reminders, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  @override
  Set<String> get toolNames => const {WriteToolNames.createReminder};

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    if (toolName != WriteToolNames.createReminder) {
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message:
            'No pude registrarlo: Recordatorios no conoce la acción «$toolName». No se guardó nada.',
      ));
    }
    return _createReminder(args, ctx);
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    if (toolName != WriteToolNames.createReminder) {
      throw StateError('Recordatorios no puede deshacer «$toolName».');
    }
    final id = undoPayload['reminderId'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('No sé qué recordatorio deshacer.');
    }
    await _reminders.deleteReminder(id);
  }

  Future<WriteOutcome> _createReminder(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.createReminder;
    final title = _str(args, 'title');
    final dueRaw = _str(args, 'dueAt');
    final priorityRaw = _str(args, 'priority');
    final recurrenceRaw = _str(args, 'recurrence');
    final notes = _str(args, 'notes');

    final missing = <String>[];
    final resolved = <String, dynamic>{};
    final options = <String, List<String>>{};

    if (title == null) {
      missing.add('title');
    } else {
      resolved['title'] = title;
    }

    final dueAt = dueRaw == null ? null : parseDueAt(dueRaw);
    if (dueAt == null) {
      missing.add('dueAt');
    } else {
      resolved['dueAt'] = _isoLocal(dueAt);
    }

    ReminderPriority? priority;
    if (priorityRaw != null) {
      priority = _byCode(ReminderPriority.values, (p) => p.code, priorityRaw);
      if (priority == null) {
        missing.add('priority');
        options['priority'] = [for (final p in ReminderPriority.values) p.code];
      } else {
        resolved['priority'] = priority.code;
      }
    }

    ReminderRecurrence? recurrence;
    if (recurrenceRaw != null) {
      recurrence =
          _byCode(ReminderRecurrence.values, (r) => r.code, recurrenceRaw);
      if (recurrence == null) {
        missing.add('recurrence');
        options['recurrence'] = [
          for (final r in ReminderRecurrence.values) r.code,
        ];
      } else {
        resolved['recurrence'] = recurrence.code;
      }
    }

    if (missing.isNotEmpty) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
        options: options,
      ));
    }

    final due = dueAt!;
    final reasons = <String>[...ctx.forcedProposalReasons];
    if (!ctx.confirmedByUser && due.isBefore(ctx.now())) {
      reasons.add(RemindersWriteReason.pastDate);
    }

    final summaryTitle = title!;
    final parts = [
      SummaryPart(_dateTimeLabel(due)),
      if (priority != null) SummaryPart(priority.label),
      if (recurrence != null && recurrence != ReminderRecurrence.none)
        SummaryPart(recurrence.shortLabel),
    ];

    if (reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: _joinSummary(summaryTitle, parts),
          resolved: resolved,
        ),
        summaryTitle: summaryTitle,
        summaryParts: parts,
        commitArgs: {
          'title': summaryTitle,
          'dueAt': _isoLocal(due),
          if (priority != null) 'priority': priority.code,
          if (recurrence != null) 'recurrence': recurrence.code,
          'notes': ?notes,
        },
      );
    }

    final now = ctx.now();
    final reminder = ReminderModel(
      id: _uuid.v4(),
      title: summaryTitle,
      notes: notes,
      priority: priority ?? ReminderPriority.p3Medium,
      dueAt: due,
      rrule: recurrence?.rruleString,
      weeklyPlanId: _reminders.currentWeeklyPlan?.id,
      scheduledDayOfWeek: due.weekday - 1,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final ok = await _reminders.saveReminder(reminder);
      if (!ok) {
        // saveReminder ya lo dejó en la lista: se quita para no mentir.
        await _quietly(() => _reminders.deleteReminder(reminder.id));
        return _saveError(action, 'no se pudo guardar en Recordatorios');
      }
    } catch (_) {
      await _quietly(() => _reminders.deleteReminder(reminder.id));
      return _saveError(action, 'falló el guardado en Recordatorios');
    }

    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: reminder.id,
        summary: _joinSummary(summaryTitle, parts),
        route: SuiteRoutes.recordatorio(reminder.id),
        undoId: _uuid.v4(),
      ),
      summaryTitle: summaryTitle,
      summaryParts: parts,
      undoPayload: {'reminderId': reminder.id},
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  static final RegExp _isoDateTime = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$',
  );

  /// Fecha y hora ISO 8601 (`2026-11-18T10:00`, con segundos o zona
  /// opcionales) en hora local. `null` si falta la hora, el formato no es
  /// ISO o la fecha no existe («2026-02-30T10:00»).
  static DateTime? parseDueAt(String raw) {
    final text = raw.trim();
    final m = _isoDateTime.firstMatch(text);
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    final hour = int.parse(m.group(4)!);
    final minute = int.parse(m.group(5)!);
    final second = int.parse(m.group(6) ?? '0');
    if (hour > 23 || minute > 59 || second > 59) return null;
    final calendar = DateTime(year, month, day);
    if (calendar.year != year || calendar.month != month || calendar.day != day) {
      return null;
    }
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return m.group(7) == null ? parsed : parsed.toLocal();
  }

  static T? _byCode<T>(List<T> values, String Function(T) code, String raw) {
    final wanted = norm(raw);
    for (final v in values) {
      if (code(v) == wanted) return v;
    }
    return null;
  }

  static String? _str(Map<String, dynamic> args, String key) {
    final value = args[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _dateTimeLabel(DateTime d) =>
      '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _isoLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String _joinSummary(String title, List<SummaryPart> parts) =>
      [title, ...parts.map((p) => p.text)].join(' · ');

  static WriteOutcome _saveError(String action, String reason) =>
      WriteOutcome(WriteToolResult.error(
        action: action,
        message: 'No pude registrarlo: $reason. No se guardó nada.',
      ));

  static Future<void> _quietly(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {}
  }
}
