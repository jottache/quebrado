import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/mood_catalog.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';

/// Tendencia de ánimo: valor diario (puntos) + media móvil de 7 días (línea).
class MoodTrendChart extends StatefulWidget {
  final String? contactId;
  final double height;

  const MoodTrendChart({super.key, this.contactId, this.height = 190});

  @override
  State<MoodTrendChart> createState() => _MoodTrendChartState();
}

class _MoodTrendChartState extends State<MoodTrendChart> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final animo = AnimoState.maybeOf(context);
    if (animo == null) return const SizedBox.shrink();

    final series = animo.dailySeries(contactId: widget.contactId, days: _days);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - (_days - 1));

    // x = índice de día dentro de la ventana
    final points = <FlSpot>[];
    for (var i = 0; i < _days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final value = series[_key(d)];
      if (value != null) points.add(FlSpot(i.toDouble(), value));
    }
    final moving = _movingAverage(points, window: 7);
    final avg = points.isEmpty ? null : points.map((p) => p.y).reduce((a, b) => a + b) / points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                avg == null
                    ? 'Sin datos en este rango'
                    : 'Promedio ${MoodCatalog.metaForAverage(avg).emoji} ${avg.toStringAsFixed(1)} · ${points.length} días',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DiarioColors.textSecondary),
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
                ButtonSegment(value: 365, label: Text('1a')),
              ],
              selected: {_days},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _days = s.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                selectedBackgroundColor: DiarioColors.primaryLight,
                selectedForegroundColor: DiarioColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: points.length < 2
              ? const Center(
                  child: Text(
                    'Registra al menos 2 días para ver tu tendencia',
                    style: TextStyle(fontSize: 12, color: DiarioColors.textMuted, fontWeight: FontWeight.w700),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (_days - 1).toDouble(),
                    minY: -2.3,
                    maxY: 2.3,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.black.withOpacity(value.round() == 0 ? 0.12 : 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble() || value.abs() > 2) return const SizedBox.shrink();
                            return Text(MoodCatalog.valenceMeta(value.round()).emoji, style: const TextStyle(fontSize: 13));
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey[900]!,
                        getTooltipItems: (spots) => spots.map((s) {
                          final d = DateTime(start.year, start.month, start.day + s.x.round());
                          final isAvg = s.barIndex == 1;
                          return LineTooltipItem(
                            '${d.day}/${d.month}\n${isAvg ? "Media 7d" : MoodCatalog.metaForAverage(s.y).label} ${s.y.toStringAsFixed(1)}',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: points,
                        isCurved: false,
                        barWidth: 0,
                        color: Colors.transparent,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                            radius: _days > 90 ? 2.2 : 3.6,
                            color: MoodCatalog.colorForAverage(spot.y),
                            strokeWidth: 0,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: moving,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: DiarioColors.primary,
                        barWidth: 2.6,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Media de los días con dato dentro de los últimos [window] días de cada punto.
  static List<FlSpot> _movingAverage(List<FlSpot> points, {required int window}) {
    final result = <FlSpot>[];
    for (final p in points) {
      final inWindow = points.where((q) => q.x <= p.x && q.x > p.x - window).toList();
      final avg = inWindow.map((q) => q.y).reduce((a, b) => a + b) / inWindow.length;
      result.add(FlSpot(p.x, avg));
    }
    return result;
  }
}
