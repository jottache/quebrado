/// Ejecutor de las herramientas de escritura de Finanzas (spec 03,
/// `docs/design/ortiz-registra.md` §2.2, §3 y U2.1): `registerTransaction` y
/// `payRecurringPayment`.
///
/// Escribe solo a través de [AppState] (Supabase o SQLite según el modo).
/// `payRecurringPayment` escribe solo en el libro activo; `registerTransaction`
/// también en otro libro nombrado (`bookName`), siempre con tarjeta y sin
/// cambiar el libro abierto (solo con Supabase).
library;

import 'package:uuid/uuid.dart';

import '../../../quebrado/models/currency_type.dart';
import '../../../quebrado/models/recurring_payment.dart';
import '../../../quebrado/models/recurring_payment_partial.dart';
import '../../../quebrado/models/transaction.dart';
import '../../../quebrado/models/transaction_category.dart';
import '../../../quebrado/viewmodels/app_state.dart';
import '../../../quebrado/widgets/helpers.dart'
    show formatBs, formatCurrency, formatDate, formatUSD;
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'ortiz_resolver.dart';
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

/// Motivos (`reasons`) propios de Finanzas, además de los de [ResolverReason]
/// y los de [WriteContext.forcedProposalReasons].
abstract final class FinanzasReason {
  static const futureDate = 'future_date';
  static const amountNotInUserText = 'amount_not_in_user_text';
  static const amountAboveDue = 'amount_above_due';

  /// S3-02: el pago no salió de lo que escribió la persona.
  static const nameNotInUserText = 'name_not_in_user_text';

  /// El movimiento va a un libro que no es el abierto: siempre con tarjeta.
  static const otherBook = 'other_book';
}

/// Libro donde se registra un movimiento.
typedef _Book = ({String id, String name});

/// Tipos de registro que entiende [FinanzasWriteTools.undo] (`kind` del payload).
abstract final class FinanzasUndoKind {
  static const transaction = 'transaction';
  static const recurringConfirmation = 'recurring_confirmation';
  static const recurringPartial = 'recurring_partial';
}

/// Texto de error único de los ejecutores (U4).
String _errorText(String motivo) =>
    'No pude registrarlo: $motivo. No se guardó nada.';

/// Motivo legible de una excepción de guardado (sin `$e`, U2.5).
String _saveFailureReason(Object e) {
  final text = e.toString().toLowerCase();
  const offline = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'connection',
    'network',
  ];
  if (offline.any(text.contains)) return 'no hay conexión con la base de datos';
  return 'falló el guardado';
}

class FinanzasWriteTools implements WriteToolHandler {
  final AppState _app;
  final Uuid _uuid = const Uuid();

  FinanzasWriteTools(this._app);

  static const String _exchangeCategoryName = 'Cambio de Divisa';

