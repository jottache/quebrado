import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class ReminderEditorDialog extends StatefulWidget {
  final ReminderModel? reminder;
  final int? scheduledDayOfWeek;
  final bool? isBigRock;
  final String? roleId;
  final CoveyQuadrant? quadrant;

  const ReminderEditorDialog({
    super.key,
    this.reminder,
    this.scheduledDayOfWeek,
    this.isBigRock,
    this.roleId,
    this.quadrant,
  });

  @override
  State<ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<ReminderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _tagInputController;
  late ReminderPriority _priority;
  late ReminderRecurrence _recurrence;
  late bool _isNagging;
  late int _nagIntervalMinutes;
  late bool _isPinned;
  DateTime? _dueAt;
  late List<String> _tags;
  String? _roleId;
  late CoveyQuadrant _quadrant;
  late bool _isBigRock;
  late int _estimatedDurationMinutes;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _titleController = TextEditingController(text: r?.title ?? '');
    _notesController = TextEditingController(text: r?.notes ?? '');
    _tagInputController = TextEditingController();
    _priority = r?.priority ?? ReminderPriority.p3Medium;
    _recurrence = r?.recurrence ?? ReminderRecurrence.none;
    _isNagging = r?.isNagging ?? false;
    _nagIntervalMinutes = r?.nagIntervalMinutes ?? 10;
    _isPinned = r?.isPinned ?? false;
    _dueAt = r?.dueAt;
    _tags = r?.tags != null ? List<String>.from(r!.tags) : [];
    _roleId = r?.roleId ?? widget.roleId;
    _quadrant = r?.quadrant ?? widget.quadrant ?? CoveyQuadrant.q2ImportantNotUrgent;
    _isBigRock = r?.isBigRock ?? widget.isBigRock ?? false;
    _estimatedDurationMinutes = r?.estimatedDurationMinutes ?? 30;

    if (r == null && widget.scheduledDayOfWeek != null) {
      // El día corresponde a la semana que se está viendo en la agenda, no siempre a la actual.
      final monday = Provider.of<RemindersState>(context, listen: false).currentMonday;
      _dueAt = DateTime(monday.year, monday.month, monday.day + widget.scheduledDayOfWeek!, 9, 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final datePicked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'Fecha del Recordatorio',
      confirmText: 'Siguiente',
      cancelText: 'Cancelar',
    );

    if (datePicked == null) return;
    if (!mounted) return;

    final timePicked = await showTimePicker(
      context: context,
      initialTime: _dueAt != null
          ? TimeOfDay(hour: _dueAt!.hour, minute: _dueAt!.minute)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Hora del Recordatorio',
      confirmText: 'Aceptar',
      cancelText: 'Omitir Hora',
    );

    setState(() {
      if (timePicked != null) {
        _dueAt = DateTime(
          datePicked.year,
          datePicked.month,
          datePicked.day,
          timePicked.hour,
          timePicked.minute,
        );
      } else {
        _dueAt = DateTime(datePicked.year, datePicked.month, datePicked.day, 9, 0);
      }
    });
  }

  void _addTag() {
    final text = _tagInputController.text.trim().replaceAll('#', '').toLowerCase();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final state = Provider.of<RemindersState>(context, listen: false);

    final reminder = ReminderModel(
      id: widget.reminder?.id ?? const Uuid().v4(),
      userId: widget.reminder?.userId,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      priority: _priority,
      status: widget.reminder?.status ?? ReminderStatus.pending,
      dueAt: _dueAt,
      rrule: _recurrence.rruleString,
      isNagging: _isNagging,
      nagIntervalMinutes: _nagIntervalMinutes,
      isPinned: _isPinned,
      tags: _tags,
      roleId: _roleId,
      weeklyPlanId: widget.reminder?.weeklyPlanId ?? state.currentWeeklyPlan?.id,
      quadrant: _quadrant,
      isBigRock: _isBigRock,
      scheduledDayOfWeek: _dueAt != null
          ? _dueAt!.weekday - 1
          : (widget.reminder?.scheduledDayOfWeek ?? widget.scheduledDayOfWeek),
      estimatedDurationMinutes: _estimatedDurationMinutes,
      createdAt: widget.reminder?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state.saveReminder(reminder);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reminder != null;

    return Dialog(
      backgroundColor: RemindersColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: RemindersColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: const Icon(Icons.alarm_add_rounded, color: RemindersColors.primary, size: OrtizIconSize.lg),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Recordatorio' : 'Nuevo Recordatorio',
                          style: const TextStyle(
                            fontSize: OrtizFontSize.title,
                            fontWeight: FontWeight.w900,
                            color: RemindersColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEditing ? 'Ajusta la programación y detalles' : 'Configura fecha, hora y nivel de urgencia',
                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: OrtizSpace.lg),

              // Formulario
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Título
                        TextFormField(
                          controller: _titleController,
                          autofocus: !isEditing,
                          decoration: InputDecoration(
                            labelText: 'Título del Recordatorio *',
                            hintText: 'Ej: Pagar servicio de electricidad',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: RemindersColors.background,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El título es obligatorio' : null,
                        ),

                        const SizedBox(height: OrtizSpace.md),

                        // Notas
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Notas o detalles adicionales (opcional)',
                            hintText: 'Ej: Incluir número de contrato y soporte de pago...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: RemindersColors.background,
                          ),
                        ),

                        const SizedBox(height: OrtizSpace.lg),

                        // Rol Vital & Cuadrante Covey (Hábito 3)
                        Consumer<RemindersState>(
                          builder: (context, state, _) {
                            final roles = state.roles;
                            return Container(
                              padding: const EdgeInsets.all(OrtizSpace.md),
                              decoration: BoxDecoration(
                                color: RemindersColors.background,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                border: Border.all(color: RemindersColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.pie_chart_outline, color: RemindersColors.primary, size: OrtizIconSize.md),
                                      SizedBox(width: OrtizSpace.sm),
                                      Text(
                                        'Rol Vital y Cuadrante Covey',
                                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: OrtizSpace.sm),
                                  // Selector de Rol
                                  const Text('Rol asignado:', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
                                  const SizedBox(height: OrtizSpace.xs),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Sin rol', style: TextStyle(fontSize: OrtizFontSize.caption)),
                                        selected: _roleId == null,
                                        onSelected: (_) => setState(() => _roleId = null),
                                      ),
                                      ...roles.map((r) {
                                        final isSelected = _roleId == r.id;
                                        return ChoiceChip(
                                          avatar: Icon(r.iconData, size: OrtizIconSize.sm, color: isSelected ? OrtizPalette.onAccent : r.color),
                                          label: Text(r.name, style: const TextStyle(fontSize: OrtizFontSize.caption)),
                                          selected: isSelected,
                                          selectedColor: r.color,
                                          labelStyle: TextStyle(color: isSelected ? OrtizPalette.onAccent : RemindersColors.textPrimary),
                                          onSelected: (_) => setState(() => _roleId = r.id),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: OrtizSpace.md),
                                  // Selector de Cuadrante
                                  const Text('Cuadrante:', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
                                  const SizedBox(height: OrtizSpace.xs),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: CoveyQuadrant.values.map((q) {
                                      final isSelected = _quadrant == q;
                                      return ChoiceChip(
                                        avatar: isSelected ? const Icon(Icons.check, size: OrtizIconSize.sm, color: OrtizPalette.onAccent) : null,
                                        label: Text(
                                          '${q.shortLabel} ${q.title}',
                                          style: const TextStyle(fontSize: OrtizFontSize.caption),
                                        ),
                                        selected: isSelected,
                                        selectedColor: q.color,
                                        labelStyle: TextStyle(
                                          color: isSelected ? OrtizPalette.onAccent : RemindersColors.textPrimary,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        onSelected: (_) => setState(() => _quadrant = q),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: OrtizSpace.md),
                                  // Switch Gran Roca
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _isBigRock ? OrtizPalette.warnTint : Colors.transparent,
                                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      border: Border.all(
                                        color: _isBigRock ? OrtizPalette.warnBorder : RemindersColors.cardBorder,
                                      ),
                                    ),
                                    child: SwitchListTile(
                                      dense: true,
                                      title: const Text(
                                        '⭐ Gran Roca de la Semana',
                                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: const Text(
                                        'Meta prioritaria de alto impacto para tu rol esta semana',
                                        style: TextStyle(fontSize: OrtizFontSize.caption),
                                      ),
                                      value: _isBigRock,
                                      activeColor: OrtizPalette.warn,
                                      onChanged: (val) => setState(() => _isBigRock = val),
                                    ),
                                  ),
                                  const SizedBox(height: OrtizSpace.md),
                                  // Duración estimada
                                  const Text('Duración estimada:', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
                                  const SizedBox(height: OrtizSpace.xs),
                                  Wrap(
                                    spacing: 6,
                                    children: [15, 30, 45, 60, 90, 120].map((dur) {
                                      final isSelected = _estimatedDurationMinutes == dur;
                                      return ChoiceChip(
                                        label: Text('${dur}m', style: const TextStyle(fontSize: OrtizFontSize.caption)),
                                        selected: isSelected,
                                        selectedColor: RemindersColors.primary,
                                        labelStyle: TextStyle(color: isSelected ? OrtizPalette.onAccent : RemindersColors.textPrimary),
                                        onSelected: (_) => setState(() => _estimatedDurationMinutes = dur),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: OrtizSpace.lg),

                        // Fecha y Hora
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.md),
                          decoration: BoxDecoration(
                            color: RemindersColors.background,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            border: Border.all(color: RemindersColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, color: RemindersColors.primary, size: OrtizIconSize.lg),
                              const SizedBox(width: OrtizSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fecha y Hora Programada', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: OrtizSpace.xxs),
                                    Text(
                                      _dueAt != null
                                          ? '${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year} a las ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}'
                                          : 'Sin fecha asignada',
                                      style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w700, color: RemindersColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              if (_dueAt != null)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: OrtizIconSize.md),
                                  tooltip: 'Quitar fecha',
                                  onPressed: () => setState(() => _dueAt = null),
                                ),
                              ElevatedButton(
                                onPressed: _pickDateTime,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RemindersColors.primary,
                                  foregroundColor: OrtizPalette.onAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                ),
                                child: Text(_dueAt == null ? 'Definir' : 'Cambiar', style: const TextStyle(fontSize: OrtizFontSize.bodySm)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: OrtizSpace.lg),

                        // Selector de Recurrencia Automática
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.md),
                          decoration: BoxDecoration(
                            color: RemindersColors.background,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            border: Border.all(color: RemindersColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.repeat_rounded, color: RemindersColors.primary, size: OrtizIconSize.md),
                                  const SizedBox(width: OrtizSpace.sm),
                                  const Text(
                                    'Repetir Automáticamente',
                                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                                  ),
                                  const Spacer(),
                                  if (_recurrence != ReminderRecurrence.none)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                      decoration: BoxDecoration(
                                        color: RemindersColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      child: Text(
                                        _recurrence.shortLabel,
                                        style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: RemindersColors.primary),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: OrtizSpace.sm),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ReminderRecurrence.none,
                                  ReminderRecurrence.weekly,
                                  ReminderRecurrence.biweekly,
                                  ReminderRecurrence.monthly,
                                  ReminderRecurrence.daily,
                                ].map((rec) {
                                  final isSelected = _recurrence == rec;
                                  return ChoiceChip(
                                    label: Text(
                                      rec == ReminderRecurrence.none ? 'No se repite' : rec.label,
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                    ),
                                    selected: isSelected,
                                    selectedColor: RemindersColors.primary,
                                    labelStyle: TextStyle(color: isSelected ? OrtizPalette.onAccent : RemindersColors.textSecondary),
                                    backgroundColor: RemindersColors.cardSurface,
                                    side: BorderSide(color: isSelected ? RemindersColors.primary : RemindersColors.cardBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                    onSelected: (_) => setState(() => _recurrence = rec),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: OrtizSpace.lg),

                        // Selector de Prioridad
                        const Text('Prioridad:', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
                        const SizedBox(height: OrtizSpace.sm),
                        Row(
                          children: ReminderPriority.values.map((p) {
                            final isSelected = _priority == p;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
                                child: InkWell(
                                  onTap: () => setState(() => _priority = p),
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                    decoration: BoxDecoration(
                                      color: isSelected ? p.color.withValues(alpha: 0.12) : RemindersColors.background,
                                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      border: Border.all(
                                        color: isSelected ? p.color : RemindersColors.cardBorder,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      p.label.split(' ')[0], // P1, P2, P3, P4
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected ? p.color : RemindersColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: OrtizSpace.lg),

                        // Alerta persistente (Nagging Alert)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Alerta Persistente (Nagging)', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Re-notificar periódicamente hasta que la completes o pospongas', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textSecondary)),
                          value: _isNagging,
                          activeColor: RemindersColors.primary,
                          onChanged: (val) => setState(() => _isNagging = val),
                        ),

                        // Fijar al inicio (Pinned Reminder)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fijar en la parte superior', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Destacar en el banner superior como mensaje fijado', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textSecondary)),
                          value: _isPinned,
                          activeColor: RemindersColors.primary,
                          onChanged: (val) => setState(() => _isPinned = val),
                        ),

                        const SizedBox(height: OrtizSpace.sm),

                        // Tags
                        const Text('Etiquetas:', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
                        const SizedBox(height: OrtizSpace.xs),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tagInputController,
                                decoration: InputDecoration(
                                  hintText: 'Escribe etiqueta y presiona +',
                                  prefixIcon: const Icon(Icons.tag_rounded, size: OrtizIconSize.md),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                ),
                                onFieldSubmitted: (_) => _addTag(),
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            IconButton.filled(
                              icon: const Icon(Icons.add_rounded),
                              style: IconButton.styleFrom(backgroundColor: RemindersColors.primary),
                              onPressed: _addTag,
                            ),
                          ],
                        ),
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: OrtizSpace.sm),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _tags.map((tag) {
                              return Chip(
                                label: Text(tag, style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold)),
                                deleteIcon: const Icon(Icons.close_rounded, size: OrtizIconSize.sm),
                                onDeleted: () => setState(() => _tags.remove(tag)),
                                backgroundColor: RemindersColors.primaryLight,
                                side: BorderSide(color: RemindersColors.primary.withValues(alpha: 0.2)),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: OrtizSpace.lg),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RemindersColors.primary,
                        foregroundColor: OrtizPalette.onAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                      ),
                      child: Text(isEditing ? 'Guardar Cambios' : 'Crear Recordatorio', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
