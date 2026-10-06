import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/saving_pocket.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';

Account _acc(String id, double balance, {CurrencyType currency = CurrencyType.usd}) => Account(
      id: id,
      name: id,
      currency: currency,
      balance: balance,
      colorHex: '#2FA084',
      icon: 'creditcard',
    );

Transaction _tx(String id, double amount, TransactionType type, {String? accountId, String? pocketId}) => Transaction(
      id: id,
      date: DateTime(2026, 10, 1),
      amount: amount,
      currency: CurrencyType.usd,
      accountId: accountId,
      destinationPocketId: pocketId,
      note: 'Movimiento $id',
      type: type,
      exchangeRate: 1.0,
    );

void main() {
  // Simula la app en web con Supabase: la base SQLite local no tiene los datos.
  setUp(() => AppState.debugLocalDbIsSourceOfTruth = false);
  tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

  test('editar el monto de un gasto ajusta el saldo y conserva el resto de los datos', () async {
    final app = AppState();
    final cash = _acc('cash', 70); // 100 - 30
    final bank = _acc('bank', 500);
    app.accounts = [cash, bank];
    final expense = _tx('g1', 30, TransactionType.expense, accountId: 'cash');
    final other = _tx('i1', 200, TransactionType.income, accountId: 'bank');
    app.transactions = [expense, other];

    final edited = _tx('g1', 45, TransactionType.expense, accountId: 'cash');
    await app.updateTransaction(expense, edited);

    expect(cash.balance, 55, reason: '100 - 45');
    expect(bank.balance, 500, reason: 'la otra cuenta no cambia');
    expect(app.accounts.map((a) => a.id), ['cash', 'bank'], reason: 'antes se recargaba desde SQLite y quedaba vacío');
    expect(app.transactions.length, 2);
    expect(app.transactions.firstWhere((t) => t.id == 'g1').amount, 45);
    expect(app.transactions.any((t) => t.id == 'i1'), isTrue);
  });

  test('cambiar un gasto a ingreso invierte su efecto', () async {
    final app = AppState();
    final cash = _acc('cash', 70); // 100 - 30
    app.accounts = [cash];
    final expense = _tx('g1', 30, TransactionType.expense, accountId: 'cash');
    app.transactions = [expense];

    await app.updateTransaction(expense, _tx('g1', 30, TransactionType.income, accountId: 'cash'));

    expect(cash.balance, 130, reason: '100 + 30');
    expect(app.transactions.single.type, TransactionType.income);
  });

  test('mover un ingreso a otra cuenta revierte la original y aplica en la nueva', () async {
    final app = AppState();
    final cash = _acc('cash', 150); // 100 + 50
    final bank = _acc('bank', 20);
    app.accounts = [cash, bank];
    final income = _tx('i1', 50, TransactionType.income, accountId: 'cash');
    app.transactions = [income];

    await app.updateTransaction(income, _tx('i1', 50, TransactionType.income, accountId: 'bank'));

    expect(cash.balance, 100);
    expect(bank.balance, 70);
    expect(app.transactions.single.accountId, 'bank');
  });

  test('editar un movimiento de bolsillo ajusta el saldo del bolsillo', () async {
    final app = AppState();
    final pocket = SavingPocket(
      id: 'p1',
      name: 'Viaje',
      targetAmountUSD: 500,
      currentAmountUSD: 125, // 100 + 25
      colorHex: '#2FA084',
      icon: 'briefcase',
    );
    app.pockets = [pocket];
    final deposit = _tx('p_in', 25, TransactionType.income, pocketId: 'p1');
    app.transactions = [deposit];

    await app.updateTransaction(deposit, _tx('p_in', 40, TransactionType.income, pocketId: 'p1'));

    expect(pocket.currentAmountUSD, 140, reason: '100 + 40');
    expect(app.pockets.single.id, 'p1');
  });

  test('depositar y retirar de un bolsillo no vacía la lista de bolsillos', () async {
    final app = AppState();
    final cash = _acc('cash', 1000);
    app.accounts = [cash];
    final pocket = SavingPocket(
      id: 'p1',
      name: 'Ahorro',
      targetAmountUSD: 500,
      currentAmountUSD: 100,
      colorHex: '#2FA084',
      icon: 'briefcase',
    );
    app.pockets = [pocket];

    await app.depositToPocket(id: 'p1', amountUSD: 50);
    expect(app.pockets.single.currentAmountUSD, 150);

    await app.withdrawFromPocket(id: 'p1', amountUSD: 30);
    expect(app.pockets.single.currentAmountUSD, 120);
  });

  test('un cambio de divisa agrega sus dos movimientos sin recargar desde SQLite', () async {
    final app = AppState();
    final usd = _acc('usd', 100);
    final ves = _acc('ves', 0, currency: CurrencyType.bsBCV);
    app.accounts = [usd, ves];
    app.transactions = [_tx('previo', 10, TransactionType.expense, accountId: 'usd')];

    await app.exchangeCurrency(
      usdAccountId: 'usd',
      vesAccountId: 'ves',
      amountUSD: 10,
      exchangeRate: 40,
      isVenta: true,
      note: '',
    );

    expect(usd.balance, 90);
    expect(ves.balance, 400);
    expect(app.accounts.length, 2);
    expect(app.transactions.length, 3);
    expect(app.transactions.where((t) => t.id.contains('_usd_exp') || t.id.contains('_ves_inc')).length, 2);
  });
}
