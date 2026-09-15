import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

class ReminderEditorDialog extends StatefulWidget {
  final ReminderModel? reminder;

  const ReminderEditorDialog({super.key, this.reminder});

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
    final isEditing = widget.reminder != null;

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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RemindersColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.alarm_add_rounded, color: RemindersColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Recordatorio' : 'Nuevo Recordatorio',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: RemindersColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEditing ? 'Ajusta la programación y detalles' : 'Configura fecha, hora y nivel de urgencia',
                          style: const TextStyle(fontSize: 12, color: RemindersColors.textSecondary),
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

              const SizedBox(height: 18),

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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: RemindersColors.background,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El título es obligatorio' : null,
                        ),

                        const SizedBox(height: 14),

                        // Notas
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Notas o detalles adicionales (opcional)',
                            hintText: 'Ej: Incluir número de contrato y soporte de pago...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: RemindersColors.background,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Fecha y Hora
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RemindersColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RemindersColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, color: RemindersColors.primary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fecha y Hora Programada', style: TextStyle(fontSize: 11, color: RemindersColors.textMuted, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _dueAt != null
                                          ? '${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year} a las ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}'
                                          : 'Sin fecha asignada',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RemindersColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              if (_dueAt != null)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  tooltip: 'Quitar fecha',
                                  onPressed: () => setState(() => _dueAt = null),
                                ),
                              ElevatedButton(
                                onPressed: _pickDateTime,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RemindersColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(_dueAt == null ? 'Definir' : 'Cambiar', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Selector de Recurrencia Automática
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: RemindersColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RemindersColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.repeat_rounded, color: RemindersColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Repetir Automáticamente',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                                  ),
                                  const Spacer(),
                                  if (_recurrence != ReminderRecurrence.none)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: RemindersColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _recurrence.shortLabel,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: RemindersColors.primary),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                                      style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                    ),
                                    selected: isSelected,
                                    selectedColor: RemindersColors.primary,
                                    labelStyle: TextStyle(color: isSelected ? Colors.white : RemindersColors.textSecondary),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: isSelected ? RemindersColors.primary : RemindersColors.cardBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    onSelected: (_) => setState(() => _recurrence = rec),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Selector de Prioridad
                        const Text('Prioridad:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: ReminderPriority.values.map((p) {
                            final isSelected = _priority == p;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () => setState(() => _priority = p),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? p.color.withOpacity(0.12) : RemindersColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? p.color : RemindersColors.cardBorder,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      p.label.split(' ')[0], // P1, P2, P3, P4
                                      style: TextStyle(
                                        fontSize: 12,
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

                        const SizedBox(height: 16),

                        // Alerta persistente (Nagging Alert)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Alerta Persistente (Nagging)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Re-notificar periódicamente hasta que la completes o pospongas', style: TextStyle(fontSize: 11, color: RemindersColors.textSecondary)),
                          value: _isNagging,
                          activeColor: RemindersColors.primary,
                          onChanged: (val) => setState(() => _isNagging = val),
                        ),

                        // Fijar al inicio (Pinned Reminder)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fijar en la parte superior', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Destacar en el banner superior como mensaje fijado', style: TextStyle(fontSize: 11, color: RemindersColors.textSecondary)),
                          value: _isPinned,
                          activeColor: RemindersColors.primary,
                          onChanged: (val) => setState(() => _isPinned = val),
                        ),

                        const SizedBox(height: 8),

                        // Tags
                        const Text('Etiquetas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RemindersColors.textSecondary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tagInputController,
                                decoration: InputDecoration(
                                  hintText: 'Escribe etiqueta y presiona +',
                                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onFieldSubmitted: (_) => _addTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add_rounded),
                              style: IconButton.styleFrom(backgroundColor: RemindersColors.primary),
                              onPressed: _addTag,
                            ),
                          ],
                        ),
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _tags.map((tag) {
                              return Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                onDeleted: () => setState(() => _tags.remove(tag)),
                                backgroundColor: RemindersColors.primaryLight,
                                side: BorderSide(color: RemindersColors.primary.withOpacity(0.2)),
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

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RemindersColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
