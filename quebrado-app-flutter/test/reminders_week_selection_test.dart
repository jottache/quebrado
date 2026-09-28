import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/recordatorios/dialogs/sunday_planning_wizard_dialog.dart';
import 'package:quebrado_app_flutter/recordatorios/models/covey_quadrant.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/services/reminders_supabase_service.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';

DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Semana a planificar', () {
    test('sábado y domingo sugieren la semana siguiente; entre semana la actual', () {
      expect(RemindersState.defaultPlanningMonday(DateTime(2026, 9, 27, 18)), DateTime(2026, 9, 28)); // domingo
      expect(RemindersState.defaultPlanningMonday(DateTime(2026, 9, 26, 10)), DateTime(2026, 9, 28)); // sábado
      expect(RemindersState.defaultPlanningMonday(DateTime(2026, 9, 28, 8)), DateTime(2026, 9, 28)); // lunes
      expect(RemindersState.defaultPlanningMonday(DateTime(2026, 9, 23, 12)), DateTime(2026, 9, 21)); // miércoles
    });

    test('el cambio de mes y de año calcula bien el lunes siguiente', () {
      expect(RemindersState.defaultPlanningMonday(DateTime(2026, 11, 1)), DateTime(2026, 11, 2)); // domingo 1 nov
      expect(RemindersState.defaultPlanningMonday(DateTime(2027, 1, 3)), DateTime(2027, 1, 4)); // domingo 3 ene
    });

    test('isUuid rechaza ids locales que Supabase no acepta', () {
      expect(RemindersSupabaseService.isUuid('3c442d53-85ba-49af-b6ad-3930cf186bc7'), isTrue);
      expect(RemindersSupabaseService.isUuid('local-user'), isFalse);
      expect(RemindersSupabaseService.isUuid('role_individual'), isFalse);
      expect(RemindersSupabaseService.isUuid('local-week-2026-09-28'), isFalse);
      expect(RemindersSupabaseService.isUuid(null), isFalse);
    });
  });

  group('RemindersState · navegación por semanas', () {
    late RemindersState state;
    late DateTime thisMonday;

    setUp(() async {
      state = RemindersState(service: RemindersSupabaseService());
      await state.init();
      thisMonday = RemindersState.thisWeekMonday();
    });

    test('empieza en la semana actual y navega hacia adelante y atrás', () async {
      expect(state.isViewingCurrentWeek, isTrue);
      expect(state.selectedWeekOffset, 0);

      await state.nextWeek();
      expect(state.currentMonday, _addDays(thisMonday, 7));
      expect(state.selectedWeekOffset, 1);
      expect(state.currentWeeklyPlan!.weekStartDate, _addDays(thisMonday, 7));

      await state.previousWeek();
      await state.previousWeek();
      expect(state.selectedWeekOffset, -1);

      await state.goToCurrentWeek();
      expect(state.isViewingCurrentWeek, isTrue);
    });

    test('mover un recordatorio a un día usa la fecha de la semana seleccionada', () async {
      final r = await state.createFromNlp('Preparar presentación !q2');
      await state.nextWeek();
      await state.moveReminderToDay(r.id, 2); // miércoles de la próxima semana

      final moved = state.allReminders.firstWhere((x) => x.id == r.id);
      expect(DateTime(moved.dueAt!.year, moved.dueAt!.month, moved.dueAt!.day), _addDays(thisMonday, 7 + 2));
      expect(state.remindersForDayOfWeek(2).any((x) => x.id == r.id), isTrue);

      // En la semana actual ya no aparece ese miércoles
      await state.goToCurrentWeek();
      expect(state.remindersForDayOfWeek(2).any((x) => x.id == r.id), isFalse);
    });

    test('un recordatorio con fecha solo aparece en su semana (no en todas)', () async {
      final nextMonday = _addDays(thisMonday, 7);
      final rock = ReminderModel(
        id: 'rock-next',
        title: 'Gran Roca de la próxima semana',
        priority: ReminderPriority.p1Urgent,
        status: ReminderStatus.pending,
        dueAt: DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 9),
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: true,
        scheduledDayOfWeek: 0,
      );
      await state.saveReminder(rock);

      expect(state.remindersForDayOfWeek(0).any((x) => x.id == rock.id), isFalse);
      expect(state.bigRocksForCurrentWeek.any((x) => x.id == rock.id), isFalse);

      await state.nextWeek();
      expect(state.remindersForDayOfWeek(0).any((x) => x.id == rock.id), isTrue);
      expect(state.bigRocksForCurrentWeek.any((x) => x.id == rock.id), isTrue);
    });

    test('no se asocia al plan de la semana vista un recordatorio con fecha en otra semana', () async {
      await state.nextWeek();
      final planId = state.currentWeeklyPlan!.id;
      final r = ReminderModel(
        id: 'r-this-week',
        title: 'Algo para esta semana',
        priority: ReminderPriority.p3Medium,
        status: ReminderStatus.pending,
        dueAt: DateTime(thisMonday.year, thisMonday.month, thisMonday.day, 10),
        weeklyPlanId: planId,
      );
      await state.saveReminder(r);
      expect(state.allReminders.firstWhere((x) => x.id == r.id).weeklyPlanId, isNull);
    });

    test('un recordatorio solo con día (sin fecha ni plan) se muestra en la semana en curso', () async {
      final legacy = ReminderModel(
        id: 'legacy-day',
        title: 'Rutina del jueves',
        priority: ReminderPriority.p3Medium,
        status: ReminderStatus.pending,
        scheduledDayOfWeek: 3,
      );
      await state.saveReminder(legacy);
      expect(state.remindersForDayOfWeek(3).any((x) => x.id == legacy.id), isTrue);

      await state.nextWeek();
      expect(state.remindersForDayOfWeek(3).any((x) => x.id == legacy.id), isFalse);
    });
  });

  group('Ritual dominical', () {
    testWidgets('abre en la semana sugerida y permite cambiar a la próxima', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = RemindersState(service: RemindersSupabaseService());
      await tester.runAsync(() => state.init());

      await tester.pumpWidget(ChangeNotifierProvider<RemindersState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SundayPlanningWizardDialog())),
      ));
      await tester.pumpAndSettle();

      final suggested = RemindersState.defaultPlanningMonday();
      expect(state.currentMonday, suggested);
      expect(find.byKey(const ValueKey('wizard_week_range')), findsOneWidget);

      await tester.tap(find.text('Próxima semana'));
      await tester.pumpAndSettle();
      expect(state.selectedWeekOffset, 1);

      await tester.tap(find.text('Esta semana'));
      await tester.pumpAndSettle();
      expect(state.selectedWeekOffset, 0);
    });
  });
}
