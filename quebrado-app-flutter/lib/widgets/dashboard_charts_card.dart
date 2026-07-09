import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../models/timeline_event.dart';
import 'helpers.dart';
import 'claymorphic_card.dart';

class DashboardChartsCard extends StatefulWidget {
  const DashboardChartsCard({super.key});

  @override
  State<DashboardChartsCard> createState() => _DashboardChartsCardState();
}

class _DashboardChartsCardState extends State<DashboardChartsCard> {
  int _activeTab = 0; // 0: Flujo de Caja, 1: Categorías, 2: Tendencia

  // Helper for currency conversion
  double _convertToDisplayCurrency(
    double amount,
    CurrencyType fromCurrency,
    double txRate,
    AppState appState,
  ) {
    final target = appState.selectedCurrency;
    if (fromCurrency == target) return amount;

    final rate = txRate > 0 ? txRate : appState.bcvRate;
    if (target == CurrencyType.usd) {
      return rate > 0 ? amount / rate : 0.0;
    } else {
      return amount * rate;
    }
  }

  String _formatDisplayAmount(double amount, AppState appState) {
    if (appState.selectedCurrency == CurrencyType.usd) {
      return formatUSD(amount);
    } else {
      return formatBs(amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isUsd = appState.selectedCurrency == CurrencyType.usd;

    return ClaymorphicCard(
      cornerRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Análisis Financiero",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Tabs Selector
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.nestedTabTrackBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton("Flujo", 0),
                ),
                Expanded(
                  child: _buildTabButton("Categorías", 1),
                ),
                Expanded(
                  child: _buildTabButton("Tendencia", 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Graph Container
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SizedBox(
              key: ValueKey<int>(_activeTab),
              height: 260,
              child: _buildActiveChart(appState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int tabIndex) {
    final selected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.nestedTabActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: selected
                ? AppColors.nestedTabActiveText
                : AppColors.nestedTabInactiveText,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChart(AppState appState) {
    switch (_activeTab) {
      case 0:
        return _buildCashFlowChart(appState);
      case 1:
        return _buildCategoryChart(appState);
      case 2:
        return _buildTrendChart(appState);
      default:
        return const SizedBox.shrink();
    }
  }

  // MARK: - 1. CASH FLOW CHART (Line Chart)
  Widget _buildCashFlowChart(AppState appState) {
    final now = DateTime.now();

    // Generate 6 months: 2 past, 1 current, 3 future
    final monthDates = List.generate(6, (i) {
      return DateTime(now.year, now.month + (i - 2), 1);
    });

    final monthNamesShort = [
      "Ene", "Feb", "Mar", "Abr", "May", "Jun",
      "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
    ];

    final events = appState.getTimelineEvents(120);

    // Color definitions for cash flow lines
    final Color colIngRec = AppColors.primary; // Teal/Primary
    final Color colIngInd = AppColors.accent;  // Accent Green
    final Color colEgrRec = AppColors.expense; // Expense Red
    const Color colEgrInd = Color(0xFFE28743);  // Orange/Amber

    List<FlSpot> incRecSpots = [];
    List<FlSpot> incIndSpots = [];
    List<FlSpot> expRecSpots = [];
    List<FlSpot> expIndSpots = [];
    double maxAmount = 10.0;

    for (int i = 0; i < 6; i++) {
      final monthStart = monthDates[i];
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);

      final bool isPast = monthStart.year < now.year ||
          (monthStart.year == now.year && monthStart.month < now.month);
      final bool isFuture = monthStart.year > now.year ||
          (monthStart.year == now.year && monthStart.month > now.month);
      final bool isCurrent = monthStart.year == now.year && monthStart.month == now.month;

      double incRec = 0.0;
      double incInd = 0.0;
      double expRec = 0.0;
      double expInd = 0.0;

      // Helper date formats for matching
      final todayMidnight = DateTime(now.year, now.month, now.day);

      if (isPast) {
        // Historical only
        for (var tx in appState.transactions) {
          if (tx.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            final amt = _convertToDisplayCurrency(tx.amount, tx.currency, tx.exchangeRate, appState);
            final isRecurring = tx.id.endsWith('_rec') || tx.note.contains('Confirmado:');
            
            if (tx.type == TransactionType.income) {
              if (isRecurring) {
                incRec += amt;
              } else {
                incInd += amt;
              }
            } else {
              if (isRecurring) {
                expRec += amt;
              } else {
                expInd += amt;
              }
            }
          }
        }
      } else if (isFuture) {
        // Projected only (all projections count as recurring)
        for (var e in events) {
          if (e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            final amt = _convertToDisplayCurrency(e.amount, e.currency, appState.bcvRate, appState);
            if (e.type == TransactionType.income) {
              incRec += amt;
            } else {
              expRec += amt;
            }
          }
        }
      } else if (isCurrent) {
        // Mixed: real transactions up to today + projections for rest of month
        for (var tx in appState.transactions) {
          if (tx.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            // Check if tx is today or past
            final txDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
            if (!txDay.isAfter(todayMidnight)) {
              final amt = _convertToDisplayCurrency(tx.amount, tx.currency, tx.exchangeRate, appState);
              final isRecurring = tx.id.endsWith('_rec') || tx.note.contains('Confirmado:');
              if (tx.type == TransactionType.income) {
                if (isRecurring) {
                  incRec += amt;
                } else {
                  incInd += amt;
                }
              } else {
                if (isRecurring) {
                  expRec += amt;
                } else {
                  expInd += amt;
                }
              }
            }
          }
        }

        for (var e in events) {
          if (e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            // Check if projection is strictly after today
            final eDay = DateTime(e.date.year, e.date.month, e.date.day);
            if (eDay.isAfter(todayMidnight)) {
              final amt = _convertToDisplayCurrency(e.amount, e.currency, appState.bcvRate, appState);
              if (e.type == TransactionType.income) {
                incRec += amt;
              } else {
                expRec += amt;
              }
            }
          }
        }
      }

      incRecSpots.add(FlSpot(i.toDouble(), incRec));
      incIndSpots.add(FlSpot(i.toDouble(), incInd));
      expRecSpots.add(FlSpot(i.toDouble(), expRec));
      expIndSpots.add(FlSpot(i.toDouble(), expInd));

      final double totalInc = incRec + incInd;
      final double totalExp = expRec + expInd;
      maxAmount = max(maxAmount, max(totalInc, totalExp));
    }

    final double maxYCeiling = maxAmount * 1.15;

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == maxYCeiling) return const SizedBox.shrink();
                      String text = "";
                      if (value >= 1000) {
                        text = "${(value / 1000).toStringAsFixed(1)}K";
                      } else {
                        text = value.toStringAsFixed(0);
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4,
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 8.5, color: AppColors.cardSubtitleText),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= 6) return const SizedBox.shrink();
                      final dt = monthDates[index];
                      final name = monthNamesShort[dt.month - 1];
                      final isCurr = dt.year == now.year && dt.month == now.month;

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isCurr ? FontWeight.bold : FontWeight.normal,
                            color: isCurr ? AppColors.primary : AppColors.cardSubtitleText,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey[900]!,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    final int xIndex = touchedSpots.first.x.toInt();
                    final monthName = monthNamesShort[monthDates[xIndex].month - 1];
                    final double ir = incRecSpots[xIndex].y;
                    final double ii = incIndSpots[xIndex].y;
                    final double er = expRecSpots[xIndex].y;
                    final double ei = expIndSpots[xIndex].y;

                    return touchedSpots.map((spot) {
                      if (spot.barIndex == 0) {
                        return LineTooltipItem(
                          "$monthName\n"
                          "Ingresos Recurrentes: ${_formatDisplayAmount(ir, appState)}\n"
                          "Ingresos Individuales: ${_formatDisplayAmount(ii, appState)}\n"
                          "Egresos Recurrentes: ${_formatDisplayAmount(er, appState)}\n"
                          "Egresos Individuales: ${_formatDisplayAmount(ei, appState)}",
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
              ),
              minX: 0,
              maxX: 5,
              minY: 0,
              maxY: maxYCeiling,
              lineBarsData: [
                // 1. Ingresos Recurrentes
                LineChartBarData(
                  spots: incRecSpots,
                  isCurved: true,
                  color: colIngRec,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colIngRec.withOpacity(0.15),
                        colIngRec.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // 2. Ingresos Individuales
                LineChartBarData(
                  spots: incIndSpots,
                  isCurved: true,
                  color: colIngInd,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colIngInd.withOpacity(0.15),
                        colIngInd.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // 3. Egresos Recurrentes
                LineChartBarData(
                  spots: expRecSpots,
                  isCurved: true,
                  color: colEgrRec,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colEgrRec.withOpacity(0.15),
                        colEgrRec.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // 4. Egresos Individuales
                LineChartBarData(
                  spots: expIndSpots,
                  isCurved: true,
                  color: colEgrInd,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colEgrInd.withOpacity(0.15),
                        colEgrInd.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legends Scrollable
        SizedBox(
          height: 22,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  _buildLegendItem("Ingresos Recurrentes", colIngRec),
                  const SizedBox(width: 16),
                  _buildLegendItem("Ingresos Individuales", colIngInd),
                  const SizedBox(width: 16),
                  _buildLegendItem("Egresos Recurrentes", colEgrRec),
                  const SizedBox(width: 16),
                  _buildLegendItem("Egresos Individuales", colEgrInd),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.cardSubtitleText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // MARK: - 2. CATEGORY CHART (Pie/Donut of Current Month Expenses)
  Widget _buildCategoryChart(AppState appState) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final todayMidnight = DateTime(now.year, now.month, now.day);

    Map<String, double> categorySums = {}; // Key: Category ID (or 'projected')
    double totalSpend = 0.0;

    // 1. Process historical expenses for current month up to today
    for (var tx in appState.transactions) {
      if (tx.type == TransactionType.expense &&
          tx.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
          tx.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
        final txDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
        if (!txDay.isAfter(todayMidnight)) {
          final amt = _convertToDisplayCurrency(tx.amount, tx.currency, tx.exchangeRate, appState);
          final catId = tx.categoryId ?? 'otros';
          categorySums[catId] = (categorySums[catId] ?? 0.0) + amt;
          totalSpend += amt;
        }
      }
    }

    // 2. Process projected occurrences for rest of month
    final events = appState.getTimelineEvents(31);
    for (var e in events) {
      if (e.type == TransactionType.expense &&
          e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
        final eDay = DateTime(e.date.year, e.date.month, e.date.day);
        if (eDay.isAfter(todayMidnight)) {
          final amt = _convertToDisplayCurrency(e.amount, e.currency, appState.bcvRate, appState);
          categorySums['projected'] = (categorySums['projected'] ?? 0.0) + amt;
          totalSpend += amt;
        }
      }
    }

    if (totalSpend <= 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: AppColors.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 10),
            const Text(
              "No hay egresos registrados o proyectados\npara el mes en curso.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardSubtitleText,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Create sections
    int colorIdx = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legendWidgets = [];

    categorySums.forEach((catId, sum) {
      final percentage = (sum / totalSpend) * 100;
      if (sum <= 0) return;

      Color catColor = Colors.grey;
      String catName = "Otros";
      IconData catIcon = Icons.folder_open;

      if (catId == 'projected') {
        catColor = const Color(0xFFD4A373); // Custom sand gold color
        catName = "Pagos Programados";
        catIcon = Icons.calendar_today_rounded;
      } else {
        final category = appState.categories.firstWhere(
          (c) => c.id == catId,
          orElse: () => appState.categories.firstWhere(
            (c) => c.name.toLowerCase() == 'otros',
            orElse: () => appState.categories.first,
          ),
        );
        catColor = parseHexColor(category.colorHex);
        catName = category.name;
        catIcon = getIconData(category.icon);
      }

      sections.add(
        PieChartSectionData(
          color: catColor,
          value: sum,
          title: "${percentage.toStringAsFixed(0)}%",
          radius: 22,
          showTitle: percentage >= 10,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legendWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    catIcon,
                    color: catColor,
                    size: 9,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  catName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDisplayAmount(sum, appState),
                style: TextStyle(
                  fontSize: 11,
                  color: catColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Column(
      children: [
        // Donut Chart Centered at Top
        Center(
          child: SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 42,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.cardSubtitleText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatDisplayAmount(totalSpend, appState),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cardText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Breakdown List Scrollable at Bottom with Scrollbar indicator
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legendWidgets,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - 3. BALANCE TREND CHART (30-Day Line Projection)
  Widget _buildTrendChart(AppState appState) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    // We simulate next 30 days
    final events = appState.getTimelineEvents(30);

    List<FlSpot> spots = [];
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (int i = 0; i < 30; i++) {
      final targetDate = todayMidnight.add(Duration(days: i));
      
      // Find the last event occurring on or before targetDate
      TimelineEvent? lastEventBeforeOrOn;
      for (var ev in events) {
        final evDay = DateTime(ev.date.year, ev.date.month, ev.date.day);
        if (evDay.isBefore(targetDate) || evDay.isAtSameMomentAs(targetDate)) {
          if (lastEventBeforeOrOn == null || ev.date.isAfter(lastEventBeforeOrOn.date)) {
            lastEventBeforeOrOn = ev;
          }
        }
      }

      double liquidUsd = 0.0;
      if (lastEventBeforeOrOn != null) {
        liquidUsd = lastEventBeforeOrOn.projectedLiquidBalanceUSD;
      } else {
        liquidUsd = appState.liquidBalanceUSD;
      }

      final convertedVal = _convertToDisplayCurrency(
        liquidUsd,
        CurrencyType.usd,
        appState.bcvRate,
        appState,
      );

      spots.add(FlSpot(i.toDouble(), convertedVal));
      minVal = min(minVal, convertedVal);
      maxVal = max(maxVal, convertedVal);
    }

    if (minVal == double.infinity) minVal = 0.0;
    if (maxVal == -double.infinity) maxVal = 100.0;

    // Add padding to bounds
    final double spread = maxVal - minVal;
    final double yMin = max(0.0, minVal - (spread * 0.15));
    final double yMax = maxVal + (spread * 0.15 > 0 ? spread * 0.15 : 20.0);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == yMin || value == yMax) return const SizedBox.shrink();
                      String text = "";
                      if (value >= 1000) {
                        text = "${(value / 1000).toStringAsFixed(1)}K";
                      } else {
                        text = value.toStringAsFixed(0);
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4,
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 8.5, color: AppColors.cardSubtitleText),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      if (dayIndex != 0 && dayIndex != 9 && dayIndex != 19 && dayIndex != 29) {
                        return const SizedBox.shrink();
                      }
                      
                      final date = todayMidnight.add(Duration(days: dayIndex));
                      final monthNamesShort = [
                        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
                        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
                      ];
                      final text = "${date.day}/${monthNamesShort[date.month - 1]}";

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          dayIndex == 0 ? "Hoy" : text,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.cardSubtitleText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey[900]!,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final spot = spots[touchedSpot.x.toInt()];
                      final date = todayMidnight.add(Duration(days: spot.x.toInt()));
                      final amtFormatted = _formatDisplayAmount(spot.y, appState);
                      return LineTooltipItem(
                        "${formatDate(date)}\n"
                        "Saldo Líq: $amtFormatted",
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              minX: 0,
              maxX: 29,
              minY: yMin,
              maxY: yMax,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.35),
                        AppColors.primary.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              "Proyección Saldo Líquido Consolidado (30 Días)",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.cardSubtitleText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
