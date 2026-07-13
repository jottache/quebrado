import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../viewmodels/app_state.dart';
import '../models/exchange_rate_record.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import 'settings_screen.dart';
import '../theme/colors.dart';
import '../services/bcv_predictor.dart';
import '../widgets/claymorphic_background.dart';

class RatesHistoryScreen extends StatefulWidget {
  const RatesHistoryScreen({super.key});

  @override
  State<RatesHistoryScreen> createState() => _RatesHistoryScreenState();
}

class _RatesHistoryScreenState extends State<RatesHistoryScreen> {
  int _selectedCurrencyTab = 0; // 0 = BCV, 1 = Euro
  int _selectedListTab = 0; // 0 = Últimos 10, 1 = Subidas, 2 = Bajadas

  late ScrollController _scrollController;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final isScrollingDown = _scrollController.offset > 150;
      if (isScrollingDown != _showScrollToTop) {
        setState(() {
          _showScrollToTop = isScrollingDown;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<ExchangeRateRecord> _getActiveHistory(AppState appState) {
    return _selectedCurrencyTab == 0
        ? appState.rateHistory
        : appState.euroRateHistory;
  }

  List<ExchangeRateRecord> _getChartData(List<ExchangeRateRecord> history) {
    // 30 most recent, in chronological order (oldest first for chart rendering)
    final list = history.take(30).toList();
    return list.reversed.toList();
  }

  List<_RateRowItem> _getFilteredRowItems(List<ExchangeRateRecord> history) {
    List<_RateRowItem> items = [];

    // Pre-calculate items with their predecessor comparisons
    for (int i = 0; i < history.length; i++) {
      final record = history[i];
      final previous = i + 1 < history.length ? history[i + 1] : null;
      items.add(_RateRowItem(record: record, previousRecord: previous));
    }

    switch (_selectedListTab) {
      case 1: // Subidas
        return items.where((item) {
          if (item.previousRecord == null) return false;
          return item.record.rate > item.previousRecord!.rate;
        }).toList();
      case 2: // Bajadas
        return items.where((item) {
          if (item.previousRecord == null) return false;
          return item.record.rate < item.previousRecord!.rate;
        }).toList();
      default: // Últimos 10
        return items.take(10).toList();
    }
  }

  void _showSearchRateByDateBottomSheet(
    BuildContext context,
    List<ExchangeRateRecord> history,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchRateBottomSheet(
          history: history,
          isEuro: _selectedCurrencyTab == 1,
        );
      },
    );
  }

  void _showPredictionBottomSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BcvPredictionBottomSheet(appState: appState);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final history = _getActiveHistory(appState);
    final chartRecords = _getChartData(history);
    final listItems = _getFilteredRowItems(history);

    // Dynamic Y scale bounds
    double minY = 0.0;
    double maxY = 100.0;
    if (chartRecords.isNotEmpty) {
      final rates = chartRecords.map((r) => r.rate).toList();
      final minVal = rates.reduce(min);
      final maxVal = rates.reduce(max);
      final padding = max((maxVal - minVal) * 0.05, 0.05);
      minY = max(0.0, minVal - padding);
      maxY = maxVal + padding;
    }

    final String lastUpdated = history.isNotEmpty
        ? formatDate(history.first.date)
        : "Nunca";
    final double activeRate = _selectedCurrencyTab == 0
        ? appState.bcvRate
        : appState.euroRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Tasas de Cambio",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? Padding(
              padding: EdgeInsets.only(bottom: 100.0),
              child: FloatingActionButton(
                mini: true,
                backgroundColor: AppColors.primary,
                shape: CircleBorder(),
                onPressed: () {
                  _scrollController.animateTo(
                    0.0,
                    duration: Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                  );
                },
                child: Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
      body: ClaymorphicBackground(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // Currency tab selector
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 8.0,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.mainTabTrackBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCurrencyTab = 0),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedCurrencyTab == 0
                                ? AppColors.mainTabActiveBg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Oficial BCV",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedCurrencyTab == 0
                                  ? AppColors.mainTabActiveText
                                  : AppColors.mainTabInactiveText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCurrencyTab = 1),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedCurrencyTab == 1
                                ? AppColors.mainTabActiveBg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Euro Oficial",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedCurrencyTab == 1
                                  ? AppColors.mainTabActiveText
                                  : AppColors.mainTabInactiveText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 1. Sticky Current Rate Card
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyRateCardDelegate(
              activeRate: activeRate,
              lastUpdated: lastUpdated,
              title: _selectedCurrencyTab == 0
                  ? "TASA OFICIAL BCV ACTUAL"
                  : "TASA EURO OFICIAL ACTUAL",
              shortTitle: _selectedCurrencyTab == 0
                  ? "Oficial BCV"
                  : "Euro Oficial",
              selectedCurrencyTab: _selectedCurrencyTab,
              isFetchingHistory: appState.isFetchingHistory,
              rateHistoryIsEmpty: appState.rateHistory.isEmpty,
              onPredictPressed: () =>
                  _showPredictionBottomSheet(context, appState),
            ),
          ),

