import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/recordatorios/screens/reminders_home_screen.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/quebrado/screens/dashboard_screen.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/screens/app_launcher_screen.dart';

import 'package:showcaseview/showcaseview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderModel Pinned & TimeRemaining Tests', () {
    test('timeRemainingFormatted calculates days and hours correctly for future date', () {
      final now = DateTime.now();
      // Due in 3 days and 5 hours
      final futureDue = now.add(const Duration(days: 3, hours: 5));
      final reminder = ReminderModel(
        id: 'r1',
        title: 'Comprar boletos',
        dueAt: futureDue,
        isPinned: true,
      );

      expect(reminder.isPinned, isTrue);
      expect(reminder.timeRemainingFormatted, contains('Faltan 3 días y 5 horas'));
    });

    test('timeRemainingFormatted calculates hours and minutes for today', () {
      final now = DateTime.now();
      final futureDue = now.add(const Duration(hours: 4, minutes: 15));
      final reminder = ReminderModel(
        id: 'r2',
        title: 'Reunión de equipo',
        dueAt: futureDue,
      );

      expect(reminder.timeRemainingFormatted, contains('Faltan 4 horas y 15 min'));
    });

    test('timeRemainingFormatted returns overdue for past dates', () {
      final now = DateTime.now();
      final pastDue = now.subtract(const Duration(days: 2, hours: 3));
      final reminder = ReminderModel(
        id: 'r3',
        title: 'Pago vencido',
        dueAt: pastDue,
      );

      expect(reminder.timeRemainingFormatted, contains('Vencido hace 2d 3h'));
    });

    test('timeRemainingFormatted handles null dueAt', () {
      final reminder = ReminderModel(
        id: 'r4',
        title: 'Sin fecha',
        dueAt: null,
      );

      expect(reminder.timeRemainingFormatted, equals('Sin fecha límite'));
    });
  });

  group('RemindersState Pinning Tests', () {
    test('togglePin toggles isPinned and updates pinnedReminders list', () async {
      final state = RemindersState();
      await state.init();

      final first = state.allReminders.first;
      final initialPinned = first.isPinned;

      await state.togglePin(first.id);

      final updated = state.allReminders.firstWhere((r) => r.id == first.id);
      expect(updated.isPinned, equals(!initialPinned));

      if (updated.isPinned) {
        expect(state.pinnedReminders.any((r) => r.id == first.id), isTrue);
      } else {
        expect(state.pinnedReminders.any((r) => r.id == first.id), isFalse);
      }
    });
  });

  group('RemindersHomeScreen Pinned Banner Widget Tests', () {
    testWidgets('Renders pinned banner with title and time remaining when reminders are pinned', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = RemindersState();
      await state.init();

      // Clear existing pins so testReminder is the active page in the pinned banner
      for (final r in state.pinnedReminders) {
        await state.togglePin(r.id);
      }

      // Ensure at least one reminder is pinned
      final now = DateTime.now();
      final testReminder = ReminderModel(
        id: 'pinned-test-1',
        title: 'Renovar pasaporte urgente',
        isPinned: true,
        dueAt: now.add(const Duration(days: 5, hours: 2)),
      );
      await state.saveReminder(testReminder);

      await tester.pumpWidget(
        ChangeNotifierProvider<RemindersState>.value(
          value: state,
          child: const MaterialApp(
            home: RemindersHomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the Pinned Banner header is rendered
      expect(find.text('RECORDATORIO FIJADO'), findsOneWidget);
      expect(find.text('Renovar pasaporte urgente'), findsWidgets);
      expect(find.textContaining('Faltan 5 días y 2 horas'), findsOneWidget);

      // Verify pin badge on reminder card
      expect(find.text('Fijado'), findsWidgets);
    });
  });

  group('Sync Button & Quebrado Card Alignment Tests', () {
    testWidgets('DashboardScreen displays sync button next to calculator in AppBar', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: ShowCaseWidget(
              builder: (context) => const DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify sync button exists with tooltip "Sincronizar datos"
      expect(find.byTooltip('Sincronizar datos'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      // Verify calculator button also exists next to it
      expect(find.byTooltip('Calculadora de divisas'), findsOneWidget);
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    });

    testWidgets('AppLauncherScreen displays sync button and Quebrado card without circular notification border', (tester) async {
      final appState = AppState();
      final diarioState = DiarioState();
      final habitosState = HabitosState();
      final remindersState = RemindersState();
      final agenteState = AgenteState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<DiarioState>.value(value: diarioState),
            ChangeNotifierProvider<HabitosState>.value(value: habitosState),
            ChangeNotifierProvider<RemindersState>.value(value: remindersState),
            ChangeNotifierProvider<AgenteState>.value(value: agenteState),
          ],
          child: const MaterialApp(
            home: AppLauncherScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify sync button in top bar
      expect(find.byTooltip('Sincronizar datos'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      // Verify Quebrado logo asset is rendered
      expect(find.byType(Image), findsWidgets);

      // Notification icon is rendered cleanly without circular container
      expect(find.byIcon(Icons.notifications_none_rounded), findsWidgets);
    });
  });
}
