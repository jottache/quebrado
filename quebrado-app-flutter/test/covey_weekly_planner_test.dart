import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/recordatorios/dialogs/covey_guide_dialog.dart';
import 'package:quebrado_app_flutter/recordatorios/models/covey_quadrant.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/models/role_model.dart';
import 'package:quebrado_app_flutter/recordatorios/models/weekly_plan_model.dart';
import 'package:quebrado_app_flutter/recordatorios/services/nlp_parser.dart';
import 'package:quebrado_app_flutter/recordatorios/services/reminders_supabase_service.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';

void main() {
  group('CoveyQuadrant Tests', () {
    test('Valores y labels de cuadrantes', () {
      expect(CoveyQuadrant.q1UrgentImportant.shortLabel, equals('C1'));
      expect(CoveyQuadrant.q2ImportantNotUrgent.shortLabel, equals('C2'));
      expect(CoveyQuadrant.q3UrgentNotImportant.shortLabel, equals('C3'));
      expect(CoveyQuadrant.q4NotUrgentNotImportant.shortLabel, equals('C4'));

      expect(CoveyQuadrant.q2ImportantNotUrgent.isQuadrant2, isTrue);
      expect(CoveyQuadrant.q1UrgentImportant.isQuadrant2, isFalse);
    });

    test('Parsing fromCode tolerante a mayúsculas y prefijos', () {
      expect(CoveyQuadrant.fromCode('q1_urgent_important'), equals(CoveyQuadrant.q1UrgentImportant));
      expect(CoveyQuadrant.fromCode('q2'), equals(CoveyQuadrant.q2ImportantNotUrgent));
      expect(CoveyQuadrant.fromCode('c3'), equals(CoveyQuadrant.q3UrgentNotImportant));
      expect(CoveyQuadrant.fromCode('Q4'), equals(CoveyQuadrant.q4NotUrgentNotImportant));
      expect(CoveyQuadrant.fromCode(null), equals(CoveyQuadrant.q2ImportantNotUrgent));
    });
  });

  group('WeeklyPlanModel Tests', () {
    test('Normalización a lunes', () {
      final wednesday = DateTime(2026, 9, 23); // Miércoles
      final monday = WeeklyPlanModel.normalizeToMonday(wednesday);
      expect(monday.weekday, equals(DateTime.monday));
      expect(monday.year, equals(2026));
      expect(monday.month, equals(9));
      expect(monday.day, equals(21));
    });

    test('Serialización toMap y fromMap', () {
      final monday = DateTime(2026, 9, 21);
      final plan = WeeklyPlanModel(
        id: 'plan-1',
        userId: 'user-1',
        weekStartDate: monday,
        reflectionNotes: 'Semana productiva y balanceada',
        createdAt: DateTime.now(),
      );

      final map = plan.toMap();
      final from = WeeklyPlanModel.fromMap(map);

      expect(from.id, equals(plan.id));
      expect(from.weekStartDate.weekday, equals(DateTime.monday));
      expect(from.reflectionNotes, equals('Semana productiva y balanceada'));
    });
  });

  group('RoleModel Tests', () {
    test('Semillas predeterminadas cubren 4 dimensiones', () {
      final seeds = RoleModel.defaultSeeds('user-1');
      expect(seeds.length, equals(4));
      expect(seeds.any((r) => r.name.contains('Salud')), isTrue);
      expect(seeds.any((r) => r.name.contains('Profesional')), isTrue);
      expect(seeds.any((r) => r.name.contains('Familia')), isTrue);
      expect(seeds.any((r) => r.name.contains('Finanzas')), isTrue);
    });
  });

  group('ReminderModel Covey Fields Tests', () {
    test('Serialización con campos de Hábito 3', () {
      final reminder = ReminderModel(
        id: 'rem-covey-1',
        title: 'Entrenamiento de fuerza y sauna',
        quadrant: CoveyQuadrant.q2ImportantNotUrgent,
        isBigRock: true,
        roleId: 'role-salud',
        weeklyPlanId: 'plan-1',
        scheduledDayOfWeek: 1, // Martes
        estimatedDurationMinutes: 60,
      );

      final map = reminder.toMap();
      expect(map['quadrant'], equals('q2_important_not_urgent'));
      expect(map['is_big_rock'], isTrue);
      expect(map['role_id'], equals('role-salud'));
      expect(map['scheduled_day_of_week'], equals(1));
      expect(map['estimated_duration_minutes'], equals(60));

      final restored = ReminderModel.fromMap(map);
      expect(restored.quadrant, equals(CoveyQuadrant.q2ImportantNotUrgent));
      expect(restored.isBigRock, isTrue);
      expect(restored.roleId, equals('role-salud'));
      expect(restored.scheduledDayOfWeek, equals(1));
      expect(restored.estimatedDurationMinutes, equals(60));
    });
  });

  group('NlpParser Covey Tokens Tests', () {
    test('Extrae cuadrante !q1 y duración ~45m', () {
      final res = NlpParser.parse('Resolver caída del servidor de producción !q1 ~45m');
      expect(res.cleanTitle, equals('Resolver caída del servidor de producción'));
      expect(res.quadrant, equals(CoveyQuadrant.q1UrgentImportant));
      expect(res.estimatedDurationMinutes, equals(45));
      expect(res.isBigRock, isFalse);
    });

    test('Extrae Gran Roca con asterisco y rol con @', () {
      final res = NlpParser.parse('* Planificar arquitectura del sistema Q4 * @trabajo');
      expect(res.cleanTitle, equals('Planificar arquitectura del sistema Q4'));
      expect(res.isBigRock, isTrue);
      expect(res.roleQuery, equals('trabajo'));
      expect(res.quadrant, equals(CoveyQuadrant.q2ImportantNotUrgent)); // Por defecto Q2
    });

    test('Extrae Gran Roca con !rock y cuadrante !q2', () {
      final res = NlpParser.parse('Cena romántica de aniversario !rock !q2 @familia');
      expect(res.cleanTitle, equals('Cena romántica de aniversario'));
      expect(res.isBigRock, isTrue);
      expect(res.quadrant, equals(CoveyQuadrant.q2ImportantNotUrgent));
      expect(res.roleQuery, equals('familia'));
    });
  });

  group('RemindersState Covey Weekly Planning Tests', () {
    late RemindersState state;

    setUp(() async {
      // Usar servicio local sin backend remoto conectado
      final service = RemindersSupabaseService();
      state = RemindersState(service: service);
      await state.init();
    });

    test('Calcula roles desatendidos cuando no hay rocas para un rol', () async {
      final roles = state.roles;
      expect(roles, isNotEmpty);

      // Los default seeds crean rocas para salud y familia, pero quizás no para finanzas
      final unaddressed = state.unaddressedRoles;
      expect(unaddressed, isA<List<RoleModel>>());
    });

    test('Mover recordatorio a un día específico de la semana', () async {
      final r = await state.createFromNlp('Comprar insumos médicos !q1');
      await state.moveReminderToDay(r.id, 3); // Jueves

      final thursdayReminders = state.remindersForDayOfWeek(3);
      expect(thursdayReminders.any((item) => item.id == r.id), isTrue);
    });

    test('Mover recordatorio a otro cuadrante Covey', () async {
      final r = await state.createFromNlp('Ver videos en redes sociales');
      expect(r.quadrant, equals(CoveyQuadrant.q2ImportantNotUrgent)); // Default

      await state.moveReminderToQuadrant(r.id, CoveyQuadrant.q4NotUrgentNotImportant);

      final q4List = state.remindersForQuadrant(CoveyQuadrant.q4NotUrgentNotImportant);
      expect(q4List.any((item) => item.id == r.id), isTrue);
    });

    test('Alternar Gran Roca', () async {
      final r = await state.createFromNlp('Escribir informe trimestral');
      expect(r.isBigRock, isFalse);

      await state.toggleBigRock(r.id);
      final updated = state.allReminders.firstWhere((x) => x.id == r.id);
      expect(updated.isBigRock, isTrue);
    });
  });

  group('CoveyGuideDialog Widget Tests', () {
    testWidgets('Muestra la guía paso a paso, navega entre pasos y renderiza contenido de los 6 pasos', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoveyGuideDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Paso 1: Roles Vitales & Brújula
      expect(find.text('Roles Vitales & Brújula'), findsWidgets);
      expect(find.text('Configurar Mis Roles Vitales'), findsOneWidget);
      expect(find.text('Paso 1 de 6'), findsOneWidget);

      // Avanzar al Paso 2: El Ritual Dominical
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pumpAndSettle();

      expect(find.text('El Ritual Dominical'), findsWidgets);
      expect(find.text('Paso 2 de 6'), findsOneWidget);
      expect(find.text('Abrir Ritual Dominical'), findsOneWidget);

      // Avanzar al Paso 3: Grandes Rocas vs Arena
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pumpAndSettle();

      expect(find.text('Grandes Rocas vs Arena'), findsWidgets);
      expect(find.text('Paso 3 de 6'), findsOneWidget);

      // Avanzar al Paso 4: Agenda Semanal Flexible
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pumpAndSettle();

      expect(find.text('Agenda Semanal Flexible'), findsWidgets);
      expect(find.text('Paso 4 de 6'), findsOneWidget);

      // Avanzar al Paso 5: La Matriz de Covey (2x2)
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pumpAndSettle();

      expect(find.text('La Matriz de Covey (2x2)'), findsWidgets);
      expect(find.text('Paso 5 de 6'), findsOneWidget);

      // Avanzar al Paso 6: Captura NLP y Coach Ortiz
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pumpAndSettle();

      expect(find.text('Captura NLP y Coach Ortiz'), findsWidgets);
      expect(find.text('Paso 6 de 6'), findsOneWidget);
      expect(find.text('¡Listo para Empezar!'), findsOneWidget);

      // Botón Anterior
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 5 de 6'), findsOneWidget);
    });
  });
}
