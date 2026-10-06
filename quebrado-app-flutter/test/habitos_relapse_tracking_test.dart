import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/dialogs/habit_detail_cli_dialog.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

class FakeHabitosService extends HabitosSupabaseService {
  final List<HabitModel> habits;
  final List<HabitLogModel> logs;
  final List<HabitLogModel> saved = [];

  FakeHabitosService({required this.habits, required this.logs}) : super(client: null);

  @override
  Future<HabitosBootstrapData> bootstrapData() async =>
      HabitosBootstrapData(habits: habits, stacks: [], logs: logs);

  @override
  Future<void> saveHabitLog(HabitLogModel log) async => saved.add(log);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final comerMal = HabitModel(
    id: 'cm',
    title: 'Comer Mal',
    type: HabitType.counter,
    isNegative: true,
    unit: 'veces',
    createdAt: _daysAgo(40),
  );
  final noFap = HabitModel(
    id: 'nf',
    title: 'No Fap',
    type: HabitType.negative,
    isNegative: true,
    createdAt: _daysAgo(20),
  );
  final abrazos = HabitModel(id: 'ab', title: 'Abrazos', type: HabitType.counter, unit: 'abrazos', createdAt: _daysAgo(40));

  // Registros tal como quedaron guardados con la versión anterior de la app
  List<HabitLogModel> legacyLogs() => [
        HabitLogModel(id: '1', habitId: 'cm', logDate: _key(_daysAgo(13)), value: 0, completed: false, notes: 'Recaída reportada en terminal'),
        HabitLogModel(id: '2', habitId: 'cm', logDate: _key(_daysAgo(12)), value: 2, completed: true), // +1 contaba como "cumplido"
        HabitLogModel(id: '3', habitId: 'cm', logDate: _key(_daysAgo(1)), value: 0, completed: false, notes: 'Recaída reportada en terminal'),
        HabitLogModel(id: '4', habitId: 'nf', logDate: _key(_daysAgo(5)), value: 0, completed: false, notes: 'Recaída reportada en terminal'),
        HabitLogModel(id: '5', habitId: 'nf', logDate: _key(_daysAgo(3)), value: 1, completed: true), // día limpio confirmado
        HabitLogModel(id: '6', habitId: 'ab', logDate: _key(_daysAgo(2)), value: 3, completed: true),
      ];

  Future<(HabitosState, FakeHabitosService)> buildState() async {
    final service = FakeHabitosService(habits: [comerMal, noFap, abrazos], logs: legacyLogs());
    final state = HabitosState(service: service);
    await Future<void>.delayed(Duration.zero);
    return (state, service);
  }

  group('Lectura de registros antiguos de malos hábitos', () {
    test('las recaídas con valor 0 y los contadores "cumplidos" cuentan como recaídas', () async {
      final (state, _) = await buildState();

      expect(state.isRelapseDay('cm', _key(_daysAgo(13))), isTrue);
      expect(state.getRelapseCount('cm', _key(_daysAgo(13))), 1, reason: 'el número exacto se perdió: mínimo 1');
      expect(state.isRelapseDay('cm', _key(_daysAgo(12))), isTrue);
      expect(state.getRelapseCount('cm', _key(_daysAgo(12))), 2);
      expect(state.isRelapseDay('nf', _key(_daysAgo(3))), isFalse, reason: 'día limpio confirmado');
      expect(state.isRelapseDay('ab', _key(_daysAgo(2))), isFalse, reason: 'un buen hábito nunca es recaída');
    });

    test('el resumen del rango cuenta días limpios, días con recaída y veces', () async {
      final (state, _) = await buildState();
      final stats = state.getRangeStats('cm', days: 30);

      expect(stats.trackedDays, 30);
      expect(stats.relapseDays, 3);
      expect(stats.relapseCount, 4); // 1 + 2 + 1
      expect(stats.successDays, 27);
      expect(state.calculateResilienceScore('cm'), closeTo(90, 0.01));
    });

    test('los días anteriores a la creación no cuentan en el rango', () async {
      final (state, _) = await buildState();
      final stats = state.getRangeStats('nf', days: 90);
      expect(stats.trackedDays, 21); // creado hace 20 días + hoy
      expect(state.getDayStatuses('nf', days: 90).first.kind, HabitDayKind.beforeCreation);
    });

    test('los días libres se cortan en la última recaída y no pasan de la creación', () async {
      final (state, _) = await buildState();
      expect(state.calculateCleanDays('cm'), 1, reason: 'hoy limpio, ayer recaída');

      final clean = HabitModel(id: 'x', title: 'Nuevo', type: HabitType.negative, isNegative: true, createdAt: _daysAgo(4));
      state.habits.add(clean);
      expect(state.calculateCleanDays('x'), 5, reason: 'antes contaba hasta 366 días');
    });
  });

