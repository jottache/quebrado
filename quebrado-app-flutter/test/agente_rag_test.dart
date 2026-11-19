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
  group('Ortiz Models Tests', () {
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
    test('Declared tools include all super-app capabilities (spec 03: escrituras)', () {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );
      final tools = rag.getDeclaredTools().first.functionDeclarations!.map((f) => f.name).toList();

      for (final name in [
        'searchSuiteData',
        'calculateCurrencyExchange',
        'getUpcomingBirthdays',
        'searchContacts',
        'getContactDetails',
        'searchDiarioEntries',
        'registerTransaction',
        'payRecurringPayment',
        'registerDiarioEntry',
        'createContact',
        'createReminder',
        'createHabit',
        'logMood',
        'markHabitDone',
        'createNote',
        'undoLastAction',
      ]) {
        expect(tools, contains(name));
      }
      for (final removed in [
        'proposeCreateDiarioEntry',
        'proposeCreateContact',
        'proposeCreateReminder',
        'proposeCreateHabit',
        'proposeCreateTransaction',
      ]) {
        expect(tools, isNot(contains(removed)));
      }
    });

    test('GeminiConfig handles model selection and fallback', () {
      GeminiConfig.setModel('gemini-3.6-flash');
      expect(GeminiConfig.selectedModel, equals('gemini-3.6-flash'));

      GeminiConfig.setModel('gemini-1.5-pro');
      expect(GeminiConfig.selectedModel, equals('gemini-1.5-pro'));
    });

    test('SuiteRagService returns 23 tools in getDeclaredTools and getToolsJson', () {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      final declared = rag.getDeclaredTools();
      expect(declared.length, equals(1));
      final funcs = declared.first.functionDeclarations!.map((f) => f.name).toList();
      expect(funcs.length, equals(23));
      expect(funcs, contains('searchSuiteData'));
      expect(funcs, contains('searchContacts'));
      expect(funcs, contains('getContactDetails'));
      expect(funcs, contains('searchDiarioEntries'));
      expect(funcs, contains('getPersonalNotes'));
      expect(funcs, contains('registerTransaction'));
      expect(funcs, contains('registerDiarioEntry'));
      expect(funcs, contains('createContact'));
      expect(funcs, contains('createReminder'));
      expect(funcs, contains('createHabit'));
      expect(funcs, contains('getWeeklySchedule'));
      expect(funcs, contains('getRolesCompass'));
      expect(funcs, contains('proposeScheduleBigRock'));

      final jsonTools = rag.getToolsJson();
      final jsonFuncs = (jsonTools.first['functionDeclarations'] as List)
          .map((f) => f['name'])
          .toList();
      expect(jsonFuncs.length, equals(23));
      // R-03: las dos copias (SDK y REST) declaran exactamente los mismos nombres.
      expect(jsonFuncs.toSet(), equals(funcs.toSet()));
      expect(funcs.toSet().length, equals(funcs.length));
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

      expect(_u(suiteRes)['totalMatches'], equals(1));
      final reminders = _u(suiteRes)['reminders'] as List;
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

      expect(_u(remindersRes)['count'], equals(1));
      final rList = _u(remindersRes)['reminders'] as List;
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

      expect(_u(res)['found'], equals(1));
      final contacts = _u(res)['contacts'] as List;
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
      expect(_u(plateRes)['found'], equals(1));

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
      expect(_u(detailsRes)['found'], isTrue);
      final detailsContact = _u(detailsRes)['contact'];
      expect(detailsContact['name'], equals('Judenys Borges'));
      expect((detailsContact['records'] as List).first['details']['placa'], equals('210RD'));

      // 5. searchDiarioEntries finds entry directly and links to contact
      final entriesRes = await rag.executeFunctionCall(
        'searchDiarioEntries',
        {'query': '210RD'},
        sessionId: 'test-session',
      );
      expect(_u(entriesRes)['found'], equals(1));
      final entryMatches = _u(entriesRes)['entries'] as List;
      expect(entryMatches.first['contactName'], equals('Judenys Borges'));
      expect(entryMatches.first['details']['placa'], equals('210RD'));
    });

    // Spec 03: las antiguas `propose*` ya no existen; sus tests pasan a
    // comprobar que el nombre viejo ya no se despacha y que el nuevo llega
    // al ejecutor del Diario. El detalle de cada ejecutor está en
    // test/agente/services/write_tools/ y el despacho en
    // test/agente/services/suite_rag_service_test.dart.
    test('las propose* retiradas ya no se ejecutan ni crean tarjetas', () async {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );
      for (final name in [
        'proposeCreateContact',
        'proposeCreateDiarioEntry',
        'proposeCreateReminder',
        'proposeCreateHabit',
        'proposeCreateTransaction',
      ]) {
        final res = await rag.executeFunctionCall(name, {'title': 'x'}, sessionId: 's');
        // S3-01: un nombre desconocido cuenta como lectura no fiable.
        expect(_u(res)['error'], contains('Función no reconocida'), reason: name);
        expect(res.generatedArtifact, isNull, reason: name);
      }
    });

    test('registerDiarioEntry con contacto inexistente sale como tarjeta pendiente', () async {
      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(mockContacts: [DiarioContact(id: 'c-mariana', name: 'Mariana Dávila')]),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );
      rag.beginTurn('anota que a Pedro le gusta el café');

      final res = await rag.executeFunctionCall(
        'registerDiarioEntry',
        {'contentText': 'Le gusta el café con canela.', 'contactName': 'Pedro'},
        sessionId: 'session-propose',
      );

      expect(res.resultData['status'], equals('proposal'));
      expect(res.resultData['reasons'], contains('contact_not_found'));
      final art = res.generatedArtifact!;
      expect(art.type, equals(ArtifactType.actionProposal));
      expect(art.metadata['status'], equals('pending'));
      expect(art.metadata['action'], equals('registerDiarioEntry'));
      expect(art.metadata['commitArgs'], isA<Map>());
    });

    test('searchSuiteData and searchDiarioEntries find notes without title through contentText', () async {
      final contact = DiarioContact(
        id: 'c-mariana',
        name: 'Mariana Dávila',
      );

      final untitledEntry = DiarioEntry(
        id: 'e-cafe',
        contactId: 'c-mariana',
        categoryId: 'cat_alimentos',
        title: '',
        contentText: 'Le encanta el café con canela y leche de avena',
      );

      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(
          mockContacts: [contact],
          mockEntries: [untitledEntry],
        ),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      // Search in searchDiarioEntries
      final resDiario = await rag.executeFunctionCall(
        'searchDiarioEntries',
        {'query': 'canela'},
        sessionId: 'session-search',
      );
      final entriesData = _u(resDiario)['entries'] as List;
      expect(entriesData, isNotEmpty);
      expect(entriesData.first['notes'], contains('canela'));

      // Search in searchSuiteData
      final resSuite = await rag.executeFunctionCall(
        'searchSuiteData',
        {'query': 'avena'},
        sessionId: 'session-suite',
      );
      final suiteDiario = _u(resSuite)['diarioEntries'] as List;
      expect(suiteDiario, isNotEmpty);
      expect(suiteDiario.first['notes'], contains('avena'));
    });

    test('SuiteRagService executes getPersonalNotes filtering by query and dateFilter correctly', () async {
      final personalEntry1 = DiarioEntry(
        id: 'note-1',
        contactId: 'personal',
        categoryId: 'cat_notas_personales',
        title: 'Idea de negocio SaaS',
        contentText: 'Desarrollar una herramienta de IA para freelancers',
        createdAt: DateTime(2026, 9, 16, 10, 0),
        updatedAt: DateTime(2026, 9, 16, 10, 0),
        isPinned: true,
      );
      final personalEntry2 = DiarioEntry(
        id: 'note-2',
        contactId: 'personal',
        categoryId: 'cat_notas_personales',
        title: 'Rutina de entrenamiento',
        contentText: '5x5 press banca y 3x12 dominadas',
        createdAt: DateTime(2026, 8, 10, 15, 0),
        updatedAt: DateTime(2026, 8, 10, 15, 0),
      );

      final rag = SuiteRagService(
        appState: _MockAppState(),
        diarioState: _MockDiarioState(
          mockEntries: [personalEntry1, personalEntry2],
        ),
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      // 1. Search by query 'freelancers'
      final resQuery = await rag.executeFunctionCall(
        'getPersonalNotes',
        {'query': 'freelancers'},
        sessionId: 'session-notes',
      );
      expect(_u(resQuery)['found'], equals(1));
      final notes = _u(resQuery)['notes'] as List;
      expect(notes.first['title'], equals('Idea de negocio SaaS'));
      expect(notes.first['isPinned'], isTrue);

      // 2. Search all personal notes
      final resAll = await rag.executeFunctionCall(
        'getPersonalNotes',
        {},
        sessionId: 'session-notes-all',
      );
      expect(_u(resAll)['found'], equals(2));

      // 3. Search by dateFilter
      final resDate = await rag.executeFunctionCall(
        'getPersonalNotes',
        {'dateFilter': '2026-08'},
        sessionId: 'session-notes-date',
      );
      expect(_u(resDate)['found'], equals(1));
      expect((_u(resDate)['notes'] as List).first['title'], equals('Rutina de entrenamiento'));
    });
  });
}

/// Las lecturas con texto libre van envueltas en `untrusted_content` (CA-10).
Map<String, dynamic> _u(ToolExecutionResult r) =>
    r.resultData['untrusted_content'] as Map<String, dynamic>;

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
  List<DiarioEntry> get personalEntries =>
      mockEntries.where((e) => e.contactId == 'personal' || e.contactId.isEmpty).toList();

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

  @override
  List<DiarioEntry> getEntriesMentioningContact(String contactId) {
    return mockEntries
        .where((e) => e.mentionedContactIds.contains(contactId))
        .toList();
  }

  @override
  List<String> extractMentionedContactIds(String text) {
    if (!text.contains('@') || mockContacts.isEmpty) return [];
    final ids = <String>[];
    for (final contact in mockContacts) {
      if (text.toLowerCase().contains('@${contact.name.toLowerCase()}')) {
        ids.add(contact.id);
      }
    }
    return ids;
  }
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


