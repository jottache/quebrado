import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/habitos_state.dart';
import '../models/habit_model.dart';
import '../theme/habitos_terminal_theme.dart';
import '../dialogs/habit_detail_cli_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class HabitosMetricsScreen extends StatelessWidget {
  const HabitosMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitosColors.background,
      appBar: AppBar(
        backgroundColor: HabitosColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: OrtizIconSize.md, color: HabitosColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Métricas & Consistencia',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: OrtizFontSize.title,
            color: HabitosColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: const HabitosMetricsView(),
    );
  }
}

class HabitosMetricsView extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const HabitosMetricsView({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.xxxl + OrtizSpace.sm),
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final heatmapData = state.getHeatmapData(daysBack: 84); // 12 semanas
    final weekdayRates = state.getDayOfWeekSuccessRates();
    final allHabits = state.allHabits;

    return ListView(
      padding: padding,
      children: [
        // 1. GitHub-Style Activity Heatmap
        _buildHeatmapCard(context, state, heatmapData),
        const SizedBox(height: OrtizSpace.lg),

        // 2. Resilience Score (30-Day Anti-Fragile Consistency)
        _buildResilienceCard(state, allHabits),
        const SizedBox(height: OrtizSpace.lg),

        // 3. Weekday Consistency
        _buildWeekdayCard(weekdayRates),
        const SizedBox(height: OrtizSpace.lg),

        // 4. Habits Ranking
        _buildHabitsSummaryCard(context, state, allHabits),
      ],
    );
  }

  /// Tarjeta con el Mapa de Actividad de 12 semanas estilo GitHub
  Widget _buildHeatmapCard(BuildContext context, HabitosState state, Map<String, double> heatmapData) {
    // Grupo sin tarjeta: va sobre el fondo, separado por espacio.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HISTORIAL DE ACTIVIDAD',
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.w800,
                      color: HabitosColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: OrtizSpace.xxs),
                  const Text(
                    'Consistencia en el Tiempo',
                    style: TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.w900,
                      color: HabitosColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: OrtizSpace.xxs),
                  const Text(
                    'Toca un cuadro para ver el conteo del día',
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      color: HabitosColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                decoration: BoxDecoration(
                  color: HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_view_week_rounded, size: OrtizIconSize.xs, color: HabitosColors.primary),
                    SizedBox(width: OrtizSpace.xs),
                    Text(
                      '84 Días',
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.lg),
          _buildHeatmapGrid(context, state, heatmapData),
          const SizedBox(height: OrtizSpace.md),
          // Leyenda de intensidades
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Menos', style: TextStyle(fontSize: OrtizFontSize.caption, color: HabitosColors.textSecondary)),
              const SizedBox(width: OrtizSpace.xs),
              _legendBox(HabitosColors.surfaceHover),
              _legendBox(HabitosColors.primaryLight),
              _legendBox(HabitosColors.primaryBorder),
              _legendBox(HabitosColors.primary),
              const SizedBox(width: OrtizSpace.xs),
              const Text('Más', style: TextStyle(fontSize: OrtizFontSize.caption, color: HabitosColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: Border.all(color: HabitosColors.cardBorder, width: 0.8),
      ),
    );
  }

  Widget _buildHeatmapGrid(BuildContext context, HabitosState state, Map<String, double> data) {
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
              // Intensidad: sin registro, tinte, borde (45 %) y color pleno.
              Color cellColor = HabitosColors.surfaceHover; // 0%

              if (rate >= 0.75) {
                cellColor = HabitosColors.primary;
              } else if (rate >= 0.45) {
                cellColor = HabitosColors.primaryBorder;
              } else if (rate > 0.0) {
                cellColor = HabitosColors.primaryLight;
              }

              return InkWell(
                onTap: () => _showHeatmapDayPopover(context, state, dateKey, rate),
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                child: Container(
                  width: 17,
                  height: 17,
                  margin: const EdgeInsets.all(OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    border: Border.all(
                      color: rate > 0 ? HabitosColors.primary.withValues(alpha: 0.15) : HabitosColors.cardBorder,
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

  void _showHeatmapDayPopover(
    BuildContext context,
    HabitosState state,
    String dateKey,
    double rate,
  ) {
    final parsedDate = DateTime.tryParse(dateKey) ?? DateTime.now();
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final formattedDate = '${parsedDate.day} de ${months[parsedDate.month - 1]}, ${parsedDate.year}';
    final habits = state.allHabits;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HabitosColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
        titlePadding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.sm),
        contentPadding: const EdgeInsets.fromLTRB(OrtizSpace.xl, 0, OrtizSpace.xl, OrtizSpace.lg),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HabitosColors.primaryLight,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
              child: const Icon(Icons.insights_rounded, color: HabitosColors.primary, size: OrtizIconSize.md),
            ),
            const SizedBox(width: OrtizSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.w900, color: HabitosColors.textPrimary),
                  ),
                  Text(
                    '${(rate * 100).toInt()}% cumplimiento global',
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 16, color: HabitosColors.cardBorder),
              const Text(
                'DESGLOSE DE HÁBITOS ESTE DÍA',
                style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: OrtizSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: habits.length,
                  separatorBuilder: (_, __) => const Divider(height: 8, color: HabitosColors.cardBorder),
                  itemBuilder: (c, idx) {
                    final h = habits[idx];
                    final isComp = state.isCompleted(h.id, dateKey);
                    final val = state.getValue(h.id, dateKey);

                    String metricText;
                    if (h.type == HabitType.counter) {
                      metricText = '${val.toInt()} ${h.unit ?? "veces"}';
                    } else if (h.type == HabitType.quantitative) {
                      metricText = '${val.toInt()}/${h.targetValue.toInt()} ${h.unit ?? ""}';
                    } else if (h.type == HabitType.timer) {
                      metricText = '${(val / 60).round()} min';
                    } else if (h.isNegative) {
                      metricText = isComp ? 'Invicto' : 'Recaída';
                    } else {
                      metricText = isComp ? 'Completado' : 'No realizado';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                      child: Row(
                        children: [
                          Icon(
                            isComp || val > 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: OrtizIconSize.sm,
                            color: isComp || val > 0 ? HabitosColors.primary : HabitosColors.textMuted,
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Text(
                              h.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: HabitosColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: isComp || val > 0 ? HabitosColors.primaryLight : HabitosColors.background,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Text(
                              metricText,
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w800,
                                color: isComp || val > 0 ? HabitosColors.primary : HabitosColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(color: HabitosColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Resiliencia a 30 días
  Widget _buildResilienceCard(HabitosState state, List<dynamic> allHabits) {
    // Grupo sin tarjeta.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ÍNDICE DE RESILIENCIA',
            style: TextStyle(
              fontSize: OrtizFontSize.caption,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: OrtizSpace.xxs),
          const Text(
            'Consistencia a 30 Días',
            style: TextStyle(
              fontSize: OrtizFontSize.titleSm,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: OrtizSpace.xs),
          const Text(
            'Mide tu constancia real tolerante a fallos aislados, evitando el desánimo por romper una racha rígida.',
            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: OrtizSpace.lg),
          ...allHabits.map((h) {
            final score = state.calculateResilienceScore(h.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: OrtizSpace.md),
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
                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: HabitosColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${score.toInt()}%',
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w900, color: HabitosColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
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

    // Grupo sin tarjeta.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISCIPLINA SEMANAL',
            style: TextStyle(
              fontSize: OrtizFontSize.caption,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: OrtizSpace.xxs),
          const Text(
            'Tasa de Éxito por Día',
            style: TextStyle(
              fontSize: OrtizFontSize.titleSm,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: OrtizSpace.md),
          ...List.generate(7, (idx) {
            final dayInt = idx + 1;
            final rate = weekdayRates[dayInt] ?? 0.0;
            final pct = (rate * 100).toInt();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 75,
                    child: Text(
                      dayNames[idx],
                      style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: HabitosColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 6,
                        backgroundColor: HabitosColors.primaryLight,
                        color: HabitosColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800, color: HabitosColors.textPrimary),
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
    // Grupo sin tarjeta.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODOS LOS HÁBITOS',
            style: TextStyle(
              fontSize: OrtizFontSize.caption,
              fontWeight: FontWeight.w800,
              color: HabitosColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: OrtizSpace.xxs),
          const Text(
            'Rachas y Rendimiento',
            style: TextStyle(
              fontSize: OrtizFontSize.titleSm,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: OrtizSpace.md),
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
              borderRadius: BorderRadius.circular(OrtizRadius.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.xs),
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
                        size: OrtizIconSize.sm,
                        color: h.isNegative ? HabitosColors.amber : HabitosColors.primary,
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        h.title,
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: HabitosColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: h.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                      child: Text(
                        h.isNegative ? '$cleanDays d invicto' : '$streak d racha',
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w800,
                          color: h.isNegative ? HabitosColors.amber : HabitosColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.xs),
                    const Icon(Icons.chevron_right_rounded, size: OrtizIconSize.sm, color: HabitosColors.textMuted),
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