  group('Registro nuevo de recaídas', () {
    test('reportar recaída suma 1 en vez de poner el contador en 0', () async {
      final (state, service) = await buildState();
      final today = state.todayKey;

      await state.reportRelapse('cm', dateKey: today);
      await state.reportRelapse('cm', dateKey: today);
      expect(state.getRelapseCount('cm', today), 2);
      expect(state.isCompleted('cm', today), isFalse);
      expect(service.saved.last.value, 2);
      expect(service.saved.last.completed, isFalse);
    });

    test('el +1 del contador en un mal hábito registra recaída, no un día cumplido', () async {
      final (state, _) = await buildState();
      final today = state.todayKey;

      await state.incrementCounter('cm', dateStr: today);
      await state.incrementCounter('cm', dateStr: today);
      expect(state.getRelapseCount('cm', today), 2);
      expect(state.isCompleted('cm', today), isFalse);
      expect(state.calculateCleanDays('cm'), 0);
    });

    test('bajar a 0 deja el día limpio otra vez', () async {
      final (state, _) = await buildState();
      final key = _key(_daysAgo(13)); // recaída antigua con valor 0

      await state.updateHabitValue('cm', -1, key);
      expect(state.isRelapseDay('cm', key), isFalse);
      expect(state.getRelapseCount('cm', key), 0);
    });

    test('se pueden corregir recaídas de días pasados', () async {
      final (state, _) = await buildState();
      final key = _key(_daysAgo(13));
      await state.updateHabitValue('cm', 2, key); // 1 → 3
      expect(state.getRelapseCount('cm', key), 3);
    });

    test('los buenos hábitos con contador siguen igual', () async {
      final (state, _) = await buildState();
      final today = state.todayKey;
      await state.incrementCounter('ab', dateStr: today);
      expect(state.isCompleted('ab', today), isTrue);
      expect(state.getValue('ab', today), 1);
    });

    test('un mal hábito sin recaída hoy cuenta como logrado en el progreso del día', () async {
      final (state, _) = await buildState();
      expect(state.isSuccessfulDay(comerMal, DateTime.now()), isTrue);
      await state.reportRelapse('cm', dateKey: state.todayKey);
      expect(state.isSuccessfulDay(comerMal, DateTime.now()), isFalse);
    });
  });

  group('Detalle del hábito', () {
    Future<HabitosState> pumpDetail(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = FakeHabitosService(habits: [comerMal, noFap, abrazos], logs: legacyLogs());
      final state = HabitosState(service: service);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<HabitosState>.value(value: state),
          ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
        ],
        child: MaterialApp(home: Scaffold(body: HabitDetailCliDialog(habit: comerMal))),
      ));
      await tester.pump();
      return state;
    }

    testWidgets('marca las recaídas en el calendario con su número de veces', (tester) async {
      await pumpDetail(tester);

      expect(find.text('×2'), findsOneWidget);
      expect(find.text('×1'), findsNWidgets(2));
      expect(find.textContaining('3 días · 4 veces'), findsOneWidget);
      expect(find.textContaining('27 de 30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('permite cambiar el rango a 3, 6 y 12 meses sin desbordes', (tester) async {
      await pumpDetail(tester);

      for (final days in [90, 180, 365]) {
        await tester.tap(find.byKey(ValueKey('habit_range_$days')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'rango $days');
      }
      expect(find.textContaining('Recaídas · 12 meses'), findsOneWidget);
      expect(find.textContaining('38 de 41'), findsOneWidget, reason: 'solo cuenta desde la creación (hace 40 días)');
    });

    testWidgets('tocar un día de recaída permite corregir el número', (tester) async {
      final state = await pumpDetail(tester);
      final key = _key(_daysAgo(12));

      await tester.tap(find.byKey(ValueKey('habit_day_$key')));
      await tester.pumpAndSettle();
      expect(find.text('2 veces'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('habit_day_plus')));
      await tester.pump();
      expect(state.getRelapseCount('cm', key), 3);
      expect(find.text('3 veces'), findsOneWidget);
    });
  });
}
