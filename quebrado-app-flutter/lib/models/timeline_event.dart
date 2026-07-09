import 'currency_type.dart';
import 'transaction.dart';

class TimelineEvent {
  final DateTime date;
  final String title;
  final double amount;
  final CurrencyType currency;
  final TransactionType type;
  final String? accountName;
  final String? pocketName;
  final String? pocketId;
  final double projectedBalanceUSD;
  final double projectedLiquidBalanceUSD;
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
  });
}
