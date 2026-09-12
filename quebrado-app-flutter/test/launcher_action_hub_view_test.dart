import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/screens/launcher_action_hub_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LauncherActionHubView Tests', () {
    testWidgets('Renders all 4 operational app sections and quick actions', (tester) async {
      final appState = AppState();
      final diarioState = DiarioState();
      final habitosState = HabitosState();
      final remindersState = RemindersState();

      // Wait until loading finishes
      for (int i = 0; i < 20; i++) {
        if (!habitosState.isLoading && !remindersState.isLoading) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Add a missing habit
      habitosState.habits.add(
        HabitModel(
          id: 'test_habit_1',
          title: 'Tomar 2L de agua',
          type: HabitType.binary,
        ),
      );

      // Add an infinite counter habit
      habitosState.habits.add(
        HabitModel(
          id: 'test_habit_2',
          title: 'Decir groserías',
          type: HabitType.counter,
          unit: 'veces',
        ),
      );

      // Add a pending reminder
      await remindersState.saveReminder(
        ReminderModel(
          id: 'rem_1',
          title: 'Pagar tarjeta de crédito',
          status: ReminderStatus.pending,
          dueAt: DateTime.now().add(const Duration(hours: 3)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LauncherActionHubView(
                appState: appState,
                diarioState: diarioState,
                habitosState: habitosState,
                remindersState: remindersState,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify Section Headers
      expect(find.text('QUEBRADO • FINANZAS'), findsOneWidget);
      expect(find.text('DIARIO JOTTACHE'), findsOneWidget);
      expect(find.text('HÁBITOS • HOY'), findsOneWidget);
      expect(find.text('RECORDATORIOS & AGENDA'), findsOneWidget);

      // Verify Quebrado buttons
      expect(find.text('Registrar Ingreso'), findsOneWidget);
      expect(find.text('Registrar Gasto'), findsOneWidget);
      expect(find.text('BCV'), findsOneWidget);
      expect(find.text('PARALELO'), findsOneWidget);
      expect(find.text('EURO'), findsOneWidget);
      expect(find.text('CUENTAS & BALANCES'), findsOneWidget);

      // Verify Diario
      expect(find.text('PRÓXIMOS CUMPLEAÑOS'), findsOneWidget);
      expect(find.text('Registro Rápido en Contacto'), findsOneWidget);
      expect(find.text('ÚLTIMOS 5 REGISTROS EN CONTACTOS'), findsOneWidget);

      // Verify Hábitos
      expect(find.text('FALTANTES POR REGISTRAR HOY'), findsOneWidget);
      expect(find.text('Tomar 2L de agua'), findsOneWidget);
      expect(find.text('Decir groserías'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_rounded), findsWidgets); // Counter +1 button

      // Verify Recordatorios
      expect(find.text('PRÓXIMOS 5 EVENTOS'), findsOneWidget);
      expect(find.text('Pagar tarjeta de crédito'), findsOneWidget);
      expect(find.text('Nuevo'), findsOneWidget);
    });

    testWidgets('Counter habit +1 button increments value in state', (tester) async {
      final appState = AppState();
      final diarioState = DiarioState();
      final habitosState = HabitosState();
      final remindersState = RemindersState();

      for (int i = 0; i < 20; i++) {
        if (!habitosState.isLoading && !remindersState.isLoading) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      final counterHabit = HabitModel(
        id: 'counter_h1',
        title: 'Groserías',
        type: HabitType.counter,
        unit: 'veces',
      );
      habitosState.habits.add(counterHabit);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LauncherActionHubView(
                appState: appState,
                diarioState: diarioState,
                habitosState: habitosState,
                remindersState: remindersState,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(habitosState.getValue('counter_h1'), equals(0.0));

      final addBtn = find.byIcon(Icons.add_circle_rounded);
      expect(addBtn, findsWidgets);

      await tester.ensureVisible(addBtn.first);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(addBtn.first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(habitosState.getValue('counter_h1'), equals(1.0));
    });
  });
}
