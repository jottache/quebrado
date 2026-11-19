import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';
import 'package:quebrado_app_flutter/agente/services/daily_briefing_service.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/briefing_block.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/pending_confirmations_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/widgets/briefing_actions.dart';

import '../helpers/pump_app.dart';

// Datos inventados. 2026-11-18 es miércoles.
final _now = DateTime(2026, 11, 18, 10);

final _internet = RecurringPayment(
  id: 'pago-internet',
  name: 'Internet',
  amount: 25,
  currency: CurrencyType.usd,
  frequency: SubscriptionFrequency.monthly,
  startDate: DateTime(2026, 10, 18),
  notificationOption: NotificationOption.none,
  icon: 'wifi',
  colorHex: '#2FA084',
  type: TransactionType.expense,
);

final _occInternet = PendingOccurrence(payment: _internet, occurrenceDate: DateTime(2026, 11, 18));

final _payInternet = BriefingPay(
  paymentId: 'pago-internet',
  oldestOccurrenceDate: DateTime(2026, 11, 18),
  partial: false,
);

Transaction _tx(String id) => Transaction(
      id: id,
      date: DateTime(2026, 11, 18),
      amount: 25,
      currency: CurrencyType.usd,
      note: 'Internet',
      type: TransactionType.expense,
      exchangeRate: 1,
    );

DailyBriefingSnapshot _snap({
  List<PendingOccurrence> pending = const [],
  List<ReminderStamp> reminders = const [],
}) =>
    DailyBriefingSnapshot(
      financeLoaded: true,
      bookName: 'Libro de prueba',
      pendingWindow: pending,
      bcv: 250,
      parallel: 300,
      euro: 270,
      diarioLoaded: true,
      moodLoaded: true,
      habitsLoaded: true,
      remindersLoaded: true,
      reminders: reminders,
    );

