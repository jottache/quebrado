import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/habitos_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

/// Servicio fake: datos fijos en memoria y registro de lo guardado.
class _FakeHabitosService extends HabitosSupabaseService {
  _FakeHabitosService({required List<HabitModel> habits, List<HabitLogModel>? logs})
      : habits = List.of(habits),
        logs = List.of(logs ?? const []);

  final List<HabitModel> habits;
  final List<HabitLogModel> logs;
  final List<HabitLogModel> savedLogs = [];
  final List<HabitModel> savedHabits = [];
  final List<String> deletedHabits = [];
  bool fail = false;

  @override
  Future<HabitosBootstrapData> bootstrapData() async =>
      HabitosBootstrapData(habits: List.of(habits), stacks: [], logs: List.of(logs));

  @override
  Future<void> saveHabitLog(HabitLogModel log) async {
    if (fail) throw StateError('sin conexión');
    savedLogs.add(log);
  }

  @override
  Future<void> saveHabit(HabitModel habit) async {
    if (fail) throw StateError('sin conexión');
    savedHabits.add(habit);
  }

  @override
  Future<void> deleteHabit(String habitId) async => deletedHabits.add(habitId);
}

const _today = '2026-11-18';

Future<HabitosState> _state(_FakeHabitosService service) async {
  final state = HabitosState(service: service);
  await Future<void>.delayed(Duration.zero);
  expect(state.isLoading, isFalse);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 18, 10);
  WriteContext ctx({
    bool untrusted = false,
    bool second = false,
    bool confirmed = false,
    String userText = 'ya leí hoy',
  }) =>
      WriteContext(
        userText: userText,
        untrustedRead: untrusted,
        directWriteDone: second,
        confirmedByUser: confirmed,
        now: () => now,
      );

  final leer = HabitModel(id: 'h-leer', title: 'Leer');
  final correr = HabitModel(id: 'h-correr', title: 'Correr');

  Future<(HabitosState, _FakeHabitosService, HabitosWriteTools)> setup(
    List<HabitModel> habits, {
    List<HabitLogModel>? logs,
  }) async {
    final service = _FakeHabitosService(habits: habits, logs: logs);
    final state = await _state(service);
    return (state, service, HabitosWriteTools(state));
  }

  test('atiende markHabitDone y createHabit', () async {
    final (_, _, tools) = await setup([leer]);
    expect(tools.toolNames, {WriteToolNames.markHabitDone, WriteToolNames.createHabit});
  });

  group('markHabitDone', () {
    test('CA-08: «leer» marca «Leer» como hecho hoy y deshacer lo desmarca', () async {
      final (state, service, tools) = await setup([leer, correr]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'leer'}, ctx());

      expect(out.result.isSaved, isTrue);
      expect(state.isCompleted('h-leer', _today), isTrue);
      expect(service.savedLogs.single.logDate, _today);
      expect(out.result.recordId, 'h-leer');
      expect(out.result.route, SuiteRoutes.habito('h-leer'));
      expect(out.summaryTitle, 'Leer');
      expect(out.summaryParts.map((p) => p.text), ['Hecho hoy']);
      expect(out.result.summary, 'Leer · Hecho hoy');
      expect(out.undoPayload, isNotNull);

      await tools.undo(WriteToolNames.markHabitDone, out.undoPayload!);
      expect(state.isCompleted('h-leer', _today), isFalse);
    });

    test('si ya estaba hecho responde saved sin nada que deshacer ni guardar', () async {
      final (state, service, tools) = await setup([leer], logs: [
        HabitLogModel(id: 'l1', habitId: 'h-leer', logDate: _today, completed: true),
      ]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'Leer'}, ctx());

      expect(out.result.isSaved, isTrue);
      expect(out.undoPayload, isNull);
      expect(out.result.undoId, isNull);
      expect(out.result.summary, startsWith('Ya estaba marcado'));
      expect(service.savedLogs, isEmpty);
      expect(state.isCompleted('h-leer', _today), isTrue);
    });

    test('con la fecha de ayer lo marca ese día y lo dice', () async {
      final (state, _, tools) = await setup([leer]);

      final out = await tools.execute(
        WriteToolNames.markHabitDone,
        {'habitName': 'Leer', 'date': '2026-11-17'},
        ctx(),
      );

      expect(out.result.isSaved, isTrue);
      expect(state.isCompleted('h-leer', '2026-11-17'), isTrue);
      expect(state.isCompleted('h-leer', _today), isFalse);
      expect(out.summaryParts.single.text, 'Hecho ayer');
    });

    test('en un contador suma 1 y deshacer resta 1', () async {
      final agua = HabitModel(id: 'h-agua', title: 'Vasos de agua', type: HabitType.counter, unit: 'vasos');
      final (state, _, tools) = await setup([agua], logs: [
        HabitLogModel(id: 'l1', habitId: 'h-agua', logDate: _today, value: 2, completed: true),
      ]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'vasos de agua'}, ctx(userText: 'me tomé un vaso de agua'));

      expect(out.result.isSaved, isTrue);
      expect(state.getValue('h-agua', _today), 3);
      expect(out.summaryParts.single.text, '3 vasos hoy');

      await tools.undo(WriteToolNames.markHabitDone, out.undoPayload!);
      expect(state.getValue('h-agua', _today), 2);
    });

    test('un hábito negativo no se marca: devuelve error claro', () async {
      final fumar = HabitModel(id: 'h-fumar', title: 'Fumar', isNegative: true, type: HabitType.negative);
      final azucar = HabitModel(id: 'h-azucar', title: 'Azúcar', isNegative: true);
      final (state, service, tools) = await setup([fumar, azucar]);

      for (final name in ['fumar', 'azucar']) {
        final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': name}, ctx());
        expect(out.result.isError, isTrue);
        expect(out.result.message, contains('hábito que quieres dejar'));
        expect(out.result.message, startsWith('No pude registrarlo: '));
        expect(out.result.message, endsWith('No se guardó nada.'));
      }
      expect(service.savedLogs, isEmpty);
      expect(state.getLog('h-fumar', _today), isNull);
    });

    test('con varias coincidencias pide elegir el hábito', () async {
      final (_, service, tools) = await setup([
        HabitModel(id: 'a', title: 'Leer libro'),
        HabitModel(id: 'b', title: 'Leer noticias'),
        correr,
      ]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'leer'}, ctx());

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['habit']);
      expect(out.result.options['habit'], ['Leer libro', 'Leer noticias']);
      expect(service.savedLogs, isEmpty);
    });

    test('sin coincidencias devuelve error con los hábitos existentes', () async {
      final (_, _, tools) = await setup([leer, correr]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'nadar'}, ctx());

      expect(out.result.isError, isTrue);
      expect(out.result.message, contains('«nadar»'));
      expect(out.result.message, contains('Leer, Correr'));
    });

    test('fecha inválida pide la fecha y lista lo ya resuelto', () async {
      final (_, _, tools) = await setup([leer]);

      final out = await tools.execute(
        WriteToolNames.markHabitDone,
        {'habitName': 'Leer', 'date': 'mañana'},
        ctx(),
      );

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['date']);
      expect(out.result.resolved, {'habit': 'Leer'});
    });

    test('fecha futura sale como tarjeta y al confirmar se guarda', () async {
      final (state, _, tools) = await setup([leer]);
      final args = {'habitName': 'Leer', 'date': '2026-11-20'};

      final out = await tools.execute(WriteToolNames.markHabitDone, args, ctx());
      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['future_date']);
      expect(state.isCompleted('h-leer', '2026-11-20'), isFalse);

      final confirmed = await tools.execute(WriteToolNames.markHabitDone, out.commitArgs!, ctx(confirmed: true));
      expect(confirmed.result.isSaved, isTrue);
      expect(state.isCompleted('h-leer', '2026-11-20'), isTrue);
    });

    test('S3-09: el término del modelo no ancla («Correr hola» con «hola»)', () async {
      final (state, _, tools) = await setup([leer, correr]);

      final out = await tools.execute(
          WriteToolNames.markHabitDone, {'habitName': 'Correr hola'}, ctx(userText: 'hola'));

      expect(out.result.isSaved, isFalse, reason: out.result.toString());
      expect(state.isCompleted('h-correr', _today), isFalse);
    });

    test('S3-02: un hábito que la persona no nombró sale como tarjeta y no se marca', () async {
      final (state, _, tools) = await setup([leer, correr]);

      final out = await tools.execute(
          WriteToolNames.markHabitDone, {'habitName': 'Correr'}, ctx(userText: 'hola, ¿les cuento algo?'));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['name_not_in_user_text']);
      expect(state.isCompleted('h-correr', _today), isFalse);

      final confirmed = await tools.execute(WriteToolNames.markHabitDone, out.commitArgs!, ctx(confirmed: true));
      expect(confirmed.result.isSaved, isTrue);
      expect(state.isCompleted('h-correr', _today), isTrue);
    });

    test('S3-02: el hábito se ancla conjugado («corrí» → Correr), no por palabras parecidas', () async {
      final (state, _, tools) = await setup([leer, correr]);

      final conjugado = await tools.execute(
          WriteToolNames.markHabitDone, {'habitName': 'Correr'}, ctx(userText: 'hoy corrí 5 km'));
      expect(conjugado.result.isSaved, isTrue);

      final parecido = await tools.execute(
          WriteToolNames.markHabitDone, {'habitName': 'Leer'}, ctx(userText: 'compré leche y les escribí'));
      expect(parecido.result.isProposal, isTrue);
      expect(state.isCompleted('h-leer', _today), isFalse);
    });

    test('segunda escritura del turno sale como tarjeta y al confirmar se guarda', () async {
      final (state, _, tools) = await setup([leer]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'Leer'}, ctx(second: true));
      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['multiple_writes']);
      expect(out.commitArgs, {'habitId': 'h-leer', 'habitName': 'Leer', 'date': _today});
      expect(state.isCompleted('h-leer', _today), isFalse);

      final confirmed = await tools.execute(
        WriteToolNames.markHabitDone,
        out.commitArgs!,
        ctx(second: true, confirmed: true),
      );
      expect(confirmed.result.isSaved, isTrue);
      expect(state.isCompleted('h-leer', _today), isTrue);
    });

    test('deshacer no vuelve a alternar si la persona ya lo desmarcó', () async {
      final (state, _, tools) = await setup([leer]);
      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'Leer'}, ctx());
      await state.toggleHabitCompletion('h-leer', dateKey: _today);
      expect(state.isCompleted('h-leer', _today), isFalse);

      await tools.undo(WriteToolNames.markHabitDone, out.undoPayload!);

      expect(state.isCompleted('h-leer', _today), isFalse);
    });

    test('deshacer recupera el avance parcial de un hábito de cantidad', () async {
      final paginas = HabitModel(id: 'h-pag', title: 'Páginas', type: HabitType.quantitative, targetValue: 20);
      final (state, _, tools) = await setup([paginas], logs: [
        HabitLogModel(id: 'l1', habitId: 'h-pag', logDate: _today, value: 5, completed: false),
      ]);

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'paginas'}, ctx(userText: 'leí mis páginas'));
      expect(state.isCompleted('h-pag', _today), isTrue);

      await tools.undo(WriteToolNames.markHabitDone, out.undoPayload!);
      expect(state.isCompleted('h-pag', _today), isFalse);
      expect(state.getValue('h-pag', _today), 5);
    });

    test('si el guardado falla devuelve error y no deja el hábito marcado', () async {
      final (state, service, tools) = await setup([leer]);
      service.fail = true;

      final out = await tools.execute(WriteToolNames.markHabitDone, {'habitName': 'Leer'}, ctx());

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'No pude registrarlo: falló el guardado del hábito. No se guardó nada.');
      expect(out.undoPayload, isNull);
      expect(state.isCompleted('h-leer', _today), isFalse);
    });
  });

  group('createHabit', () {
    test('crea el hábito y deshacer lo borra', () async {
      final (state, service, tools) = await setup([leer]);

      final out = await tools.execute(WriteToolNames.createHabit, {'title': 'Meditar 10 min'}, ctx());

      expect(out.result.isSaved, isTrue);
      final id = out.result.recordId!;
      final created = state.habits.firstWhere((h) => h.id == id);
      expect(created.title, 'Meditar 10 min');
      expect(created.isNegative, isFalse);
      expect(created.type, HabitType.binary);
      expect(service.savedHabits.single.id, id);
      expect(out.result.route, SuiteRoutes.habito(id));
      expect(out.result.summary, 'Meditar 10 min · Hábito por construir');
      expect(out.undoPayload, {'habitId': id});

      await tools.undo(WriteToolNames.createHabit, out.undoPayload!);
      expect(state.habits.any((h) => h.id == id), isFalse);
      expect(service.deletedHabits, [id]);
    });

    test('un mal hábito se crea como negativo', () async {
      final (state, _, tools) = await setup([]);

      final out = await tools.execute(
        WriteToolNames.createHabit,
        {'title': 'No comer azúcar', 'isNegative': true},
        ctx(),
      );

      final created = state.habits.single;
      expect(created.isNegative, isTrue);
      expect(created.type, HabitType.negative);
      expect(out.summaryParts.single.text, 'Hábito por dejar');
    });

    test('nombre duplicado sale como tarjeta y al confirmar se crea', () async {
      final (state, _, tools) = await setup([leer]);

      final out = await tools.execute(WriteToolNames.createHabit, {'title': ' leer. '}, ctx());
      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['duplicate_name']);
      expect(state.habits, hasLength(1));

      final confirmed = await tools.execute(WriteToolNames.createHabit, out.commitArgs!, ctx(confirmed: true));
      expect(confirmed.result.isSaved, isTrue);
      expect(state.habits, hasLength(2));
    });

    test('sin título pide el título', () async {
      final (state, _, tools) = await setup([]);

      final out = await tools.execute(WriteToolNames.createHabit, {'title': '  '}, ctx());

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['title']);
      expect(state.habits, isEmpty);
    });

    test('con texto leído en el turno sale como tarjeta', () async {
      final (state, _, tools) = await setup([]);

      final out = await tools.execute(WriteToolNames.createHabit, {'title': 'Correr'}, ctx(untrusted: true));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['read_untrusted_text']);
      expect(out.commitArgs, {'title': 'Correr', 'isNegative': false});
      expect(state.habits, isEmpty);
    });

    test('si el guardado falla devuelve error y no deja el hábito', () async {
      final (state, service, tools) = await setup([]);
      service.fail = true;

      final out = await tools.execute(WriteToolNames.createHabit, {'title': 'Correr'}, ctx());

      expect(out.result.isError, isTrue);
      expect(out.result.message, endsWith('No se guardó nada.'));
      expect(state.habits, isEmpty);
    });
  });
}
