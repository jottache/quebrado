class TimelineDaySummaryEvent {
  final double incomeNativeUSD;
  final double incomeNativeBs;
  final double incomeBsConvertedUsd;
  final double incomeNativeEur;
  final double incomeEurConvertedUsd;
  
  final double expenseNativeUSD;
  final double expenseNativeBs;
  final double expenseBsConvertedUsd;
  final double expenseNativeEur;
  final double expenseEurConvertedUsd;
  
  final double pocketUSD;
  
  final double finalBalanceUSD;
  final double finalLiquidBalanceUSD;

  TimelineDaySummaryEvent({
    required this.incomeNativeUSD,
    required this.incomeNativeBs,
    required this.incomeBsConvertedUsd,
    required this.incomeNativeEur,
    required this.incomeEurConvertedUsd,
    required this.expenseNativeUSD,
    required this.expenseNativeBs,
    required this.expenseBsConvertedUsd,
    required this.expenseNativeEur,
    required this.expenseEurConvertedUsd,
    required this.pocketUSD,
    required this.finalBalanceUSD,
    required this.finalLiquidBalanceUSD,
  });
}