void main() {
  late DailyBriefingSnapshot current;
  late AgenteState agente;

  setUp(() {
    current = _snap();
    agente = AgenteState(
      autoInit: false,
      clock: () => _now,
      briefingLoadTimeout: Duration.zero,
      briefingSnapshotReader: (_) => current,
    );
  });

  tearDown(() => agente.dispose());

  /// Crea el resumen vivo (como el chip «Resumen del día», sin Gemini).
  Future<void> startBriefing(WidgetTester tester) => tester.runAsync(() async {
        await agente.startNewSession();
        await agente.runDailyBriefing();
      });

  Future<void> pumpHarness(
    WidgetTester tester,
    BriefingAction action, {
    List<SingleChildWidget> providers = const [],
    WindowClass window = WindowClass.compact,
  }) async {
    setWindowSize(tester, window.size);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runBriefingAction(context, action),
              child: const Text('Ejecutar'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/:app/:section/:id',
        builder: (_, state) => Scaffold(body: Text('Ruta ${state.uri.path}')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AgenteState>.value(value: agente),
        ...providers,
      ],
      child: MaterialApp.router(theme: testAppTheme(), routerConfig: router),
    ));
    await tester.pump();
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  BriefingPaymentState internetState() =>
      agente.liveBriefing!.payments.items.firstWhere((p) => p.paymentId == _internet.id).state;

  group('Pagar (CA-10)', () {
    late _TestAppState app;

    setUp(() {
      app = _TestAppState()
        ..pending = [_occInternet]
        ..accounts = [
          Account(id: 'default_usd', name: 'Cuenta de prueba', currency: CurrencyType.usd, balance: 100, colorHex: '#2FA084', icon: 'wallet'),
        ];
      current = _snap(pending: [_occInternet]);
    });

    tearDown(() => app.dispose());

    for (final window in [WindowClass.compact, WindowClass.expanded]) {
      testWidgets('«Pagar todo» abre la hoja y al confirmar la fila queda pagada con «Ver» (${window.name})',
          (tester) async {
        await startBriefing(tester);
        expect(internetState(), BriefingPaymentState.pending);
        await pumpHarness(tester, _payInternet,
            providers: [ChangeNotifierProvider<AppState>.value(value: app)], window: window);

        await tester.tap(find.text('Ejecutar'));
        await pumpFrames(tester);
        final sheet = tester.widget<PendingConfirmationsBottomSheet>(find.byType(PendingConfirmationsBottomSheet));
        expect(sheet.filterOccurrence!.payment.id, _internet.id);
        expect(sheet.filterOccurrence!.occurrenceDate, DateTime(2026, 11, 18));

        // Confirmar: la ocurrencia sale de la ventana y la hoja devuelve el movimiento.
        app.pending = [];
        current = _snap();
        Navigator.of(tester.element(find.byType(PendingConfirmationsBottomSheet))).pop([_tx('m1')]);
        await pumpFrames(tester);

        expect(internetState(), BriefingPaymentState.paid);
        expect(agente.liveBriefing!.payments.items, hasLength(1));
        expect(find.text('Pago confirmado'), findsOneWidget);
        expect(agente.ortizMood, OrtizMood.happy);

        await tester.tap(find.text('Ver'));
        await pumpFrames(tester);
        expect(find.text('Ruta /finanzas/movimientos/m1'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    }

    testWidgets('si se omite el pago (hoja sin lista y ocurrencia confirmada) la fila queda omitida',
        (tester) async {
      await startBriefing(tester);
      await pumpHarness(tester, _payInternet, providers: [ChangeNotifierProvider<AppState>.value(value: app)]);

      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);
      app
        ..pending = []
        ..confirmed = true;
      current = _snap();
      Navigator.of(tester.element(find.byType(PendingConfirmationsBottomSheet))).pop();
      await pumpFrames(tester);

      expect(internetState(), BriefingPaymentState.dismissed);
      expect(find.text('Pago confirmado'), findsNothing);
    });

    testWidgets('cerrar la hoja sin confirmar no cambia la fila', (tester) async {
      await startBriefing(tester);
      await pumpHarness(tester, _payInternet, providers: [ChangeNotifierProvider<AppState>.value(value: app)]);

      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);
      Navigator.of(tester.element(find.byType(PendingConfirmationsBottomSheet))).pop();
      await pumpFrames(tester);

      expect(internetState(), BriefingPaymentState.pending);
      expect(agente.ortizMood, OrtizMood.idle);
    });

    testWidgets('si el pago ya no está pendiente avisa sin abrir hoja', (tester) async {
      await startBriefing(tester);
      app.pending = [];
      await pumpHarness(tester, _payInternet, providers: [ChangeNotifierProvider<AppState>.value(value: app)]);

      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);

      expect(find.byType(PendingConfirmationsBottomSheet), findsNothing);
      expect(find.text('Ese pago ya no está pendiente'), findsOneWidget);
      expect(internetState(), BriefingPaymentState.pending);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('si el pago ya no está pendiente y salió de la ventana, la fila se quita (no consta si se pagó u omitió)',
        (tester) async {
      await startBriefing(tester);
      app.pending = [];
      current = _snap();
      await pumpHarness(tester, _payInternet, providers: [ChangeNotifierProvider<AppState>.value(value: app)]);

      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);

      expect(find.byType(PendingConfirmationsBottomSheet), findsNothing);
      expect(find.text('Ese pago ya no está pendiente'), findsOneWidget);
      final items = agente.liveBriefing!.payments.items;
      expect(items.where((p) => p.paymentId == _internet.id), isEmpty);
      expect(items.where((p) => p.state == BriefingPaymentState.paid), isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('briefingSnoozeNotice (U10)', () {
    test('dice «a las HH:mm» si es hoy', () {
      expect(briefingSnoozeNotice(DateTime(2026, 11, 18, 15, 30), DateTime(2026, 11, 18, 16, 30)),
          'Recordatorio pospuesto a las 16:30');
    });

    test('dice «a mañana HH:mm» si es mañana, también al cambiar de mes', () {
      expect(briefingSnoozeNotice(DateTime(2026, 11, 18, 15, 30), DateTime(2026, 11, 19, 15, 30)),
          'Recordatorio pospuesto a mañana 15:30');
      expect(briefingSnoozeNotice(DateTime(2026, 11, 30, 23, 30), DateTime(2026, 12, 1, 0, 30)),
          'Recordatorio pospuesto a mañana 00:30');
    });

    test('más allá de mañana usa la fecha completa', () {
      expect(briefingSnoozeNotice(DateTime(2026, 11, 18, 9, 5), DateTime(2026, 11, 20, 9, 5)),
          'Recordatorio pospuesto a 20/11/2026 09:05');
    });
  });

  group('Posponer', () {
    late _RecordingReminders reminders;

    setUp(() {
      reminders = _RecordingReminders();
      current = _snap(reminders: [
        ReminderStamp(id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15), status: ReminderStatus.pending),
      ]);
    });

    tearDown(() => reminders.dispose());

    testWidgets('«1 hora» llama a snoozeTo con ahora + 1 hora y marca la fila con esa misma hora', (tester) async {
      await startBriefing(tester);
      await pumpHarness(
        tester,
        const BriefingSnooze(reminderId: 'rec-1', option: BriefingSnoozeOption.oneHour),
        providers: [ChangeNotifierProvider<RemindersState>.value(value: reminders)],
      );

      final before = DateTime.now();
      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);

      expect(reminders.calls, hasLength(1));
      expect(reminders.calls.single, startsWith('to:rec-1:'));
      final to = reminders.snoozedTo!;
      expect(to.difference(before.add(const Duration(hours: 1))).inMinutes.abs(), lessThan(1));
      // La fila usa exactamente la misma hora que el recordatorio.
      expect(agente.liveBriefing!.reminders.items.single.snoozedUntil, to);
      expect(find.text(briefingSnoozeNotice(before, to)), findsOneWidget);
      expect(find.text('Ver'), findsOneWidget);
      expect(agente.ortizMood, OrtizMood.happy);
      await tester.pump(const Duration(seconds: 5));
    });

    for (final (caso, existing) in [
      ('ya no existe', <ReminderModel>[]),
      (
        'está completado',
        [
          ReminderModel(
              id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15), status: ReminderStatus.completed),
        ]
      ),
    ]) {
      testWidgets('si el recordatorio $caso no pospone, no marca la fila y avisa sin «Ver»', (tester) async {
        reminders.existing = existing;
        await startBriefing(tester);
        await pumpHarness(
          tester,
          const BriefingSnooze(reminderId: 'rec-1', option: BriefingSnoozeOption.oneHour),
          providers: [ChangeNotifierProvider<RemindersState>.value(value: reminders)],
        );

        await tester.tap(find.text('Ejecutar'));
        await pumpFrames(tester);

        expect(reminders.calls, isEmpty);
        expect(agente.liveBriefing!.reminders.items.single.snoozedUntil, isNull);
        expect(find.text('Ese recordatorio ya no está pendiente.'), findsOneWidget);
        expect(find.textContaining('Recordatorio pospuesto'), findsNothing);
        expect(find.text('Ver'), findsNothing);
        expect(agente.ortizMood, OrtizMood.idle);
        await tester.pump(const Duration(seconds: 5));
      });
    }

    testWidgets('un recordatorio ya pospuesto se puede volver a posponer', (tester) async {
      reminders.existing = [
        ReminderModel(id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15), status: ReminderStatus.snoozed),
      ];
      await startBriefing(tester);
      await pumpHarness(
        tester,
        const BriefingSnooze(reminderId: 'rec-1', option: BriefingSnoozeOption.oneHour),
        providers: [ChangeNotifierProvider<RemindersState>.value(value: reminders)],
      );

      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);

      expect(reminders.calls, hasLength(1));
      expect(find.textContaining('Recordatorio pospuesto a '), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('«Mañana a esta hora» llama a snoozeTo con mañana a la misma hora y minuto', (tester) async {
      await startBriefing(tester);
      await pumpHarness(
        tester,
        const BriefingSnooze(reminderId: 'rec-1', option: BriefingSnoozeOption.tomorrowSameTime),
        providers: [ChangeNotifierProvider<RemindersState>.value(value: reminders)],
      );

      final before = DateTime.now();
      await tester.tap(find.text('Ejecutar'));
      await pumpFrames(tester);

      expect(reminders.calls, hasLength(1));
      expect(reminders.calls.single, startsWith('to:rec-1:'));
      final to = reminders.snoozedTo!;
      // Día de calendario siguiente (no 24 h), a la hora y minuto de ahora.
      final expected = DateTime(before.year, before.month, before.day + 1, before.hour, before.minute);
      expect(to.difference(expected).inMinutes.abs(), lessThanOrEqualTo(1));
      expect(to.second, 0);
      expect(agente.liveBriefing!.reminders.items.single.snoozedUntil, to);
      expect(find.text(briefingSnoozeNotice(before, to)), findsOneWidget);
      expect(find.textContaining('Recordatorio pospuesto a mañana '), findsOneWidget);
      expect(agente.ortizMood, OrtizMood.happy);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('«Ver contacto» navega a la ficha del contacto', (tester) async {
    await pumpHarness(tester, const BriefingViewContact('c1'));

    await tester.tap(find.text('Ejecutar'));
    await pumpFrames(tester);

    expect(find.text('Ruta /diario/contactos/c1'), findsOneWidget);
  });
}

/// AppState sin carga de datos, con las ocurrencias pendientes del test.
class _TestAppState extends AppState {
  List<PendingOccurrence> pending = [];
  bool confirmed = false;

  @override
  Future<void> loadData({bool forceReload = false}) async {}

  @override
  List<PendingOccurrence> pendingPaymentsWithin({DateTime? now, int daysAhead = 7}) => pending;

  @override
  bool isOccurrenceConfirmed(String paymentId, DateTime occurrenceDate) => confirmed;
}

/// Registra las llamadas de posponer; el resto de RemindersState no se usa.
class _RecordingReminders extends ChangeNotifier implements RemindersState {
  final calls = <String>[];
  DateTime? snoozedTo;
  List<ReminderModel> existing = [ReminderModel(id: 'rec-1', title: 'Llamar', dueAt: DateTime(2026, 11, 18, 15))];

  @override
  List<ReminderModel> get allReminders => List.unmodifiable(existing);

  @override
  Future<void> snoozeRelative(String id, Duration offset) async => calls.add('relative:$id:$offset');

  @override
  Future<void> snoozeTo(String id, DateTime newDueAt) async {
    snoozedTo = newDueAt;
    calls.add('to:$id:$newDueAt');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
