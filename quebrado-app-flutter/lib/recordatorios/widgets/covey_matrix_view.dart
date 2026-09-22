import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/reminder_editor_dialog.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

class CoveyMatrixView extends StatelessWidget {
  const CoveyMatrixView({super.key});

  void _openEditor(BuildContext context, ReminderModel reminder) {
    showDialog(
      context: context,
      builder: (ctx) => ReminderEditorDialog(reminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final q2Percentage = state.q2FocusPercentage;

    return Column(
      children: [
        // Banner Superior de Métricas Covey
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grid_view_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Matriz de Administración del Tiempo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RemindersColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stephen Covey (Hábito 3)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrastra tarjetas entre cuadrantes para reclasificarlas. Tu objetivo es maximizar el tiempo en el Cuadrante II.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Indicador de Foco en Cuadrante II
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${q2Percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: q2Percentage >= 65 ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'en C2',
                        style: TextStyle(fontSize: 11, color: RemindersColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 100,
                      height: 6,
                      child: LinearProgressIndicator(
                        value: (q2Percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          q2Percentage >= 65 ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Matriz 2x2 Responsive
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Columna 1: Urgente (Q1 arriba, Q3 abajo)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildQuadrantCard(
                          context,
                          state,
                          CoveyQuadrant.q1UrgentImportant,
                          isHighlighted: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildQuadrantCard(
                          context,
                          state,
                          CoveyQuadrant.q3UrgentNotImportant,
                          isHighlighted: false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Columna 2: No Urgente (Q2 arriba [DESTACADO], Q4 abajo)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildQuadrantCard(
                          context,
                          state,
                          CoveyQuadrant.q2ImportantNotUrgent,
                          isHighlighted: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildQuadrantCard(
                          context,
                          state,
                          CoveyQuadrant.q4NotUrgentNotImportant,
                          isHighlighted: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrantCard(
    BuildContext context,
    RemindersState state,
    CoveyQuadrant quadrant, {
    required bool isHighlighted,
  }) {
    final reminders = state.remindersForQuadrant(quadrant);

    return DragTarget<ReminderModel>(
      onWillAcceptWithDetails: (details) => details.data.quadrant != quadrant,
      onAcceptWithDetails: (details) {
        state.moveReminderToQuadrant(details.data.id, quadrant);
      },
      builder: (context, candidateData, rejectedData) {
        final isDroppingHere = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDroppingHere
                ? quadrant.color.withOpacity(0.08)
                : isHighlighted
                    ? const Color(0xFFF9FBF9)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDroppingHere
                  ? quadrant.color
                  : isHighlighted
                      ? const Color(0xFF059669)
                      : Colors.grey.shade300,
              width: isHighlighted || isDroppingHere ? 2 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado del Cuadrante
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isHighlighted ? const Color(0xFFECFDF5) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: quadrant.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            quadrant.shortLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          quadrant.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? const Color(0xFF065F46) : RemindersColors.textPrimary,
                          ),
                        ),
                        if (isHighlighted) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${reminders.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Subtítulo con la esencia del cuadrante
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Text(
                  quadrant.description,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ),

              // Lista de Tareas en este Cuadrante
              Expanded(
                child: reminders.isEmpty
                    ? Center(
                        child: Text(
                          isHighlighted
                              ? '⭐ Este es el corazón de tu efectividad.\nAgrega o arrastra metas de alto valor aquí.'
                              : 'No hay actividades en este cuadrante',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isHighlighted ? const Color(0xFF059669).withOpacity(0.7) : Colors.grey.shade400,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          final role = state.getRoleById(reminder.roleId);

                          return Draggable<ReminderModel>(
                            data: reminder,
                            feedback: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: quadrant.color, width: 2),
                                ),
                                child: Text(
                                  reminder.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildReminderCard(context, state, reminder, role),
                            ),
                            child: _buildReminderCard(context, state, reminder, role),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    RemindersState state,
    ReminderModel reminder,
    dynamic role,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: reminder.isBigRock ? const Color(0xFFF59E0B) : Colors.grey.shade200,
          width: reminder.isBigRock ? 1.5 : 1,
        ),
      ),
      color: reminder.isBigRock ? const Color(0xFFFFFBEB) : Colors.white,
      child: InkWell(
        onTap: () => _openEditor(context, reminder),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => state.toggleCompleted(reminder.id),
                    child: Icon(
                      reminder.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: reminder.isCompleted ? Colors.green : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        color: reminder.isCompleted ? Colors.grey : RemindersColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.toggleBigRock(reminder.id),
                    child: Icon(
                      reminder.isBigRock ? Icons.star : Icons.star_border,
                      size: 16,
                      color: reminder.isBigRock ? const Color(0xFFD97706) : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              if (role != null || reminder.dueAt != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (role != null) ...[
                      Icon(role.iconData, size: 12, color: role.color),
                      const SizedBox(width: 4),
                      Text(
                        role.name,
                        style: TextStyle(fontSize: 10, color: role.color, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (reminder.dueAt != null)
                      Text(
                        reminder.formattedDueTime,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    const Spacer(),
                    Text(
                      '~${reminder.estimatedDurationMinutes}m',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
