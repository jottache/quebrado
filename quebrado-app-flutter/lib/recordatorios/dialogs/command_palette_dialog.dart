import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../services/nlp_parser.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _input = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _input = _controller.text;
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleCreateFromInput(RemindersState state) {
    if (_input.trim().isEmpty) return;
    state.createFromNlp(_input.trim());
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recordatorio creado: "${_input.trim()}"'),
        backgroundColor: RemindersColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final nlpResult = _input.trim().isNotEmpty ? NlpParser.parse(_input.trim()) : null;

    // Buscar recordatorios existentes que coincidan
    final matchingReminders = _input.trim().isEmpty
        ? <ReminderModel>[]
        : state.allReminders
            .where((r) =>
                r.title.toLowerCase().contains(_input.toLowerCase()) ||
                r.tags.any((t) => t.toLowerCase().contains(_input.toLowerCase())))
            .take(5)
            .toList();

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: OrtizSpace.xxxl + OrtizSpace.xxxl + OrtizSpace.lg, left: OrtizSpace.lg, right: OrtizSpace.lg, bottom: OrtizSpace.xxl),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Container(
          // La paleta flota sobre `surface` (como hojas y diálogos), sin sombra.
          decoration: BoxDecoration(
            color: RemindersColors.cardSurface,
            borderRadius: BorderRadius.circular(OrtizRadius.dialog),
            border: Border.all(color: RemindersColors.cardBorder, width: OrtizStroke.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search / Command Input Header
              Padding(
                padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.md),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: RemindersColors.primary, size: OrtizIconSize.lg),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: OrtizFontSize.titleSm,
                          fontWeight: FontWeight.w600,
                          color: RemindersColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Escribe un recordatorio o comando (ej. Reunión mañana 10am !p1)...',
                          hintStyle: TextStyle(fontSize: OrtizFontSize.body, color: RemindersColors.textMuted, fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _handleCreateFromInput(state),
                      ),
                    ),
                    if (_input.isNotEmpty)
                      GestureDetector(
                        onTap: () => _controller.clear(),
                        child: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: RemindersColors.textMuted),
                      ),
                    const SizedBox(width: OrtizSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: OrtizPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        border: Border.all(color: RemindersColors.cardBorder),
                      ),
                      child: const Text(
                        'ESC',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: RemindersColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: RemindersColors.cardBorder),

              // NLP Realtime Token Chips Preview
              if (nlpResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                  color: RemindersColors.primaryLight.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      const Text(
                        'NLP Detectado:',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: RemindersColors.primary),
                      ),
                      const SizedBox(width: OrtizSpace.sm),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (nlpResult.dueAt != null)
                              _buildTokenChip(
                                icon: Icons.alarm_rounded,
                                label: nlpResult.matchedDateText ?? 'Fecha detectada',
                                color: RemindersColors.primary,
                              ),
                            if (nlpResult.isRecurring)
                              _buildTokenChip(
                                icon: Icons.repeat_rounded,
                                label: nlpResult.matchedRecurrenceText ?? nlpResult.recurrence.shortLabel,
                                color: RemindersColors.primary,
                              ),
                            _buildTokenChip(
                              icon: Icons.flag_rounded,
                              label: nlpResult.priority.label,
                              color: nlpResult.priority.color,
                            ),
                            ...nlpResult.tags.map(
                              (t) => _buildTokenChip(
                                icon: Icons.tag_rounded,
                                label: t,
                                color: RemindersColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _handleCreateFromInput(state),
                        icon: const Icon(Icons.keyboard_return_rounded, size: OrtizIconSize.sm),
                        label: const Text('Crear', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: RemindersColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

              // Command List & Search Results
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                  shrinkWrap: true,
                  children: [
                    // Acción de creación directa si hay texto
                    if (_input.trim().isNotEmpty)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(OrtizSpace.xs),
                          decoration: BoxDecoration(
                            color: RemindersColors.primaryLight,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                          child: const Icon(Icons.add_task_rounded, color: RemindersColors.primary, size: OrtizIconSize.md),
                        ),
                        title: RichText(
                          text: TextSpan(
                            text: 'Crear recordatorio: ',
                            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary),
                            children: [
                              TextSpan(
                                text: '"${nlpResult?.cleanTitle ?? _input.trim()}"',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Text('Enter ↵', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
                        onTap: () => _handleCreateFromInput(state),
                      ),

                    // Coincidencias existentes
                    if (matchingReminders.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.xs),
                        child: Text(
                          'RECORDATORIOS EXISTENTES',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: RemindersColors.textMuted, letterSpacing: 0.5),
                        ),
                      ),
                      ...matchingReminders.map(
                        (r) => ListTile(
                          dense: true,
                          leading: Icon(
                            r.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: r.isCompleted ? RemindersColors.completed : r.priority.color,
                            size: OrtizIconSize.md,
                          ),
                          title: Text(
                            r.title,
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.w600,
                              decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            r.formattedDueTime,
                            style: const TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.snooze_rounded, size: OrtizIconSize.md, color: RemindersColors.snoozed),
                            tooltip: 'Posponer +1 hora',
                            onPressed: () {
                              state.snoozeRelative(r.id, const Duration(hours: 1));
                              Navigator.of(context).pop();
                            },
                          ),
                          onTap: () {
                            state.toggleCompleted(r.id);
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],

                    // Acciones Rápidas del Sistema
                    const Padding(
                      padding: EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.xs),
                      child: Text(
                        'ACCIONES RÁPIDAS',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: RemindersColors.textMuted, letterSpacing: 0.5),
                      ),
                    ),

                    if (state.overdueCount > 0)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.next_plan_outlined, color: RemindersColors.overdue, size: OrtizIconSize.md),
                        title: Text(
                          'Posponer todos los vencidos (${state.overdueCount}) a mañana 9:00 AM',
                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          state.snoozeAllOverdueToTomorrow();
                          Navigator.of(context).pop();
                        },
                      ),

                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.filter_alt_outlined, color: RemindersColors.primary, size: OrtizIconSize.md),
                      title: const Text('Filtrar solo prioritarios (P1 Urgente y P2 Alta)', style: TextStyle(fontSize: OrtizFontSize.bodySm)),
                      onTap: () {
                        state.setPriorityFilter(ReminderPriority.p1Urgent);
                        Navigator.of(context).pop();
                      },
                    ),

                    if (state.selectedPriorityFilter != null || state.selectedTagFilter != null || state.searchQuery.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.filter_list_off_rounded, color: RemindersColors.textSecondary, size: OrtizIconSize.md),
                        title: const Text('Limpiar todos los filtros activos', style: TextStyle(fontSize: OrtizFontSize.bodySm)),
                        onTap: () {
                          state.clearFilters();
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),

              // Footer Bar with Shortcut Hints
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                decoration: const BoxDecoration(
                  color: RemindersColors.background,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(OrtizRadius.dialog)),
                  border: Border(top: BorderSide(color: RemindersColors.cardBorder)),
                ),
                child: Row(
                  children: [
                    _buildKeyBadge('↵ Enter', 'Crear / Seleccionar'),
                    const SizedBox(width: OrtizSpace.md),
                    _buildKeyBadge('ESC', 'Cerrar'),
                    const Spacer(),
                    const Text(
                      'OrtizApp Reminders',
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w600, color: RemindersColors.textMuted),
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

  Widget _buildTokenChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: OrtizIconSize.xs, color: color),
          const SizedBox(width: OrtizSpace.xs),
          Text(
            label,
            style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBadge(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
          decoration: BoxDecoration(
            color: OrtizPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            border: Border.all(color: RemindersColors.cardBorder),
          ),
          child: Text(key, style: const TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
        ),
        const SizedBox(width: OrtizSpace.xs),
        Text(label, style: const TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
      ],
    );
  }
}
