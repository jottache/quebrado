import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

/// Servicio fake: datos fijos en memoria y registro de lo guardado.
class _FakeHabitosService extends HabitosSupabaseService {
  _FakeHabitosService({required this.habits, List<HabitLogModel>? logs})
      : logs = logs ?? [];

  final List<HabitModel> habits;
  final List<HabitLogModel> logs;
  final List<HabitLogModel> saved = [];

  @override
  Future<HabitosBootstrapData> bootstrapData() async =>
      HabitosBootstrapData(habits: habits, stacks: [], logs: logs);

  @override
  Future<void> saveHabitLog(HabitLogModel log) async => saved.add(log);
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

HabitLogModel _done(String habitId, DateTime d) =>
    HabitLogModel(id: 'log-$habitId-${_key(d)}', habitId: habitId, logDate: _key(d), completed: true);

Future<HabitosState> _state(_FakeHabitosService service) async {
  final state = HabitosState(service: service);
  await Future<void>.delayed(Duration.zero);
  expect(state.isLoading, isFalse);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Miércoles 18 de noviembre de 2026.
  final wednesday = DateTime(2026, 11, 18);
  final monday = DateTime(2026, 11, 16);
  final tuesday = DateTime(2026, 11, 17);

  test('dateKeyOf da la clave yyyy-MM-dd con ceros a la izquierda', () async {
    final state = await _state(_FakeHabitosService(habits: []));
    expect(state.dateKeyOf(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  group('toggleHabitCompletion con dateKey', () {
    test('marca el día indicado sin cambiar la fecha seleccionada', () async {
      final service = _FakeHabitosService(habits: [HabitModel(id: 'h1', title: 'Meditar')]);
      final state = await _state(service);
      state.selectDate(DateTime(2026, 1, 5));
      final selectedBefore = state.selectedDateKey;
      final target = _key(wednesday);

      var notified = 0;
      state.addListener(() => notified++);
      await state.toggleHabitCompletion('h1', dateKey: target);

      expect(state.selectedDateKey, selectedBefore);
      expect(state.isCompleted('h1', target), isTrue);
      expect(state.isCompleted('h1', selectedBefore), isFalse);
      expect(service.saved.single.logDate, target);
      expect(notified, greaterThan(0));
    });

    test('sin dateKey marca la fecha seleccionada (comportamiento de siempre)', () async {
      final service = _FakeHabitosService(habits: [HabitModel(id: 'h1', title: 'Meditar')]);
      final state = await _state(service);
      state.selectDate(DateTime(2026, 1, 5));

      await state.toggleHabitCompletion('h1');

      expect(state.isCompleted('h1', '2026-01-05'), isTrue);
      expect(service.saved.single.logDate, '2026-01-05');
    });

    test('un segundo toque con dateKey desmarca ese día', () async {
      final service = _FakeHabitosService(habits: [HabitModel(id: 'h1', title: 'Meditar')]);
      final state = await _state(service);
      final target = _key(wednesday);

      await state.toggleHabitCompletion('h1', dateKey: target);
      await state.toggleHabitCompletion('h1', dateKey: target);

      expect(state.isCompleted('h1', target), isFalse);
    });
  });

  group('isScheduledOn / goodHabitsScheduledOn', () {
    test('diario: siempre programado', () async {
      final h = HabitModel(id: 'd', title: 'Leer');
      final state = await _state(_FakeHabitosService(habits: [h]));
      expect(state.isScheduledOn(h, wednesday), isTrue);
    });

    test('días específicos: solo los días de la lista (1 = lunes)', () async {
      final h = HabitModel(
        id: 'c',
        title: 'Gimnasio',
        frequencyType: HabitFrequencyType.customDays,
        frequencyPayload: const {'days': [1, 5]},
      );
      final state = await _state(_FakeHabitosService(habits: [h]));
      expect(state.isScheduledOn(h, monday), isTrue);
      expect(state.isScheduledOn(h, wednesday), isFalse);
    });

    test('días específicos sin lista válida: se muestra todos los días', () async {
      final h = HabitModel(
        id: 'c',
        title: 'Gimnasio',
        frequencyType: HabitFrequencyType.customDays,
      );
      final state = await _state(_FakeHabitosService(habits: [h]));
      expect(state.isScheduledOn(h, wednesday), isTrue);
    });

    test('meta semanal cumplida antes de hoy: ya no está programado', () async {
      final h = HabitModel(
        id: 'w',
        title: 'Correr',
        frequencyType: HabitFrequencyType.weeklyTarget,
        frequencyPayload: const {'times_per_week': 2},
      );
      final state = await _state(_FakeHabitosService(
        habits: [h],
        logs: [_done('w', monday), _done('w', tuesday)],
      ));
      expect(state.isScheduledOn(h, wednesday), isFalse);
    });

    test('meta semanal sin cumplir: sigue programado', () async {
      final h = HabitModel(
        id: 'w',
        title: 'Correr',
        frequencyType: HabitFrequencyType.weeklyTarget,
        frequencyPayload: const {'times_per_week': 2},
      );
      final state = await _state(_FakeHabitosService(habits: [h], logs: [_done('w', monday)]));
      expect(state.isScheduledOn(h, wednesday), isTrue);
    });

    test('meta semanal: los días de la semana anterior no cuentan', () async {
      final h = HabitModel(
        id: 'w',
        title: 'Correr',
        frequencyType: HabitFrequencyType.weeklyTarget,
        frequencyPayload: const {'times_per_week': 1},
      );
      // Domingo 15 de noviembre pertenece a la semana anterior.
      final state = await _state(_FakeHabitosService(
        habits: [h],
        logs: [_done('w', DateTime(2026, 11, 15))],
      ));
      expect(state.isScheduledOn(h, wednesday), isTrue);
    });

    test('meta semanal cumplida y hecho hoy: sigue programado para poder desmarcarlo', () async {
      final h = HabitModel(
        id: 'w',
        title: 'Correr',
        frequencyType: HabitFrequencyType.weeklyTarget,
        frequencyPayload: const {'times_per_week': 1},
      );
      final state = await _state(_FakeHabitosService(
        habits: [h],
        logs: [_done('w', monday), _done('w', wednesday)],
      ));
      expect(state.isScheduledOn(h, wednesday), isTrue);
    });

    test('goodHabitsScheduledOn excluye malos, archivados y no programados', () async {
      final state = await _state(_FakeHabitosService(habits: [
        HabitModel(id: 'ok', title: 'Leer'),
        HabitModel(id: 'bad', title: 'Fumar', type: HabitType.negative, isNegative: true),
        HabitModel(id: 'arch', title: 'Viejo', archived: true),
        HabitModel(
          id: 'fri',
          title: 'Viernes',
          frequencyType: HabitFrequencyType.customDays,
          frequencyPayload: const {'days': [5]},
        ),
      ]));
      expect(state.goodHabitsScheduledOn(wednesday).map((h) => h.id), ['ok']);
    });
  });

  group('addHabit', () {
    test('devuelve el hábito creado con el id pedido y ya está en la lista antes de guardar', () async {
      final state = await _state(_FakeHabitosService(habits: []));
      var notified = 0;
      state.addListener(() => notified++);

      final pending = state.addHabit(id: 'h-nuevo', title: '  Leer  ', contactId: 'c1');
      // Sin esperar el guardado: el diálogo lo busca por id al cerrar.
      expect(state.habits.map((h) => h.id), ['h-nuevo']);
      expect(notified, 1);

      final created = await pending;
      expect(created.id, 'h-nuevo');
      expect(created.title, 'Leer');
      expect(created.contactId, 'c1');
      expect(identical(created, state.habits.single), isTrue);
    });

    test('genera un id si no se pasa', () async {
      final state = await _state(_FakeHabitosService(habits: []));
      final created = await state.addHabit(title: 'Correr');
      expect(created.id, isNotEmpty);
      expect(state.habits.single.id, created.id);
    });
  });
}
