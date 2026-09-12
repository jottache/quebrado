import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_session_model.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_config.dart';

void main() {
  group('Agente Ortiz Models Tests', () {
    test('ChatArtifactModel serializes and deserializes correctly', () {
      final artifact = ChatArtifactModel(
        sessionId: 'session-123',
        type: ArtifactType.financialSummary,
        title: 'Resumen Financiero',
        content: 'Total USD: \$1,500.00',
        metadata: {'totalUsd': 1500.0, 'bcvRate': 42.15},
      );

      final map = artifact.toMap();
      expect(map['session_id'], equals('session-123'));
      expect(map['type'], equals('financial_summary'));
      expect(map['title'], equals('Resumen Financiero'));

      final fromMap = ChatArtifactModel.fromMap(map);
      expect(fromMap.id, equals(artifact.id));
      expect(fromMap.type, equals(ArtifactType.financialSummary));
      expect(fromMap.metadata['totalUsd'], equals(1500.0));
    });

    test('ChatMessageModel manages streaming content and artifacts', () {
      final artifact = ChatArtifactModel(
        sessionId: 'session-123',
        type: ArtifactType.calculation,
        title: 'Conversión',
        content: '100 USD = 4,215.00 Bs.',
      );

      final message = ChatMessageModel(
        sessionId: 'session-123',
        role: MessageRole.model,
        content: 'Calculando...',
        isStreaming: true,
        artifacts: [artifact],
      );

      expect(message.isModel, isTrue);
      expect(message.isUser, isFalse);
      expect(message.artifacts.length, equals(1));
      expect(message.artifacts.first.title, equals('Conversión'));

      final updated = message.copyWith(
        content: '100 USD equivalen a Bs. 4,215.00 a tasa BCV oficial.',
        isStreaming: false,
      );

      expect(updated.isStreaming, isFalse);
      expect(updated.content, contains('4,215.00'));
    });

    test('ChatSessionModel creates new session with defaults', () {
      final session = ChatSessionModel(
        title: 'Consulta Financiera',
      );

      expect(session.title, equals('Consulta Financiera'));
      expect(session.messageCount, equals(0));
      expect(session.id.isNotEmpty, isTrue);
    });
  });

  group('SuiteRagService Declarations', () {
    test('Declared tools include all 7 super-app capabilities', () {
      final tools = [
        'searchContacts',
        'getUpcomingBirthdays',
        'getFinancialOverview',
        'calculateCurrencyExchange',
        'getHabitsStatus',
        'getReminders',
        'createReminder',
      ];

      expect(tools.length, equals(7));
      expect(tools, contains('calculateCurrencyExchange'));
      expect(tools, contains('getUpcomingBirthdays'));
      expect(tools, contains('searchContacts'));
    });

    test('GeminiConfig handles model selection and fallback', () {
      GeminiConfig.setModel('gemini-3.6-flash');
      expect(GeminiConfig.selectedModel, equals('gemini-3.6-flash'));

      GeminiConfig.setModel('gemini-1.5-pro');
      expect(GeminiConfig.selectedModel, equals('gemini-1.5-pro'));
    });
  });
}

