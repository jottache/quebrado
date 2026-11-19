// Burbuja del resumen del día en el chat (spec 04, docs/design/resumen-del-dia.md
// U2.1 y U8): anuncio único «Resumen listo: n cosas para hoy», mismo ancho
// máximo que el resto de burbujas y resumen guardado sin filas. Datos
// inventados.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/chat_message_model.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/briefing_block.dart';
import 'package:quebrado_app_flutter/agente/widgets/chat_message_bubble.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 17, 9);

/// `AgenteState` sin red con el id del mensaje vivo a mano.
class _FakeAgente extends AgenteState {
  _FakeAgente() : super(autoInit: false);

  String? liveId;
  DailyBriefing? live;

  @override
  String? get liveBriefingMessageId => liveId;

  @override
  DailyBriefing? get liveBriefing => live;
}

DailyBriefing _briefing({bool moodLogged = false}) => DailyBriefing(
      generatedAt: _now,
      period: BriefingPeriod.morning,
      bookName: 'Personal',
      bookId: 'libro-personal',
      diario: const BriefingDiario(status: BriefingStatus.ready),
      mood: BriefingMood(status: BriefingStatus.ready, loggedToday: moodLogged),
      payments: BriefingPayments(status: BriefingStatus.ready, items: [
        BriefingPayment(
          paymentId: 'p-internet',
          name: 'Internet',
          oldestOccurrenceDate: DateTime(2026, 11, 19),
          remaining: BriefingAmount.convert(25, CurrencyType.usd, bcv: 250, euro: 270),
        ),
      ]),
      birthdays: const BriefingBirthdays(status: BriefingStatus.ready),
      habits: const BriefingHabits(status: BriefingStatus.ready),
      reminders: const BriefingReminders(status: BriefingStatus.ready),
      rates: const BriefingRates(status: BriefingStatus.ready, bcv: BriefingRate(value: 250)),
    );

ChatMessageModel _message(Map<String, dynamic> metadata, {String id = 'm-resumen'}) => ChatMessageModel(
      id: id,
      sessionId: 's-1',
      role: MessageRole.model,
      content: 'Esto es lo de hoy:',
      artifacts: [
        ChatArtifactModel(
          id: 'a-resumen',
          sessionId: 's-1',
          type: ArtifactType.dailyBriefing,
          title: 'Resumen del día',
          content: '',
          metadata: metadata,
        ),
      ],
    );