  @override
  Set<String> get toolNames => const {
        WriteToolNames.registerTransaction,
        WriteToolNames.payRecurringPayment,
      };

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    // La tarjeta queda atada al libro donde se propuso (S3-05).
    final wrongBook = _wrongBookOnConfirm(toolName, args, ctx);
    if (wrongBook != null) return wrongBook;
    try {
      switch (toolName) {
        case WriteToolNames.registerTransaction:
          return await _registerTransaction(args, ctx);
        case WriteToolNames.payRecurringPayment:
          return await _payRecurringPayment(args, ctx);
      }
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: _errorText('no sé hacer «$toolName» en Finanzas'),
      ));
    } catch (e) {
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: _errorText(_saveFailureReason(e)),
      ));
    }
  }

  // -------------------------------------------------------------------------
  // registerTransaction
  // -------------------------------------------------------------------------

  Future<WriteOutcome> _registerTransaction(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.registerTransaction;
    final missing = <String>[];
    final reasons = <String>[];
    final warnings = <String>[];
    final resolved = <String, dynamic>{};
    final options = <String, List<String>>{};

    // Libro: el de la tarjeta al confirmar, el nombrado o el abierto.
    final bookRes = _targetBook(args, ctx);
    if (bookRes.error != null) return bookRes.error!;
    final book = bookRes.book;
    if (book == null) {
      missing.add('bookName');
      options['bookName'] = bookRes.options;
    }
    final bookId = book?.id ?? _app.activeDbName;
    final isOtherBook = bookId != _app.activeDbName;
    if (book != null && isOtherBook) {
      resolved['bookName'] = book.name;
      reasons.add(FinanzasReason.otherBook);
    }

    final concept = _string(args['concept']);
    if (concept == null) missing.add('concept');
    final amount = _positiveAmount(args['amount']);
    if (amount == null) missing.add('amount');
    final type = _transactionType(args['type']);
    if (type == null) missing.add('type');
    final currency = currencyFromParam(_string(args['currency']));
    if (currency == null) missing.add('currency');
    final categoryName = _string(args['categoryName']);
    if (categoryName == null) missing.add('categoryName');

    // Categoría (del libro, solo del tipo pedido, sin «Cambio de Divisa»).
    // Con el libro sin resolver no se resuelve nada del libro.
    ResolverItem? category;
    var allCategories = const <String>[];
    if (book != null && type != null && categoryName != null) {
      final items = _categoryItems(type, bookId);
      allCategories = [for (final i in items) i.displayName];
      final res = _resolveCategoryOrLabel(categoryName, items);
      if (res.isResolved) {
        category = res.value;
      } else {
        // Las 3 más parecidas; si no hay ninguna, todas las del tipo.
        options['categoryName'] =
            res.options.isNotEmpty ? res.options : allCategories;
        if (ctx.confirmedByUser) {
          missing.add('categoryName');
        } else {
          reasons.addAll(res.reasons);
        }
      }
    }
    if (category != null) resolved['categoryName'] = category.name;

    // Cuenta (del libro). Al confirmar, la misma de la tarjeta.
    ResolverAccount? account =
        book == null ? null : _confirmedAccount(args, ctx, bookId);
    if (book != null && account == null && currency != null) {
      final requestedAccount = _string(args['accountName']);
      final res = resolveAccount(
        requestedName: requestedAccount,
        currency: currency,
        accounts: _accountItems(bookId),
        defaultAccountId: _app.defaultAccountIdForProfile(bookId, currency),
      );
      account = _applyAccountResolution(
          res, missing, reasons, warnings, options, resolved, requestedAccount);
    }
    if (account != null) _putAccount(resolved, account, reasons);

    // Fecha.
    final date = resolveDate(_string(args['date']), now: ctx.now);
    if (date.isInvalid) {
      missing.add('date');
    } else if (date.isFuture) {
      reasons.add(FinanzasReason.futureDate);
    }

    if (amount != null && !ctx.amountInUserText(amount)) {
      reasons.add(FinanzasReason.amountNotInUserText);
    }
    reasons.addAll(ctx.forcedProposalReasons);

    if (missing.isNotEmpty) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
        options: _onlyKeys(options, missing),
        reasons: _dedupe(warnings),
      ));
    }

    // Todo presente: category puede faltar solo si hay dudas sin confirmar.
    final txDate = _withTimeOfDay(date.date!, ctx.now());
    final parts = <SummaryPart>[
      SummaryPart(formatCurrency(amount!, currency!), SummaryPartKind.amount),
      ?_equivalent(amount, currency),
      if (category != null) SummaryPart(category.name),
      SummaryPart(account!.name),
      SummaryPart(_dateLabel(txDate, ctx.now())),
    ];

    if (!ctx.confirmedByUser && reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: _dedupe(reasons),
          summary: _joinSummary(concept!, parts),
          resolved: resolved,
          options: options,
        ),
        summaryTitle: concept,
        summaryParts: parts,
        // «Ver todas» de la tarjeta: todas las del tipo, con la misma regla.
        allOptions: {
          if (options.containsKey('categoryName')) 'categoryName': allCategories,
        },
        commitArgs: {
          'concept': concept,
          'amount': amount,
          'type': type!.name,
          'currency': currencyParam(currency),
          'categoryName': category?.displayName ?? categoryName,
          'accountName': account.name,
          'accountId': account.id,
          'date': _isoDate(date.date!),
          ..._bookArgs(book),
          // La tarjeta nació para otro libro (`bookName`): se confirma allí
          // aunque no esté abierto. Las demás siguen S3-05.
          if (isOtherBook) 'otherBook': true,
        },
        profileId: bookId,
      );
    }

    final tx = Transaction(
      id: _uuid.v4(),
      date: txDate,
      amount: amount,
      currency: currency,
      categoryId: category!.id,
      accountId: account.id,
      note: concept!,
      type: type!,
      exchangeRate: _rateFor(currency, account.currency),
    );
    try {
      if (isOtherBook) {
        await _app.addTransactionToProfile(bookId, tx);
      } else {
        await _app.addTransaction(tx);
      }
    } catch (e) {
      return WriteOutcome(WriteToolResult.error(
        action: action,
        message: _errorText(_saveFailureReason(e)),
      ));
    }

    return _saved(
      action: action,
      recordId: tx.id,
      title: concept,
      parts: parts,
      route: SuiteRoutes.movimiento(tx.id),
      undoPayload: {
        'kind': FinanzasUndoKind.transaction,
        'transaction': tx.toMap(),
        // Solo lo registrado a propósito en otro libro se deshace sin
        // abrirlo; el resto sigue S3-05 («Cambia al libro X»).
        if (isOtherBook) 'otherBook': true,
      },
      book: book,
    );
  }

  /// Libro de `registerTransaction`. Al confirmar, el de la tarjeta
  /// (`profileId`); si no, el nombrado en `bookName` (resuelto entre
  /// [AppState.profiles]); si no, el abierto. `book` null con `options` =
  /// nombre ambiguo; `error` = libro inexistente o que no se puede escribir.
  ({_Book? book, List<String> options, WriteOutcome? error}) _targetBook(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) {
    const action = WriteToolNames.registerTransaction;
    final active = (id: _app.activeDbName, name: _app.activeProfileName);
    _Book? book;
    final confirmedId = ctx.confirmedByUser ? _string(args['profileId']) : null;
    if (confirmedId != null) {
      final name = _app.profileNameFor(confirmedId);
      if (name == null) {
        final asked = _string(args['profileName']) ?? confirmedId;
        return (
          book: null,
          options: const [],
          error: WriteOutcome(WriteToolResult.error(
            action: action,
            message: _errorText('no encontré el libro $asked'),
          )),
        );
      }
      book = (id: confirmedId, name: name);
    } else {
      final requested = _string(args['bookName']);
      if (requested == null) return (book: active, options: const [], error: null);
      final items = [
        for (final p in _app.profiles)
          if ((p['id'] ?? '').isNotEmpty)
            ResolverItem(id: p['id']!, name: p['name'] ?? p['id']!),
      ];
      if (!items.any((i) => i.id == active.id)) {
        items.add(ResolverItem(id: active.id, name: active.name));
      }
      final res = resolveByName(requested, items);
      switch (res.status) {
        case ResolutionStatus.resolved:
          book = (id: res.value!.id, name: res.value!.name);
        case ResolutionStatus.notFound:
          return (
            book: null,
            options: const [],
            error: WriteOutcome(WriteToolResult.error(
              action: action,
              message: _errorText('no encontré el libro «$requested»; tus libros '
                  'son: ${items.map((i) => i.name).join(', ')}'),
            )),
          );
        case ResolutionStatus.missing:
        case ResolutionStatus.proposal:
          return (book: null, options: res.options, error: null);
      }
    }
    if (book.id != active.id && !_app.canWriteToProfile(book.id)) {
      return (
        book: null,
        options: const [],
        error: WriteOutcome(WriteToolResult.error(
          action: action,
          message: 'Para registrar en el libro ${book.name}, ábrelo primero en '
              'Finanzas. No se guardó nada.',
        )),
      );
    }
    return (book: book, options: const [], error: null);
  }

  // -------------------------------------------------------------------------
  // payRecurringPayment
  // -------------------------------------------------------------------------

  Future<WriteOutcome> _payRecurringPayment(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.payRecurringPayment;
    final missing = <String>[];
    final reasons = <String>[];
    final warnings = <String>[];
    final resolved = <String, dynamic>{};
    final options = <String, List<String>>{};

    // Pago (entre los del libro activo). Al confirmar, el mismo de la tarjeta.
    final payments = List<RecurringPayment>.of(_app.recurringPayments);
    final requestedName = _string(args['paymentName']) ?? '';
    final confirmedPaymentId =
        ctx.confirmedByUser ? _string(args['paymentId']) : null;
    RecurringPayment? payment = confirmedPaymentId == null
        ? null
        : payments.where((p) => p.id == confirmedPaymentId).firstOrNull;
    if (payment == null) {
      final paymentRes = resolveByName(requestedName, [
        for (final p in payments) ResolverItem(id: p.id, name: p.name),
      ]);
      switch (paymentRes.status) {
        case ResolutionStatus.resolved:
          payment = payments.firstWhere((p) => p.id == paymentRes.value!.id);
        case ResolutionStatus.notFound:
          final motivo = payments.isEmpty
              ? 'no tienes pagos recurrentes en este libro'
              : 'no encontré el pago «$requestedName»; tus pagos son: '
                  '${payments.map((p) => p.name).join(', ')}';
          return WriteOutcome(WriteToolResult.error(
              action: action, message: _errorText(motivo)));
        case ResolutionStatus.missing:
        case ResolutionStatus.proposal:
          missing.add('paymentName');
          options['paymentName'] = paymentRes.options;
      }
    }
    if (payment != null) {
      resolved['paymentName'] = payment.name;
      // S3-02: solo directo si la persona nombró el pago.
      // S3-09: solo el nombre resuelto, nunca el término del modelo.
      if (!_namedByUser(ctx, [payment.name])) {
        reasons.add(FinanzasReason.nameNotInUserText);
      }
    }

    // Monto (opcional: sin monto se paga lo pendiente).
    double? amount;
    if (args['amount'] != null) {
      amount = _positiveAmount(args['amount']);
      if (amount == null) missing.add('amount');
    }

    // Fecha del movimiento («ya pagué el internet ayer»).
    final date = resolveDate(_string(args['date']), now: ctx.now);
    if (date.isInvalid) {
      missing.add('date');
    } else if (date.isFuture) {
      reasons.add(FinanzasReason.futureDate);
    }

    ResolverAccount? account;
    PendingOccurrence? occurrence;
    if (payment != null) {
      await _app.updatePendingPaymentsToday();
      final pending = _app.pendingPaymentsToday
          .where((o) => o.payment.id == payment!.id)
          .toList()
        ..sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
      if (pending.isEmpty) {
        // Sin cuota pendiente: se avisa y no se guarda nada (sin tarjeta).
        final next = nextOccurrenceAfter(payment, ctx.now());
        return WriteOutcome(WriteToolResult.error(
          action: action,
          message: next != null
              ? '${payment.name} ya está pagado hasta el ${formatDate(next)}. '
                  'No registré nada.'
              : '${payment.name} no tiene cuotas pendientes. No registré nada.',
        ));
      }
      occurrence = pending.first;

      account = _confirmedAccount(args, ctx) ??
          _paymentAccount(payment, _string(args['accountName']), missing,
              reasons, warnings, options, resolved);
      if (account != null) _putAccount(resolved, account, reasons);
    }

    if (amount != null && !ctx.amountInUserText(amount)) {
      reasons.add(FinanzasReason.amountNotInUserText);
    }
    reasons.addAll(ctx.forcedProposalReasons);

    if (missing.isNotEmpty) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
        options: _onlyKeys(options, missing),
        reasons: _dedupe(warnings),
      ));
    }

    final now = ctx.now();
    final txDate = _withTimeOfDay(date.date!, now);
    final remaining = occurrence!.remainingAmount;
    final isPartial =
        amount != null && amount < remaining - _amountTolerance;
    // Más que lo pendiente: se confirma con tarjeta y, al confirmar, se
    // registra el monto dicho y la cuota queda pagada.
    final isAbove = amount != null && amount > remaining + _amountTolerance;
    if (isAbove) reasons.add(FinanzasReason.amountAboveDue);
    final payAmount = amount ?? remaining;
    final proposingAbove = isAbove && !ctx.confirmedByUser;
    final parts = <SummaryPart>[
      SummaryPart(
        proposingAbove
            ? 'Pagar ${formatCurrency(payAmount, payment!.currency)} '
                '(la cuota es ${formatCurrency(remaining, payment.currency)})'
            : formatCurrency(payAmount, payment!.currency),
        SummaryPartKind.amount,
      ),
      SummaryPart(account!.name),
      SummaryPart(_dateLabel(txDate, now)),
      if (isPartial)
        SummaryPart(
          'parcial, faltan ${formatCurrency(remaining - payAmount, payment.currency)}',
        ),
    ];

    if (!ctx.confirmedByUser && reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: _dedupe(reasons),
          summary: _joinSummary(payment.name, parts),
          resolved: resolved,
          options: options,
        ),
        summaryTitle: payment.name,
        summaryParts: parts,
        commitArgs: {
          'paymentName': payment.name,
          'paymentId': payment.id,
          'amount': ?amount,
          'accountName': account.name,
          'accountId': account.id,
          'date': _isoDate(date.date!),
          ..._bookArgs(),
        },
        profileId: _app.activeDbName,
      );
    }

    final occurrenceDate = occurrence.occurrenceDate;
    if (isPartial) {
      return _savePartial(
        action: action,
        payment: payment,
        amount: payAmount,
        occurrenceDate: occurrenceDate,
        transactionDate: txDate,
        accountId: account.id,
        parts: parts,
      );
    }
    return _saveComplete(
      action: action,
      payment: payment,
      amount: payAmount,
      occurrenceDate: occurrenceDate,
      transactionDate: txDate,
      accountId: account.id,
      parts: parts,
    );
  }

  /// Fecha de la próxima cuota después de [now] (misma serie que
  /// [AppState.updatePendingPaymentsToday]); `null` si ya no quedan cuotas.
  /// Pública para el contexto de Ortiz (`SuiteRagService`).
  static DateTime? nextOccurrenceAfter(RecurringPayment payment, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final total = payment.totalInstallments;
    var current = DateTime(
        payment.startDate.year, payment.startDate.month, payment.startDate.day);
    var count = 0;
    while (!current.isAfter(today)) {
      count++;
      if (total != null && count > total) return null;
      if (payment.frequency == SubscriptionFrequency.once) return null;
      current = _nextInSeries(payment, current);
    }
    if (total != null && count + 1 > total) return null;
    return current;
  }

  static DateTime _nextInSeries(RecurringPayment payment, DateTime current) {
    switch (payment.frequency) {
      case SubscriptionFrequency.weekly:
        return current.add(const Duration(days: 7));
      case SubscriptionFrequency.biweekly:
        return current.add(const Duration(days: 14));
      case SubscriptionFrequency.fifteenDays:
        if (current.day == 15) {
          return DateTime(current.year, current.month + 1, 0);
        } else if (current.day > 15) {
          return DateTime(current.year, current.month + 1, 15);
        }
        return DateTime(current.year, current.month, 15);
      case SubscriptionFrequency.monthly:
        return DateTime(current.year, current.month + 1, current.day);
      case SubscriptionFrequency.threeMonths:
        return DateTime(current.year, current.month + 3, current.day);
      case SubscriptionFrequency.yearly:
        return DateTime(current.year + 1, current.month, current.day);
      case SubscriptionFrequency.custom:
        final days = payment.customDays ?? 30;
        return current.add(Duration(days: days > 0 ? days : 30));
      case SubscriptionFrequency.once:
        return current;
    }
  }

  static const double _amountTolerance = 0.005;

  /// Cuenta del pago: la nombrada; si no, la del propio pago; si no, la
  /// predeterminada de su moneda (PA-04 y CA-03 como en registerTransaction).
  ResolverAccount? _paymentAccount(
    RecurringPayment payment,
    String? requestedName,
    List<String> missing,
    List<String> reasons,
    List<String> warnings,
    Map<String, List<String>> options,
    Map<String, dynamic> resolved,
  ) {
    final accounts = _accountItems();
    if (requestedName == null && payment.accountId != null) {
      for (final a in accounts) {
        if (a.id == payment.accountId) return a;
      }
    }
    final res = resolveAccount(
      requestedName: requestedName,
      currency: payment.currency,
      accounts: accounts,
      defaultAccountId: _app.defaultAccountIdFor(payment.currency),
    );
    return _applyAccountResolution(
        res, missing, reasons, warnings, options, resolved, requestedName);
  }

  Future<WriteOutcome> _saveComplete({
    required String action,
    required RecurringPayment payment,
    required double amount,
    required DateTime occurrenceDate,
    required DateTime transactionDate,
    required String accountId,
    required List<SummaryPart> parts,
  }) async {
    final before = {for (final t in _app.transactions) t.id};
    Transaction? tx;
    try {
      await _app.confirmRecurringPayment(
        payment: payment,
        actualAmount: amount,
        occurrenceDate: occurrenceDate,
        overrideAccountId: accountId,
        onTransactionRecorded: (t) => tx = t,
        transactionDate: transactionDate,
      );
    } catch (e) {
      // Guardado compuesto: se deshace lo que alcanzó a escribirse. Si falló
      // antes de `onTransactionRecorded`, el movimiento huérfano se reconoce
      // por ser nuevo, de la confirmación (`_rec`) y de la cuenta.
      final orphan = tx ??
          _app.transactions
              .where((t) =>
                  !before.contains(t.id) &&
                  t.id.endsWith('_rec') &&
                  t.accountId == accountId)
              .firstOrNull;
      await _quietly(() async {
        if (orphan != null) await _app.deleteTransaction(orphan);
      });
      await _quietly(
          () => _app.undoRecurringConfirmation(payment.id, occurrenceDate));
      return WriteOutcome(WriteToolResult.error(
        action: action,
        message: _errorText(_saveFailureReason(e)),
      ));
    }
    final recorded = tx;
    return _saved(
      action: action,
      recordId: recorded?.id ?? payment.id,
      title: payment.name,
      parts: parts,
      route: recorded != null
          ? SuiteRoutes.movimiento(recorded.id)
          : SuiteRoutes.pagos,
      undoPayload: {
        'kind': FinanzasUndoKind.recurringConfirmation,
        'paymentId': payment.id,
        'occurrenceDate': _isoDate(occurrenceDate),
        if (recorded != null) 'transaction': recorded.toMap(),
      },
    );
  }

  Future<WriteOutcome> _savePartial({
    required String action,
    required RecurringPayment payment,
    required double amount,
    required DateTime occurrenceDate,
    required DateTime transactionDate,
    required String accountId,
    required List<SummaryPart> parts,
  }) async {
    final before = {for (final t in _app.transactions) t.id};
    Transaction? tx;
    RecurringPaymentPartial? partial;
    try {
      await _app.registerPartialPayment(
        payment: payment,
        partialAmount: amount,
        occurrenceDate: occurrenceDate,
        transactionDate: transactionDate,
        overrideAccountId: accountId,
        onRecorded: (t, p) {
          tx = t;
          partial = p;
        },
      );
    } catch (e) {
      // `onRecorded` llega después de guardar el parcial: si falló antes, el
      // movimiento huérfano se reconoce por ser nuevo, parcial y de la cuenta.
      final orphan = tx ??
          _app.transactions
              .where((t) =>
                  !before.contains(t.id) &&
                  t.id.endsWith('_partial') &&
                  t.accountId == accountId)
              .firstOrNull;
      await _quietly(() async {
        if (partial != null) await _app.deletePartialPayment(partial!.id);
      });
      await _quietly(() async {
        if (orphan != null) await _app.deleteTransaction(orphan);
      });
      return WriteOutcome(WriteToolResult.error(
        action: action,
        message: _errorText(_saveFailureReason(e)),
      ));
    }
    return _saved(
      action: action,
      recordId: tx!.id,
      title: payment.name,
      parts: parts,
      route: SuiteRoutes.movimiento(tx!.id),
      undoPayload: {
        'kind': FinanzasUndoKind.recurringPartial,
        'paymentId': payment.id,
        'partialId': partial!.id,
        'transaction': tx!.toMap(),
      },
    );
  }

  // -------------------------------------------------------------------------
  // undo
  // -------------------------------------------------------------------------

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    final kind = undoPayload['kind'] as String?;
    final profileId = undoPayload['profileId'] as String?;
    // Un movimiento registrado a propósito en otro libro (`bookName`) se
    // deshace allí aunque no sea el abierto (si ese libro se puede escribir
    // sin abrirlo); el resto, solo en el abierto (S3-05).
    final otherBook = profileId != null && profileId != _app.activeDbName;
    if (otherBook &&
        (kind != FinanzasUndoKind.transaction ||
            undoPayload['otherBook'] != true ||
            !_app.canWriteToProfile(profileId))) {
      final name = undoPayload['profileName'] as String? ?? profileId;
      throw StateError('Cambia al libro $name para deshacerlo.');
    }

    final txMap = undoPayload['transaction'];
    final tx = txMap is Map
        ? _currentTransaction(Map<String, dynamic>.from(txMap),
            otherBook ? profileId : null)
        : null;

    switch (kind) {
      case FinanzasUndoKind.transaction:
        if (tx == null) throw StateError('Falta el movimiento que deshacer.');
        if (otherBook) {
          await _app.deleteTransactionFromProfile(profileId, tx);
        } else {
          await _app.deleteTransaction(tx);
        }
      case FinanzasUndoKind.recurringConfirmation:
        if (tx != null) await _app.deleteTransaction(tx);
        await _app.undoRecurringConfirmation(
          undoPayload['paymentId'] as String,
          DateTime.parse(undoPayload['occurrenceDate'] as String),
        );
      case FinanzasUndoKind.recurringPartial:
        await _app.deletePartialPayment(undoPayload['partialId'] as String);
        if (tx != null) await _app.deleteTransaction(tx);
      default:
        throw StateError('No sé deshacer este registro.');
    }
  }

  /// El movimiento en memoria (mismo objeto que usa la app) o, si ya no
  /// está en la lista, el reconstruido desde el payload.
  Transaction _currentTransaction(Map<String, dynamic> map, [String? bookId]) {
    final id = map['id'];
    for (final t in bookId == null
        ? _app.transactions
        : _app.getTransactionsForProfile(bookId)) {
      if (t.id == id) return t;
    }
    return Transaction.fromMap(map);
  }

  // -------------------------------------------------------------------------
  // Ayudas
  // -------------------------------------------------------------------------

  WriteOutcome _saved({
    required String action,
    required String recordId,
    required String title,
    required List<SummaryPart> parts,
    required String route,
    required Map<String, dynamic> undoPayload,
    _Book? book,
  }) {
    final target = book ?? (id: _app.activeDbName, name: _app.activeProfileName);
    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: recordId,
        summary: _joinSummary(title, parts),
        route: route,
        undoId: _uuid.v4(),
      ),
      summaryTitle: title,
      summaryParts: parts,
      undoPayload: {
        ...undoPayload,
        'profileId': target.id,
        'profileName': target.name,
      },
      profileId: target.id,
    );
  }

  /// Cuenta resuelta en `resolved`. Con `account_currency_mismatch` también su
  /// moneda (`currencyParam`), que la tarjeta usa para «X es una cuenta en …»
  /// sin volver a buscarla.
  static void _putAccount(
    Map<String, dynamic> resolved,
    ResolverAccount account,
    List<String> reasons,
  ) {
    resolved['accountName'] = account.name;
    if (reasons.contains(ResolverReason.accountCurrencyMismatch)) {
      resolved['accountCurrency'] = currencyParam(account.currency);
    }
  }

  /// Aplica una resolución de cuenta a las listas del ejecutor y devuelve la
  /// cuenta elegida (también en `proposal`), o null si hay que preguntar.
  ResolverAccount? _applyAccountResolution(
    Resolution<ResolverAccount> res,
    List<String> missing,
    List<String> reasons,
    List<String> warnings,
    Map<String, List<String>> options,
    Map<String, dynamic> resolved,
    String? requestedName,
  ) {
    switch (res.status) {
      case ResolutionStatus.resolved:
        return res.value;
      case ResolutionStatus.proposal:
        reasons.addAll(res.reasons);
        // La tarjeta dice «Entendí «{pedida}» como {cuenta}».
        if (requestedName != null &&
            res.reasons.contains(ResolverReason.accountContainsMatch)) {
          resolved['requestedAccountName'] = requestedName;
        }
        if (res.value != null) return res.value;
        missing.add('accountName');
        options['accountName'] = res.options;
        return null;
      case ResolutionStatus.missing:
      case ResolutionStatus.notFound:
        missing.add('accountName');
        options['accountName'] = res.options;
        warnings.addAll(res.reasons);
        return null;
    }
  }

  /// Categorías del tipo pedido, sin «Cambio de Divisa», con subcategorías
  /// etiquetadas «Padre › Hija».
  List<ResolverItem> _categoryItems(TransactionType type, String bookId) =>
      categoryItemsFor(
        _app.getCategoriesForProfile(bookId),
        type == TransactionType.income
            ? TransactionCategoryType.income
            : TransactionCategoryType.expense,
      );

  /// Como [_categoryItems] sobre [categories]: lo usa también el contexto de
  /// Ortiz, para que los nombres que ve sean los que el ejecutor resuelve.
  static List<ResolverItem> categoryItemsFor(
    List<TransactionCategory> categories,
    TransactionCategoryType catType,
  ) {
    final byId = {for (final c in categories) c.id: c};
    final exchange = norm(_exchangeCategoryName);
    return [
      for (final c in categories)
        if (c.type == catType && norm(c.name) != exchange)
          ResolverItem(
            id: c.id,
            name: c.name,
            label: c.parentId != null && byId[c.parentId] != null
                ? '${byId[c.parentId]!.name} › ${c.name}'
                : null,
          ),
    ];
  }

  /// Como [resolveCategory], pero acepta también la etiqueta «Padre › Hija»
  /// que la tarjeta devuelve al elegir una subcategoría.
  Resolution<ResolverItem> _resolveCategoryOrLabel(
    String name,
    List<ResolverItem> items,
  ) {
    if (name.contains('›')) {
      final wanted = norm(name);
      final byLabel =
          items.where((i) => i.label != null && norm(i.label!) == wanted).toList();
      if (byLabel.length == 1) {
        return resolveCategory(byLabel.first.name, [byLabel.first]);
      }
    }
    return resolveCategory(name, items);
  }

  /// Cuentas del libro [bookId] (por defecto, el abierto).
  List<ResolverAccount> _accountItems([String? bookId]) => [
        for (final a in bookId == null
            ? _app.accounts
            : _app.getAccountsForProfile(bookId))
          ResolverAccount(id: a.id, name: a.name, currency: a.currency),
      ];

  /// Tasa del movimiento con la regla de la pantalla de nuevo movimiento
  /// (`add_transaction_dialog.dart`): euro cuando el movimiento es en EUR en
  /// una cuenta en Bs; BCV en cuentas USD/EUR con su propia moneda y en el
  /// resto. Extensión para `account_currency_mismatch` confirmado (que la
  /// pantalla no produce): si solo uno de los dos (movimiento o cuenta) es
  /// EUR, euro, para que `_getTransactionAmountInAccountCurrency` cuadre.
  double _rateFor(CurrencyType txCurrency, CurrencyType accountCurrency) =>
      (txCurrency == CurrencyType.eur) != (accountCurrency == CurrencyType.eur)
          ? _app.euroRate
          : _app.bcvRate;

  /// Si la persona confirma en otro libro una tarjeta creada con otro libro
  /// abierto: error (S3-05). Solo las tarjetas de `registerTransaction` que
  /// nacieron para otro libro (`otherBook`, por `bookName`) se confirman en
  /// el libro de la tarjeta ([_targetBook]).
  WriteOutcome? _wrongBookOnConfirm(
    String action,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) {
    if (!ctx.confirmedByUser) return null;
    if (action == WriteToolNames.registerTransaction && args['otherBook'] == true) {
      return null;
    }
    final profileId = _string(args['profileId']);
    if (profileId == null || profileId == _app.activeDbName) return null;
    final name = _string(args['profileName']) ?? profileId;
    return WriteOutcome(WriteToolResult.error(
      action: action,
      message: 'Cambia al libro $name para confirmarlo.',
    ));
  }

  /// Libro de la tarjeta (va en `commitArgs`); por defecto, el abierto.
  Map<String, dynamic> _bookArgs([_Book? book]) => {
        'profileId': book?.id ?? _app.activeDbName,
        'profileName': book?.name ?? _app.activeProfileName,
      };

  /// Al confirmar, la cuenta de la tarjeta por su id (sin volver a buscar
  /// por nombre), salvo que la persona haya elegido otra en la tarjeta.
  ResolverAccount? _confirmedAccount(
    Map<String, dynamic> args,
    WriteContext ctx, [
    String? bookId,
  ]) {
    if (!ctx.confirmedByUser) return null;
    final id = _string(args['accountId']);
    if (id == null) return null;
    final name = _string(args['accountName']);
    for (final a in _accountItems(bookId)) {
      if (a.id == id && (name == null || norm(a.name) == norm(name))) return a;
    }
    return null;
  }

  /// S3-02: la persona nombró alguno de [names] (término completo, una
  /// palabra de 4+ letras).
  static bool _namedByUser(WriteContext ctx, List<String?> names) => names.any(
      (n) => ctx.termInUserText(n) || nameWordInText(n, ctx.userText));

  /// Equivalente con las tasas del estado: Bs → ≈ $, $ → ≈ Bs., € → ≈ $.
  SummaryPart? _equivalent(double amount, CurrencyType currency) {
    final bcv = _app.bcvRate;
    final String? text = switch (currency) {
      CurrencyType.bsBCV => bcv > 0 ? formatUSD(amount / bcv) : null,
      CurrencyType.usd => bcv > 0 ? formatBs(amount * bcv) : null,
      CurrencyType.eur => bcv > 0 && _app.euroRate > 0
          ? formatUSD(amount * _app.euroRate / bcv)
          : null,
    };
    return text == null
        ? null
        : SummaryPart('≈ $text', SummaryPartKind.amountSecondary);
  }
}