          // remaining content
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 12.0,
              bottom: 140.0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 12),
                // 2. Trend Chart Card
                ClaymorphicCard(
                  cornerRadius: 24,
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TENDENCIA DE LA TASA (ÚLTIMOS 30 DÍAS)",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 20),
                      if (chartRecords.length >= 2)
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              minY: minY,
                              maxY: maxY,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: (maxY - minY) / 4,
                                verticalInterval: max(
                                  1.0,
                                  (chartRecords.length / 5),
                                ),
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.black.withOpacity(0.08),
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.black.withOpacity(0.08),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: chartRecords.asMap().entries.map((
                                    entry,
                                  ) {
                                    return FlSpot(
                                      entry.key.toDouble(),
                                      entry.value.rate,
                                    );
                                  }).toList(),
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3.5,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.2),
                                        AppColors.primary.withOpacity(0.01),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 180,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.show_chart_rounded,
                                size: 36,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Aún no hay suficientes datos",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // 3. Historical list logs
                ClaymorphicCard(
                  cornerRadius: 24,
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "HISTORIAL DE ACTUALIZACIONES",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.2,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            onPressed: () => _showSearchRateByDateBottomSheet(
                              context,
                              history,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Segment list selector
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.nestedTabTrackBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _ListSegment(
                              title: "Últimos 10",
                              isSelected: _selectedListTab == 0,
                              onTap: () => setState(() => _selectedListTab = 0),
                            ),
                            _ListSegment(
                              title: "Subidas",
                              isSelected: _selectedListTab == 1,
                              onTap: () => setState(() => _selectedListTab = 1),
                            ),
                            _ListSegment(
                              title: "Bajadas",
                              isSelected: _selectedListTab == 2,
                              onTap: () => setState(() => _selectedListTab = 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      if (listItems.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              "No hay registros en esta categoría",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: listItems.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.black.withOpacity(0.08),
                          ),
                          itemBuilder: (context, index) {
                            final item = listItems[index];
                            return _RateRow(item: item);
                          },
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky Header Delegate for Dynamic Shrinking Rate Card
// ---------------------------------------------------------------------------
class _StickyRateCardDelegate extends SliverPersistentHeaderDelegate {
  final double activeRate;
  final String lastUpdated;
  final String title;
  final String shortTitle;
  final int selectedCurrencyTab;
  final bool isFetchingHistory;
  final bool rateHistoryIsEmpty;
  final VoidCallback? onPredictPressed;

  _StickyRateCardDelegate({
    required this.activeRate,
    required this.lastUpdated,
    required this.title,
    required this.shortTitle,
    required this.selectedCurrencyTab,
    required this.isFetchingHistory,
    required this.rateHistoryIsEmpty,
    required this.onPredictPressed,
  });

  @override
  double get minExtent => 74.0;

  @override
  double get maxExtent => 150.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double progress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    final double cardCornerRadius = 24.0 - (8.0 * progress);
    final double paddingHorizontal = 20.0 - (4.0 * progress);
    final double paddingVertical = 20.0 - (10.0 * progress);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: (maxExtent - shrinkOffset).clamp(minExtent, maxExtent),
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0 + (4.0 * (1 - progress)),
        ),
        child: ClaymorphicCard(
          cornerRadius: cardCornerRadius,
          padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal,
            vertical: paddingVertical,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanded content (fade out as scroll down)
              Opacity(
                opacity: (1.0 - progress * 2.0).clamp(0.0, 1.0),
                child: progress > 0.8
                    ? SizedBox.shrink()
                    : SingleChildScrollView(
                        physics: NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatRate(activeRate),
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_filled_rounded,
                                            size: 12,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "Sincronizado: $lastUpdated",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    AppColors.cardSubtitleText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedCurrencyTab == 0)
                                  ElevatedButton.icon(
                                    onPressed:
                                        isFetchingHistory || rateHistoryIsEmpty
                                        ? null
                                        : onPredictPressed,
                                    icon: isFetchingHistory
                                        ? SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Icon(
                                            Icons.auto_graph_rounded,
                                            size: 16,
                                          ),
                                    label: Text(
                                      isFetchingHistory
                                          ? "Sincronizando..."
                                          : "Predecir",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: AppColors.primary
                                          .withOpacity(0.12),
                                      disabledForegroundColor: Colors.grey[500],
                                      elevation: 2,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),

              // Compact content (fade in as scroll down)
              Opacity(
                opacity: ((progress - 0.5) * 2.0).clamp(0.0, 1.0),
                child: progress < 0.2
                    ? SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            shortTitle.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            formatRate(activeRate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardText,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyRateCardDelegate oldDelegate) {
    return oldDelegate.activeRate != activeRate ||
        oldDelegate.lastUpdated != lastUpdated ||
        oldDelegate.title != title ||
        oldDelegate.shortTitle != shortTitle ||
        oldDelegate.selectedCurrencyTab != selectedCurrencyTab ||
        oldDelegate.isFetchingHistory != isFetchingHistory ||
        oldDelegate.rateHistoryIsEmpty != rateHistoryIsEmpty ||
        oldDelegate.onPredictPressed != onPredictPressed;
  }
}

// ---------------------------------------------------------------------------
// Search Rate by Date Bottom Sheet Dialog
// ---------------------------------------------------------------------------
class _SearchRateBottomSheet extends StatefulWidget {
  final List<ExchangeRateRecord> history;
  final bool isEuro;

  const _SearchRateBottomSheet({required this.history, required this.isEuro});

  @override
  State<_SearchRateBottomSheet> createState() => _SearchRateBottomSheetState();
}

class _SearchRateBottomSheetState extends State<_SearchRateBottomSheet> {
  DateTime? _selectedDate;
  ExchangeRateRecord? _foundRecord;
  bool _searched = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.cardText,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ExchangeRateRecord? match;
      for (final r in widget.history) {
        if (r.date.year == picked.year &&
            r.date.month == picked.month &&
            r.date.day == picked.day) {
          match = r;
          break;
        }
      }

      setState(() {
        _selectedDate = picked;
        _foundRecord = match;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedSelectedDate = _selectedDate != null
        ? "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}"
        : "";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),

          // Title
          Text(
            "Buscar Tasa por Fecha",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.isEuro
                ? "Búsqueda en el historial del Euro Oficial"
                : "Búsqueda en el historial del Oficial BCV",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cardSubtitleText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 24),

          // Selector button
          GestureDetector(
            onTap: () => _selectDate(context),
            child: ClaymorphicCard(
              cornerRadius: 16,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    _selectedDate == null
                        ? "Seleccionar Fecha"
                        : "Fecha: $formattedSelectedDate",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // Results
          if (_searched)
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _foundRecord != null
                  ? _buildResultCard(_foundRecord!)
                  : _buildNotFoundCard(formattedSelectedDate),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 48,
                    color: Colors.black.withOpacity(0.15),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Selecciona una fecha para consultar el tipo de cambio histórico.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.cardSubtitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildResultCard(ExchangeRateRecord record) {
    final formattedTime =
        "${record.date.hour.toString().padLeft(2, '0')}:${record.date.minute.toString().padLeft(2, '0')}";
    return ClaymorphicCard(
      cornerRadius: 20,
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isEuro ? "EURO OFICIAL" : "DÓLAR BCV",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 12,
                    color: AppColors.cardSubtitleText,
                  ),
                  SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            formatRate(record.rate),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Tasa correspondiente al ${formatDate(record.date)}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.cardSubtitleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard(String dateStr) {
    return ClaymorphicCard(
      cornerRadius: 20,
      padding: EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.expense,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sin Registro",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "No se encontró ninguna tasa registrada para el $dateStr.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ListSegment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.nestedTabActiveBg
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.nestedTabActiveText
                  : AppColors.nestedTabInactiveText,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _RateRowItem {
  final ExchangeRateRecord record;
  final ExchangeRateRecord? previousRecord;

  _RateRowItem({required this.record, this.previousRecord});

  _TrendDirection get direction {
    if (previousRecord == null) return _TrendDirection.none;
    if (record.rate > previousRecord!.rate) return _TrendDirection.up;
    if (record.rate < previousRecord!.rate) return _TrendDirection.down;
    return _TrendDirection.flat;
  }

  String get changeDelta {
    if (previousRecord == null) return "";
    final diff = record.rate - previousRecord!.rate;
    final prefix = diff > 0 ? "+" : "-";
    return "${prefix}Bs. ${diff.abs().toStringAsFixed(2)}";
  }
}

enum _TrendDirection { up, down, flat, none }

class _RateRow extends StatelessWidget {
  final _RateRowItem item;

  const _RateRow({required this.item});

  IconData _getTrendIcon(_TrendDirection dir) {
    switch (dir) {
      case _TrendDirection.up:
        return Icons.arrow_outward_rounded;
      case _TrendDirection.down:
        return Icons.south_east_rounded;
      case _TrendDirection.flat:
        return Icons.arrow_forward_rounded;
      case _TrendDirection.none:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = item.direction;
    final formattedDate = formatDate(item.record.date);

    final hour = item.record.date.hour.toString().padLeft(2, '0');
    final minute = item.record.date.minute.toString().padLeft(2, '0');
    final formattedTime = "$hour:$minute";

    final Color trendColor;
    switch (dir) {
      case _TrendDirection.up:
        trendColor = AppColors.income;
        break;
      case _TrendDirection.down:
        trendColor = AppColors.expense;
        break;
      default:
        trendColor = AppColors.cardSubtitleText;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getTrendIcon(dir), color: trendColor, size: 14),
          ),
          SizedBox(width: 12),

          // Date / Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.cardSubtitleText,
                  ),
                ),
              ],
            ),
          ),

          // Rate / Change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRate(item.record.rate),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardText,
                ),
              ),
              if (item.changeDelta.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  item.changeDelta,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: trendColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BcvPredictionBottomSheet extends StatelessWidget {
  final AppState appState;

  const _BcvPredictionBottomSheet({required this.appState});

  @override
  Widget build(BuildContext context) {
    final prediction = BcvPredictor.predict(appState.rateHistory);

    final diff = prediction.predictedRateNextDay - prediction.currentRate;
    final pct = prediction.currentRate > 0
        ? (diff / prediction.currentRate) * 100
        : 0.0;

    Color trendColor;
    IconData trendIcon;
    if (prediction.trend == "Alcista") {
      trendColor = AppColors.income;
      trendIcon = Icons.trending_up_rounded;
    } else if (prediction.trend == "Bajista") {
      trendColor = AppColors.expense;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendColor = AppColors.cardSubtitleText;
      trendIcon = Icons.trending_flat_rounded;
    }

    Color confidenceColor;
    if (prediction.confidence == "Alta") {
      confidenceColor = AppColors.income;
    } else if (prediction.confidence == "Media") {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = AppColors.expense;
    }

    final diff7 = prediction.predictedRate7Days - prediction.currentRate;
    final pct7 = prediction.currentRate > 0
        ? (diff7 / prediction.currentRate) * 100
        : 0.0;

    final diff14 = prediction.predictedRate14Days - prediction.currentRate;
    final pct14 = prediction.currentRate > 0
        ? (diff14 / prediction.currentRate) * 100
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: 28.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Predicción Oficial BCV",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              "Cálculo matemático basado en regresión lineal y promedios móviles ponderados",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardSubtitleText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),

            // Main Prediction Card
            ClaymorphicCard(
              cornerRadius: 24,
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    "TASA ESTIMADA PRÓXIMO DÍA HÁBIL",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "${prediction.predictedRateNextDay.toStringAsFixed(4)} Bs.",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(trendIcon, color: trendColor, size: 18),
                      SizedBox(width: 4),
                      Text(
                        "${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(4)} Bs. (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Row of Indicators (Tendencia, Confianza, Racha)
            Row(
              children: [
                Expanded(
                  child: ClaymorphicCard(
                    cornerRadius: 16,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "TENDENCIA",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardSubtitleText,
                          ),
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(trendIcon, size: 14, color: trendColor),
                            SizedBox(width: 4),
                            Text(
                              prediction.trend,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ClaymorphicCard(
                    cornerRadius: 16,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "CONFIANZA",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardSubtitleText,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          prediction.confidence,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: confidenceColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ClaymorphicCard(
                    cornerRadius: 16,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "CONSECUTIVOS",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardSubtitleText,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          prediction.consecutivePositiveDays > 0
                              ? "${prediction.consecutivePositiveDays} días"
                              : "N/D",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Justification Text Card
            Text(
              "EXPLICACIÓN Y JUSTIFICACIÓN",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            ClaymorphicCard(
              cornerRadius: 18,
              padding: EdgeInsets.all(16.0),
              child: RichText(
                text: _parseJustification(prediction.justification),
              ),
            ),
            SizedBox(height: 20),

            // Future Horizon Projections
            Text(
              "PROYECCIONES A DIFERENTES PLAZOS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            ClaymorphicCard(
              cornerRadius: 18,
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProjectionRow(
                    timeframe: "A 1 día hábil",
                    rate: prediction.predictedRateNextDay,
                    delta: diff,
                    pct: pct,
                    color: trendColor,
                  ),
                  Divider(height: 20, thickness: 0.5),
                  _buildProjectionRow(
                    timeframe: "A 7 días hábiles",
                    rate: prediction.predictedRate7Days,
                    delta: diff7,
                    pct: pct7,
                    color: diff7 >= 0 ? AppColors.income : AppColors.expense,
                  ),
                  Divider(height: 20, thickness: 0.5),
                  _buildProjectionRow(
                    timeframe: "A 14 días hábiles",
                    rate: prediction.predictedRate14Days,
                    delta: diff14,
                    pct: pct14,
                    color: diff14 >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionRow({
    required String timeframe,
    required double rate,
    required double delta,
    required double pct,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeframe,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardSubtitleText,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "${rate.toStringAsFixed(4)} Bs.",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
          ],
        ),
        Text(
          "${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(4)} Bs.\n(${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)",
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Simple markdown-to-TextSpan parser for **bold** text in justification
  TextSpan _parseJustification(String text) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.cardText,
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.cardText,
      ),
      children: spans,
    );
  }
}
