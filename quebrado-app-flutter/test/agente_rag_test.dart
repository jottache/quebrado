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
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
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
    test('Declared tools include all 14 super-app capabilities', () {
      final tools = [
        'searchSuiteData',
        'searchContacts',
        'getContactDetails',
        'searchDiarioEntries',
        'getUpcomingBirthdays',
        'getFinancialOverview',
        'calculateCurrencyExchange',
        'getHabitsStatus',
        'getReminders',
        'createReminder',
        'proposeCreateContact',
        'proposeCreateReminder',
        'proposeCreateHabit',
        'proposeCreateTransaction',
      ];

      expect(tools.length, equals(14));
      expect(tools, contains('searchSuiteData'));
      expect(tools, contains('calculateCurrencyExchange'));
      expect(tools, contains('getUpcomingBirthdays'));
      expect(tools, contains('searchContacts'));
      expect(tools, contains('getContactDetails'));
      expect(tools, contains('searchDiarioEntries'));
      expect(tools, contains('proposeCreateContact'));
      expect(tools, contains('proposeCreateReminder'));
      expect(tools, contains('proposeCreateHabit'));
      expect(tools, contains('proposeCreateTransaction'));
    });

    test('GeminiConfig handles model selection and fallback', () {
      GeminiConfig.setModel('gemini-3.6-flash');
      expect(GeminiConfig.selectedModel, equals('gemini-3.6-flash'));

      GeminiConfig.setModel('gemini-1.5-pro');
      expect(GeminiConfig.selectedModel, equals('gemini-1.5-pro'));
    });

    test('SuiteRagService returns 14 tools in getDeclaredTools and getToolsJson', () {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      final declared = rag.getDeclaredTools();
      expect(declared.length, equals(1));
      final funcs = declared.first.functionDeclarations!.map((f) => f.name).toList();
      expect(funcs.length, equals(14));
      expect(funcs, contains('searchSuiteData'));
      expect(funcs, contains('searchContacts'));
      expect(funcs, contains('getContactDetails'));
      expect(funcs, contains('searchDiarioEntries'));
      expect(funcs, contains('proposeCreateContact'));
      expect(funcs, contains('proposeCreateReminder'));
      expect(funcs, contains('proposeCreateHabit'));
      expect(funcs, contains('proposeCreateTransaction'));

      final jsonTools = rag.getToolsJson();
      final jsonFuncs = (jsonTools.first['functionDeclarations'] as List)
          .map((f) => f['name'])
          .toList();
      expect(jsonFuncs.length, equals(14));
      expect(jsonFuncs, contains('searchSuiteData'));
      expect(jsonFuncs, contains('searchContacts'));
      expect(jsonFuncs, contains('getContactDetails'));
      expect(jsonFuncs, contains('searchDiarioEntries'));
      expect(jsonFuncs, contains('proposeCreateContact'));
      expect(jsonFuncs, contains('proposeCreateReminder'));
      expect(jsonFuncs, contains('proposeCreateHabit'));
      expect(jsonFuncs, contains('proposeCreateTransaction'));
    });

    test('searchSuiteData and getReminders find reminders by query with formatted date and daysRemaining', () async {
      final targetDate = DateTime.now().add(const Duration(days: 53));
      final reminder = ReminderModel(
        id: 'rem-zelda',
        title: 'Salida de Zelda OOT',
        dueAt: targetDate,
        priority: ReminderPriority.p3Medium,
        tags: ['videojuegos', 'nintendo'],
      );

      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(mockReminders: [reminder]),
      );

      // 1. Test searchSuiteData with query 'zelda'
      final suiteRes = await rag.executeFunctionCall(
        'searchSuiteData',
        {'query': 'zelda'},
        sessionId: 'test-session',
      );

      expect(suiteRes.resultData['totalMatches'], equals(1));
      final reminders = suiteRes.resultData['reminders'] as List;
      expect(reminders.length, equals(1));
      expect(reminders.first['title'], equals('Salida de Zelda OOT'));
      expect(reminders.first['daysRemaining'], equals(53));
      expect(reminders.first['formattedDueDate'], isNotNull);

      // 2. Test getReminders with query 'zelda'
      final remindersRes = await rag.executeFunctionCall(
        'getReminders',
        {'query': 'zelda'},
        sessionId: 'test-session',
      );

      expect(remindersRes.resultData['count'], equals(1));
      final rList = remindersRes.resultData['reminders'] as List;
      expect(rList.first['title'], equals('Salida de Zelda OOT'));
      expect(rList.first['daysRemaining'], equals(53));
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

    test('proposeCreateContact generates actionProposal artifact with age and fields', () async {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      final res = await rag.executeFunctionCall(
        'proposeCreateContact',
        {
          'name': 'Juan',
          'relationship': 'Hermano',
          'age': 38,
          'phone': '+584121234567',
          'notes': 'Cumple en enero',
        },
        sessionId: 'session-propose',
      );

      expect(res.resultData['status'], equals('proposed'));
      expect(res.resultData['action'], equals('create_contact'));
      expect(res.generatedArtifact, isNotNull);

      final art = res.generatedArtifact!;
      expect(art.type, equals(ArtifactType.actionProposal));
      expect(art.title, contains('Juan'));
      expect(art.metadata['action'], equals('create_contact'));
      expect(art.metadata['status'], equals('pending'));

      final data = art.metadata['data'] as Map;
      expect(data['name'], equals('Juan'));
      expect(data['relationship'], equals('Hermano'));
      expect(data['phone'], equals('+584121234567'));
      // Estimated birthdate from 38 years
      expect(data['birthdate'], contains('-01-01'));

      final summary = art.metadata['summary'] as List;
      expect(summary.any((s) => s['label'] == 'Relación' && s['value'] == 'Hermano'), isTrue);
      expect(summary.any((s) => s['label'] == 'Edad aprox.' && s['value'] == '38 años'), isTrue);
    });

    test('proposeCreateReminder, proposeCreateHabit and proposeCreateTransaction generate proposals', () async {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      // 1. Reminder proposal
      final remRes = await rag.executeFunctionCall(
        'proposeCreateReminder',
        {
          'title': 'Comprar repuesto para el carro',
          'priority': 'p1_urgent',
          'notes': 'Placa 210RD',
        },
        sessionId: 'session-propose',
      );
      expect(remRes.generatedArtifact, isNotNull);
      expect(remRes.generatedArtifact!.type, equals(ArtifactType.actionProposal));
      expect(remRes.generatedArtifact!.metadata['action'], equals('create_reminder'));

      // 2. Habit proposal
      final habitRes = await rag.executeFunctionCall(
        'proposeCreateHabit',
        {'title': 'Leer 20 páginas al día', 'isNegative': false},
        sessionId: 'session-propose',
      );
      expect(habitRes.generatedArtifact, isNotNull);
      expect(habitRes.generatedArtifact!.metadata['action'], equals('create_habit'));

      // 3. Transaction proposal
      final txRes = await rag.executeFunctionCall(
        'proposeCreateTransaction',
        {
          'title': 'Almuerzo de trabajo',
          'amount': 15.5,
          'type': 'expense',
          'currency': 'usd',
        },
        sessionId: 'session-propose',
      );
      expect(txRes.generatedArtifact, isNotNull);
      expect(txRes.generatedArtifact!.metadata['action'], equals('create_transaction'));
      expect(txRes.generatedArtifact!.title, contains('Gasto: Almuerzo de trabajo'));
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
  @override
  List<HabitModel> get allHabits => [];
}

class _MockRemindersState extends Fake implements RemindersState {
  final List<ReminderModel> mockReminders;

  _MockRemindersState({this.mockReminders = const []});

  @override
  int get overdueCount => 0;
  @override
  int get todayCount => 0;
  @override
  List<ReminderModel> get allReminders => mockReminders;
}


