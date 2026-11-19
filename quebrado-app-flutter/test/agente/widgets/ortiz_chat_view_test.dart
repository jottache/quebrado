import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_chat_view.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

import '../../helpers/pump_app.dart';

/// Gemini simulado: la respuesta llega cuando el test la empuja.
class _FakeGemini implements GeminiService {
  final controller = StreamController<GeminiStreamResponse>();
  final prompts = <String>[];

  @override
  Stream<GeminiStreamResponse> sendMessageStream({
    required String prompt,
    required List<ChatMessageModel> previousMessages,
    required String sessionId,
  }) {
    prompts.add(prompt);
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reduce el movimiento para que la vista no anime (y el test se asiente).
Widget _reduced(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

void main() {
  late _FakeGemini gemini;
  late AgenteState state;

  setUp(() async {
    gemini = _FakeGemini();
    state = AgenteState(autoInit: false, geminiService: gemini);
    await state.startNewSession();
  });

  tearDown(() {
    unawaited(gemini.controller.close());
    state.dispose();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    bool enabled = true,
    Widget? aboveInput,
    WindowClass window = WindowClass.compact,
  }) =>
      pumpApp(
        tester,
        _reduced(OrtizChatView(
          enabled: enabled,
          aboveInput: aboveInput,
          emptyBuilder: (_) => const Text('Chat vacío'),
        )),
        providers: [ChangeNotifierProvider<AgenteState>.value(value: state)],
        window: window,
      );

  Finder field() => find.byType(TextField);
  // El único IconButton de la vista es «Enviar».
  Finder sendButton() => find.byType(IconButton);

  testWidgets('envía el mensaje escrito y muestra la respuesta de Gemini simulado',
      (tester) async {
    await pumpView(tester);
    expect(find.text('Chat vacío'), findsOneWidget);
    expect(find.text('Pregúntale algo a Ortiz…'), findsOneWidget);

    await tester.enterText(field(), '¿Cuánto gasté hoy?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();

    expect(gemini.prompts, ['¿Cuánto gasté hoy?']);
    expect(state.messages.first.content, '¿Cuánto gasté hoy?');
    // El campo se vacía y, mientras genera, enviar queda deshabilitado.
    expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNull);

    gemini.controller.add(
        GeminiStreamResponse(textChunk: 'Hoy gastaste 12 \$', fullText: 'Hoy gastaste 12 \$', isDone: true));
    await gemini.controller.close();
    await tester.pumpAndSettle();

    expect(find.text('Chat vacío'), findsNothing);
    expect(find.textContaining('Hoy gastaste 12', findRichText: true), findsOneWidget);
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNotNull);
  });

  testWidgets('Enter envía y Shift+Enter no', (tester) async {
    await pumpView(tester, window: WindowClass.expanded);

    await tester.enterText(field(), 'primera línea');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(state.messages, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(gemini.prompts, ['primera línea']);
  });

  testWidgets('no envía texto vacío', (tester) async {
    await pumpView(tester);

    await tester.enterText(field(), '   ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();

    expect(state.messages, isEmpty);
    expect(gemini.prompts, isEmpty);
  });

  testWidgets('deshabilitada, el campo y enviar no responden', (tester) async {
    await pumpView(tester, enabled: false);

    expect(tester.widget<TextField>(field()).enabled, isFalse);
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNull);
  });

  testWidgets('oculta la fila de encima mientras el campo tiene texto', (tester) async {
    await pumpView(tester, aboveInput: const Text('Chips'));
    expect(find.text('Chips'), findsOneWidget);

    await tester.enterText(field(), 'hola');
    await tester.pumpAndSettle();
    expect(find.text('Chips'), findsNothing);

    await tester.enterText(field(), '');
    await tester.pumpAndSettle();
    expect(find.text('Chips'), findsOneWidget);
  });

  testWidgets('el botón enviar va en fg inverso, no en accent', (tester) async {
    await pumpView(tester);
    final context = tester.element(sendButton());
    final t = OrtizTokens.of(context);
    final style = tester.widget<IconButton>(sendButton()).style!;

    expect(style.backgroundColor!.resolve({}), t.fg);
    expect(style.foregroundColor!.resolve({}), t.bg);
  });

  for (final window in WindowClass.values) {
    testWidgets('con mensajes cabe sin desbordes y el campo respeta la columna de lectura (${window.name})',
        (tester) async {
      await pumpView(tester, window: window, aboveInput: const Text('Chips'));
      await tester.enterText(field(), 'Un mensaje');
      await tester.tap(find.byTooltip('Enviar'));
      gemini.controller.add(GeminiStreamResponse(
          textChunk: 'Respuesta', fullText: 'Respuesta', isDone: true));
      await gemini.controller.close();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(field()).width,
          lessThanOrEqualTo(OrtizSize.chatMaxWidth - 2 * OrtizSpace.md));
    });
  }
}
