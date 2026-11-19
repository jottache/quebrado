import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/agente_prompt_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/services/daily_briefing_service.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/briefing_block.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/screens/ortiz_home_screen.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

import '../helpers/fake_write_handler.dart';
import '../helpers/pump_app.dart';

class _FakeNotasState extends Fake implements NotasState {}

/// Todo cargado y vacío salvo lo que pida cada test (datos inventados).
DailyBriefingSnapshot _snap({
  List<DiaryEntryStamp> diary = const [],
  List<ContactBirthday> contacts = const [],
  List<HabitStamp> habits = const [],
  List<ReminderStamp> reminders = const [],
  List<PendingOccurrence> pendingWindow = const [],
  bool moodLoggedToday = false,
}) =>
    DailyBriefingSnapshot(
      financeLoaded: true,
      bookName: 'Libro de prueba',
      pendingWindow: pendingWindow,
      bcv: 250,
      parallel: 300,
      euro: 270,
      diarioLoaded: true,
      diaryEntries: diary,
      contacts: contacts,
      moodLoaded: true,
      moodLoggedToday: moodLoggedToday,
      habitsLoaded: true,
      scheduledGoodHabits: habits,
      remindersLoaded: true,
      reminders: reminders,
    );

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
    late DailyBriefingSnapshot snapshot;

    setUp(() async {
      gemini = _FakeGemini();
      snapshot = _snap();
      state = AgenteState(
        autoInit: false,
        geminiService: gemini,
        clock: _afternoon,
        briefingLoadTimeout: Duration.zero,
        briefingSnapshotReader: (_) => snapshot,
      );
      await state.startNewSession();
    });

    /// Calcula `todayBriefing` como lo hace el ProxyProvider de la app.
    Future<void> loadBriefing(WidgetTester tester) async {
      state.updateDependencies(
        appState: FakeAppState(),
        diarioState: FakeDiarioState(),
        habitosState: FakeHabitosState(),
        remindersState: FakeRemindersState(),
        animoState: FakeAnimoState(),
        notasState: _FakeNotasState(),
      );
      await tester.pump();
    }

    /// Deja que termine `runDailyBriefing` (sin Gemini: frase fija).
    Future<void> settleBriefing(WidgetTester tester) async {
      for (var i = 0; i < 10 && state.isGenerating; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      expect(state.isGenerating, isFalse);
    }

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
      // Spec 04 (CA-07): el chip del resumen se ve también sin Gemini.
      expect(find.text('Resumen del día'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.ensureVisible(find.text('Registrar gasto'));
      await tester.tap(find.text('Registrar gasto'));
      expect(gastoTapped, 1);
    });

    testWidgets('«Resumen del día» lanza el resumen (no envía un mensaje a Gemini)',
        (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Resumen del día'));
      await tester.pump();
      await settleBriefing(tester);

      expect(gemini.prompts, isEmpty);
      expect(state.messages.first.content, AgenteState.dailyBriefingUserText);
      expect(state.messages.last.artifacts.single.type, ArtifactType.dailyBriefing);
      expect(find.byType(BriefingBlock), findsOneWidget);
      expect(find.text('Buenas tardes, soy Ortiz.'), findsNothing);
    });

    testWidgets('CA-07: sin Gemini el chip se ve y al tocarlo salen las filas y «Esto es lo de hoy:»',
        (tester) async {
      await pumpHome(tester, connected: false);

      await tester.tap(find.text('Resumen del día'));
      await tester.pump();
      await settleBriefing(tester);

      expect(find.text('Esto es lo de hoy:'), findsOneWidget);
      final block = tester.widget<BriefingBlock>(find.byType(BriefingBlock));
      expect(block.variant, BriefingBlockVariant.chat);
      expect(block.actionsEnabled, isTrue);
      expect(find.text('Aún no escribes hoy.'), findsOneWidget);
      expect(find.textContaining('Error'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('franja de hoy (compact): hasta 3 etiquetas, sin panel; tocarla lanza el resumen',
        (tester) async {
      snapshot = _snap(
        // Cuatro candidatas: recordatorio vencido, cumpleaños hoy, diario y hábitos.
        reminders: [
          ReminderStamp(
              id: 'r1', title: 'Renovar seguro', dueAt: DateTime(2026, 11, 16, 9),
              status: ReminderStatus.pending),
        ],
        contacts: [ContactBirthday(id: 'c1', name: 'Andrea', birthdate: DateTime(1990, 11, 17))],
        habits: [const HabitStamp(id: 'h1', title: 'Leer', doneToday: false)],
      );
      await loadBriefing(tester);
      await pumpHome(tester);

      final expected = state.todayBriefing!.highlights;
      expect(expected, hasLength(3));
      final pills = tester.widgetList<OrtizPill>(find.byType(OrtizPill)).toList();
      expect(pills, hasLength(3));
      expect([for (final p in pills) p.label], [for (final h in expected) h.label]);
      expect(pills.every((p) => p.dotColor != null), isTrue);
      // Sin nombres ni montos.
      expect(find.textContaining('Andrea'), findsNothing);
      expect(find.text('El resumen de hoy llega pronto.'), findsNothing);
      expect(find.byType(BriefingBlock), findsNothing);
      // Cada etiqueta es un botón activo para el lector de pantalla.
      expect(
        tester.getSemantics(find.bySemanticsLabel('${expected.first.label}. Ver el resumen del día')),
        containsSemantics(isButton: true, hasEnabledState: true, isEnabled: true),
      );

      await tester.tap(find.text(expected.first.label));
      await tester.pump();
      await settleBriefing(tester);
      expect(state.messages.first.content, AgenteState.dailyBriefingUserText);
      // Con el chat ya no vacío la franja desaparece: no queda ninguna
      // píldora de la franja (las de la franja llevan punto de color; las
      // «Vencido» de las filas del resumen, no).
      final stripPills = tester
          .widgetList<OrtizPill>(find.byType(OrtizPill))
          .where((p) => p.dotColor != null)
          .toList();
      expect(stripPills, isEmpty);
    });

    testWidgets('a 900 px (entre 840 y 1199) la franja de hoy se ve y no hay panel', (tester) async {
      snapshot = _snap(
        habits: [const HabitStamp(id: 'h1', title: 'Leer', doneToday: false)],
      );
      await loadBriefing(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 800);
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        _reduced(OrtizHomeScreen(clock: _afternoon, geminiConfigured: true)),
        providers: [ChangeNotifierProvider<AgenteState>.value(value: state)],
      );

      final expected = state.todayBriefing!.highlights;
      expect(expected, isNotEmpty);
      final pills = tester.widgetList<OrtizPill>(find.byType(OrtizPill)).toList();
      expect([for (final p in pills) p.label], [for (final h in expected) h.label]);
      expect(find.byType(BriefingBlock), findsNothing);
      expect(find.text(panelText), findsNothing);
      expect(find.byTooltip('Menú'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('franja con todo al día: una sola etiqueta «Todo al día» con la marca de éxito',
        (tester) async {
      snapshot = _snap(moodLoggedToday: true, diary: [
        DiaryEntryStamp(createdAt: DateTime(2026, 11, 17, 8), entryType: 'simple_text'),
      ]);
      await loadBriefing(tester);
      await pumpHome(tester);

      expect(find.text('Todo al día'), findsOneWidget);
      expect(find.byType(OrtizSuccessMark), findsOneWidget);
      expect(find.byType(OrtizPill), findsNothing);
      // La misma píldora neutra que las demás etiquetas: fondo `surface`.
      final tokens = OrtizTokens.of(tester.element(find.text('Todo al día')));
      final pill = tester.widget<DecoratedBox>(find
          .ancestor(of: find.text('Todo al día'), matching: find.byType(DecoratedBox))
          .first);
      expect((pill.decoration as BoxDecoration).color, tokens.surface);
      expect(find.ancestor(of: find.byType(OrtizSuccessMark), matching: find.byWidget(pill)),
          findsOneWidget);
    });

    testWidgets('mientras Ortiz responde el chip «Resumen del día» se desactiva con texto e icono en muted',
        (tester) async {
      await pumpHome(tester);
      final chip = find.widgetWithText(ActionChip, 'Resumen del día');
      final tokens = OrtizTokens.of(tester.element(chip));
      Color? labelColor() => tester
          .widget<RichText>(find.descendant(of: chip, matching: find.byType(RichText)).first)
          .text
          .style
          ?.color;
      Color? iconColor() =>
          tester.widget<Icon>(find.descendant(of: chip, matching: find.byIcon(Icons.wb_sunny_outlined))).color;

      expect(labelColor(), tokens.onAccent);
      expect(iconColor(), tokens.onAccent);

      unawaited(state.sendMessage('¿Cómo voy?'));
      await tester.pump();
      expect(state.isGenerating, isTrue);
      expect(tester.widget<ActionChip>(chip).onPressed, isNull);
      expect(labelColor(), tokens.muted);
      expect(iconColor(), tokens.muted);

      await finishAnswer(tester, 'Hoy vas bien.');
    });

    testWidgets('CA-09 (expanded ≥ 1200): el panel pinta el resumen de hoy y no hay franja',
        (tester) async {
      final internet = RecurringPayment(
        id: 'home_test_internet',
        name: 'Internet de prueba',
        amount: 25,
        currency: CurrencyType.usd,
        frequency: SubscriptionFrequency.once,
        startDate: DateTime(2026, 11, 19),
        notificationOption: NotificationOption.none,
        icon: 'wifi',
        colorHex: '#2FA084',
        type: TransactionType.expense,
      );
      snapshot = _snap(
        contacts: [ContactBirthday(id: 'c1', name: 'Andrea', birthdate: DateTime(1990, 11, 17))],
        pendingWindow: [PendingOccurrence(payment: internet, occurrenceDate: DateTime(2026, 11, 19))],
        reminders: [
          ReminderStamp(
              id: 'r1', title: 'Llamar al banco', dueAt: DateTime(2026, 11, 17, 18),
              status: ReminderStatus.pending),
        ],
      );
      await loadBriefing(tester);
      await pumpHome(tester, window: WindowClass.expanded);

      final block = tester.widget<BriefingBlock>(find.byType(BriefingBlock));
      expect(block.variant, BriefingBlockVariant.panel);
      expect(block.actionsEnabled, isTrue);
      expect(identical(block.briefing, state.todayBriefing), isTrue);
      // Las filas del panel son las del resumen de hoy: mismos pagos y
      // recordatorios, por nombre.
      final today = state.todayBriefing!;
      final paymentNames = [for (final p in today.payments.sortedItems) p.name];
      final reminderNames = [for (final r in today.reminders.sortedTodayItems) r.title];
      expect(paymentNames, ['Internet de prueba']);
      expect(reminderNames, ['Llamar al banco']);
      final panel = find.byType(BriefingBlock);
      for (final name in [...paymentNames, ...reminderNames]) {
        expect(find.descendant(of: panel, matching: find.text(name)), findsOneWidget);
      }
      expect(find.text('Andrea cumple hoy'), findsOneWidget);
      expect(find.text('Aún no escribes hoy.'), findsOneWidget);
      expect(find.text('El resumen de hoy llega pronto.'), findsNothing);
      expect(find.byType(OrtizPill), findsNothing);
      expect(tester.takeException(), isNull);
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

      unawaited(state.sendMessage('¿Cómo voy?'));
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
      unawaited(state.sendMessage('¿Cómo voy?'));
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
        unawaited(state.sendMessage('¿Cómo voy?'));
        await tester.pump();
        await finishAnswer(tester, 'Hoy vas bien.');
        expect(tester.takeException(), isNull);

        // Resumen del día en el chat (y en el panel en ≥ 1200).
        await loadBriefing(tester);
        await tester.tap(find.text('Resumen del día'));
        await tester.pump();
        await settleBriefing(tester);
        expect(find.byType(BriefingBlock), findsWidgets);
        expect(tester.takeException(), isNull);

        await pumpHome(tester, window: window, connected: false);
        expect(find.text(ortizOfflineMessage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
