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

  /// Cambios de divisa sugeridos del día (dólares vendidos → Bs recibidos).
  final double exchangeUSD;
  final double exchangeBs;
  
  final double finalBalanceUSD;
  final double finalLiquidBalanceUSD;
  final double finalBsBalance;

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
    this.exchangeUSD = 0.0,
    this.exchangeBs = 0.0,
    required this.finalBalanceUSD,
    required this.finalLiquidBalanceUSD,
    this.finalBsBalance = 0.0,
  });
}
