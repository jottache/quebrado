import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/habitos/widgets/habits_today_sheet.dart';

import '../../helpers/pump_app.dart';

class _FakeHabitosService extends HabitosSupabaseService {
  _FakeHabitosService(this.habits);

  final List<HabitModel> habits;
  final List<HabitLogModel> saved = [];

  @override
  Future<HabitosBootstrapData> bootstrapData() async =>
      HabitosBootstrapData(habits: habits, stacks: [], logs: []);

  @override
  Future<void> saveHabitLog(HabitLogModel log) async => saved.add(log);
}

void main() {
  late _FakeHabitosService service;
  late HabitosState state;

  setUp(() async {
    final today = DateTime.now().weekday;
    final notToday = today == DateTime.sunday ? DateTime.monday : today + 1;
    service = _FakeHabitosService([
      HabitModel(id: 'g', title: 'Meditar'),
      HabitModel(id: 'c', title: 'Café', type: HabitType.counter),
      HabitModel(id: 'b', title: 'Fumar', type: HabitType.negative, isNegative: true),
      HabitModel(
        id: 'x',
        title: 'Gimnasio',
        frequencyType: HabitFrequencyType.customDays,
        frequencyPayload: {'days': [notToday]},
      ),
    ]);
    state = HabitosState(service: service);
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> open(WidgetTester tester, WindowClass window, {AgenteState? agente}) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showHabitsTodaySheet(context),
          child: const Text('abrir'),
        ),
      ),
      providers: [
        ChangeNotifierProvider<HabitosState>.value(value: state),
        if (agente != null) ChangeNotifierProvider<AgenteState>.value(value: agente),
      ],
      window: window,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    group('en ${window.name}', () {
      testWidgets('muestra solo los buenos programados para hoy', (tester) async {
        await open(tester, window);
        expect(find.text('Meditar'), findsOneWidget);
        expect(find.text('Café'), findsOneWidget);
        expect(find.text('Fumar'), findsNothing);
        expect(find.text('Gimnasio'), findsNothing);
        expect(find.text('Los malos hábitos se registran en Hábitos.'), findsOneWidget);
      });

      testWidgets('marcar guarda en hoy aunque Hábitos tenga otra fecha', (tester) async {
        state.selectDate(DateTime(2020, 1, 1));
        await open(tester, window);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(state.isCompleted('g', state.todayKey), isTrue);
        expect(state.selectedDateKey, '2020-01-01');
        expect(service.saved.last.logDate, state.todayKey);

        await tester.tap(find.text('+1'));
        await tester.pump();
        expect(state.getValue('c', state.todayKey), 1);
      });

      testWidgets('«Listo» cierra y muestra el aviso con el conteo', (tester) async {
        await open(tester, window);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();
        expect(find.text('Hábitos de hoy'), findsNothing);
        expect(find.text('Hábitos de hoy: 1 de 2 hechos'), findsOneWidget);
      });

      testWidgets('«Listo» sin cambios no muestra aviso', (tester) async {
        await open(tester, window);
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Hábitos de hoy:'), findsNothing);
      });

      testWidgets('«Listo» con cambios pone contento a Ortiz (CA-09)', (tester) async {
        final agente = AgenteState(autoInit: false);
        addTearDown(agente.dispose);
        await open(tester, window, agente: agente);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Listo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(agente.ortizMood, OrtizMood.happy);
        await tester.pump(AgenteState.celebrateDuration);
        await tester.pumpAndSettle();
      });

      testWidgets('«Listo» sin cambios no pone contento a Ortiz', (tester) async {
        final agente = AgenteState(autoInit: false);
        addTearDown(agente.dispose);
        await open(tester, window, agente: agente);
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();
        expect(agente.ortizMood, OrtizMood.idle);
      });
    });
  }
}
