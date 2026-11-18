import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';

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
}