// ---------------------------------------------------------------------------
// Funciones puras compartidas en este archivo
// ---------------------------------------------------------------------------

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

/// Monto > 0 (número o texto «450», «12,50»); null si falta o no es válido.
double? _positiveAmount(Object? raw) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim().replaceAll(',', '.'));
  }
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }
  return value;
}

TransactionType? _transactionType(Object? raw) =>
    switch (norm(_string(raw) ?? '')) {
      'expense' => TransactionType.expense,
      'income' => TransactionType.income,
      _ => null,
    };

/// Hoy conserva la hora actual; otro día, esa fecha con la hora actual
/// (para que el orden del historial sea natural).
DateTime _withTimeOfDay(DateTime day, DateTime now) {
  if (_sameDay(day, now)) return now;
  return DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// «hoy», «ayer» o dd/MM/yyyy.
String _dateLabel(DateTime date, DateTime now) {
  if (_sameDay(date, now)) return 'hoy';
  if (_sameDay(date, DateTime(now.year, now.month, now.day - 1))) return 'ayer';
  return formatDate(date);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _joinSummary(String title, List<SummaryPart> parts) =>
    [title, ...parts.map((p) => p.text)].join(' · ');

List<String> _dedupe(List<String> list) {
  final out = <String>[];
  for (final item in list) {
    if (!out.contains(item)) out.add(item);
  }
  return out;
}

Map<String, List<String>> _onlyKeys(
  Map<String, List<String>> options,
  List<String> keys,
) =>
    {
      for (final e in options.entries)
        if (keys.contains(e.key)) e.key: e.value,
    };

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // Deshacer a mitad de un fallo: lo que no se pueda revertir se ignora; el
    // error original es el que se informa.
  }
}
