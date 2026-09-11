import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../services/nlp_parser.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

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
      insetPadding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RemindersColors.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search / Command Input Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: RemindersColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: RemindersColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Escribe un recordatorio o comando (ej. Reunión mañana 10am !p1)...',
                          hintStyle: TextStyle(fontSize: 14, color: RemindersColors.textMuted, fontWeight: FontWeight.normal),
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
                        child: const Icon(Icons.close_rounded, size: 18, color: RemindersColors.textMuted),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'ESC',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: RemindersColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: RemindersColors.cardBorder),

              // NLP Realtime Token Chips Preview
              if (nlpResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: RemindersColors.primaryLight.withOpacity(0.5),
                  child: Row(
                    children: [
                      const Text(
                        'NLP Detectado:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: RemindersColors.primary),
                      ),
                      const SizedBox(width: 8),
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
                        icon: const Icon(Icons.keyboard_return_rounded, size: 14),
                        label: const Text('Crear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: RemindersColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  children: [
                    // Acción de creación directa si hay texto
                    if (_input.trim().isNotEmpty)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: RemindersColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_task_rounded, color: RemindersColors.primary, size: 18),
                        ),
                        title: RichText(
                          text: TextSpan(
                            text: 'Crear recordatorio: ',
                            style: const TextStyle(fontSize: 13, color: RemindersColors.textSecondary),
                            children: [
                              TextSpan(
                                text: '"${nlpResult?.cleanTitle ?? _input.trim()}"',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Text('Enter ↵', style: TextStyle(fontSize: 11, color: RemindersColors.textMuted)),
                        onTap: () => _handleCreateFromInput(state),
                      ),

                    // Coincidencias existentes
                    if (matchingReminders.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          'RECORDATORIOS EXISTENTES',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: RemindersColors.textMuted, letterSpacing: 0.5),
                        ),
                      ),
                      ...matchingReminders.map(
                        (r) => ListTile(
                          dense: true,
                          leading: Icon(
                            r.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: r.isCompleted ? RemindersColors.completed : r.priority.color,
                            size: 20,
                          ),
                          title: Text(
                            r.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            r.formattedDueTime,
                            style: const TextStyle(fontSize: 11, color: RemindersColors.textMuted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.snooze_rounded, size: 18, color: RemindersColors.snoozed),
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
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        'ACCIONES RÁPIDAS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: RemindersColors.textMuted, letterSpacing: 0.5),
                      ),
                    ),

                    if (state.overdueCount > 0)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.next_plan_outlined, color: RemindersColors.overdue, size: 20),
                        title: Text(
                          'Posponer todos los vencidos (${state.overdueCount}) a mañana 9:00 AM',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          state.snoozeAllOverdueToTomorrow();
                          Navigator.of(context).pop();
                        },
                      ),

                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.filter_alt_outlined, color: RemindersColors.primary, size: 20),
                      title: const Text('Filtrar solo prioritarios (P1 Urgente y P2 Alta)', style: TextStyle(fontSize: 13)),
                      onTap: () {
                        state.setPriorityFilter(ReminderPriority.p1Urgent);
                        Navigator.of(context).pop();
                      },
                    ),

                    if (state.selectedPriorityFilter != null || state.selectedTagFilter != null || state.searchQuery.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.filter_list_off_rounded, color: Colors.grey, size: 20),
                        title: const Text('Limpiar todos los filtros activos', style: TextStyle(fontSize: 13)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: RemindersColors.background,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: RemindersColors.cardBorder)),
                ),
                child: Row(
                  children: [
                    _buildKeyBadge('↵ Enter', 'Crear / Seleccionar'),
                    const SizedBox(width: 14),
                    _buildKeyBadge('ESC', 'Cerrar'),
                    const Spacer(),
                    const Text(
                      'OrtizApp Reminders',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: RemindersColors.textMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(key, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: RemindersColors.textMuted)),
      ],
    );
  }
}
