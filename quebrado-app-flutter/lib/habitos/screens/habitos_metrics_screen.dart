import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import '../dialogs/habit_detail_cli_dialog.dart';

class HabitosMetricsScreen extends StatelessWidget {
  const HabitosMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final heatmapData = state.getHeatmapData(daysBack: 84); // 12 semanas
    final weekdayRates = state.getDayOfWeekSuccessRates();
    final allHabits = state.allHabits;

    return Scaffold(
      backgroundColor: HabitosColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: HabitosColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Métricas & Consistencia',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: HabitosColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // 1. GitHub-Style Activity Heatmap
          _buildHeatmapCard(heatmapData),
          const SizedBox(height: 16),

          // 2. Resilience Score (30-Day Anti-Fragile Consistency)
          _buildResilienceCard(state, allHabits),
          const SizedBox(height: 16),

          // 3. Weekday Consistency
          _buildWeekdayCard(weekdayRates),
          const SizedBox(height: 16),

          // 4. Habits Ranking
          _buildHabitsSummaryCard(context, state, allHabits),
        ],
      ),
    );
  }

  /// Tarjeta con el Mapa de Actividad de 12 semanas estilo GitHub
  Widget _buildHeatmapCard(Map<String, double> heatmapData) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: HabitosColors.primary.withOpacity(0.03),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HISTORIAL DE ACTIVIDAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: HabitosColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Últimas 12 Semanas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: HabitosColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 14, color: HabitosColors.primary),
                    SizedBox(width: 4),
                    Text(
                      '84 Días',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(heatmapData),
          const SizedBox(height: 14),
          // Leyenda de intensidades
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Menos', style: TextStyle(fontSize: 11, color: HabitosColors.textSecondary)),
              const SizedBox(width: 6),
              _legendBox(const Color(0xFFF3F4F6)),
              _legendBox(const Color(0xFFCBE3DC)),
              _legendBox(const Color(0xFF6FB3A4)),
              _legendBox(HabitosColors.primary),
              const SizedBox(width: 6),
              const Text('Más', style: TextStyle(fontSize: 11, color: HabitosColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.8),
      ),
    );
  }

  Widget _buildHeatmapGrid(Map<String, double> data) {
    final dates = data.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(12, (weekIndex) {
          final weekDays = dates.skip(weekIndex * 7).take(7).toList();

          return Column(
            children: weekDays.map((dateKey) {
              final rate = data[dateKey] ?? 0.0;
              Color cellColor = const Color(0xFFF3F4F6); // 0%

              if (rate >= 0.75) {
                cellColor = HabitosColors.primary;
              } else if (rate >= 0.45) {
                cellColor = const Color(0xFF6FB3A4);
              } else if (rate > 0.0) {
                cellColor = const Color(0xFFCBE3DC);
              }

              return Tooltip(
                message: "$dateKey: ${(rate * 100).toInt()}% completado",
                child: Container(
                  width: 17,
                  height: 17,
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(3.5),
                    border: Border.all(
                      color: rate > 0 ? HabitosColors.primary.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                      width: 0.8,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),
    );
  }

  /// Tarjeta de Resiliencia a 30 días
  Widget _buildResilienceCard(HabitosState state, List<dynamic> allHabits) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ÍNDICE DE RESILIENCIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Consistencia a 30 Días',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mide tu constancia real tolerante a fallos aislados, evitando el desánimo por romper una racha rígida.',
            style: TextStyle(fontSize: 12, color: HabitosColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 16),
          ...allHabits.map((h) {
            final score = state.calculateResilienceScore(h.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          h.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HabitosColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${score.toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: HabitosColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 6,
                      backgroundColor: HabitosColors.primaryLight,
                      color: HabitosColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Tarjeta de Consistencia por Día de la Semana
  Widget _buildWeekdayCard(Map<int, double> weekdayRates) {
    final dayNames = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISCIPLINA SEMANAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tasa de Éxito por Día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(7, (idx) {
            final dayInt = idx + 1;
            final rate = weekdayRates[dayInt] ?? 0.0;
            final pct = (rate * 100).toInt();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 75,
                    child: Text(
                      dayNames[idx],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HabitosColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 6,
                        backgroundColor: HabitosColors.primaryLight,
                        color: HabitosColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: HabitosColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Tarjeta de Resumen y Acceso a Hábitos
  Widget _buildHabitsSummaryCard(BuildContext context, HabitosState state, List<dynamic> allHabits) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODOS LOS HÁBITOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Rachas y Rendimiento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...allHabits.map((h) {
            final streak = state.calculateCurrentStreak(h.id);
            final cleanDays = h.isNegative ? state.calculateCleanDays(h.id) : null;

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => HabitDetailCliDialog(habit: h),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: h.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        h.isNegative ? Icons.shield_outlined : Icons.check_circle_outline_rounded,
                        size: 15,
                        color: h.isNegative ? HabitosColors.amber : HabitosColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        h.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HabitosColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: h.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        h.isNegative ? '$cleanDays d invicto' : '$streak d racha',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: h.isNegative ? HabitosColors.amber : HabitosColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: HabitosColors.textMuted),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
