import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/finanzas_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction_category.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/helpers.dart' show formatDate;
import 'package:quebrado_app_flutter/services/supabase_service.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

/// AppState cuyo guardado de movimientos falla (error de guardado).
class _AddFails extends AppState {
  @override
  Future<void> addTransaction(Transaction transaction) async =>
      throw Exception('SocketException: sin red');
}

/// AppState que registra el movimiento del pago y luego falla al confirmar
/// (guardado compuesto a medias).
class _ConfirmFailsHalfway extends AppState {
  @override
  Future<bool> confirmRecurringPayment({
    required RecurringPayment payment,
    required double actualAmount,
    DateTime? occurrenceDate,
    CurrencyType? overrideCurrency,
    double? customExchangeRate,
    String? customNote,
    String? overrideAccountId,
    void Function(Transaction transaction)? onTransactionRecorded,
    DateTime? transactionDate,
  }) async {
    final tx = Transaction(
      id: 'tx_mitad_${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      amount: actualAmount,
      currency: payment.currency,
      accountId: overrideAccountId,
      note: 'Confirmado: ${payment.name}',
      type: payment.type,
      exchangeRate: bcvRate,
    );
    await addTransaction(tx);
    onTransactionRecorded?.call(tx);
    throw Exception('falló la confirmación');
  }
}

/// Servicio de Supabase falso para escribir en otro libro: anota lo que se
/// guarda (con su `profileId`) sin red.
class _FakeBookService extends SupabaseService {
  _FakeBookService() : super.forTesting();

  final inserted = <(String, Transaction)>[];
  final updatedAccounts = <(String?, double)>[];
  final deleted = <String>[];

  @override
  Future<void> insertTransaction(Transaction transaction, {String profileId = 'quebrado.db'}) async =>
      inserted.add((profileId, transaction));
  @override
  Future<void> updateAccount(Account account, {String? profileId}) async =>
      updatedAccounts.add((profileId, account.balance));
  @override
  Future<void> deleteTransaction(String id) async => deleted.add(id);
}

typedef _Escenario = ({
  AppState app,
  FinanzasWriteTools tools,
  Account banesco,
  TransactionCategory comida,
  String suffix,
});

