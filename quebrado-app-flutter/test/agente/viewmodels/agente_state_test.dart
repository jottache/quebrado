import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/agente_prompt_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';
import 'package:quebrado_app_flutter/agente/models/undo_result.dart';
import 'package:quebrado_app_flutter/agente/services/agente_supabase_service.dart';
import 'package:quebrado_app_flutter/agente/services/daily_briefing_service.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';

import '../../helpers/fake_write_handler.dart';

/// Gemini simulado: la respuesta llega cuando el test la empuja.
class _FakeGemini implements GeminiService {
  final controller = StreamController<GeminiStreamResponse>();

  @override
  Stream<GeminiStreamResponse> sendMessageStream({
    required String prompt,
    required List<ChatMessageModel> previousMessages,
    required String sessionId,
  }) =>
      controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Gemini simulado para el resumen del día: cuenta llamadas y guarda la
/// instrucción y el JSON recibidos.
class _BriefingGemini implements GeminiService {
  _BriefingGemini(this.respond);
  final Stream<String> Function() respond;
  int calls = 0;
  String? instruction;
  Map<String, dynamic>? briefingJson;

  @override
  Stream<String> streamDailyBriefing({
    required String instruction,
    required Map<String, dynamic> briefingJson,
  }) {
    calls++;
    this.instruction = instruction;
    this.briefingJson = briefingJson;
    return respond();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotasState extends Fake implements NotasState {}

// Datos inventados para el resumen del día. 2026-11-18 es miércoles.
final _briefingNow = DateTime(2026, 11, 18, 10);

RecurringPayment _pago(String id, String name) => RecurringPayment(
      id: id,
      name: name,
      amount: 25,
      currency: CurrencyType.usd,
      frequency: SubscriptionFrequency.monthly,
      startDate: DateTime(2026, 10, 18),
      notificationOption: NotificationOption.none,
      icon: 'wifi',
      colorHex: '#2FA084',
      type: TransactionType.expense,
    );

final _internet = _pago('pago-internet', 'Internet');
final _agua = _pago('pago-agua', 'Agua');

PendingOccurrence _occ(RecurringPayment p, int day, {double partial = 0}) =>
    PendingOccurrence(payment: p, occurrenceDate: DateTime(2026, 11, day), partialAmountPaid: partial);

/// Todo cargado y vacío salvo lo que pida cada test.
DailyBriefingSnapshot _snap({
  bool financeLoaded = true,
  bool diarioLoaded = true,
  List<PendingOccurrence> pending = const [],
  List<DiaryEntryStamp> diary = const [],
  List<ReminderStamp> reminders = const [],
}) =>
    DailyBriefingSnapshot(
      financeLoaded: financeLoaded,
      bookName: 'Libro de prueba',
      pendingWindow: pending,
      bcv: 250,
      parallel: 300,
      euro: 270,
      diarioLoaded: diarioLoaded,
      diaryEntries: diary,
      moodLoaded: true,
      habitsLoaded: true,
      remindersLoaded: true,
      reminders: reminders,
    );

AgentePromptModel _prompt(String id, String text, {int sortOrder = 0}) => AgentePromptModel(
      id: id,
      text: text,
      sortOrder: sortOrder,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  group('AgenteState.ortizMood', () {
    late _FakeGemini gemini;
    late AgenteState state;

    setUp(() async {
      gemini = _FakeGemini();
      state = AgenteState(autoInit: false, geminiService: gemini);
      await state.startNewSession();
    });

    tearDown(() {
      // Sin oyente, `close()` no termina nunca: no se espera.
      unawaited(gemini.controller.close());
      state.dispose();
    });

    test('está en reposo cuando no genera', () {
      expect(state.ortizMood, OrtizMood.idle);
    });

    test('piensa mientras genera sin texto, habla con el streaming y vuelve al reposo',
        () async {
      final moods = <OrtizMood>[];
      state.addListener(() => moods.add(state.ortizMood));

      final sending = state.sendMessage('¿Cuánto gasté hoy?');
      expect(state.ortizMood, OrtizMood.thinking);

      gemini.controller.add(GeminiStreamResponse(
        textChunk: '',
        fullText: '',
        toolCalls: const [
          {'name': 'consultar_gastos'},
        ],
      ));
      await pumpEventQueue();
      expect(state.ortizMood, OrtizMood.thinking);

      gemini.controller.add(GeminiStreamResponse(textChunk: 'Hoy', fullText: 'Hoy'));
      await pumpEventQueue();
      expect(state.ortizMood, OrtizMood.talking);

      gemini.controller.add(GeminiStreamResponse(
          textChunk: ' 12 \$', fullText: 'Hoy 12 \$', isDone: true));
      await gemini.controller.close();
      await sending;

      expect(state.ortizMood, OrtizMood.idle);
      expect(moods, containsAllInOrder(
          [OrtizMood.thinking, OrtizMood.talking, OrtizMood.idle]));
      // El chat sigue igual: la respuesta queda guardada y sin streaming.
      expect(state.messages.last.content, 'Hoy 12 \$');
      expect(state.messages.last.isStreaming, isFalse);
      expect(state.isGenerating, isFalse);
    });
  });

  group('AgenteState.celebrate', () {
    testWidgets('pone a Ortiz contento ~1,8 s y vuelve al reposo', (tester) async {
      final state = AgenteState(autoInit: false);
      addTearDown(state.dispose);
      var notifications = 0;
      state.addListener(() => notifications++);

      state.celebrate();
      expect(state.ortizMood, OrtizMood.happy);
      expect(notifications, 1);

      await tester.pump(AgenteState.celebrateDuration - const Duration(milliseconds: 1));
      expect(state.ortizMood, OrtizMood.happy);

      await tester.pump(const Duration(milliseconds: 1));
      expect(state.ortizMood, OrtizMood.idle);
      expect(notifications, 2);
    });

    testWidgets('celebrar de nuevo alarga la alegría', (tester) async {
      final state = AgenteState(autoInit: false);
      addTearDown(state.dispose);

      state.celebrate();
      await tester.pump(AgenteState.celebrateDuration ~/ 2);
      state.celebrate();
      await tester.pump(AgenteState.celebrateDuration ~/ 2 + const Duration(milliseconds: 1));
      expect(state.ortizMood, OrtizMood.happy);

      await tester.pump(AgenteState.celebrateDuration);
      expect(state.ortizMood, OrtizMood.idle);
    });

    testWidgets('la alegría no tapa a pensar ni a hablar', (tester) async {
      final gemini = _FakeGemini();
      final state = AgenteState(autoInit: false, geminiService: gemini);
      addTearDown(state.dispose);
      await state.startNewSession();

      state.celebrate();
      final sending = state.sendMessage('Anota un gasto');
      expect(state.ortizMood, OrtizMood.thinking);

      gemini.controller
          .add(GeminiStreamResponse(textChunk: 'Listo', fullText: 'Listo'));
      await tester.pump();
      expect(state.ortizMood, OrtizMood.talking);

      gemini.controller.add(
          GeminiStreamResponse(textChunk: '', fullText: 'Listo', isDone: true));
      await gemini.controller.close();
      await sending;
      // Terminó antes de 1,8 s: le queda alegría.
      expect(state.ortizMood, OrtizMood.happy);
      await tester.pump(AgenteState.celebrateDuration);
      expect(state.ortizMood, OrtizMood.idle);
    });

    testWidgets('dispose cancela el temporizador de la alegría', (tester) async {
      // Si el temporizador quedara vivo, el test falla por "Timer pendiente".
      final state = AgenteState(autoInit: false);
      state.celebrate();
      state.dispose();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('registros de Ortiz (tarjetas y deshacer)', () {
    late _FakeGemini gemini;
    late _GatedWriteHandler handler;
    late AgenteState state;
    late Future<void> sending;

    ChatArtifactModel card() => ChatArtifactModel(
          id: 'art-1',
          sessionId: state.currentSession!.id,
          type: ArtifactType.actionProposal,
          title: 'Leer',
          content: 'Leer',
          metadata: {
            'status': 'pending',
            'action': WriteToolNames.createHabit,
            'reasons': ['read_untrusted_text'],
            'summary': 'Leer',
            'commitArgs': {'title': 'Leer', 'notes': 'dato de prueba'},
          },
        );

    Map<String, dynamic> shownMetadata() =>
        state.messages.last.artifacts.single.metadata;

    /// Envía un mensaje y Gemini responde con la tarjeta (sin terminar).
    Future<void> streamCard() async {
      sending = state.sendMessage('crea el hábito leer');
      gemini.controller.add(GeminiStreamResponse(textChunk: '', fullText: '', artifacts: [card()]));
      await pumpEventQueue();
    }

    Future<void> finishStream() async {
      gemini.controller.add(GeminiStreamResponse(
          textChunk: 'Listo', fullText: 'Listo', artifacts: [card()], isDone: true));
      await gemini.controller.close();
      await sending;
    }

    setUp(() async {
      gemini = _FakeGemini();
      handler = _GatedWriteHandler();
      final rag = SuiteRagService(
        appState: FakeAppState(),
        diarioState: FakeDiarioState(),
        habitosState: FakeHabitosState(),
        remindersState: FakeRemindersState(),
        writeHandlers: [handler],
      );
      state = AgenteState(autoInit: false, geminiService: gemini, ragService: rag);
      await state.startNewSession();
    });

    tearDown(() {
      unawaited(gemini.controller.close());
      state.dispose();
    });

    test('un trozo del streaming no devuelve a pending una tarjeta confirmada', () async {
      await streamCard();
      expect(state.isGenerating, isTrue);
      await state.confirmProposal('art-1');
      expect(shownMetadata()['status'], 'saved');

      // Gemini repite su lista con la tarjeta original (pending).
      gemini.controller.add(GeminiStreamResponse(textChunk: 'Lis', fullText: 'Lis', artifacts: [card()]));
      await pumpEventQueue();
      expect(shownMetadata()['status'], 'saved');

      await finishStream();
      expect(shownMetadata()['status'], 'saved');
      expect(state.allArtifacts.firstWhere((a) => a.id == 'art-1').metadata['status'], 'saved');
      expect(handler.calls, hasLength(1));
    });

    test('confirmProposal es idempotente: dos toques guardan una vez', () async {
      await streamCard();
      await finishStream();
      handler.gate = Completer<void>();

      final first = state.confirmProposal('art-1');
      final second = state.confirmProposal('art-1');
      await pumpEventQueue();
      handler.gate!.complete();
      await Future.wait([first, second]);
      expect(handler.calls, hasLength(1));
      expect(shownMetadata()['status'], 'saved');

      await state.confirmProposal('art-1');
      expect(handler.calls, hasLength(1));
    });

    test('negar mientras se confirma no pisa el guardado', () async {
      await streamCard();
      await finishStream();
      handler.gate = Completer<void>();

      final confirming = state.confirmProposal('art-1');
      await pumpEventQueue();
      await state.rejectProposal('art-1');
      handler.gate!.complete();
      await confirming;
      expect(shownMetadata()['status'], 'saved');
    });

    test('rejectProposal deja la tarjeta cancelada y borra commitArgs (S3-07)', () async {
      await streamCard();
      await finishStream();
      await state.rejectProposal('art-1');
      final m = shownMetadata();
      expect(m['status'], 'cancelled');
      expect(m.containsKey('commitArgs'), isFalse);
      expect(m['summary'], 'Leer');
      expect(handler.calls, isEmpty);
    });

    test('undoAction devuelve UndoResult: deshecho, motivo del ejecutor o fallo sin detalle', () async {
      await streamCard();
      await finishStream();
      await state.confirmProposal('art-1');
      final undoId = shownMetadata()['undoId'] as String;

      handler.undoError = StateError('Cambia al libro Casa para deshacerlo.');
      expect(await state.undoAction(undoId),
          const UndoResult.notice('Cambia al libro Casa para deshacerlo.'));

      handler.undoError = Exception('detalle interno 0412-555');
      final failed = await state.undoAction(undoId);
      expect(failed.ok, isFalse);
      expect(failed.message, AgenteState.undoFailedMessage);
      expect(failed.message, isNot(contains('0412')));
      expect(shownMetadata()['status'], 'saved');

      handler.undoError = null;
      expect(await state.undoAction(undoId), const UndoResult.done());
      expect(shownMetadata()['status'], 'undone');
      expect(await state.undoAction(undoId), const UndoResult.failed('Ya estaba deshecho.'));
      expect(await state.undoLast(),
          const UndoResult.failed('No hay nada que deshacer en esta conversación.'));
    });
  });

  group('AgenteState.mergeStreamedArtifacts', () {
    ChatArtifactModel art(String id, String status) => ChatArtifactModel(
          id: id,
          sessionId: 's',
          type: ArtifactType.actionProposal,
          title: id,
          content: id,
          metadata: {'status': status},
        );

    test('gana el artefacto local y se añaden los nuevos en el orden del streaming', () {
      final merged = AgenteState.mergeStreamedArtifacts(
        [art('a', 'saved')],
        [art('a', 'pending'), art('b', 'pending')],
      );
      expect([for (final a in merged) '${a.id}:${a.metadata['status']}'], ['a:saved', 'b:pending']);
    });
  });

  group('AgenteState.runDailyBriefing (spec 04)', () {
    late DailyBriefingSnapshot current;

    var snapshotReads = 0;

    AgenteState make({
      GeminiService? gemini,
      Duration timeout = Duration.zero,
      Duration? unavailableAfter,
      AgenteSupabaseService? service,
    }) {
      final s = AgenteState(
        autoInit: false,
        supabaseService: service,
        geminiService: gemini,
        clock: () => _briefingNow,
        briefingLoadTimeout: timeout,
        briefingUnavailableAfter: unavailableAfter,
        briefingSnapshotReader: (_) {
          snapshotReads++;
          return current;
        },
      );
      addTearDown(s.dispose);
      return s;
    }

    void updateDeps(AgenteState s) => s.updateDependencies(
          appState: FakeAppState(),
          diarioState: FakeDiarioState(),
          habitosState: FakeHabitosState(),
          remindersState: FakeRemindersState(),
          animoState: FakeAnimoState(),
          notasState: _FakeNotasState(),
        );

    ChatArtifactModel briefingArtifact(AgenteState s) => s.messages.last.artifacts.single;
    DailyBriefing shownBriefing(AgenteState s) =>
        DailyBriefing.fromArtifactMetadata(briefingArtifact(s).metadata);

    setUp(() {
      current = _snap();
      snapshotReads = 0;
    });

    test('CA-07: sin Gemini muestra las filas y «Esto es lo de hoy:», sin error', () async {
      current = _snap(pending: [_occ(_internet, 18)]);
      final s = make();
      await s.startNewSession();
      await s.runDailyBriefing();

      expect(s.messages, hasLength(2));
      expect(s.messages.first.isUser, isTrue);
      expect(s.messages.first.content, 'Resumen del día');
      final msg = s.messages.last;
      expect(msg.isModel, isTrue);
      expect(msg.content, 'Esto es lo de hoy:');
      expect(msg.isStreaming, isFalse);
      expect(msg.content, isNot(contains('Error')));
      expect(briefingArtifact(s).type, ArtifactType.dailyBriefing);
      expect(shownBriefing(s).payments.items.single.name, 'Internet');
      expect(s.liveBriefingMessageId, msg.id);
      expect(s.isGenerating, isFalse);
    });

    test('sin Gemini y todo al día usa la frase «Todo al día…»', () async {
      current = _snap(diary: [DiaryEntryStamp(createdAt: DateTime(2026, 11, 18, 8), entryType: 'simple_text')]);
      final s = make();
      await s.startNewSession();
      await s.runDailyBriefing();

      expect(s.messages.last.content,
          'Todo al día: escribiste en el diario, no tienes pagos esta semana y tus hábitos están completos');
    });

    test('con Gemini el texto llega en streaming y queda concatenado', () async {
      current = _snap(pending: [_occ(_internet, 18)]);
      final gemini = _BriefingGemini(() => Stream.fromIterable(['Hoy ', 'vence ', 'Internet.']));
      final s = make(gemini: gemini);
      await s.startNewSession();
      final moods = <OrtizMood>[];
      s.addListener(() => moods.add(s.ortizMood));

      await s.runDailyBriefing();

      expect(s.messages.last.content, 'Hoy vence Internet.');
      expect(s.messages.last.isStreaming, isFalse);
      expect(gemini.calls, 1);
      expect((gemini.briefingJson!['pagos'] as Map)['items'], hasLength(1));
      expect(moods, containsAllInOrder([OrtizMood.thinking, OrtizMood.talking, OrtizMood.idle]));
    });

    test('si el stream de Gemini falla queda la frase fija y ningún error visible', () async {
      Stream<String> failing() async* {
        yield 'Hoy ';
        throw Exception('red caída');
      }

      final s = make(gemini: _BriefingGemini(failing));
      await s.startNewSession();
      await s.runDailyBriefing();

      expect(s.messages.last.content, 'Esto es lo de hoy:');
      expect(s.messages.last.content, isNot(contains('red caída')));
      expect(s.messages.last.isStreaming, isFalse);
    });

    test('espera a que carguen los datos pensando y updateDependencies corta la espera', () async {
      current = _snap(financeLoaded: false);
      final s = make(timeout: const Duration(minutes: 1));
      await s.startNewSession();

      final running = s.runDailyBriefing();
      await pumpEventQueue();
      expect(s.ortizMood, OrtizMood.thinking);
      expect(s.messages, hasLength(1));

      current = _snap(pending: [_occ(_internet, 18)]);
      updateDeps(s);
      await running;

      expect(shownBriefing(s).isFullyLoaded, isTrue);
      expect(shownBriefing(s).payments.items.single.name, 'Internet');
    });

    test('sin datos al terminar la espera máxima sale con secciones cargando', () async {
      current = _snap(financeLoaded: false);
      final s = make(timeout: const Duration(milliseconds: 10));
      await s.startNewSession();
      await s.runDailyBriefing();

      expect(shownBriefing(s).payments.status, BriefingStatus.loading);
      expect(s.messages.last.content, 'Esto es lo de hoy:');
    });

    test('una sección loading pasa a ready con updateDependencies sin otra llamada a Gemini',
        () async {
      current = _snap(financeLoaded: false);
      final controller = StreamController<String>();
      final gemini = _BriefingGemini(() => controller.stream);
      final s = make(gemini: gemini);
      await s.startNewSession();

      final running = s.runDailyBriefing();
      await pumpEventQueue();
      expect(shownBriefing(s).payments.status, BriefingStatus.loading);
      expect(gemini.calls, 1);
      expect((gemini.briefingJson!['pagos'] as Map)['estado'], 'loading');

      var notified = 0;
      s.addListener(() => notified++);
      current = _snap(pending: [_occ(_internet, 18)]);
      updateDeps(s);
      await pumpEventQueue();

      expect(shownBriefing(s).payments.status, BriefingStatus.ready);
      expect(shownBriefing(s).payments.items.single.name, 'Internet');
      expect(s.liveBriefing!.payments.status, BriefingStatus.ready);
      expect(s.todayBriefing!.payments.items.single.name, 'Internet');
      expect(notified, greaterThan(0));

      controller.add('Listo.');
      await controller.close();
      await running;
      expect(gemini.calls, 1);
      expect(s.messages.last.content, 'Listo.');
      expect(shownBriefing(s).payments.status, BriefingStatus.ready);
    });

    test('todayBriefing se recalcula en cada updateDependencies', () {
      final s = make();
      expect(s.todayBriefing, isNull);
      updateDeps(s);
      expect(s.todayBriefing!.payments.items, isEmpty);

      current = _snap(pending: [_occ(_agua, 20)]);
      updateDeps(s);
      expect(s.todayBriefing!.payments.items.single.name, 'Agua');
      expect(s.todayBriefing!.generatedAt, _briefingNow);
    });

    test('varios updateDependencies seguidos recalculan el resumen una sola vez', () async {
      final s = make();
      updateDeps(s);
      updateDeps(s);
      updateDeps(s);
      expect(snapshotReads, 0);
      await pumpEventQueue();
      expect(snapshotReads, 1);
      expect(s.todayBriefing, isNotNull);
      expect(snapshotReads, 1);
    });

    test('isBriefingScanning va de pedir el resumen a que aparecen las filas', () async {
      current = _snap(financeLoaded: false);
      final controller = StreamController<String>();
      final s = make(gemini: _BriefingGemini(() => controller.stream), timeout: const Duration(minutes: 1));
      await s.startNewSession();
      expect(s.isBriefingScanning, isFalse);

      final running = s.runDailyBriefing();
      await pumpEventQueue();
      expect(s.isBriefingScanning, isTrue);
      expect(s.messages, hasLength(1));

      current = _snap(pending: [_occ(_internet, 18)]);
      updateDeps(s);
      await pumpEventQueue();
      // Ya están las filas y Gemini sigue escribiendo: ya no escanea.
      expect(s.messages, hasLength(2));
      expect(s.isGenerating, isTrue);
      expect(s.isBriefingScanning, isFalse);

      await controller.close();
      await running;
      expect(s.isBriefingScanning, isFalse);
    });

    test('una sección que sigue cargando al cumplirse el tope pasa a unavailable', () async {
      current = _snap(financeLoaded: false);
      final s = make(unavailableAfter: const Duration(milliseconds: 40));
      await s.startNewSession();
      await s.runDailyBriefing();
      expect(shownBriefing(s).payments.status, BriefingStatus.loading);
      expect(shownBriefing(s).diario.status, BriefingStatus.ready);

      var notified = 0;
      s.addListener(() => notified++);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(shownBriefing(s).payments.status, BriefingStatus.unavailable);
      expect(s.liveBriefing!.payments.status, BriefingStatus.unavailable);
      expect(shownBriefing(s).diario.status, BriefingStatus.ready);
      expect(notified, greaterThan(0));

      // Si los datos llegan después del tope, la sección no vuelve a cambiar.
      current = _snap(pending: [_occ(_internet, 18)]);
      updateDeps(s);
      await pumpEventQueue();
      expect(shownBriefing(s).payments.status, BriefingStatus.unavailable);
    });

    test('pedir otro resumen reinicia el tope y dispose lo cancela', () async {
      current = _snap(financeLoaded: false);
      final s = AgenteState(
        autoInit: false,
        clock: () => _briefingNow,
        briefingLoadTimeout: Duration.zero,
        briefingUnavailableAfter: const Duration(milliseconds: 60),
        briefingSnapshotReader: (_) => current,
      );
      await s.startNewSession();
      await s.runDailyBriefing();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await s.runDailyBriefing();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // 80 ms desde el primero, 40 ms desde el segundo: sigue cargando.
      expect(s.liveBriefing!.payments.status, BriefingStatus.loading);

      s.dispose();
      // Sin el Timer cancelado, notificaría tras dispose y fallaría.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(s.liveBriefing!.payments.status, BriefingStatus.loading);
    });

    test('el resumen se guarda sin filas ni montos; en memoria queda completo', () async {
      current = _snap(
        pending: [_occ(_internet, 18)],
        reminders: [
          ReminderStamp(id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15), status: ReminderStatus.pending),
        ],
      );
      final service = _RecordingAgenteService();
      final s = make(service: service);
      await s.startNewSession();
      await s.runDailyBriefing();
      await s.markBriefingPayment(_internet.id, BriefingPaymentState.dismissed);
      await pumpEventQueue();

      final stored = [
        for (final m in service.savedMessages)
          for (final a in m.artifacts)
            if (a.type == ArtifactType.dailyBriefing) a,
      ];
      expect(stored, isNotEmpty);
      for (final a in stored) {
        expect(a.metadata.keys.toSet(), {'version', 'generatedAt', 'period'});
        final text = jsonEncode(a.metadata);
        for (final secret in ['Internet', 'Llamar', 'Libro de prueba', 'remaining', 'items']) {
          expect(text, isNot(contains(secret)));
        }
        final back = DailyBriefing.fromArtifactMetadata(a.metadata);
        expect(back.generatedAt, _briefingNow);
      }
      expect(shownBriefing(s).payments.items.single.name, 'Internet');
      expect(shownBriefing(s).reminders.items.single.title, 'Llamar');
    });

    test('un id con prefijo system: que no es el del resumen sí es un atajo', () {
      final s = make();
      s.setQuickPrompts([
        _prompt(kDailyBriefingPromptId, 'Instrucción', sortOrder: 0),
        _prompt('system:otro', '¿Qué hay?', sortOrder: 1),
      ]);
      expect([for (final p in s.quickPrompts) p.id], ['system:otro']);
    });

    test('el prompt del sistema no sale en los atajos y su texto es la instrucción', () async {
      final gemini = _BriefingGemini(() => Stream.value('Bien.'));
      final s = make(gemini: gemini);
      expect(s.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);

      s.setQuickPrompts([
        _prompt(kDailyBriefingPromptId, 'Instrucción de prueba', sortOrder: 0),
        _prompt('p1', '¿Qué tengo hoy?', sortOrder: 1),
        _prompt('p2', '¿Cuánto gasté?', sortOrder: 2),
      ]);
      expect([for (final p in s.quickPrompts) p.id], ['p1', 'p2']);
      expect(s.dailyBriefingPrompt!.text, 'Instrucción de prueba');
      expect(s.dailyBriefingInstruction, 'Instrucción de prueba');

      await s.startNewSession();
      await s.runDailyBriefing();
      expect(gemini.instruction, 'Instrucción de prueba');

      // Reordenar usa los índices de los atajos visibles.
      await s.reorderQuickPrompts(1, 0, persist: false);
      expect([for (final p in s.quickPrompts) p.id], ['p2', 'p1']);
      expect(s.dailyBriefingPrompt, isNotNull);
    });

    test('una fila del sistema vacía usa la instrucción por defecto', () {
      final s = make();
      s.setQuickPrompts([_prompt(kDailyBriefingPromptId, '   ')]);
      expect(s.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);
      expect(s.quickPrompts, isEmpty);
    });

    test('CA-10: un pago confirmado pasa a paid y sigue en la lista', () async {
      current = _snap(pending: [_occ(_internet, 18), _occ(_agua, 20)]);
      final s = make();
      await s.startNewSession();
      await s.runDailyBriefing();
      expect(shownBriefing(s).payments.items, hasLength(2));

      // Se confirmó la ocurrencia de Internet: ya no está en la ventana.
      current = _snap(pending: [_occ(_agua, 20)]);
      await s.refreshBriefingPayments(paymentId: _internet.id);
      var items = shownBriefing(s).payments.items;
      expect(items, hasLength(2));
      expect(items.firstWhere((p) => p.paymentId == _internet.id).state, BriefingPaymentState.paid);
      expect(items.firstWhere((p) => p.paymentId == _agua.id).state, BriefingPaymentState.pending);

      // Abono en Agua: se recalcula lo que falta; Internet sigue pagado.
      current = _snap(pending: [_occ(_agua, 20, partial: 10)]);
      await s.refreshBriefingPayments();
      items = shownBriefing(s).payments.items;
      final agua = items.firstWhere((p) => p.paymentId == _agua.id);
      expect(agua.state, BriefingPaymentState.pending);
      expect(agua.partialPaid, 10);
      expect(agua.remaining.originalAmount, 15);
      expect(items.firstWhere((p) => p.paymentId == _internet.id).state, BriefingPaymentState.paid);

      // Omitir a mano: dismissed, y la fila se queda.
      await s.markBriefingPayment(_agua.id, BriefingPaymentState.dismissed);
      items = shownBriefing(s).payments.items;
      expect(items, hasLength(2));
      expect(items.firstWhere((p) => p.paymentId == _agua.id).state, BriefingPaymentState.dismissed);
      expect(s.liveBriefing!.payments.pendingItems, isEmpty);
    });

    test('CA-10: con varias ocurrencias, pagar la más antigua deja la fila pendiente', () async {
      current = _snap(pending: [_occ(_internet, 4), _occ(_internet, 11), _occ(_internet, 18)]);
      final s = make();
      await s.startNewSession();
      await s.runDailyBriefing();
      var row = shownBriefing(s).payments.items.single;
      expect(row.occurrenceCount, 3);
      expect(row.oldestOccurrenceDate, DateTime(2026, 11, 4));

      // Se pagó la del día 4: quedan dos.
      current = _snap(pending: [_occ(_internet, 11), _occ(_internet, 18)]);
      await s.refreshBriefingPayments(paymentId: _internet.id);
      row = shownBriefing(s).payments.items.single;
      expect(row.state, BriefingPaymentState.pending);
      expect(row.occurrenceCount, 2);
      expect(row.oldestOccurrenceDate, DateTime(2026, 11, 11));
      expect(row.overdueCount, 1);
      expect(row.remaining.originalAmount, 50);

      // Se pagaron las que quedaban: pasa a paid y la fila se queda.
      current = _snap();
      await s.refreshBriefingPayments(paymentId: _internet.id);
      row = shownBriefing(s).payments.items.single;
      expect(row.state, BriefingPaymentState.paid);
    });

    test('posponer desde la fila marca el recordatorio y la fila se queda', () async {
      current = _snap(reminders: [
        ReminderStamp(id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15), status: ReminderStatus.pending),
        ReminderStamp(id: 'rec-2', title: 'Comprar', dueAt: DateTime(2026, 11, 18, 16), status: ReminderStatus.pending),
      ]);
      final s = make();
      await s.startNewSession();
      await s.runDailyBriefing();

      final until = DateTime(2026, 11, 18, 11);
      await s.markBriefingReminderSnoozed('rec-1', until);

      final items = shownBriefing(s).reminders.items;
      expect(items, hasLength(2));
      expect(items.firstWhere((r) => r.id == 'rec-1').snoozedUntil, until);
      expect(items.firstWhere((r) => r.id == 'rec-2').isSnoozed, isFalse);
      expect(s.liveBriefing!.reminders.items.firstWhere((r) => r.id == 'rec-1').isSnoozed, isTrue);
    });
  });

  group('AgenteState instrucción editable del resumen (spec 04, §5.1)', () {
    test('guardar crea la fila del sistema con upsert y no la muestra como atajo', () async {
      final service = _RecordingAgenteService();
      final s = AgenteState(autoInit: false, supabaseService: service);
      s.setQuickPrompts([_prompt('p1', '¿Qué tengo hoy?')]);
      var notified = 0;
      s.addListener(() => notified++);

      await s.saveDailyBriefingInstruction('  Habla corto y en tono amable.  ');

      expect(s.dailyBriefingInstruction, 'Habla corto y en tono amable.');
      expect([for (final p in s.quickPrompts) p.id], ['p1']);
      expect(service.saved.single.id, kDailyBriefingPromptId);
      expect(service.saved.single.text, 'Habla corto y en tono amable.');
      expect(notified, greaterThan(0));
    });

    test('guardar de nuevo actualiza la misma fila', () async {
      final service = _RecordingAgenteService();
      final s = AgenteState(autoInit: false, supabaseService: service);
      await s.saveDailyBriefingInstruction('Primera versión.');
      await s.saveDailyBriefingInstruction('Segunda versión.');

      expect(s.dailyBriefingInstruction, 'Segunda versión.');
      expect([for (final p in service.saved) p.id], [kDailyBriefingPromptId, kDailyBriefingPromptId]);
      expect(s.quickPrompts, isEmpty);
    });

    test('restaurar borra la fila y vuelve al texto por defecto', () async {
      final service = _RecordingAgenteService();
      final s = AgenteState(autoInit: false, supabaseService: service);
      await s.saveDailyBriefingInstruction('Texto propio.');

      await s.resetDailyBriefingInstruction();

      expect(s.dailyBriefingPrompt, isNull);
      expect(s.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);
      expect(service.deleted, [kDailyBriefingPromptId]);
    });

    test('guardar el texto por defecto o vacío equivale a restaurar', () async {
      final service = _RecordingAgenteService();
      final s = AgenteState(autoInit: false, supabaseService: service);
      await s.saveDailyBriefingInstruction('Texto propio.');

      await s.saveDailyBriefingInstruction(kDailyBriefingDefaultInstruction);
      expect(s.dailyBriefingPrompt, isNull);
      expect(service.deleted, [kDailyBriefingPromptId]);

      await s.saveDailyBriefingInstruction('   ');
      expect(service.saved, hasLength(1));
      expect(s.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);
    });

    test('sin Supabase configurado guardar y restaurar funcionan en local', () async {
      final s = AgenteState(autoInit: false);

      await s.saveDailyBriefingInstruction('Sin conexión.');
      expect(s.dailyBriefingInstruction, 'Sin conexión.');
      expect(s.quickPrompts, isEmpty);

      await s.resetDailyBriefingInstruction();
      expect(s.dailyBriefingInstruction, kDailyBriefingDefaultInstruction);
    });
  });
}

/// Servicio de Supabase falso que anota lo que se guarda y se borra.
class _RecordingAgenteService extends AgenteSupabaseService {
  final saved = <AgentePromptModel>[];
  final deleted = <String>[];
  final savedMessages = <ChatMessageModel>[];

  @override
  Future<ChatMessageModel> saveMessage(ChatMessageModel message) async {
    savedMessages.add(message);
    return message;
  }

  @override
  Future<AgentePromptModel> savePrompt(AgentePromptModel prompt) async {
    saved.add(prompt);
    return prompt;
  }

  @override
  Future<bool> deletePrompt(String promptId) async {
    deleted.add(promptId);
    return true;
  }
}

/// Ejecutor falso que puede esperar a [gate] antes de guardar.
class _GatedWriteHandler extends FakeWriteHandler {
  Completer<void>? gate;
  _GatedWriteHandler() : super({WriteToolNames.createHabit});

  @override
  Future<WriteOutcome> execute(String toolName, Map<String, dynamic> args, WriteContext ctx) async {
    final g = gate;
    if (g != null) await g.future;
    return super.execute(toolName, args, ctx);
  }
}
