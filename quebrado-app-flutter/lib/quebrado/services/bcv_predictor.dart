import 'dart:math';
import '../models/exchange_rate_record.dart';

class BcvPrediction {
  final double currentRate;
  final double predictedRateNextDay;
  final double predictedRate7Days;
  final double predictedRate14Days;
  final double avgDailyDelta;
  final double avgDailyDeltaPercent;
  final double monthlyDelta;
  final double monthlyDeltaPercent;
  final double volatility;
  final String trend; // "Alcista", "Estable", "Bajista"
  final String confidence; // "Alta", "Media", "Baja"
  final String justification;
  final int consecutivePositiveDays;
  final double rSquared;

  BcvPrediction({
    required this.currentRate,
    required this.predictedRateNextDay,
    required this.predictedRate7Days,
    required this.predictedRate14Days,
    required this.avgDailyDelta,
    required this.avgDailyDeltaPercent,
    required this.monthlyDelta,
    required this.monthlyDeltaPercent,
    required this.volatility,
    required this.trend,
    required this.confidence,
    required this.justification,
    required this.consecutivePositiveDays,
    required this.rSquared,
  });
}

class BcvPredictor {
  static BcvPrediction predict(List<ExchangeRateRecord> history) {
    if (history.isEmpty) {
      return BcvPrediction(
        currentRate: 0.0,
        predictedRateNextDay: 0.0,
        predictedRate7Days: 0.0,
        predictedRate14Days: 0.0,
        avgDailyDelta: 0.0,
        avgDailyDeltaPercent: 0.0,
        monthlyDelta: 0.0,
        monthlyDeltaPercent: 0.0,
        volatility: 0.0,
        trend: "Estable",
        confidence: "Baja",
        justification: "No hay registros suficientes en el historial para realizar una predicción.",
        consecutivePositiveDays: 0,
        rSquared: 0.0,
      );
    }

    final double currentRate = history.first.rate;

    if (history.length < 5) {
      return BcvPrediction(
        currentRate: currentRate,
        predictedRateNextDay: currentRate,
        predictedRate7Days: currentRate,
        predictedRate14Days: currentRate,
        avgDailyDelta: 0.0,
        avgDailyDeltaPercent: 0.0,
        monthlyDelta: 0.0,
        monthlyDeltaPercent: 0.0,
        volatility: 0.0,
        trend: "Estable",
        confidence: "Baja",
        justification: "Se requieren al menos 5 días de historial de tasas para calcular una proyección de tendencia válida.",
        consecutivePositiveDays: 0,
        rSquared: 0.0,
      );
    }

    // history is sorted descending (latest first). Let's take the latest 30 records
    // and reverse them to have chronological order (oldest first).
    final List<ExchangeRateRecord> recentRecords = history.take(30).toList().reversed.toList();
    final int n = recentRecords.length;

    // Rates list in chronological order
    final List<double> rates = recentRecords.map((r) => r.rate).toList();

    // Calculate daily absolute changes and percentage returns
    final List<double> absoluteDeltas = [];
    final List<double> percentDeltas = [];
    for (int i = 1; i < n; i++) {
      absoluteDeltas.add(rates[i] - rates[i - 1]);
      percentDeltas.add((rates[i] - rates[i - 1]) / rates[i - 1]);
    }

    final int m = percentDeltas.length;

    // Calculate averages over the active window (up to last 15 deltas)
    final int windowSize = min(15, m);
    double sumDelta = 0.0;
    double sumPercent = 0.0;
    for (int i = m - windowSize; i < m; i++) {
      sumDelta += absoluteDeltas[i];
      sumPercent += percentDeltas[i];
    }
    final double avgDailyDelta = sumDelta / windowSize;
    final double avgDailyDeltaPercent = sumPercent / windowSize;

    // Weighted moving average of daily returns (last 15 days, recent gets more weight)
    double weightedSumPercent = 0.0;
    double sumWeights = 0.0;
    for (int i = 0; i < windowSize; i++) {
      final double weight = (i + 1).toDouble();
      final double percentVal = percentDeltas[m - windowSize + i];
      weightedSumPercent += percentVal * weight;
      sumWeights += weight;
    }
    final double weightedGrowthRate = sumWeights > 0 ? weightedSumPercent / sumWeights : 0.0;

    // Projections based on weighted growth rate
    final double predictedRateNextDay = currentRate * (1 + weightedGrowthRate);
    final double predictedRate7Days = currentRate * pow(1 + weightedGrowthRate, 7);
    final double predictedRate14Days = currentRate * pow(1 + weightedGrowthRate, 14);

    // Calculate monthly delta (or overall delta if history < 30)
    final double oldestRate = rates.first;
    final double monthlyDelta = currentRate - oldestRate;
    final double monthlyDeltaPercent = oldestRate > 0 ? (currentRate - oldestRate) / oldestRate : 0.0;

    // Calculate volatility (standard deviation of daily returns in the window)
    double variance = 0.0;
    for (int i = m - windowSize; i < m; i++) {
      final double diff = percentDeltas[i] - avgDailyDeltaPercent;
      variance += diff * diff;
    }
    variance = variance / windowSize;
    final double volatility = sqrt(variance);

    // Linear regression on the window of rates to see linearity (R-squared)
    // Points are (x, y) where x = index (0 to windowSize), y = rate
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < windowSize + 1; i++) {
      final double x = i.toDouble();
      final double y = rates[n - (windowSize + 1) + i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }
    final int pointsCount = windowSize + 1;
    final double denom = (pointsCount * sumX2 - sumX * sumX);
    final double slope = denom == 0 ? 0 : (pointsCount * sumXY - sumX * sumY) / denom;
    final double intercept = (sumY - slope * sumX) / pointsCount;

    double yMean = sumY / pointsCount;
    double ssTot = 0.0;
    double ssRes = 0.0;
    for (int i = 0; i < pointsCount; i++) {
      final double x = i.toDouble();
      final double y = rates[n - (pointsCount) + i];
      final double yPred = slope * x + intercept;
      ssTot += (y - yMean) * (y - yMean);
      ssRes += (y - yPred) * (y - yPred);
    }
    final double rSquared = ssTot == 0 ? 1.0 : (1.0 - (ssRes / ssTot)).clamp(0.0, 1.0);

    // Determine Trend direction
    String trend = "Estable";
    if (weightedGrowthRate > 0.0001) {
      trend = "Alcista";
    } else if (weightedGrowthRate < -0.0001) {
      trend = "Bajista";
    }

    // Determine Confidence level
    String confidence = "Media";
    if (volatility < 0.001) {
      confidence = "Alta";
    } else if (volatility > 0.004) {
      confidence = "Baja";
    }

    // Calculate consecutive positive/negative days (racha)
    int consecutivePositiveDays = 0;
    if (absoluteDeltas.isNotEmpty) {
      final bool lastWasPositive = absoluteDeltas.last >= 0;
      for (int i = absoluteDeltas.length - 1; i >= 0; i--) {
        final bool isPositive = absoluteDeltas[i] >= 0;
        if (isPositive == lastWasPositive) {
          consecutivePositiveDays++;
        } else {
          break;
        }
      }
    }

    // Format strings for justification
    final String trendStr = trend == "Alcista" ? "alcista" : trend == "Bajista" ? "bajista" : "estable";
    final String growthStr = (avgDailyDeltaPercent * 100).toStringAsFixed(3);
    final String deltaStr = avgDailyDelta.abs().toStringAsFixed(4);
    final String sign = avgDailyDelta >= 0 ? "+" : "-";
    final String r2Percent = (rSquared * 100).toStringAsFixed(1);
    final String stabilityStr = confidence == "Alta" ? "muy estable" : confidence == "Media" ? "moderadamente estable" : "de alta volatilidad";

    String streakDescription = "";
    if (consecutivePositiveDays > 1) {
      streakDescription = " y acumula una racha de $consecutivePositiveDays días hábiles consecutivos de movimiento en la misma dirección";
    }

    final String justification = "La tasa del dólar oficial BCV muestra una tendencia **$trendStr** en los últimos $windowSize días hábiles$streakDescription. "
        "Durante este período, la tasa ha registrado una variación diaria promedio de **$sign$deltaStr Bs. ($growthStr%)**. "
        "El comportamiento del mercado ha sido **$stabilityStr** (volatilidad de **${(volatility * 100).toStringAsFixed(3)}%**). "
        "La consistencia matemática de la tendencia (coeficiente de determinación R² = **$r2Percent%**) respalda la validez de este modelo, "
        "estimando que la tasa se ubicará en torno a los **${predictedRateNextDay.toStringAsFixed(4)} Bs.** en la próxima actualización oficial.";

    return BcvPrediction(
      currentRate: currentRate,
      predictedRateNextDay: predictedRateNextDay,
      predictedRate7Days: predictedRate7Days,
      predictedRate14Days: predictedRate14Days,
      avgDailyDelta: avgDailyDelta,
      avgDailyDeltaPercent: avgDailyDeltaPercent,
      monthlyDelta: monthlyDelta,
      monthlyDeltaPercent: monthlyDeltaPercent,
      volatility: volatility,
      trend: trend,
      confidence: confidence,
      justification: justification,
      consecutivePositiveDays: consecutivePositiveDays,
      rSquared: rSquared,
    );
  }
}
