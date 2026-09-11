import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import 'habit_terminal_editor_dialog.dart';

class HabitDetailCliDialog extends StatelessWidget {
  final HabitModel habit;

  const HabitDetailCliDialog({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final streak = state.calculateCurrentStreak(habit.id);
    final resilience = state.calculateResilienceScore(habit.id);
    final cleanDays = habit.isNegative ? state.calculateCleanDays(habit.id) : null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Minimalista
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: habit.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      habit.isNegative ? Icons.shield_outlined : Icons.track_changes_rounded,
                      color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: HabitosColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (habit.description != null && habit.description!.isNotEmpty)
                          Text(
                            habit.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: HabitosColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: HabitosColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: HabitosColors.cardBorder),

            // Contenido de estadísticas
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Resumen Métricas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HabitosColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HabitosColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _metricRow('Tipo de hábito', habit.type.label),
                          const Divider(height: 16, color: HabitosColors.cardBorder),
                          if (habit.isNegative) ...[
                            _metricRow('Días libre de recaída', '$cleanDays días invicto', isHighlight: true),
                            const Divider(height: 16, color: HabitosColors.cardBorder),
                          ] else ...[
                            _metricRow('Racha actual', '$streak días seguidos', isHighlight: true),
                            const Divider(height: 16, color: HabitosColors.cardBorder),
                          ],
                          _metricRow('Consistencia a 30 días', '${resilience.toStringAsFixed(0)}% de cumplimiento'),
                          if (habit.type == HabitType.quantitative) ...[
                            const Divider(height: 16, color: HabitosColors.cardBorder),
                            _metricRow('Meta diaria', '${habit.targetValue.toInt()} ${habit.unit ?? ""}'),
                          ],
                          if (habit.type == HabitType.timer) ...[
                            const Divider(height: 16, color: HabitosColors.cardBorder),
                            _metricRow('Tiempo objetivo', '${(habit.targetValue / 60).round()} minutos'),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Matriz de los últimos 30 días
                    const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 16, color: HabitosColors.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'Actividad de los últimos 30 días',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: HabitosColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _build30DayGrid(context, state),
                  ],
                ),
              ),
            ),

            // Acciones inferiores (Eliminar & Editar)
            const Divider(height: 1, color: HabitosColors.cardBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: HabitosColors.rose),
                    label: const Text('Eliminar', style: TextStyle(color: HabitosColors.rose, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text(
                            '¿Eliminar hábito?',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                          content: Text(
                            'Se eliminarán el hábito "${habit.title}" y todos sus registros históricos.',
                            style: const TextStyle(fontSize: 13, color: HabitosColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar', style: TextStyle(color: HabitosColors.textSecondary)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HabitosColors.rose,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        state.deleteHabit(habit.id);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar Hábito', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HabitosColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => HabitTerminalEditorDialog(habit: habit),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: HabitosColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isHighlight ? HabitosColors.primary : HabitosColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _build30DayGrid(BuildContext context, HabitosState state) {
    final now = DateTime.now();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(30, (i) {
        final date = now.subtract(Duration(days: 29 - i));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isCompleted = state.isCompleted(habit.id, dateStr);

        Color boxColor = const Color(0xFFF3F4F6); // Gris suave no completado
        if (isCompleted) {
          boxColor = HabitosColors.primary;
        }

        return Tooltip(
          message: "$dateStr: ${isCompleted ? 'Completado' : 'No completado'}",
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted ? HabitosColors.primary : HabitosColors.cardBorder,
                width: 1,
              ),
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isCompleted ? Colors.white : HabitosColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}