/// Anuncios enviados al lector de pantalla (`SemanticsService`).
List<String> _captureAnnouncements(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic message) async {
      final map = message as Map<Object?, Object?>;
      if (map['type'] == 'announce') {
        announced.add((map['data']! as Map<Object?, Object?>)['message']! as String);
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
  return announced;
}

void main() {
  late _FakeAgente agente;

  setUp(() => agente = _FakeAgente());
  tearDown(() => agente.dispose());

  Future<void> pumpBubble(WidgetTester tester, ValueNotifier<ChatMessageModel> message,
          {WindowClass window = WindowClass.compact}) =>
      pumpApp(
        tester,
        ValueListenableBuilder<ChatMessageModel>(
          valueListenable: message,
          builder: (context, m, _) => ListView(children: [ChatMessageBubble(message: m)]),
        ),
        providers: [ChangeNotifierProvider<AgenteState>.value(value: agente)],
        window: window,
      );

  testWidgets('el resumen vivo se anuncia una sola vez, aunque cambie el número de cosas', (tester) async {
    final announced = _captureAnnouncements(tester);
    agente.liveId = 'm-resumen';
    final message = ValueNotifier(_message(_briefing().toArtifactMetadata()));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);
    await tester.pump();
    expect(announced, ['Resumen listo: 3 cosas para hoy']);

    message.value = _message(_briefing(moodLogged: true).toArtifactMetadata());
    await tester.pump();
    await tester.pump();
    expect(announced, hasLength(1));
  });

  testWidgets('un resumen que no es el vivo no se anuncia', (tester) async {
    final announced = _captureAnnouncements(tester);
    agente.liveId = 'otro-mensaje';
    final message = ValueNotifier(_message(_briefing().toArtifactMetadata()));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);
    await tester.pump();
    expect(announced, isEmpty);
  });

  testWidgets('sin cosas que contar y sin estar todo al día anuncia «Resumen listo» sin número', (tester) async {
    final announced = _captureAnnouncements(tester);
    agente.liveId = 'm-resumen';
    final briefing = DailyBriefing(
      generatedAt: _now,
      period: BriefingPeriod.morning,
      bookName: 'Personal',
      diario: const BriefingDiario(status: BriefingStatus.ready, entriesToday: 1),
      mood: const BriefingMood(status: BriefingStatus.ready, loggedToday: true),
      payments: const BriefingPayments(status: BriefingStatus.ready),
      birthdays: const BriefingBirthdays(status: BriefingStatus.ready),
      habits: const BriefingHabits(status: BriefingStatus.ready),
      reminders: const BriefingReminders(status: BriefingStatus.ready),
      rates: const BriefingRates(status: BriefingStatus.unavailable),
    );
    expect(briefing.itemCount, 0);
    expect(briefing.isAllClear, isFalse);
    final message = ValueNotifier(_message(briefing.toArtifactMetadata()));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);
    await tester.pump();
    expect(announced, ['Resumen listo']);
  });

  testWidgets('el mensaje vivo se pinta con el resumen de AgenteState aunque su metadata venga recortada',
      (tester) async {
    agente.liveId = 'm-resumen';
    agente.live = _briefing();
    // Metadata como vuelve del historial: sin filas.
    final message = ValueNotifier(_message({'generatedAt': _now.toIso8601String(), 'period': 'morning'}));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);

    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Pagar'), findsOneWidget);
    expect(find.text('Escribir'), findsOneWidget);
    expect(find.textContaining('Pide uno nuevo para actuar'), findsNothing);
  });

  testWidgets('un mensaje que no es el vivo usa su metadata aunque haya un resumen vivo', (tester) async {
    agente.liveId = 'otro-mensaje';
    agente.live = _briefing();
    final message = ValueNotifier(_message({'generatedAt': _now.toIso8601String(), 'period': 'morning'}));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);

    expect(find.text('Internet'), findsNothing);
    expect(find.text('Resumen del 17/11/2026 a las 09:00. Pide uno nuevo para actuar.'), findsOneWidget);
  });

  testWidgets('un resumen guardado sin datos solo trae su línea de fecha, sin filas', (tester) async {
    final message = ValueNotifier(_message({'generatedAt': _now.toIso8601String(), 'period': 'morning'}));
    addTearDown(message.dispose);

    await pumpBubble(tester, message);

    expect(find.text('Esto es lo de hoy:'), findsOneWidget);
    expect(find.text('Resumen del 17/11/2026 a las 09:00. Pide uno nuevo para actuar.'), findsOneWidget);
    expect(find.textContaining('No pude leer'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('la burbuja del resumen no pasa del 85 % del ancho (${window.name})', (tester) async {
      agente.liveId = 'm-resumen';
      final message = ValueNotifier(_message(_briefing().toArtifactMetadata()));
      addTearDown(message.dispose);

      await pumpBubble(tester, message, window: window);

      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final bubble = find.ancestor(of: find.byType(BriefingBlock), matching: find.byType(Container)).first;
      expect(tester.getSize(bubble).width, moreOrLessEquals(screenWidth * 0.85));
      expect(tester.takeException(), isNull);
    });

    testWidgets('una burbuja de texto largo usa el mismo ancho máximo (${window.name})', (tester) async {
      final message = ValueNotifier(ChatMessageModel(
        id: 'm-texto',
        sessionId: 's-1',
        role: MessageRole.model,
        content: List.filled(80, 'palabra').join(' '),
      ));
      addTearDown(message.dispose);

      await pumpBubble(tester, message, window: window);

      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final context = tester.element(find.byType(ChatMessageBubble));
      final bubble = find.ancestor(of: find.byType(MarkdownBody), matching: find.byType(Container)).first;
      expect(tester.getSize(bubble).width, moreOrLessEquals(ChatMessageBubble.maxWidthOf(context)));
      expect(tester.getSize(bubble).width, moreOrLessEquals(screenWidth * 0.85));
    });
  }
}
