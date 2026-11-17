import 'currency_type.dart';
import 'transaction.dart';

class SuggestionReason {
  final String name;
  final String detail;
  SuggestionReason(this.name, this.detail);
}

class TimelineEvent {
  final DateTime date;
  final String title;
  final double amount;
  final CurrencyType currency;
  final TransactionType type;
  final String? accountName;
  final String? pocketName;
  final String? pocketId;
  /// Patrimonio total proyectado, todo convertido a $ (cuentas en $ y en Bs).
  final double projectedBalanceUSD;

  /// Dinero disponible en $: cuentas en $ menos lo apartado en bolsillos. No incluye
  /// los Bs: esos van en [projectedBsBalance]. Negativo = dinero que faltará.
  final double projectedLiquidBalanceUSD;

  /// Bolívares proyectados (suma de las cuentas en Bs).
  final double projectedBsBalance;

  /// Saldo proyectado de cada cuenta (en su moneda) después de este evento.
  final Map<String, double>? accountBalances;

  /// Monto del evento en $ (para sumar eventos de distintas monedas).
  final double? amountUSD;

  /// Moneda de la cuenta con la que se paga o cobra (lo que de verdad se mueve):
  /// un pago "USD a tasa BCV" desde una cuenta en Bs tiene [currency] = usd y
  /// [paidInCurrency] = bsBCV. Null en los cambios de divisa ($ → Bs).
  final CurrencyType? paidInCurrency;

  /// Cambio de divisa sugerido: vender [amount] $ para tener [exchangeAmountBs] Bs
  /// el día de un gasto en Bs que no alcanzan a cubrir los Bs proyectados.
  /// No es ingreso ni gasto: los resúmenes deben ignorarlo.
  final bool isExchangeSuggestion;
  final double? exchangeAmountBs;
  final double? exchangeRate;
  final String? exchangeSourceAccountId;
  final String? exchangeTargetAccountId;
  final int? installmentNumber; // e.g. 3 for "Cuota 3/6"
  final int? totalInstallments;
  final bool isSuggestion;
  final bool isVariable;
  final double? maxAmount;
  final String? recurringPaymentId;
  final bool isOverdue;
  final double partialAmountPaid;
  final bool isCompletedAbono;
  final bool isLastProvisioning;
  final List<String>? associatedTransactionIds;
  final List<SuggestionReason>? suggestionReasons;

  TimelineEvent({
    required this.date,
    required this.title,
    required this.amount,
    required this.currency,
    required this.type,
    this.accountName,
    this.pocketName,
    this.pocketId,
    required this.projectedBalanceUSD,
    required this.projectedLiquidBalanceUSD,
    this.projectedBsBalance = 0.0,
    this.accountBalances,
    this.amountUSD,
    this.paidInCurrency,
    this.isExchangeSuggestion = false,
    this.exchangeAmountBs,
    this.exchangeRate,
    this.exchangeSourceAccountId,
    this.exchangeTargetAccountId,
    this.installmentNumber,
    this.totalInstallments,
    this.isSuggestion = false,
    this.isVariable = false,
    this.maxAmount,
    this.recurringPaymentId,
    this.isOverdue = false,
    this.partialAmountPaid = 0.0,
    this.isCompletedAbono = false,
    this.isLastProvisioning = false,
    this.associatedTransactionIds,
    this.suggestionReasons,
  });

  /// Ingreso o gasto real (no sugerencias de bolsillo ni cambios de divisa).
  bool get isCashFlow => !isSuggestion && !isExchangeSuggestion;
}
