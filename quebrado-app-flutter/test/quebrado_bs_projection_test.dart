import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/add_exchange_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/add_recurring_payment_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/currency_pill.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/timeline_event_row.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/saving_pocket.dart';
import 'package:quebrado_app_flutter/quebrado/models/timeline_event.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _day(int offset) => _today().add(Duration(days: offset));

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

RecurringPayment _once({
  required String id,
  required String name,
  required double amount,
  required CurrencyType currency,
  required TransactionType type,
  required String accountId,
  required int inDays,
  String? pocketId,
}) =>
    RecurringPayment(
      id: id,
      name: name,
      amount: amount,
      currency: currency,
      frequency: SubscriptionFrequency.once,
      startDate: _day(inDays),
      notificationOption: NotificationOption.none,
      icon: 'home',
      colorHex: '#2FA084',
      type: type,
      accountId: accountId,
      pocketId: pocketId,
      totalInstallments: 1,
    );

Future<AppState> _scenario({
  double usd = 500,
  double bs = 2000,
  List<RecurringPayment> payments = const [],
  List<SavingPocket> pockets = const [],
}) async {
  final app = AppState();
  await app.loadData();
  app.debugSetRates(bcv: 100, euro: 110, parallel: 120);
  app.accounts = [
    Account(id: 'usd', name: 'Efectivo \$', currency: CurrencyType.usd, balance: usd, colorHex: '#2FA084', icon: 'creditcard'),
    Account(id: 'bs', name: 'Banesco', currency: CurrencyType.bsBCV, balance: bs, colorHex: '#1F6F5F', icon: 'bank'),
  ];
  app.pockets = [...pockets];
  app.recurringPayments
    ..clear()
    ..addAll(payments);
  app.transactions = [];
  app.partialPayments.clear();
  app.notifyListeners();
  return app;
}

List<TimelineEvent> _exchanges(AppState app) => app.getTimelineEvents(30).where((e) => e.isExchangeSuggestion).toList();

TimelineEvent _event(AppState app, String title) => app.getTimelineEvents(30).firstWhere((e) => e.title == title);

