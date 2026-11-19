import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/reminders_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_result.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/services/reminders_supabase_service.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';

/// Sin Supabase (modo local) y con la respuesta de guardado controlable.
class _FakeRemindersService extends RemindersSupabaseService {
  final List<ReminderModel> saved = [];
  final List<String> deleted = [];
  bool saveResult = true;

  @override
  Future<bool> saveReminder(ReminderModel reminder) async {
    if (saveResult) saved.add(reminder);
    return saveResult;
  }

  @override
  Future<bool> deleteReminder(String id) async {
    deleted.add(id);
    return true;
  }
}

final DateTime _now = DateTime(2026, 11, 18, 15, 30);

WriteContext _ctx({
  bool untrustedRead = false,
  bool confirmed = false,
}) =>
    WriteContext(
      untrustedRead: untrustedRead,
      confirmedByUser: confirmed,
      now: () => _now,
    );

void main() {
  late _FakeRemindersService service;
  late RemindersState state;
  late RemindersWriteTools tools;

  setUp(() async {
    service = _FakeRemindersService();
    state = RemindersState(service: service);
    await state.init();
    tools = RemindersWriteTools(state);
  });

  Future<WriteOutcome> create(Map<String, dynamic> args, [WriteContext? ctx]) =>
      tools.execute(WriteToolNames.createReminder, args, ctx ?? _ctx());

  test('atiende solo createReminder', () {
    expect(tools.toolNames, {WriteToolNames.createReminder});
  });

  test('con título y fecha futura guarda el recordatorio con resumen, ruta y deshacer', () async {
    final out = await create({'title': 'Llamar a Nora', 'dueAt': '2026-11-19T09:00:00'});

    expect(out.result.status, WriteToolStatus.saved);
    final reminder = state.allReminders.firstWhere((r) => r.id == out.result.recordId);
    expect(reminder.title, 'Llamar a Nora');
    expect(reminder.dueAt, DateTime(2026, 11, 19, 9));
    expect(reminder.priority, ReminderPriority.p3Medium);
    expect(reminder.rrule, isNull);
    expect(reminder.scheduledDayOfWeek, DateTime(2026, 11, 19).weekday - 1);
    expect(service.saved.map((r) => r.id), contains(reminder.id));
    expect(out.summaryTitle, 'Llamar a Nora');
    expect(out.summaryParts.map((p) => p.text), ['19/11/2026 09:00']);
    expect(out.result.summary, 'Llamar a Nora · 19/11/2026 09:00');
    expect(out.result.route, '/recordatorios/${reminder.id}');
    expect(out.result.undoId, isNotEmpty);
    expect(out.undoPayload, {'reminderId': reminder.id});
  });

  test('usa la prioridad y la repetición indicadas y las dice en el resumen', () async {
    final out = await create({
      'title': 'Pagar el gimnasio',
      'dueAt': '2026-11-20T08:15',
      'priority': 'p2_high',
      'recurrence': 'monthly',
      'notes': 'En efectivo',
    });

    final reminder = state.allReminders.firstWhere((r) => r.id == out.result.recordId);
    expect(reminder.priority, ReminderPriority.p2High);
    expect(reminder.recurrence, ReminderRecurrence.monthly);
    expect(reminder.notes, 'En efectivo');
    expect(out.summaryParts.map((p) => p.text), ['20/11/2026 08:15', 'P2 Alta', 'Mensual']);
  });

  test('sin fecha responde missing [dueAt] y no inventa una (nada de ahora + 2 h)', () async {
    final before = state.allReminders.length;
    final out = await create({'title': 'Llamar a Nora'});

    expect(out.result.status, WriteToolStatus.missing);
    expect(out.result.missing, ['dueAt']);
    expect(out.result.resolved['title'], 'Llamar a Nora');
    expect(state.allReminders.length, before);
    expect(service.saved, isEmpty);
  });

  test('sin título ni fecha pide los dos de una vez', () async {
    final out = await create({});

    expect(out.result.missing, ['title', 'dueAt']);
  });

  test('una fecha sin hora, en otro formato o imposible se trata como faltante', () async {
    for (final raw in ['2026-11-19', 'mañana a las 9', '2026-02-30T10:00', '2026-11-19T25:00']) {
      final out = await create({'title': 'Algo', 'dueAt': raw});
      expect(out.result.missing, ['dueAt'], reason: raw);
    }
    expect(service.saved, isEmpty);
  });

  test('una fecha con zona horaria se guarda en hora local', () {
    expect(
      RemindersWriteTools.parseDueAt('2026-11-19T14:00:00Z'),
      DateTime.utc(2026, 11, 19, 14).toLocal(),
    );
  });

  test('una prioridad que no existe pide elegir entre las reales', () async {
    final out = await create({'title': 'Algo', 'dueAt': '2026-11-19T09:00', 'priority': 'altísima'});

    expect(out.result.status, WriteToolStatus.missing);
    expect(out.result.missing, ['priority']);
    expect(out.result.options['priority'], [for (final p in ReminderPriority.values) p.code]);
  });

  test('una fecha en el pasado sale como tarjeta y al confirmarla se guarda', () async {
    final before = state.allReminders.length;

    final first = await create({'title': 'Sacar la basura', 'dueAt': '2026-11-18T10:00:00'});
    expect(first.result.status, WriteToolStatus.proposal);
    expect(first.result.reasons, [RemindersWriteReason.pastDate]);
    expect(first.commitArgs?['dueAt'], '2026-11-18T10:00:00');
    expect(state.allReminders.length, before);

    final out = await create(first.commitArgs!, _ctx(confirmed: true));
    expect(out.result.status, WriteToolStatus.saved);
    expect(state.allReminders.length, before + 1);
  });

  test('si en el turno se leyó texto libre sale como tarjeta', () async {
    final read = await create(
      {'title': 'Algo', 'dueAt': '2026-11-19T09:00'},
      _ctx(untrustedRead: true),
    );

    expect(read.result.status, WriteToolStatus.proposal);
    expect(read.result.reasons, ['read_untrusted_text']);
    expect(service.saved, isEmpty);
  });

  test('si Supabase no lo guarda responde error y lo quita de la lista', () async {
    service.saveResult = false;
    final before = state.allReminders.length;

    final out = await create({'title': 'Algo', 'dueAt': '2026-11-19T09:00'});

    expect(out.result.status, WriteToolStatus.error);
    expect(out.result.message, startsWith('No pude registrarlo: '));
    expect(out.result.message, endsWith('No se guardó nada.'));
    expect(state.allReminders.length, before);
  });

  test('deshacer borra el recordatorio creado', () async {
    final out = await create({'title': 'Llamar a Nora', 'dueAt': '2026-11-19T09:00'});
    final id = out.result.recordId!;

    await tools.undo(WriteToolNames.createReminder, out.undoPayload!);

    expect(state.allReminders.any((r) => r.id == id), isFalse);
    expect(service.deleted, [id]);
  });

  test('deshacer sin id lanza para que el llamador lo diga', () {
    expect(() => tools.undo(WriteToolNames.createReminder, const {}), throwsStateError);
  });
}
