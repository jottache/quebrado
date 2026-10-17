import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/saving_pocket.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Future<AppState> _buildState({required SavingPocket pocket, required RecurringPayment income}) async {
  final app = AppState();
  // Esperar a que termine la carga inicial (si no, puede pisar los datos del escenario)
  await app.loadData();
  app.accounts = [
    Account(id: 'usd', name: 'Efectivo', currency: CurrencyType.usd, balance: 5000, colorHex: '#2FA084', icon: 'creditcard'),
  ];
  app.pockets = [pocket];
  app.recurringPayments
    ..clear()
    ..add(income);
  app.transactions = [];
  app.notifyListeners();
  return app;
}

List<double> _suggestionsOn(AppState app, String pocketId, DateTime day) => app
    .getTimelineEvents(45)
    .where((e) => e.isSuggestion && e.pocketId == pocketId && _sameDay(e.date, day))
    .map((e) => e.amount)
    .toList();

void main() {
  setUp(() async {
    AppState.debugLocalDbIsSourceOfTruth = false;
    // Las marcas se guardan en la SQLite de pruebas: empezar cada test sin marcas previas
    await DatabaseHelper.instance.setSetting(AppState.fulfilledSuggestionsSettingKey, '[]');
  });
  tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

  test('meta con fecha: tras abonar la sugerencia de hoy no reaparece a la mitad', () async {
    final today = _today();
    final app = await _buildState(
      pocket: SavingPocket(
        id: 'viaje',
        name: 'Viaje',
        currentAmountUSD: 0,
        targetAmountUSD: 200,
        targetDate: today.add(const Duration(days: 20)),
        colorHex: '#2FA084',
        icon: 'briefcase',
      ),
      income: RecurringPayment(
        id: 'sueldo',
        name: 'Sueldo',
        amount: 1000,
        currency: CurrencyType.usd,
        frequency: SubscriptionFrequency.biweekly,
        startDate: today, // cobros hoy y en 14 días
        notificationOption: NotificationOption.none,
        icon: 'briefcase',
        colorHex: '#2FA084',
        type: TransactionType.income,
        accountId: 'usd',
      ),
    );

    final before = _suggestionsOn(app, 'viaje', today);
    expect(before, [closeTo(100, 0.001)], reason: '200 repartido en 2 cobros');

    final ok = await app.fulfillPocketSuggestion(date: today, pocketId: 'viaje', amountUSD: before.single);
    expect(ok, isTrue);
    expect(app.pockets.single.currentAmountUSD, closeTo(100, 0.001));
    expect(app.isPocketSuggestionFulfilled(today, 'viaje'), isTrue);

    expect(_suggestionsOn(app, 'viaje', today), isEmpty, reason: 'antes volvía a sugerir 50, luego 25…');
    final next = _suggestionsOn(app, 'viaje', today.add(const Duration(days: 14)));
    expect(next, [closeTo(100, 0.001)], reason: 'lo que falta (100) pasa completo al siguiente cobro');
  });

  test('regla de ahorro sin fecha: tras abonar, la sugerencia de ese ingreso no se repite', () async {
    final today = _today();
    final app = await _buildState(
      pocket: SavingPocket(
        id: 'fondo',
        name: 'Fondo',
        currentAmountUSD: 0,
        targetAmountUSD: 0,
        targetDate: null,
        fundingRuleType: 'percentage',
        fundingRuleValue: 10,
        colorHex: '#2FA084',
        icon: 'savings',
      ),
      income: RecurringPayment(
        id: 'sueldo',
        name: 'Sueldo',
        amount: 500,
        currency: CurrencyType.usd,
        frequency: SubscriptionFrequency.monthly,
        startDate: today,
        notificationOption: NotificationOption.none,
        icon: 'briefcase',
        colorHex: '#2FA084',
        type: TransactionType.income,
        accountId: 'usd',
      ),
    );

    final before = _suggestionsOn(app, 'fondo', today);
    expect(before, [closeTo(50, 0.001)]);

    expect(await app.fulfillPocketSuggestion(date: today, pocketId: 'fondo', amountUSD: 50), isTrue);
    expect(_suggestionsOn(app, 'fondo', today), isEmpty);
  });

  test('si no hay saldo líquido el abono no se hace y la sugerencia sigue visible', () async {
    final today = _today();
    final app = await _buildState(
      pocket: SavingPocket(
        id: 'viaje_sin_saldo',
        name: 'Viaje',
        currentAmountUSD: 0,
        targetAmountUSD: 200,
        targetDate: today.add(const Duration(days: 20)),
        colorHex: '#2FA084',
        icon: 'briefcase',
      ),
      income: RecurringPayment(
        id: 'sueldo',
        name: 'Sueldo',
        amount: 1000,
        currency: CurrencyType.usd,
        frequency: SubscriptionFrequency.biweekly,
        startDate: today,
        notificationOption: NotificationOption.none,
        icon: 'briefcase',
        colorHex: '#2FA084',
        type: TransactionType.income,
        accountId: 'usd',
      ),
    );
    app.accounts.single.balance = 0;
    app.notifyListeners();

    final r = await app.fulfillPocketSuggestion(date: today, pocketId: 'viaje_sin_saldo', amountUSD: 100);
    expect(r, isFalse);
    expect(app.pockets.single.currentAmountUSD, 0);
    expect(app.isPocketSuggestionFulfilled(today, 'viaje_sin_saldo'), isFalse);
    expect(_suggestionsOn(app, 'viaje_sin_saldo', today), isNotEmpty, reason: 'la sugerencia sigue disponible');
  });

  group('reparto de la meta desde la creación del bolsillo', () {
    RecurringPayment biweeklyIncome(DateTime start) => RecurringPayment(
          id: 'quincena',
          name: 'Quincena',
          amount: 1000,
          currency: CurrencyType.usd,
          frequency: SubscriptionFrequency.biweekly,
          startDate: start,
          notificationOption: NotificationOption.none,
          icon: 'briefcase',
          colorHex: '#2FA084',
          type: TransactionType.income,
          accountId: 'usd',
        );

    SavingPocket goalPocket(String id, {double current = 0}) {
      final today = _today();
      return SavingPocket(
        id: id,
        name: 'Tatuaje',
        currentAmountUSD: current,
        targetAmountUSD: 200,
        targetDate: today.add(const Duration(days: 10)),
        createdAt: today.subtract(const Duration(days: 10)),
        colorHex: '#2FA084',
        icon: 'briefcase',
      );
    }

    test('un cobro que pasó sin apartar no se acumula en el último: se sugiere hoy como atrasado', () async {
      final today = _today();
      // Cobros: hace 7 días (pasado) y en 7 días (futuro), ambos antes de la fecha meta
      final app = await _buildState(pocket: goalPocket('tatuaje_a'), income: biweeklyIncome(today.subtract(const Duration(days: 7))));

      expect(_suggestionsOn(app, 'tatuaje_a', today), [closeTo(100, 0.001)], reason: 'parte del cobro pasado');
      expect(_suggestionsOn(app, 'tatuaje_a', today.add(const Duration(days: 7))), [closeTo(100, 0.001)],
          reason: 'antes salían los 200 completos en el último cobro');
      final todayEvent = app.getTimelineEvents(45).firstWhere((e) => e.isSuggestion && e.pocketId == 'tatuaje_a' && _sameDay(e.date, today));
      expect(todayEvent.suggestionReasons!.map((r) => r.name).join(' '), contains('Atrasado'));
    });

    test('si ya se apartó directo lo del cobro pasado, no hay atrasado', () async {
      final today = _today();
      final app = await _buildState(pocket: goalPocket('tatuaje_b', current: 100), income: biweeklyIncome(today.subtract(const Duration(days: 7))));

      expect(_suggestionsOn(app, 'tatuaje_b', today), isEmpty);
      expect(_suggestionsOn(app, 'tatuaje_b', today.add(const Duration(days: 7))), [closeTo(100, 0.001)]);
    });

    test('abonar el atrasado de hoy lo quita y el siguiente cobro mantiene su parte', () async {
      final today = _today();
      final app = await _buildState(pocket: goalPocket('tatuaje_c'), income: biweeklyIncome(today.subtract(const Duration(days: 7))));

      expect(await app.fulfillPocketSuggestion(date: today, pocketId: 'tatuaje_c', amountUSD: 100), isTrue);
      expect(_suggestionsOn(app, 'tatuaje_c', today), isEmpty);
      expect(_suggestionsOn(app, 'tatuaje_c', today.add(const Duration(days: 7))), [closeTo(100, 0.001)]);
    });

    test('un bolsillo sin fecha de creación (como el del simulador) reparte desde hoy como antes', () async {
      final today = _today();
      final pocket = SavingPocket(
        id: 'b6f1c2a0-uuid-simulado',
        name: 'Simulado',
        currentAmountUSD: 0,
        targetAmountUSD: 200,
        targetDate: today.add(const Duration(days: 10)),
        colorHex: '#2FA084',
        icon: 'star',
      );
      final app = await _buildState(pocket: pocket, income: biweeklyIncome(today.subtract(const Duration(days: 7))));

      expect(_suggestionsOn(app, pocket.id, today), isEmpty);
      expect(_suggestionsOn(app, pocket.id, today.add(const Duration(days: 7))), [closeTo(200, 0.001)]);
    });
  });
}
