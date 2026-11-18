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
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

class DashboardChartsCard extends StatefulWidget {
  const DashboardChartsCard({super.key});

  @override
  State<DashboardChartsCard> createState() => _DashboardChartsCardState();
}

class _DashboardChartsCardState extends State<DashboardChartsCard> {
  int _activeTab = 0; // 0: Flujo de Caja, 1: Categorías, 2: Tendencia

  // Opacidad de las series individuales (no recurrentes) del flujo de caja:
  // mismo tono que su serie recurrente, atenuado para distinguirlas.
  static const double _oneOffAlpha = 0.5;

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

    return OrtizSection(
      surface: true,
      children: [Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: OrtizIconSize.md,
                ),
              ),
              SizedBox(width: OrtizSpace.sm),
              Text(
                "Análisis Financiero",
                style: TextStyle(
                  fontSize: OrtizFontSize.body,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.lg),

          // Custom Tabs Selector
          Container(
            padding: EdgeInsets.all(OrtizSpace.xxs),
            decoration: BoxDecoration(
              color: AppColors.nestedTabTrackBg,
              borderRadius: BorderRadius.circular(OrtizRadius.field),
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
          SizedBox(height: OrtizSpace.xl),

          // Active Graph Container
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: SizedBox(
              key: ValueKey<int>(_activeTab),
              height: 260,
              child: _buildActiveChart(appState),
            ),
          ),
        ],
      )],
    );
  }

  Widget _buildTabButton(String label, int tabIndex) {
    final selected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabIndex),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.nestedTabActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: OrtizFontSize.bodySm,
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
        return SizedBox.shrink();
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

    // Colores de las series: ingresos en `income` y egresos en `expense`
    // (PA-02); lo recurrente en el tono pleno y lo individual atenuado.
    const Color colIngRec = AppColors.income;
    final Color colIngInd = AppColors.income.withValues(alpha: _oneOffAlpha);
    const Color colEgrRec = AppColors.expense;
    final Color colEgrInd = AppColors.expense.withValues(alpha: _oneOffAlpha);

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
          if (tx.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
              tx.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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
          if (e.isExchangeSuggestion) continue; // cambio $→Bs: no es ingreso ni gasto
          if (e.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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
          if (tx.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
              tx.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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

          if (e.isExchangeSuggestion) continue; // cambio $→Bs: no es ingreso ni gasto
          if (e.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == maxYCeiling) return SizedBox.shrink();
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
                          style: TextStyle(fontSize: OrtizFontSize.micro, color: AppColors.cardSubtitleText),
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
                      if (index < 0 || index >= 6) return SizedBox.shrink();
                      final dt = monthDates[index];
                      final name = monthNamesShort[dt.month - 1];
                      final isCurr = dt.year == now.year && dt.month == now.month;

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: OrtizFontSize.micro,
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
                  tooltipBgColor: OrtizPalette.surfaceHigh,
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
                          TextStyle(
                            color: OrtizPalette.fg,
                            fontSize: OrtizFontSize.caption,
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
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colIngRec.withValues(alpha: 0.15),
                        colIngRec.withValues(alpha: 0.0),
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
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colIngInd.withValues(alpha: 0.15),
                        colIngInd.withValues(alpha: 0.0),
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
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colEgrRec.withValues(alpha: 0.15),
                        colEgrRec.withValues(alpha: 0.0),
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
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colEgrInd.withValues(alpha: 0.15),
                        colEgrInd.withValues(alpha: 0.0),
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
        SizedBox(height: OrtizSpace.md),
        // Legends Scrollable
        SizedBox(
          height: 22,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(width: OrtizSpace.sm),
                  _buildLegendItem("Ingresos Recurrentes", colIngRec),
                  SizedBox(width: OrtizSpace.lg),
                  _buildLegendItem("Ingresos Individuales", colIngInd),
                  SizedBox(width: OrtizSpace.lg),
                  _buildLegendItem("Egresos Recurrentes", colEgrRec),
                  SizedBox(width: OrtizSpace.lg),
                  _buildLegendItem("Egresos Individuales", colEgrInd),
                  SizedBox(width: OrtizSpace.sm),
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
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
          ),
        ),
        SizedBox(width: OrtizSpace.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.caption,
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
          tx.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
          tx.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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
      if (e.isExchangeSuggestion) continue; // cambio $→Bs: no es ingreso ni gasto
      if (e.type == TransactionType.expense &&
          e.date.isAfter(monthStart.subtract(Duration(seconds: 1))) &&
          e.date.isBefore(monthEnd.add(Duration(seconds: 1)))) {
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
              size: OrtizIconSize.xxl,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              "No hay egresos registrados o proyectados\npara el mes en curso.",
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
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

      Color catColor = OrtizPalette.muted;
      String catName = "Otros";
      IconData catIcon = Icons.folder_open;

      if (catId == 'projected') {
        catColor = OrtizPalette.warn; // pagos programados
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
          titleStyle: TextStyle(
            fontSize: OrtizFontSize.caption,
            fontWeight: FontWeight.bold,
            color: OrtizPalette.onAccent,
          ),
        ),
      );

      legendWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: OrtizSpace.sm),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    catIcon,
                    color: catColor,
                    size: OrtizIconSize.xs,
                  ),
                ),
              ),
              SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  catName,
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: OrtizSpace.sm),
              Text(
                _formatDisplayAmount(sum, appState),
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
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
                    Text(
                      "Total",
                      style: TextStyle(
                        fontSize: OrtizFontSize.micro,
                        color: AppColors.cardSubtitleText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xxs),
                    Text(
                      _formatDisplayAmount(totalSpend, appState),
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
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
        SizedBox(height: OrtizSpace.md),
        // Breakdown List Scrollable at Bottom with Scrollbar indicator
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => true,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.only(right: OrtizSpace.md),
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
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == yMin || value == yMax) return SizedBox.shrink();
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
                          style: TextStyle(fontSize: OrtizFontSize.micro, color: AppColors.cardSubtitleText),
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
                        return SizedBox.shrink();
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
                          style: TextStyle(
                            fontSize: OrtizFontSize.micro,
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
                  tooltipBgColor: OrtizPalette.surfaceHigh,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final spot = spots[touchedSpot.x.toInt()];
                      final date = todayMidnight.add(Duration(days: spot.x.toInt()));
                      final amtFormatted = _formatDisplayAmount(spot.y, appState);
                      return LineTooltipItem(
                        "${formatDate(date)}\n"
                        "Saldo Líq: $amtFormatted",
                        TextStyle(
                          color: OrtizPalette.fg,
                          fontSize: OrtizFontSize.caption,
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
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.35),
                        AppColors.primary.withValues(alpha: 0.0),
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
        SizedBox(height: OrtizSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
            ),
            SizedBox(width: OrtizSpace.xs),
            Text(
              "Proyección Saldo Líquido Consolidado (30 Días)",
              style: TextStyle(
                fontSize: OrtizFontSize.micro,
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
