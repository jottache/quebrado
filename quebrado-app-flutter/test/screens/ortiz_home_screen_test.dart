import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/agente_prompt_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/screens/ortiz_home_screen.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';

import '../helpers/pump_app.dart';

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

/// Reduce el movimiento: las caras quedan fijas y el test se asienta.
Widget _reduced(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

/// Martes 17 de noviembre de 2026 a las 15:00.
DateTime _afternoon() => DateTime(2026, 11, 17, 15);

void main() {
  group('ortizGreeting', () {
    test('cambia en los límites de cada franja', () {
      expect(ortizGreeting(DateTime(2026, 11, 17, 4, 59)), 'Buenas noches');
      expect(ortizGreeting(DateTime(2026, 11, 17, 5)), 'Buenos días');
      expect(ortizGreeting(DateTime(2026, 11, 17, 11, 59)), 'Buenos días');
      expect(ortizGreeting(DateTime(2026, 11, 17, 12)), 'Buenas tardes');
      expect(ortizGreeting(DateTime(2026, 11, 17, 18, 59)), 'Buenas tardes');
      expect(ortizGreeting(DateTime(2026, 11, 17, 19)), 'Buenas noches');
      expect(ortizGreeting(DateTime(2026, 11, 17, 0)), 'Buenas noches');
    });
  });

  test('ortizTodayLabel da el día de la semana, el día y el mes en español', () {
    expect(ortizTodayLabel(_afternoon()), 'HOY · MAR 17 NOV');
    expect(ortizTodayLabel(DateTime(2026, 3, 1)), 'HOY · DOM 1 MAR');
  });

  group('OrtizHomeScreen', () {
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

    Future<void> pumpHome(
      WidgetTester tester, {
      WindowClass window = WindowClass.compact,
      bool connected = true,
      VoidCallback? onOpenMenu,
      List<Widget> quickChips = const [],
      DateTime Function() clock = _afternoon,
    }) =>
        pumpApp(
          tester,
          _reduced(OrtizHomeScreen(
            onOpenMenu: onOpenMenu,
            quickChips: quickChips,
            clock: clock,
            geminiConfigured: connected,
          )),
          providers: [ChangeNotifierProvider<AgenteState>.value(value: state)],
          window: window,
        );

    Future<void> finishAnswer(WidgetTester tester, String text) async {
      gemini.controller.add(GeminiStreamResponse(textChunk: text, fullText: text, isDone: true));
      await gemini.controller.close();
      await tester.pumpAndSettle();
    }

    const panelText = 'El resumen de hoy llega pronto.';

    testWidgets('CA-01: en compact se ven ☰, el saludo según la hora, los chips y el campo',
        (tester) async {
      var menuOpened = 0;
      var gastoTapped = 0;
      await pumpHome(
        tester,
        onOpenMenu: () => menuOpened++,
        quickChips: [
          ActionChip(label: const Text('Registrar gasto'), onPressed: () => gastoTapped++),
        ],
      );

      expect(find.byTooltip('Menú'), findsOneWidget);
      expect(find.text('Ortiz'), findsOneWidget);
      expect(find.text('Conectado a 5 apps'), findsOneWidget);
      expect(find.byTooltip('Nueva conversación'), findsOneWidget);
      expect(find.text('Buenas tardes, soy Ortiz.'), findsOneWidget);
      expect(find.text('¿Qué hacemos hoy?'), findsOneWidget);
      expect(find.text('Resumen del día'), findsOneWidget);
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('Pregúntale algo a Ortiz…'), findsOneWidget);
      expect(find.text(panelText), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Menú'));
      // Los chips se desplazan en horizontal: se trae el chip a la vista.
      await tester.ensureVisible(find.text('Registrar gasto'));
      await tester.tap(find.text('Registrar gasto'));
      expect(menuOpened, 1);
      expect(gastoTapped, 1);
    });

    testWidgets('el saludo sigue al reloj inyectado', (tester) async {
      await pumpHome(tester, clock: () => DateTime(2026, 11, 17, 8));
      expect(find.text('Buenos días, soy Ortiz.'), findsOneWidget);
    });

    testWidgets('entre 840 y 1199 no hay ☰ ni panel: solo el chat con su cabecera',
        (tester) async {
      await pumpHome(tester, window: WindowClass.desktop);

      expect(find.byTooltip('Menú'), findsNothing);
      expect(find.text('Ortiz'), findsOneWidget);
      expect(find.byTooltip('Nueva conversación'), findsOneWidget);
      expect(find.text('Buenas tardes, soy Ortiz.'), findsOneWidget);
      expect(find.text(panelText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desde 1200 aparece el panel «Hoy» con su ancho y su fecha', (tester) async {
      await pumpHome(tester, window: WindowClass.expanded);

      expect(find.byTooltip('Menú'), findsNothing);
      expect(find.text(panelText), findsOneWidget);
      expect(find.text('HOY · MAR 17 NOV'), findsOneWidget);
      final panel = find.ancestor(of: find.text(panelText), matching: find.byType(SizedBox)).last;
      expect(tester.getSize(panel).width, OrtizSize.todayPanelWidthExpanded);
      // La columna del chat no pasa del ancho de lectura.
      expect(tester.getSize(find.byType(TextField)).width,
          lessThanOrEqualTo(OrtizSize.chatMaxWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin Gemini avisa, ofrece conectar y deshabilita el campo, pero las acciones siguen',
        (tester) async {
      var gastoTapped = 0;
      await pumpHome(
        tester,
        connected: false,
        quickChips: [
          ActionChip(label: const Text('Registrar gasto'), onPressed: () => gastoTapped++),
        ],
      );

      expect(find.text(ortizOfflineMessage), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Conectar a Ortiz'), findsOneWidget);
      expect(find.text('Sin conectar'), findsOneWidget);
      expect(find.text('Conectado a 5 apps'), findsNothing);
      expect(find.text('Resumen del día'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.text('Registrar gasto'));
      expect(gastoTapped, 1);
    });

    testWidgets('«Resumen del día» envía el mensaje al chat', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Resumen del día'));
      await tester.pump();

      expect(gemini.prompts, [ortizDailySummaryPrompt]);
      expect(state.messages.first.content, ortizDailySummaryPrompt);
      await finishAnswer(tester, 'Hoy vas bien.');
      expect(find.text('Buenas tardes, soy Ortiz.'), findsNothing);
    });

    testWidgets('los atajos de consulta guardados se envían al tocarlos', (tester) async {
      state.setQuickPrompts([
        AgentePromptModel(
          id: 'p1',
          label: 'Gastos',
          text: '¿Cuánto gasté esta semana?',
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);
      await pumpHome(tester);

      expect(find.text('＋ Atajo'), findsOneWidget);
      await tester.tap(find.text('Gastos'));
      await tester.pump();

      expect(gemini.prompts, ['¿Cuánto gasté esta semana?']);
      await finishAnswer(tester, 'Unos 40 \$.');
    });

    testWidgets('la cara refleja el ánimo de AgenteState', (tester) async {
      await pumpHome(tester);
      List<OrtizMood> moods() =>
          tester.widgetList<OrtizFace>(find.byType(OrtizFace)).map((f) => f.mood).toList();

      // Barra superior y saludo.
      expect(moods(), [OrtizMood.idle, OrtizMood.idle]);

      state.celebrate();
      await tester.pump();
      expect(moods(), everyElement(OrtizMood.happy));

      await tester.pump(OrtizMotion.celebrate);
      expect(moods(), everyElement(OrtizMood.idle));

      await tester.tap(find.text('Resumen del día'));
      await tester.pump();
      expect(state.ortizMood, OrtizMood.thinking);
      expect(moods(), [OrtizMood.thinking]);
      // La línea de estado de la barra muestra lo que hace Ortiz.
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Pensando...')),
          findsOneWidget);

      gemini.controller.add(GeminiStreamResponse(textChunk: 'Hoy', fullText: 'Hoy'));
      await tester.pump();
      expect(moods(), [OrtizMood.talking]);

      await finishAnswer(tester, 'Hoy vas bien.');
      expect(moods(), [OrtizMood.idle]);
    });

    testWidgets('«Nueva conversación» vacía el chat y vuelve el saludo', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Resumen del día'));
      await tester.pump();
      await finishAnswer(tester, 'Hoy vas bien.');
      expect(state.messages, isNotEmpty);

      await tester.tap(find.byTooltip('Nueva conversación'));
      await tester.pumpAndSettle();

      expect(state.messages, isEmpty);
      expect(find.text('Buenas tardes, soy Ortiz.'), findsOneWidget);
    });

    for (final window in [WindowClass.compact, WindowClass.desktop, WindowClass.expanded]) {
      testWidgets('no se desborda con conversación ni sin Gemini (${window.name})', (tester) async {
        await pumpHome(tester, window: window, quickChips: [
          for (final label in ['Registrar gasto', 'Nueva entrada', 'Registrar ánimo'])
            ActionChip(label: Text(label), onPressed: () {}),
        ]);
        await tester.tap(find.text('Resumen del día'));
        await tester.pump();
        await finishAnswer(tester, 'Hoy vas bien.');
        expect(tester.takeException(), isNull);

        await pumpHome(tester, window: window, connected: false);
        expect(find.text(ortizOfflineMessage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
