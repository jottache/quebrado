import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';

void main() {
  group('Covey Ortiz AI RAG Integration Tests', () {
    late AppState appState;
    late DiarioState diarioState;
    late HabitosState habitosState;
    late RemindersState remindersState;
    late SuiteRagService ragService;

    setUp(() async {
      appState = AppState();
      diarioState = DiarioState();
      habitosState = HabitosState();
      remindersState = RemindersState();
      await remindersState.init();

      ragService = SuiteRagService(
        appState: appState,
        diarioState: diarioState,
        habitosState: habitosState,
        remindersState: remindersState,
      );
    });

    test('generateLiveContextSnapshot incluye sección de Agenda Covey Hábito 3', () {
      final snapshot = ragService.generateLiveContextSnapshot();

      expect(snapshot, contains('Agenda y Planificación Semanal (Stephen Covey - Hábito 3'));
      expect(snapshot, contains('Foco en Cuadrante II'));
      expect(snapshot, contains('Grandes Rocas'));
      expect(snapshot, contains('Roles Vitales del usuario'));
    });

    test('Herramienta getRolesCompass retorna la brújula y estado de balance', () async {
      final res = await ragService.executeFunctionCall(
        'getRolesCompass',
        {},
        sessionId: 'test-session',
      );

      final data = res.resultData;
      expect(data['totalRoles'], isNotNull);
      expect(data['roles'], isA<List>());
      expect(data['balanceStatus'], isNotNull);
    });

    test('Herramienta getWeeklySchedule retorna el cronograma semanal', () async {
      final res = await ragService.executeFunctionCall(
        'getWeeklySchedule',
        {},
        sessionId: 'test-session',
      );

      final data = res.resultData;
      expect(data['days'], isA<List>());
      final days = data['days'] as List;
      expect(days.length, equals(7));
      expect(days[0]['dayName'], equals('Lunes'));
    });

    test('Herramienta proposeScheduleBigRock genera un Action Proposal Artifact', () async {
      final res = await ragService.executeFunctionCall(
        'proposeScheduleBigRock',
        {
          'title': 'Entrenar 1 hora de natación',
          'roleName': 'Salud',
          'dayOfWeek': 'martes',
          'estimatedDurationMinutes': 60,
          'notes': 'Meta de alta importancia para condición física',
        },
        sessionId: 'test-session',
      );

      expect(res.generatedArtifact, isNotNull);
      final artifact = res.generatedArtifact!;
      expect(artifact.type, equals(ArtifactType.actionProposal));
      expect(artifact.title, contains('Entrenar 1 hora de natación'));
      expect(artifact.metadata['action'], equals('create_reminder'));
      expect(artifact.metadata['data']['isBigRock'], isTrue);
      expect(artifact.metadata['data']['quadrant'], equals('q2_important_not_urgent'));
    });
  });
}
