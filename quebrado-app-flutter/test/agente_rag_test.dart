import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_session_model.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_config.dart';
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';

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

  group('SuiteRagService Declarations and Execution', () {
    test('Declared tools include all 9 super-app capabilities', () {
      final tools = [
        'searchContacts',
        'getContactDetails',
        'searchDiarioEntries',
        'getUpcomingBirthdays',
        'getFinancialOverview',
        'calculateCurrencyExchange',
        'getHabitsStatus',
        'getReminders',
        'createReminder',
      ];

      expect(tools.length, equals(9));
      expect(tools, contains('calculateCurrencyExchange'));
      expect(tools, contains('getUpcomingBirthdays'));
      expect(tools, contains('searchContacts'));
      expect(tools, contains('getContactDetails'));
      expect(tools, contains('searchDiarioEntries'));
    });

    test('GeminiConfig handles model selection and fallback', () {
      GeminiConfig.setModel('gemini-3.6-flash');
      expect(GeminiConfig.selectedModel, equals('gemini-3.6-flash'));

      GeminiConfig.setModel('gemini-1.5-pro');
      expect(GeminiConfig.selectedModel, equals('gemini-1.5-pro'));
    });

    test('SuiteRagService returns 9 tools in getDeclaredTools and getToolsJson', () {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      final declared = rag.getDeclaredTools();
      expect(declared.length, equals(1));
      final funcs = declared.first.functionDeclarations!.map((f) => f.name).toList();
      expect(funcs.length, equals(9));
      expect(funcs, contains('searchContacts'));
      expect(funcs, contains('getContactDetails'));
      expect(funcs, contains('searchDiarioEntries'));

      final jsonTools = rag.getToolsJson();
      final jsonFuncs = (jsonTools.first['functionDeclarations'] as List)
          .map((f) => f['name'])
          .toList();
      expect(jsonFuncs.length, equals(9));
      expect(jsonFuncs, contains('searchContacts'));
      expect(jsonFuncs, contains('getContactDetails'));
      expect(jsonFuncs, contains('searchDiarioEntries'));
    });

    test('searchContacts and getContactDetails include records with plate and car details', () async {
      final contact = DiarioContact(
        id: 'c-1',
        name: 'Judenys Borges',
        nickname: 'Yaku',
        relationship: 'Amiga',
      );

      final carEntry = DiarioEntry(
        id: 'e-1',
        contactId: 'c-1',
        categoryId: 'cat-auto',
        title: 'Automóvil / Vehículo',
        contentData: {
          'marca': 'hunday',
          'modelo': 'stylus',
          'color': 'gris',
          'placa': '210RD',
        },
      );

      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(
          mockContacts: [contact],
          mockEntries: [carEntry],
        ),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      // 1. Search contacts for 'yaku' (without requesting card)
      final res = await rag.executeFunctionCall(
        'searchContacts',
        {'query': 'yaku'},
        sessionId: 'test-session',
      );

      expect(res.resultData['found'], equals(1));
      final contacts = res.resultData['contacts'] as List;
      expect(contacts.length, equals(1));
      final firstContact = contacts.first;
      expect(firstContact['name'], equals('Judenys Borges'));
      expect(firstContact['records'], isNotEmpty);
      final records = firstContact['records'] as List;
      expect(records.first['title'], equals('Automóvil / Vehículo'));
      expect(records.first['details']['placa'], equals('210RD'));
      // Does not generate full card artifact unless requested
      expect(res.generatedArtifact, isNull);

      // 2. Search contacts by plate query '210RD' finds contact via entry records
      final plateRes = await rag.executeFunctionCall(
        'searchContacts',
        {'query': '210RD'},
        sessionId: 'test-session',
      );
      expect(plateRes.resultData['found'], equals(1));

      // 3. Search specifically asking for 'ficha de yaku' generates contact card artifact
      final cardRes = await rag.executeFunctionCall(
        'searchContacts',
        {'query': 'ficha de yaku'},
        sessionId: 'test-session',
      );
      expect(cardRes.generatedArtifact, isNotNull);
      expect(cardRes.generatedArtifact!.type, equals(ArtifactType.contactCard));

      // 4. getContactDetails returns records
      final detailsRes = await rag.executeFunctionCall(
        'getContactDetails',
        {'nameOrQuery': 'Yaku'},
        sessionId: 'test-session',
      );
      expect(detailsRes.resultData['found'], isTrue);
      final detailsContact = detailsRes.resultData['contact'];
      expect(detailsContact['name'], equals('Judenys Borges'));
      expect((detailsContact['records'] as List).first['details']['placa'], equals('210RD'));

      // 5. searchDiarioEntries finds entry directly and links to contact
      final entriesRes = await rag.executeFunctionCall(
        'searchDiarioEntries',
        {'query': '210RD'},
        sessionId: 'test-session',
      );
      expect(entriesRes.resultData['found'], equals(1));
      final entryMatches = entriesRes.resultData['entries'] as List;
      expect(entryMatches.first['contactName'], equals('Judenys Borges'));
      expect(entryMatches.first['details']['placa'], equals('210RD'));
    });
  });
}

class _MockAppState extends Fake implements AppState {
  @override
  double get totalBalanceUSD => 100.0;
  @override
  double get bcvRate => 42.0;
  @override
  double get euroRate => 45.0;
  @override
  List<Account> get accounts => [];
  @override
  List<PendingOccurrence> get pendingPaymentsToday => [];
}

class _MockDiarioState extends Fake implements DiarioState {
  final List<DiarioContact> mockContacts;
  final List<DiarioEntry> mockEntries;
  final List<DiarioCategory> mockCategories;

  _MockDiarioState({
    this.mockContacts = const [],
    this.mockEntries = const [],
    this.mockCategories = const [],
  });

  @override
  List<DiarioContact> get contacts => mockContacts;
  @override
  List<DiarioEntry> get entries => mockEntries;
  @override
  List<DiarioCategory> get categories => mockCategories;

  @override
  List<DiarioEntry> getEntriesForContact(String contactId) {
    return mockEntries.where((e) => e.contactId == contactId).toList();
  }

  @override
  DiarioContact? getContactById(String id) {
    try {
      return mockContacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  List<DiarioContact> getUpcomingBirthdays({int limit = 5}) => [];
}

class _MockHabitosState extends Fake implements HabitosState {
  @override
  double get todayCompletionRate => 0.8;
  @override
  int get bestCurrentStreak => 5;
}

class _MockRemindersState extends Fake implements RemindersState {
  @override
  int get overdueCount => 0;
  @override
  int get todayCount => 0;
}


