import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/models/undo_result.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
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