void main() {
  setUp(() => AppState.debugLocalDbIsSourceOfTruth = false);
  tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

  final now = DateTime(2026, 9, 28, 12);
  WriteContext ctx(String userText, {bool untrusted = false}) =>
      WriteContext(userText: userText, untrustedRead: untrusted, now: () => now);

  /// Libro de prueba con datos inventados. La SQLite de tests es compartida
  /// (P-14): ids únicos y limpieza al final.
  Future<_Escenario> preparar({AppState? app, List<Account> extra = const []}) async {
    app ??= AppState();
    await app.loadData();
    app.debugSetRates(bcv: 200, euro: 220);
    final suffix = '${DateTime.now().microsecondsSinceEpoch}';
    Account cuenta(String id, String name, CurrencyType c, double balance) =>
        Account(id: '${id}_$suffix', name: name, currency: c, balance: balance, colorHex: '#2FA084', icon: 'creditcard');
    TransactionCategory cat(String id, String name, TransactionCategoryType t, {String? parentId}) =>
        TransactionCategory(id: '${id}_$suffix', name: name, icon: 'tag', colorHex: '#2FA084', type: t, parentId: parentId);

    final banesco = cuenta('acc_banesco', 'Banesco Bs', CurrencyType.bsBCV, 10000);
    final accounts = [banesco, ...extra];
    final comida = cat('cat_comida', 'Comida', TransactionCategoryType.expense);
    final categories = [
      comida,
      cat('cat_transporte', 'Transporte', TransactionCategoryType.expense),
      cat('cat_mascota', 'Veterinario', TransactionCategoryType.expense),
      cat('cat_cambio', 'Cambio de Divisa', TransactionCategoryType.expense),
      cat('cat_sueldo', 'Sueldo', TransactionCategoryType.income),
    ];
    for (final a in accounts) {
      await DatabaseHelper.instance.insertAccount(a);
    }
    for (final c in categories) {
      await DatabaseHelper.instance.insertCategory(c);
    }
    final ids = {for (final a in accounts) a.id};
    addTearDown(() async {
      for (final t in (await DatabaseHelper.instance.getTransactions()).where((t) => ids.contains(t.accountId))) {
        await DatabaseHelper.instance.deleteTransaction(t.id);
      }
      for (final t in app!.transactions.where((t) => ids.contains(t.accountId)).toList()) {
        await DatabaseHelper.instance.deleteTransaction(t.id);
      }
      for (final c in categories) {
        await DatabaseHelper.instance.deleteCategory(c.id);
      }
      for (final a in accounts) {
        await DatabaseHelper.instance.deleteAccount(a.id);
      }
    });
    app.accounts = accounts;
    app.categories = categories;
    app.applyRemoteSettings({AppState.defaultAccountSettingKey(app.activeDbName, CurrencyType.bsBCV): banesco.id});
    return (app: app, tools: FinanzasWriteTools(app), banesco: banesco, comida: comida, suffix: suffix);
  }

  const register = WriteToolNames.registerTransaction;
  const pay = WriteToolNames.payRecurringPayment;
  const frase = 'registra un gasto en bolívares de un cartón de huevos que le compré a mi novia';
  Map<String, dynamic> huevos({Object? amount}) => {
        'concept': 'Cartón de huevos para mi novia',
        'amount': ?amount,
        'type': 'expense',
        'currency': 'ves',
        'categoryName': 'Comida',
      };

  group('registerTransaction', () {
    test('CA-01: sin monto pregunta solo el monto, dice lo resuelto y no guarda nada', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(), ctx(frase));

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['amount']);
      expect(out.result.resolved, {'categoryName': 'Comida', 'accountName': 'Banesco Bs'});
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
      expect(e.banesco.balance, 10000);
    });

    test('CA-02 y CA-05: con «450» guarda el gasto en Comida y Banesco Bs hoy, y deshacer devuelve el saldo', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(amount: 450), ctx('$frase\n450'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      final tx = e.app.transactions.singleWhere((t) => t.id == out.result.recordId);
      expect(tx.type, TransactionType.expense);
      expect(tx.currency, CurrencyType.bsBCV);
      expect(tx.amount, 450);
      expect(tx.categoryId, e.comida.id);
      expect(tx.accountId, e.banesco.id);
      expect((tx.date.year, tx.date.month, tx.date.day), (2026, 9, 28));
      expect(tx.note, contains('huevos'));
      expect(tx.exchangeRate, 200);
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-').hasMatch(tx.id), isTrue, reason: 'uuid v4');
      expect(e.banesco.balance, closeTo(9550, 0.001));
      expect(out.result.summary, 'Cartón de huevos para mi novia · Bs. 450.00 · ≈ \$2.25 · Comida · Banesco Bs · hoy');
      expect(out.summaryTitle, 'Cartón de huevos para mi novia');
      expect(out.summaryParts.map((p) => p.kind.name), ['amount', 'amountSecondary', 'text', 'text', 'text']);
      expect(out.result.route, SuiteRoutes.movimiento(tx.id));
      expect(out.result.undoId, isNotNull);
      expect(out.profileId, e.app.activeDbName);

      await e.tools.undo(register, out.undoPayload!);

      expect(e.app.transactions.any((t) => t.id == tx.id), isFalse);
      expect(e.banesco.balance, closeTo(10000, 0.001));
    });

    test('deshacer en otro libro lanza con el mensaje para cambiar de libro', () async {
      final e = await preparar();
      final out = await e.tools.execute(register, huevos(amount: 450), ctx('450'));

      final payload = {...out.undoPayload!, 'profileId': 'otro_libro.db', 'profileName': 'Negocio'};

      await expectLater(
        e.tools.undo(register, payload),
        throwsA(isA<StateError>().having((s) => s.message, 'message', 'Cambia al libro Negocio para deshacerlo.')),
      );
      expect(e.app.transactions.any((t) => t.id == out.result.recordId), isTrue);
    });

    test('CA-03: sin predeterminada y con 2 cuentas en la moneda pregunta la cuenta y las lista', () async {
      final e = await preparar(extra: [
        Account(id: 'acc_usd_a_${DateTime.now().microsecondsSinceEpoch}', name: 'Zelle', currency: CurrencyType.usd, balance: 0, colorHex: '#2FA084', icon: 'creditcard'),
        Account(id: 'acc_usd_b_${DateTime.now().microsecondsSinceEpoch}', name: 'Efectivo \$', currency: CurrencyType.usd, balance: 0, colorHex: '#2FA084', icon: 'creditcard'),
      ]);

      final out = await e.tools.execute(register, {...huevos(amount: 20), 'currency': 'usd', 'concept': 'Gasolina', 'categoryName': 'Transporte'}, ctx('gasté 20 dólares en gasolina'));

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['accountName']);
      expect(out.result.options['accountName'], unorderedEquals(['Zelle', 'Efectivo \$']));
      expect(out.result.resolved['categoryName'], 'Transporte');
      expect(e.app.transactions.where((t) => t.note == 'Gasolina'), isEmpty);
    });

    test('PA-04: una sola cuenta en la moneda sin predeterminada sale como tarjeta', () async {
      final e = await preparar(extra: [
        Account(id: 'acc_eur_${DateTime.now().microsecondsSinceEpoch}', name: 'Revolut', currency: CurrencyType.eur, balance: 0, colorHex: '#2FA084', icon: 'creditcard'),
      ]);

      final out = await e.tools.execute(register, {...huevos(amount: 10), 'currency': 'eur'}, ctx('10 euros'));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['single_account_no_default']);
      expect(out.result.resolved['accountName'], 'Revolut');
      expect(out.commitArgs!['accountName'], 'Revolut');
      expect(out.summaryParts[1].text, '≈ \$11.00', reason: '€ → ≈ \$ con tasa euro / BCV');
      expect(e.app.transactions.where((t) => t.currency == CurrencyType.eur && t.note.contains('huevos')), isEmpty);
    });

    test('CA-04: categoría inexistente da tarjeta con 3 parecidas sin «Cambio de Divisa» y no guarda', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, {...huevos(amount: 450), 'categoryName': 'Mascotas'}, ctx('450'));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['category_not_found']);
      final opciones = out.result.options['categoryName']!;
      expect(opciones, hasLength(3));
      expect(opciones, isNot(contains('Cambio de Divisa')));
      expect(opciones, isNot(contains('Sueldo')), reason: 'solo las del tipo pedido');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
    });

    test('la tarjeta con duda de categoría trae en allOptions todas las del tipo, «Padre › Hija» y sin «Cambio de Divisa»', () async {
      final e = await preparar();
      // Subcategoría solo en memoria (la regla lee app.categories).
      e.app.categories = [
        ...e.app.categories,
        TransactionCategory(id: 'cat_sub_${e.suffix}', name: 'Mercado', icon: 'tag', colorHex: '#2FA084', type: TransactionCategoryType.expense, parentId: e.comida.id),
      ];

      final out = await e.tools.execute(register, {...huevos(amount: 450), 'categoryName': 'Mascotas'}, ctx('450'));

      expect(out.result.isProposal, isTrue);
      expect(out.allOptions.keys, ['categoryName']);
      expect(out.allOptions['categoryName'], ['Comida', 'Transporte', 'Veterinario', 'Comida › Mercado']);
      expect(out.result.toJson().containsKey('allOptions'), isFalse, reason: 'solo para la tarjeta, no para el modelo');
    });

    test('sin duda de categoría la tarjeta no trae allOptions', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(amount: 450), ctx('otro monto'));

      expect(out.result.isProposal, isTrue, reason: out.result.toString());
      expect(out.allOptions, isEmpty);
    });

    test('al confirmar sin elegir categoría sigue faltando; eligiendo una se guarda en ella', () async {
      final e = await preparar();
      final propuesta = await e.tools.execute(register, {...huevos(amount: 450), 'categoryName': 'Mascotas'}, ctx('450'));
      final confirmado = ctx('450').copyWith(confirmedByUser: true);

      final sinElegir = await e.tools.execute(register, propuesta.commitArgs!, confirmado);
      expect(sinElegir.result.isMissing, isTrue);
      expect(sinElegir.result.missing, ['categoryName']);
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);

      final eligiendo = await e.tools.execute(register, {...propuesta.commitArgs!, 'categoryName': 'Veterinario'}, confirmado);
      expect(eligiendo.result.isSaved, isTrue);
      final tx = e.app.transactions.singleWhere((t) => t.id == eligiendo.result.recordId);
      expect(tx.categoryId, 'cat_mascota_${e.suffix}');
    });

    test('un monto que no escribió la persona sale como tarjeta y se guarda al confirmar', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(amount: 100), ctx(frase));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['amount_not_in_user_text']);
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);

      final ok = await e.tools.execute(register, out.commitArgs!, ctx(frase).copyWith(confirmedByUser: true));
      expect(ok.result.isSaved, isTrue);
      expect(e.app.transactions.singleWhere((t) => t.id == ok.result.recordId).amount, 100);
    });

    test('con texto libre leído en el turno, todo resuelto igual sale como tarjeta', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(amount: 450), ctx('450', untrusted: true));

      expect(out.result.isProposal, isTrue);
      expect(out.result.reasons, ['read_untrusted_text']);
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
    });

    test('fecha inválida falta y fecha futura pide confirmar; ayer se resume como «ayer»', () async {
      final e = await preparar();

      final invalida = await e.tools.execute(register, {...huevos(amount: 450), 'date': '2026-02-30'}, ctx('450'));
      expect(invalida.result.missing, ['date']);

      final futura = await e.tools.execute(register, {...huevos(amount: 450), 'date': '2026-10-01'}, ctx('450'));
      expect(futura.result.reasons, ['future_date']);

      final ayer = await e.tools.execute(register, {...huevos(amount: 450), 'date': '2026-09-27'}, ctx('450'));
      expect(ayer.result.isSaved, isTrue);
      expect(ayer.summaryParts.last.text, 'ayer');
    });

    test('faltan varios datos a la vez y se piden todos', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, {'concept': 'Algo'}, ctx(''));

      expect(out.result.missing, ['amount', 'type', 'currency', 'categoryName']);
    });

    test('si falla el guardado responde error legible y no guarda nada', () async {
      final e = await preparar(app: _AddFails());

      final out = await e.tools.execute(register, huevos(amount: 450), ctx('450'));

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'No pude registrarlo: no hay conexión con la base de datos. No se guardó nada.');
      expect(out.undoPayload, isNull);
    });

    test('CA-11: sin Supabase el gasto queda en SQLite', () async {
      AppState.debugLocalDbIsSourceOfTruth = null;
      final e = await preparar();

      final out = await e.tools.execute(register, huevos(amount: 450), ctx('450'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      final guardados = await DatabaseHelper.instance.getTransactions();
      final tx = guardados.singleWhere((t) => t.id == out.result.recordId);
      expect(tx.amount, 450);
      expect(tx.accountId, e.banesco.id);
    });
  });

  group('payRecurringPayment', () {
    Future<(_Escenario, RecurringPayment)> conPago({AppState? app, int? totalInstallments}) async {
      final e = await preparar(app: app);
      final today = DateTime.now();
      final payment = RecurringPayment(
        id: 'pago_internet_${e.suffix}',
        name: 'Internet Cantv',
        amount: 1000,
        currency: CurrencyType.bsBCV,
        frequency: SubscriptionFrequency.monthly,
        startDate: DateTime(today.year, today.month, today.day),
        totalInstallments: totalInstallments,
        notificationOption: NotificationOption.none,
        icon: 'wifi',
        colorHex: '#2FA084',
        type: TransactionType.expense,
      );
      await DatabaseHelper.instance.insertRecurringPayment(payment);
      addTearDown(() async {
        for (final p in (await DatabaseHelper.instance.getAllPartials()).where((p) => p['recurring_payment_id'] == payment.id)) {
          await DatabaseHelper.instance.deletePartial(p['id'] as String);
        }
        final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await DatabaseHelper.instance.deleteConfirmation(payment.id, key);
        await DatabaseHelper.instance.deleteRecurringPayment(payment.id);
      });
      e.app.recurringPayments = [payment];
      return (e, payment);
    }

    WriteContext hoy(String text) => WriteContext(userText: text);

    test('CA-06: «ya pagué el internet» paga la ocurrencia en la predeterminada de su moneda y se deshace', () async {
      final (e, payment) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      expect(e.app.getConfirmedCountForPayment(payment.id), 1);
      final tx = e.app.transactions.singleWhere((t) => t.id == out.result.recordId);
      expect(tx.accountId, e.banesco.id);
      expect(tx.amount, 1000);
      expect(e.banesco.balance, closeTo(9000, 0.001));
      expect(out.result.summary, 'Internet Cantv · Bs. 1000.00 · Banesco Bs · hoy');
      expect(out.result.route, SuiteRoutes.movimiento(tx.id));

      await e.tools.undo(pay, out.undoPayload!);

      expect(e.app.getConfirmedCountForPayment(payment.id), 0);
      expect(e.app.transactions.any((t) => t.id == tx.id), isFalse);
      expect(e.banesco.balance, closeTo(10000, 0.001));
    });

    test('un monto menor que lo pendiente es un pago parcial y se deshace', () async {
      final (e, payment) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'Internet Cantv', 'amount': 400}, hoy('pagué 400 del internet'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      expect(out.result.summary, 'Internet Cantv · Bs. 400.00 · Banesco Bs · hoy · parcial, faltan Bs. 600.00');
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);
      final parcial = e.app.partialPayments.singleWhere((p) => p.recurringPaymentId == payment.id);
      expect(parcial.amount, 400);
      expect(e.banesco.balance, closeTo(9600, 0.001));

      await e.tools.undo(pay, out.undoPayload!);

      expect(e.app.partialPayments.where((p) => p.recurringPaymentId == payment.id), isEmpty);
      expect(e.app.transactions.any((t) => t.id == out.result.recordId), isFalse);
      expect(e.banesco.balance, closeTo(10000, 0.001));
    });

    test('sin cuota pendiente responde error con la fecha de la próxima cuota, sin tarjeta y sin guardar', () async {
      final (e, payment) = await conPago();
      final primero = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));
      expect(primero.result.isSaved, isTrue, reason: primero.result.toString());

      final out = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));

      final t = DateTime.now();
      expect(out.result.isError, isTrue, reason: out.result.toString());
      expect(out.result.message, 'Internet Cantv ya está pagado hasta el ${formatDate(DateTime(t.year, t.month + 1, t.day))}. No registré nada.');
      expect(out.commitArgs, isNull);
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), hasLength(1));
      expect(e.app.getConfirmedCountForPayment(payment.id), 1);
      expect(e.banesco.balance, closeTo(9000, 0.001));
    });

    test('sin cuotas por pagar (la última ya está pagada) lo dice y no guarda nada', () async {
      final (e, _) = await conPago(totalInstallments: 1);
      final primero = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));
      expect(primero.result.isSaved, isTrue, reason: primero.result.toString());

      final out = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'Internet Cantv no tiene cuotas pendientes. No registré nada.');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), hasLength(1));
    });

    test('un monto mayor que lo pendiente sale como tarjeta y al confirmar guarda ese monto con la cuota pagada', () async {
      final (e, payment) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'internet', 'amount': 1500}, hoy('pagué 1500 del internet'));

      expect(out.result.isProposal, isTrue, reason: out.result.toString());
      expect(out.result.reasons, ['amount_above_due']);
      expect(out.result.summary, 'Internet Cantv · Pagar Bs. 1500.00 (la cuota es Bs. 1000.00) · Banesco Bs · hoy');
      expect(out.summaryParts.first.text, 'Pagar Bs. 1500.00 (la cuota es Bs. 1000.00)');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);

      final ok = await e.tools.execute(pay, out.commitArgs!, hoy('pagué 1500 del internet').copyWith(confirmedByUser: true));

      expect(ok.result.isSaved, isTrue, reason: ok.result.toString());
      expect(e.app.transactions.singleWhere((t) => t.id == ok.result.recordId).amount, 1500);
      expect(e.app.getConfirmedCountForPayment(payment.id), 1);
      expect(e.app.partialPayments.where((p) => p.recurringPaymentId == payment.id), isEmpty);
      expect(e.banesco.balance, closeTo(8500, 0.001));
    });

    test('«ya pagué el internet ayer» fecha el movimiento ayer', () async {
      final (e, payment) = await conPago();
      final t = DateTime.now();
      final ayer = DateTime(t.year, t.month, t.day - 1);

      final out = await e.tools.execute(pay, {'paymentName': 'internet', 'date': _iso(ayer)}, hoy('ya pagué el internet ayer'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      expect(out.result.summary, 'Internet Cantv · Bs. 1000.00 · Banesco Bs · ayer');
      expect(_iso(e.app.transactions.singleWhere((t) => t.id == out.result.recordId).date), _iso(ayer));
      expect(e.app.getConfirmedCountForPayment(payment.id), 1);
    });

    test('un pago parcial de ayer fecha el movimiento ayer', () async {
      final (e, payment) = await conPago();
      final t = DateTime.now();
      final ayer = DateTime(t.year, t.month, t.day - 1);

      final out = await e.tools.execute(pay, {'paymentName': 'internet', 'amount': 400, 'date': _iso(ayer)}, hoy('pagué 400 del internet ayer'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      expect(_iso(e.app.transactions.singleWhere((t) => t.id == out.result.recordId).date), _iso(ayer));
      expect(e.app.partialPayments.singleWhere((p) => p.recurringPaymentId == payment.id).amount, 400);
    });

    test('un pago que no existe responde error con los pagos que hay', () async {
      final (e, _) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'gimnasio'}, hoy('ya pagué el gimnasio'));

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'No pude registrarlo: no encontré el pago «gimnasio»; tus pagos son: Internet Cantv. No se guardó nada.');
    });

    test('si la confirmación falla a mitad, deshace el movimiento y responde error', () async {
      final (e, payment) = await conPago(app: _ConfirmFailsHalfway());

      final out = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('ya pagué el internet'));

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'No pude registrarlo: falló el guardado. No se guardó nada.');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
      expect(e.banesco.balance, closeTo(10000, 0.001));
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);
    });

    test('S3-02: un pago que la persona no nombró sale como tarjeta y no guarda nada', () async {
      final (e, payment) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'Internet Cantv'}, hoy('hola'));

      expect(out.result.isProposal, isTrue, reason: out.result.toString());
      expect(out.result.reasons, [FinanzasReason.nameNotInUserText]);
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);

      final ok = await e.tools.execute(pay, out.commitArgs!, hoy('hola').copyWith(confirmedByUser: true));
      expect(ok.result.isSaved, isTrue, reason: ok.result.toString());
      expect(e.app.getConfirmedCountForPayment(payment.id), 1);
    });

    test('S3-09: el término del modelo no ancla («Internet Cantv hola» con «hola»)', () async {
      final (e, payment) = await conPago();

      final out = await e.tools.execute(pay, {'paymentName': 'Internet Cantv hola'}, hoy('hola'));

      expect(out.result.isProposal, isTrue, reason: out.result.toString());
      expect(out.result.reasons, contains(FinanzasReason.nameNotInUserText));
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);
    });

    test('S3-05: la tarjeta lleva libro, pago y cuenta; confirmada en otro libro da error', () async {
      final (e, payment) = await conPago();
      final out = await e.tools.execute(pay, {'paymentName': 'internet'}, hoy('hola'));

      expect(out.commitArgs, containsPair('paymentId', payment.id));
      expect(out.commitArgs, containsPair('accountId', e.banesco.id));
      expect(out.commitArgs, containsPair('profileId', e.app.activeDbName));

      final otroLibro = {...out.commitArgs!, 'profileId': 'otro_libro.db', 'profileName': 'Negocio'};
      final err = await e.tools.execute(pay, otroLibro, hoy('hola').copyWith(confirmedByUser: true));

      expect(err.result.isError, isTrue);
      expect(err.result.message, 'Cambia al libro Negocio para confirmarlo.');
      expect(e.app.getConfirmedCountForPayment(payment.id), 0);
    });
  });

  group('registerTransaction en otro libro (bookName)', () {
    /// Escenario con un segundo libro «Libro B» (datos inventados) que tiene
    /// una cuenta USDT y una categoría «Gasto» que no existe en el activo.
    Future<(_Escenario, String, Account, _FakeBookService?)> conOtroLibro({bool conSupabase = true}) async {
      final e = await preparar();
      final bookId = 'libro_b_${e.suffix}.db';
      final usdt = Account(id: 'acc_usdt_${e.suffix}', name: 'USDT', currency: CurrencyType.usd, balance: 100, colorHex: '#2FA084', icon: 'creditcard');
      final gasto = TransactionCategory(id: 'cat_gasto_${e.suffix}', name: 'Gasto', icon: 'tag', colorHex: '#2FA084', type: TransactionCategoryType.expense);
      e.app.debugSeedBook(bookId, name: 'Libro B', accounts: [usdt], categories: [gasto]);
      final service = conSupabase ? _FakeBookService() : null;
      e.app.debugOtherBookService = service;
      return (e, bookId, usdt, service);
    }

    const fraseB = 'registra un gasto en la contabilidad del libro b de 35\$ en la cuenta usdt';
    Map<String, dynamic> gastoB({String bookName = 'Libro B'}) => {
          'concept': 'Compra de prueba',
          'amount': 35,
          'type': 'expense',
          'currency': 'usd',
          'categoryName': 'Gasto',
          'accountName': 'USDT',
          'bookName': bookName,
        };

    test('un libro que no es el abierto sale como tarjeta other_book con su categoría y cuenta', () async {
      final (e, bookId, usdt, service) = await conOtroLibro();
      final activo = e.app.activeDbName;

      final out = await e.tools.execute(register, gastoB(), ctx(fraseB));

      expect(out.result.isProposal, isTrue, reason: out.result.toString());
      expect(out.result.reasons, ['other_book']);
      expect(out.result.resolved, containsPair('bookName', 'Libro B'));
      expect(out.result.resolved, containsPair('categoryName', 'Gasto'), reason: '«Gasto» solo existe en el libro B');
      expect(out.result.resolved, containsPair('accountName', 'USDT'));
      expect(out.commitArgs, containsPair('profileId', bookId));
      expect(out.commitArgs, containsPair('profileName', 'Libro B'));
      expect(out.commitArgs, containsPair('accountId', usdt.id));
      expect(out.profileId, bookId);
      expect(service!.inserted, isEmpty);
      expect(usdt.balance, 100);
      expect(e.app.activeDbName, activo);
    });

    test('confirmar guarda en ese libro, cambia el saldo de su cuenta y deshacer lo revierte allí', () async {
      final (e, bookId, usdt, service) = await conOtroLibro();
      final activo = e.app.activeDbName;
      final antesActivo = e.app.transactions.length;
      final out = await e.tools.execute(register, gastoB(), ctx(fraseB));

      final ok = await e.tools.execute(register, out.commitArgs!, ctx(fraseB).copyWith(confirmedByUser: true));

      expect(ok.result.isSaved, isTrue, reason: ok.result.toString());
      final (savedIn, tx) = service!.inserted.single;
      expect(savedIn, bookId);
      expect(tx.id, ok.result.recordId);
      expect(tx.amount, 35);
      expect(tx.categoryId, 'cat_gasto_${e.suffix}');
      expect(tx.accountId, usdt.id);
      expect(usdt.balance, closeTo(65, 0.001));
      expect(service.updatedAccounts.single, (bookId, 65.0));
      expect(e.app.getTransactionsForProfile(bookId).map((t) => t.id), [tx.id]);
      expect(e.app.activeDbName, activo, reason: 'no cambia el libro abierto');
      expect(e.app.transactions.length, antesActivo);
      expect(e.app.transactions.any((t) => t.id == tx.id), isFalse);
      expect(ok.profileId, bookId);
      expect(ok.undoPayload, containsPair('profileId', bookId));
      expect(ok.undoPayload, containsPair('profileName', 'Libro B'));

      await e.tools.undo(register, ok.undoPayload!);

      expect(service.deleted, [tx.id]);
      expect(usdt.balance, closeTo(100, 0.001));
      expect(e.app.getTransactionsForProfile(bookId), isEmpty);
      expect(e.app.activeDbName, activo);
    });

    test('sin cuenta nombrada usa la predeterminada de ese libro', () async {
      final (e, bookId, usdt, _) = await conOtroLibro();
      e.app.applyRemoteSettings({AppState.defaultAccountSettingKey(bookId, CurrencyType.usd): usdt.id});

      final out = await e.tools.execute(register, {...gastoB()}..remove('accountName'), ctx(fraseB));

      expect(out.result.reasons, ['other_book']);
      expect(out.commitArgs, containsPair('accountId', usdt.id));
    });

    test('nombrar el libro abierto registra directo como siempre', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, {...huevos(amount: 450), 'bookName': e.app.activeProfileName}, ctx('450'));

      expect(out.result.isSaved, isTrue, reason: out.result.toString());
      expect(out.profileId, e.app.activeDbName);
      expect(e.banesco.balance, closeTo(9550, 0.001));
    });

    test('un nombre de libro ambiguo pregunta el libro con las opciones', () async {
      final (e, _, _, service) = await conOtroLibro();
      e.app.debugSeedBook('libro_c1_${e.suffix}.db', name: 'Prueba Casa');
      e.app.debugSeedBook('libro_c2_${e.suffix}.db', name: 'Prueba Oficina');

      final out = await e.tools.execute(register, gastoB(bookName: 'prueba'), ctx(fraseB));

      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['bookName']);
      expect(out.result.options['bookName'], unorderedEquals(['Prueba Casa', 'Prueba Oficina']));
      expect(service!.inserted, isEmpty);
    });

    test('un libro que no existe da error con la lista de libros', () async {
      final (e, _, _, service) = await conOtroLibro();

      final out = await e.tools.execute(register, gastoB(bookName: 'Zzz inexistente'), ctx(fraseB));

      expect(out.result.isError, isTrue);
      expect(out.result.message, startsWith('No pude registrarlo: no encontré el libro «Zzz inexistente»; tus libros son: '));
      expect(out.result.message, contains('Libro B'));
      expect(out.result.message, endsWith('. No se guardó nada.'));
      expect(service!.inserted, isEmpty);
    });

    test('sin Supabase no escribe en otro libro y pide abrirlo', () async {
      final (e, _, usdt, _) = await conOtroLibro(conSupabase: false);

      final out = await e.tools.execute(register, gastoB(), ctx(fraseB));

      expect(out.result.isError, isTrue);
      expect(out.result.message, 'Para registrar en el libro Libro B, ábrelo primero en Finanzas. No se guardó nada.');
      expect(usdt.balance, 100);
    });
  });

  group('tarjeta confirmada (S3-05) y tasa', () {
    test('al confirmar usa la cuenta por su id aunque otra cuenta tenga el mismo nombre', () async {
      final e = await preparar();
      final out = await e.tools.execute(register, huevos(amount: 100), ctx(frase));
      expect(out.commitArgs, containsPair('accountId', e.banesco.id));
      expect(out.commitArgs, containsPair('profileId', e.app.activeDbName));
      final gemela = Account(id: 'acc_gemela_${e.suffix}', name: 'Banesco Bs', currency: CurrencyType.bsBCV, balance: 0, colorHex: '#2FA084', icon: 'creditcard');
      e.app.accounts = [gemela, ...e.app.accounts];

      final ok = await e.tools.execute(register, out.commitArgs!, ctx(frase).copyWith(confirmedByUser: true));

      expect(ok.result.isSaved, isTrue, reason: ok.result.toString());
      expect(e.app.transactions.singleWhere((t) => t.id == ok.result.recordId).accountId, e.banesco.id);
    });

    test('S3-05: una tarjeta creada con otro libro abierto (sin bookName) no se confirma aquí', () async {
      final e = await preparar();
      final out = await e.tools.execute(register, huevos(amount: 100), ctx(frase));
      expect(out.commitArgs!.containsKey('otherBook'), isFalse);

      final err = await e.tools.execute(
          register, {...out.commitArgs!, 'profileId': 'otro_libro.db', 'profileName': 'Negocio'}, ctx(frase).copyWith(confirmedByUser: true));

      expect(err.result.isError, isTrue);
      expect(err.result.message, 'Cambia al libro Negocio para confirmarlo.');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
    });

    test('confirmar una tarjeta de otro libro (bookName) que ya no existe da error y no guarda', () async {
      final e = await preparar();
      final out = await e.tools.execute(register, huevos(amount: 100), ctx(frase));

      final err = await e.tools.execute(
        register,
        {...out.commitArgs!, 'profileId': 'otro_libro.db', 'profileName': 'Negocio', 'otherBook': true},
        ctx(frase).copyWith(confirmedByUser: true),
      );

      expect(err.result.isError, isTrue);
      expect(err.result.message, 'No pude registrarlo: no encontré el libro Negocio. No se guardó nada.');
      expect(e.app.transactions.where((t) => t.accountId == e.banesco.id), isEmpty);
    });

    test('un gasto en Bs confirmado hacia una cuenta en EUR usa la tasa euro y el saldo cuadra', () async {
      final e = await preparar(extra: [
        Account(id: 'acc_eur_tasa_${DateTime.now().microsecondsSinceEpoch}', name: 'Revolut', currency: CurrencyType.eur, balance: 100, colorHex: '#2FA084', icon: 'creditcard'),
      ]);
      final revolut = e.app.accounts.singleWhere((a) => a.name == 'Revolut');

      final out = await e.tools.execute(register, {...huevos(amount: 440), 'accountName': 'Revolut'}, ctx('440'));
      expect(out.result.reasons, ['account_currency_mismatch']);
      expect(out.result.resolved['accountCurrency'], 'eur', reason: 'la tarjeta dice la moneda de la cuenta sin buscarla');
      final ok = await e.tools.execute(register, out.commitArgs!, ctx('440').copyWith(confirmedByUser: true));

      expect(ok.result.isSaved, isTrue, reason: ok.result.toString());
      expect(e.app.transactions.singleWhere((t) => t.id == ok.result.recordId).exchangeRate, 220);
      expect(revolut.balance, closeTo(98, 0.001), reason: 'Bs. 440 / 220 = € 2');
    });

    test('una cuenta que contiene el nombre pedido guarda el nombre pedido para la tarjeta', () async {
      final e = await preparar();

      final out = await e.tools.execute(register, {...huevos(amount: 450), 'accountName': 'banesco'}, ctx('450'));

      expect(out.result.reasons, ['account_contains_match']);
      expect(out.result.resolved['requestedAccountName'], 'banesco');
      expect(out.result.resolved['accountName'], 'Banesco Bs');
      expect(out.result.resolved.containsKey('accountCurrency'), isFalse, reason: 'solo con account_currency_mismatch');
    });
  });
}

String _iso(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
