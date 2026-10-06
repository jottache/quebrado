import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_log_model.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/screens/habitos_home_screen.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

class _FakeHabitosService extends HabitosSupabaseService {
  final List<HabitModel> habits;
  _FakeHabitosService(this.habits) : super(client: null);

  @override
  Future<HabitosBootstrapData> bootstrapData() async =>
      HabitosBootstrapData(habits: habits, stacks: [], logs: <HabitLogModel>[]);

  @override
  Future<void> saveHabitLog(HabitLogModel log) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la fila de contactos solo muestra contactos con hábitos, de más a menos', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final habits = [
      HabitModel(id: 'h1', title: 'Comer Mal', contactId: 'mariana'),
      HabitModel(id: 'h2', title: 'Abrazos', contactId: 'mariana'),
      HabitModel(id: 'h3', title: 'Pacientes', contactId: 'mariana'),
      HabitModel(id: 'h4', title: 'Llamar', contactId: 'carlos'),
      HabitModel(id: 'h5', title: 'Visitar', contactId: 'beto'),
      HabitModel(id: 'h6', title: 'Escribir', contactId: 'beto'),
      HabitModel(id: 'h7', title: 'Archivado', contactId: 'zoe', archived: true),
      HabitModel(id: 'h8', title: 'Leer'),
    ];
    final habitosState = HabitosState(service: _FakeHabitosService(habits));
    final diarioState = DiarioState();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    diarioState.contacts
      ..clear()
      ..addAll([
        DiarioContact(id: 'ana', name: 'Ana Sin Hábitos'),
        DiarioContact(id: 'beto', name: 'Beto'),
        DiarioContact(id: 'carlos', name: 'Carlos'),
        DiarioContact(id: 'mariana', name: 'Mariana Davila'),
        DiarioContact(id: 'zoe', name: 'Zoe Archivado'),
      ]);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitosState>.value(value: habitosState),
        ChangeNotifierProvider<DiarioState>.value(value: diarioState),
      ],
      child: const MaterialApp(home: HabitosHomeScreen()),
    ));
    await tester.pump();

    expect(find.text('Ana Sin Hábitos'), findsNothing);
    expect(find.text('Zoe Archivado'), findsNothing, reason: 'solo cuentan hábitos activos');

    final xMariana = tester.getTopLeft(find.text('Mariana Davila').first).dx;
    final xBeto = tester.getTopLeft(find.text('Beto').first).dx;
    final xCarlos = tester.getTopLeft(find.text('Carlos').first).dx;
    expect(xMariana, lessThan(xBeto), reason: '3 hábitos antes que 2');
    expect(xBeto, lessThan(xCarlos), reason: '2 hábitos antes que 1');
  });
}