void main() {
  setUp(() async {
    AppState.debugLocalDbIsSourceOfTruth = false;
    await DatabaseHelper.instance.setSetting(AppState.fulfilledSuggestionsSettingKey, '[]');
  });
  tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

  group('Proyección con dos cajas (\$ y Bs)', () {
    test('ejemplo del plan: el sueldo en Bs ayuda y solo se vende lo que falta, el día del gasto', () async {
      final app = await _scenario(payments: [
        _once(id: 'sueldo', name: 'Sueldo Bs', amount: 80, currency: CurrencyType.usd, type: TransactionType.income, accountId: 'bs', inDays: 1),
        _once(id: 'condominio', name: 'Condominio', amount: 150, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 5),
      ]);

      final exchanges = _exchanges(app);
      expect(exchanges, hasLength(1));
      final exchange = exchanges.single;
      expect(_sameDay(exchange.date, _day(5)), isTrue, reason: 'justo a tiempo: el mismo día del gasto');
      expect(exchange.amount, closeTo(50, 0.001), reason: 'faltan Bs 5.000 a tasa 100');
      expect(exchange.exchangeAmountBs, closeTo(5000, 0.001));
      expect(exchange.exchangeRate, 100);
      expect(exchange.suggestionReasons!.single.name, contains('Condominio'));
      expect(exchange.exchangeSourceAccountId, 'usd');
      expect(exchange.exchangeTargetAccountId, 'bs');

      final events = app.getTimelineEvents(30);
      expect(events.indexOf(exchange), lessThan(events.indexWhere((e) => e.title == 'Condominio')),
          reason: 'el cambio va antes del pago');

      final condominio = _event(app, 'Condominio');
      expect(condominio.projectedBsBalance, closeTo(0, 0.001));
      expect(condominio.projectedLiquidBalanceUSD, closeTo(450, 0.001));
      expect(condominio.amountUSD, closeTo(150, 0.001));
      expect(condominio.accountBalances!['bs'], closeTo(0, 0.001));
      expect(condominio.accountBalances!['usd'], closeTo(450, 0.001));

      final sueldo = _event(app, 'Sueldo Bs');
      expect(sueldo.projectedBsBalance, closeTo(10000, 0.001));
      expect(sueldo.projectedLiquidBalanceUSD, closeTo(500, 0.001), reason: 'los Bs no inflan el disponible en \$');
    });

    test('si los ingresos en Bs alcanzan, no se sugiere vender dólares', () async {
      final app = await _scenario(payments: [
        _once(id: 'sueldo', name: 'Sueldo Bs', amount: 200, currency: CurrencyType.usd, type: TransactionType.income, accountId: 'bs', inDays: 1),
        _once(id: 'condominio', name: 'Condominio', amount: 150, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 5),
      ]);
      expect(_exchanges(app), isEmpty);
      expect(_event(app, 'Condominio').projectedBsBalance, closeTo(7000, 0.001));
      expect(_event(app, 'Condominio').projectedLiquidBalanceUSD, closeTo(500, 0.001));
    });

    test('dos gastos en Bs el mismo día generan un solo cambio', () async {
      final app = await _scenario(bs: 0, payments: [
        _once(id: 'a', name: 'Condominio', amount: 30, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 3),
        _once(id: 'b', name: 'Internet', amount: 20, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 3),
      ]);
      final exchanges = _exchanges(app);
      expect(exchanges, hasLength(1));
      expect(exchanges.single.amount, closeTo(50, 0.001));
      expect(exchanges.single.suggestionReasons!.map((r) => r.name).join(), allOf(contains('Condominio'), contains('Internet')));
    });

    test('sin dólares suficientes, el cambio se sugiere igual y el faltante se ve en el disponible', () async {
      final app = await _scenario(usd: 20, bs: 0, payments: [
        _once(id: 'a', name: 'Colegio', amount: 50, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 2),
      ]);
      final exchange = _exchanges(app).single;
      expect(exchange.amount, closeTo(50, 0.001));
      expect(_event(app, 'Colegio').projectedLiquidBalanceUSD, closeTo(-30, 0.001), reason: 'faltarán \$30');
      expect(app.safeToSaveAmountUSD, closeTo(-30, 0.001));
    });

    test('un pago "USD a tasa BCV" desde la cuenta en Bs necesita Bs según la tasa', () async {
      final app = await _scenario(bs: 0, payments: [
        _once(id: 'col', name: 'Colegio', amount: 30, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 2),
      ]);
      final exchange = _exchanges(app).single;
      expect(exchange.amount, closeTo(30, 0.001));
      expect(exchange.exchangeAmountBs, closeTo(3000, 0.001));
      expect(_event(app, 'Colegio').amountUSD, closeTo(30, 0.001));
      expect(_event(app, 'Colegio').projectedBsBalance, closeTo(0, 0.001));
    });

    test('al registrar el cambio real, la sugerencia desaparece sola', () async {
      final app = await _scenario(bs: 0, payments: [
        _once(id: 'a', name: 'Condominio', amount: 50, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 2),
      ]);
      expect(_exchanges(app), hasLength(1));

      await app.exchangeCurrency(
        usdAccountId: 'usd',
        vesAccountId: 'bs',
        amountUSD: 50,
        exchangeRate: 100,
        isVenta: true,
        note: 'prueba',
      );
      expect(app.liquidBalanceBs, closeTo(5000, 0.001));
      expect(_exchanges(app), isEmpty);
    });

    test('los gastos en \$ no usan los Bs y los ingresos en \$ no tocan la caja Bs', () async {
      final app = await _scenario(payments: [
        _once(id: 'n', name: 'Netflix', amount: 10, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'usd', inDays: 1),
        _once(id: 's', name: 'Sueldo', amount: 1000, currency: CurrencyType.usd, type: TransactionType.income, accountId: 'usd', inDays: 2),
      ]);
      expect(_exchanges(app), isEmpty);
      expect(_event(app, 'Netflix').projectedLiquidBalanceUSD, closeTo(490, 0.001));
      expect(_event(app, 'Netflix').projectedBsBalance, closeTo(2000, 0.001));
      expect(_event(app, 'Sueldo').projectedLiquidBalanceUSD, closeTo(1490, 0.001));
    });

    test('el dinero disponible de hoy y el de la proyección usan la misma base (solo \$)', () async {
      final app = await _scenario(payments: [
        _once(id: 'n', name: 'Netflix', amount: 10, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'usd', inDays: 1),
      ]);
      expect(app.liquidBalanceUSD, closeTo(500, 0.001));
      expect(app.liquidBalanceBs, closeTo(2000, 0.001));
      expect(_event(app, 'Netflix').projectedLiquidBalanceUSD, closeTo(490, 0.001), reason: 'antes saltaba a 510 al sumar los Bs');
    });

    test('legado: un recurrente viejo en Bs sin cuenta usa la primera cuenta en Bs', () async {
      final app = await _scenario(bs: 0, payments: [
        RecurringPayment(
          id: 'x',
          name: 'Luz',
          amount: 1000,
          currency: CurrencyType.bsBCV,
          frequency: SubscriptionFrequency.once,
          startDate: _day(1),
          notificationOption: NotificationOption.none,
          icon: 'bolt',
          colorHex: '#2FA084',
          type: TransactionType.expense,
          totalInstallments: 1,
        ),
      ]);
      expect(_event(app, 'Luz').accountName, 'Banesco');
      expect(_exchanges(app).single.amount, closeTo(10, 0.001));
    });
  });

  group('Bolsillos con gastos en Bs', () {
    test('legado en Bs: la sugerencia de apartar se expresa en \$ y el pago sale del bolsillo', () async {
      final app = await _scenario(bs: 0, pockets: [
        SavingPocket(id: 'colegio', name: 'Colegio', currentAmountUSD: 0, targetAmountUSD: 0, icon: 'book', colorHex: '#2FA084'),
      ], payments: [
        _once(id: 'm', name: 'Mensualidad', amount: 10000, currency: CurrencyType.bsBCV, type: TransactionType.expense, accountId: 'bs', inDays: 3, pocketId: 'colegio'),
      ]);
      final apartar = app.getTimelineEvents(30).firstWhere((e) => e.isSuggestion && e.pocketId == 'colegio');
      expect(apartar.currency, CurrencyType.usd, reason: 'los bolsillos son en \$');
      expect(apartar.amount, closeTo(100, 0.001), reason: 'antes mostraba 10.000 y el botón Apartar los tomaba como \$');
      expect(apartar.amountUSD, closeTo(100, 0.001));

      final exchange = _exchanges(app).single;
      expect(exchange.amount, closeTo(100, 0.001));
      final pago = _event(app, 'Mensualidad');
      expect(pago.projectedLiquidBalanceUSD, closeTo(400, 0.001), reason: 'el dinero apartado sale del bolsillo, no del disponible');
    });
  });

  group('Formulario de recurrentes', () {
    Future<AppState> pumpForm(WidgetTester tester, {RecurringPayment? editing}) async {
      final app = await tester.runAsync(() => _scenario());
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app!,
        child: MaterialApp(home: Scaffold(body: AddRecurringPaymentBottomSheet(editingPayment: editing))),
      ));
      await tester.pump();
      return app;
    }

    testWidgets('con una cuenta en Bs solo ofrece montos anclados: USD o EUR a tasa BCV', (tester) async {
      await pumpForm(tester, editing: _once(id: 'c', name: 'Colegio', amount: 100, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 3));
      expect(find.byKey(const ValueKey('recurring_currency_usd')), findsOneWidget);
      expect(find.byKey(const ValueKey('recurring_currency_eur')), findsOneWidget);
      expect(find.byKey(const ValueKey('recurring_currency_bsBCV')), findsNothing, reason: 'no existe "Bs fijo"');
      expect(find.textContaining('se paga en Bs a la tasa BCV del día'), findsOneWidget);
    });

    testWidgets('un recurrente viejo guardado en Bs se abre convertido a \$ con la tasa BCV', (tester) async {
      await pumpForm(tester, editing: _once(id: 'c', name: 'Condominio', amount: 15000, currency: CurrencyType.bsBCV, type: TransactionType.expense, accountId: 'bs', inDays: 3));
      expect(find.widgetWithText(TextField, '150.00'), findsOneWidget, reason: 'Bs 15.000 a tasa 100 = \$150 (antes quedaba \$15.000)');
      expect(find.textContaining('lo pasamos a dólares con la tasa BCV de hoy'), findsOneWidget);
    });
  });

  group('Pantalla de proyección', () {
    testWidgets('el cambio sugerido se ve en la proyección y "Hacer cambio" abre el diálogo prellenado', (tester) async {
      final app = (await tester.runAsync(() => _scenario(bs: 0, payments: [
            _once(id: 'a', name: 'Condominio', amount: 50, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 2),
          ])))!;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final events = app.getTimelineEvents(30);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [for (final e in events) TimelineEventRow(event: e, isFirst: e == events.first, isLast: e == events.last)]),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Vender dólares para pagar en Bs'), findsOneWidget);
      expect(find.text('Para: Condominio'), findsOneWidget);
      expect(find.textContaining('Bs.'), findsWidgets, reason: 'el gasto muestra su monto en Bs');

      // Monedas a la vista: etiqueta "Bs" en el pago y "$ → Bs" en el cambio
      expect(find.byKey(const ValueKey('currency_pill_bsBCV')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_pill_usd_bsBCV')), findsOneWidget);
      expect(find.text('-Bs. 5000.00'), findsOneWidget, reason: 'el monto principal es en la moneda que se paga');
      expect(find.text('anclado a \$50.00 · tasa BCV'), findsOneWidget);
      expect(find.textContaining('Dinero libre'), findsWidgets);

      await tester.tap(find.text('Vender dólares para pagar en Bs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cambio sugerido ·'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('exchange_suggestion_do')));
      await tester.pumpAndSettle();
      expect(find.byType(AddExchangeBottomSheet), findsOneWidget);
      expect(find.widgetWithText(TextField, '50.00'), findsOneWidget, reason: 'monto prellenado');
      expect(find.widgetWithText(TextField, '100.00'), findsOneWidget, reason: 'tasa BCV prellenada');
      expect(find.widgetWithText(TextField, 'Cambio para: Condominio'), findsOneWidget);
    });
  });

  group('Montos por moneda de pago', () {
    test('un pago en \$ desde la cuenta en \$ se muestra en \$ sin línea extra', () async {
      final app = await _scenario(payments: [
        _once(id: 'n', name: 'Netflix', amount: 10, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'usd', inDays: 1),
      ]);
      final e = _event(app, 'Netflix');
      expect(paidCurrencyOf(e), CurrencyType.usd);
      final texts = projectionAmountTexts(e, app);
      expect(texts.primary, '-\$10.00');
      expect(texts.secondary, isNull);
    });

    test('un ingreso anclado a \$ que entra a la cuenta en Bs se muestra en Bs', () async {
      final app = await _scenario(payments: [
        _once(id: 's', name: 'Sueldo', amount: 80, currency: CurrencyType.usd, type: TransactionType.income, accountId: 'bs', inDays: 1),
      ]);
      final e = _event(app, 'Sueldo');
      expect(paidCurrencyOf(e), CurrencyType.bsBCV);
      final texts = projectionAmountTexts(e, app);
      expect(texts.primary, '+Bs. 8000.00');
      expect(texts.secondary, 'anclado a \$80.00 · tasa BCV');
    });

    test('las sugerencias de apartar se marcan en \$ (los bolsillos son en \$)', () async {
      final app = await _scenario(bs: 0, pockets: [
        SavingPocket(id: 'p', name: 'Colegio', currentAmountUSD: 0, targetAmountUSD: 0, icon: 'book', colorHex: '#2FA084'),
      ], payments: [
        _once(id: 'm', name: 'Mensualidad', amount: 100, currency: CurrencyType.usd, type: TransactionType.expense, accountId: 'bs', inDays: 3, pocketId: 'p'),
      ]);
      final apartar = app.getTimelineEvents(30).firstWhere((e) => e.isSuggestion);
      expect(paidCurrencyOf(apartar), CurrencyType.usd);
      expect(paidCurrencyOf(_event(app, 'Mensualidad')), CurrencyType.bsBCV);
    });
  });
}
