import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/reminder_editor_dialog.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class CoveyMatrixView extends StatefulWidget {
  const CoveyMatrixView({super.key});

  @override
  State<CoveyMatrixView> createState() => _CoveyMatrixViewState();
}

class _CoveyMatrixViewState extends State<CoveyMatrixView> {
  CoveyQuadrant _selectedQuadrantMobile = CoveyQuadrant.q2ImportantNotUrgent;

  void _openEditor(BuildContext context, ReminderModel reminder) {
    showDialog(
      context: context,
      builder: (ctx) => ReminderEditorDialog(reminder: reminder),
    );
  }

  void _showMoveQuadrantModal(BuildContext context, RemindersState state, ReminderModel reminder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.dialog))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      'Reclasificar "${reminder.title}" a:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CoveyQuadrant.values.map((q) {
                  final isCurrent = reminder.quadrant == q;
                  return ActionChip(
                    avatar: isCurrent ? const Icon(Icons.check, size: OrtizIconSize.xs, color: OrtizPalette.onAccent) : null,
                    label: Text('${q.shortLabel} - ${q.title}'),
                    backgroundColor: isCurrent ? q.color : q.color.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? OrtizPalette.onAccent : q.color,
                    ),
                    onPressed: () {
                      state.moveReminderToQuadrant(reminder.id, q);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: OrtizSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final q2Percentage = state.q2FocusPercentage;
    final t = OrtizTokens.of(context);
    // Foco en C2: verde si llega a la meta (65 %), ámbar si no.
    final focusColor = q2Percentage >= 65 ? t.ok : t.warn;
    final okTint = t.ok.withValues(alpha: 0.16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return Column(
          children: [
            // Banner Superior de Métricas Covey (sobre el fondo, sin tarjeta)
            Container(
              margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.sm),
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: okTint,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: const Icon(Icons.grid_view_rounded, color: OrtizPalette.ok, size: OrtizIconSize.sm),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            const Expanded(
                              child: Text(
                                'Matriz Stephen Covey (Hábito 3)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: OrtizFontSize.bodySm,
                                  color: RemindersColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${q2Percentage.toStringAsFixed(0)}% en C2',
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: focusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          child: LinearProgressIndicator(
                            value: (q2Percentage / 100).clamp(0.0, 1.0),
                            backgroundColor: t.line,
                            minHeight: 6,
                            valueColor: AlwaysStoppedAnimation<Color>(focusColor),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: okTint,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: OrtizPalette.ok, size: OrtizIconSize.md),
                        ),
                        const SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Matriz de Administración del Tiempo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: OrtizFontSize.body,
                                      color: RemindersColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: OrtizSpace.sm),
                                  Text(
                                    'Stephen Covey (Hábito 3)',
                                    style: TextStyle(fontSize: OrtizFontSize.caption, color: t.muted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: OrtizSpace.xs),
                              Text(
                                'Arrastra tarjetas entre cuadrantes para reclasificarlas. Tu objetivo es maximizar el tiempo en el Cuadrante II.',
                                style: TextStyle(fontSize: OrtizFontSize.caption, color: t.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.lg),
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
                                    fontSize: OrtizFontSize.titleSm,
                                    fontWeight: FontWeight.bold,
                                    color: focusColor,
                                  ),
                                ),
                                const SizedBox(width: OrtizSpace.xs),
                                const Text(
                                  'en C2',
                                  style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: OrtizSpace.xs),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              child: SizedBox(
                                width: 100,
                                height: 6,
                                child: LinearProgressIndicator(
                                  value: (q2Percentage / 100).clamp(0.0, 1.0),
                                  backgroundColor: t.line,
                                  valueColor: AlwaysStoppedAnimation<Color>(focusColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            // Contenido de la Matriz (Adaptativo para Mobile vs Desktop)
            Expanded(
              child: isMobile
                  ? _buildMobileMatrixContent(context, state)
                  : _buildDesktopMatrixContent(context, state),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // VISTA MÓVIL: Selector de Cuadrantes + Tarjeta Completa
  // ===========================================================================
  Widget _buildMobileMatrixContent(BuildContext context, RemindersState state) {
    final t = OrtizTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xs),
      child: Column(
        children: [
          // Selector horizontal de los 4 cuadrantes
          Container(
            padding: const EdgeInsets.all(OrtizSpace.xs),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(OrtizRadius.field),
              border: Border.all(color: t.line),
            ),
            child: Row(
              children: CoveyQuadrant.values.map((q) {
                final isSelected = q == _selectedQuadrantMobile;
                final count = state.remindersForQuadrant(q).length;
                final isQ2 = q == CoveyQuadrant.q2ImportantNotUrgent;

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedQuadrantMobile = q),
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs, horizontal: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: isSelected ? t.surfaceHigh : Colors.transparent,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        border: isSelected && isQ2
                            ? Border.all(color: t.ok, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                q.shortLabel,
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? q.color : t.muted,
                                ),
                              ),
                              if (isQ2) ...[
                                const SizedBox(width: OrtizSpace.xxs),
                                const Icon(Icons.star, size: OrtizIconSize.xs, color: OrtizPalette.warn),
                              ],
                            ],
                          ),
                          const SizedBox(height: OrtizSpace.xxs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: isSelected ? q.color.withValues(alpha: 0.12) : t.surfaceHigh,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? q.color : t.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: OrtizSpace.sm),

          // Tarjeta del Cuadrante Seleccionado
          Expanded(
            child: _buildQuadrantCard(
              context,
              state,
              _selectedQuadrantMobile,
              isHighlighted: _selectedQuadrantMobile == CoveyQuadrant.q2ImportantNotUrgent,
              isMobile: true,
            ),
          ),
          const SizedBox(height: OrtizSpace.md),
        ],
      ),
    );
  }

  // ===========================================================================
  // VISTA DESKTOP: Matriz 2x2 Clásica
  // ===========================================================================
  Widget _buildDesktopMatrixContent(BuildContext context, RemindersState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
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
                    isMobile: false,
                  ),
                ),
                const SizedBox(height: OrtizSpace.md),
                Expanded(
                  child: _buildQuadrantCard(
                    context,
                    state,
                    CoveyQuadrant.q3UrgentNotImportant,
                    isHighlighted: false,
                    isMobile: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: OrtizSpace.md),
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
                    isMobile: false,
                  ),
                ),
                const SizedBox(height: OrtizSpace.md),
                Expanded(
                  child: _buildQuadrantCard(
                    context,
                    state,
                    CoveyQuadrant.q4NotUrgentNotImportant,
                    isHighlighted: false,
                    isMobile: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TARJETA DE CUADRANTE COVEY
  // ===========================================================================
  Widget _buildQuadrantCard(
    BuildContext context,
    RemindersState state,
    CoveyQuadrant quadrant, {
    required bool isHighlighted,
    required bool isMobile,
  }) {
    final reminders = state.remindersForQuadrant(quadrant);
    final t = OrtizTokens.of(context);

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
                ? quadrant.color.withValues(alpha: 0.08)
                : isHighlighted
                    ? t.surfaceHigh
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(
              color: isDroppingHere
                  ? quadrant.color
                  : isHighlighted
                      ? t.ok
                      : t.line,
              width: isHighlighted || isDroppingHere ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado del Cuadrante
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: isHighlighted ? t.ok.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.field)),
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: quadrant.color,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                          child: Text(
                            quadrant.shortLabel,
                            style: const TextStyle(
                              color: OrtizPalette.onAccent,
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.sm),
                        Text(
                          quadrant.title,
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? t.ok : RemindersColors.textPrimary,
                          ),
                        ),
                        if (isHighlighted) ...[
                          const SizedBox(width: OrtizSpace.xs),
                          const Icon(Icons.star, size: OrtizIconSize.sm, color: OrtizPalette.warn),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: t.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                          child: Text(
                            '${reminders.length}',
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                              color: t.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.xs),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              color: RemindersColors.primary, size: OrtizIconSize.md),
                          tooltip: 'Nueva tarea en este cuadrante',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ReminderEditorDialog(
                                quadrant: quadrant,
                                isBigRock: quadrant == CoveyQuadrant.q2ImportantNotUrgent,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Subtítulo con la esencia del cuadrante
              Padding(
                padding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.xs, OrtizSpace.md, OrtizSpace.xs),
                child: Text(
                  quadrant.description,
                  style: TextStyle(fontSize: OrtizFontSize.caption, color: t.muted, fontStyle: FontStyle.italic),
                ),
              ),

              // Lista de Tareas en este Cuadrante
              Expanded(
                child: reminders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(OrtizSpace.xl),
                          child: Text(
                            isHighlighted
                                ? '⭐ Este es el corazón de tu efectividad.\nAgrega o arrastra metas y Grandes Rocas aquí.'
                                : 'No hay actividades en este cuadrante',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              color: isHighlighted ? t.ok : t.muted,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(OrtizSpace.sm),
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          final role = state.getRoleById(reminder.roleId);

                          return Draggable<ReminderModel>(
                            data: reminder,
                            feedback: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.all(OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: t.surfaceHigh,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                  border: Border.all(color: quadrant.color, width: 2),
                                ),
                                child: Text(
                                  reminder.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildReminderCard(context, state, reminder, role, isMobile: isMobile),
                            ),
                            child: _buildReminderCard(context, state, reminder, role, isMobile: isMobile),
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
    RoleModel? role, {
    required bool isMobile,
  }) {
    final t = OrtizTokens.of(context);
    // Fila sin tarjeta: las Grandes Rocas se distinguen con el tono ámbar.
    return Padding(
      padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
      child: Material(
      color: reminder.isBigRock ? OrtizPalette.warnTint : Colors.transparent,
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: InkWell(
        onTap: () => _openEditor(context, reminder),
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => state.toggleCompleted(reminder.id),
                    child: Icon(
                      reminder.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: OrtizIconSize.sm,
                      color: reminder.isCompleted ? t.ok : t.muted,
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.w600,
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        color: reminder.isCompleted ? t.muted : RemindersColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.toggleBigRock(reminder.id),
                    child: Icon(
                      reminder.isBigRock ? Icons.star : Icons.star_border,
                      size: OrtizIconSize.sm,
                      color: reminder.isBigRock ? t.warn : t.muted,
                    ),
                  ),
                  if (isMobile)
                    InkWell(
                      onTap: () => _showMoveQuadrantModal(context, state, reminder),
                      child: const Padding(
                        padding: EdgeInsets.only(left: OrtizSpace.xs),
                        child: Icon(Icons.more_vert_rounded, size: OrtizIconSize.sm, color: OrtizPalette.muted),
                      ),
                    ),
                ],
              ),
              if (role != null || reminder.dueAt != null) ...[
                const SizedBox(height: OrtizSpace.xs),
                Row(
                  children: [
                    if (role != null) ...[
                      Icon(role.iconData, size: OrtizIconSize.xs, color: role.color),
                      const SizedBox(width: OrtizSpace.xs),
                      Text(
                        role.name,
                        style: TextStyle(fontSize: OrtizFontSize.caption, color: role.color, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: OrtizSpace.sm),
                    ],
                    if (reminder.isPinned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs, vertical: OrtizSpace.xxs),
                        decoration: BoxDecoration(
                          color: RemindersColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icono al tamaño del texto micro de la etiqueta.
                            Icon(Icons.push_pin_rounded, size: OrtizFontSize.micro, color: RemindersColors.primary),
                            SizedBox(width: OrtizSpace.xxs),
                            Text(
                              'Fijado',
                              style: TextStyle(
                                fontSize: OrtizFontSize.micro,
                                fontWeight: FontWeight.bold,
                                color: RemindersColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: OrtizSpace.xs),
                    ],
                    if (reminder.dueAt != null)
                      Text(
                        reminder.formattedDueTime,
                        style: TextStyle(fontSize: OrtizFontSize.caption, color: t.muted),
                      ),
                    const Spacer(),
                    Text(
                      '~${reminder.estimatedDurationMinutes}m',
                      style: TextStyle(fontSize: OrtizFontSize.caption, color: t.muted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
