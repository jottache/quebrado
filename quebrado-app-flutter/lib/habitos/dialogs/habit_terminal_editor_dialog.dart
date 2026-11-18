import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_contact.dart';
import '../../diario/theme/diario_colors.dart';
import '../../diario/widgets/diario_image_helper.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class HabitTerminalEditorDialog extends StatefulWidget {
  final HabitModel? habit;
  final String? initialContactId;

  const HabitTerminalEditorDialog({super.key, this.habit, this.initialContactId});

  @override
  State<HabitTerminalEditorDialog> createState() => _HabitTerminalEditorDialogState();
}

class _HabitTerminalEditorDialogState extends State<HabitTerminalEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _targetController;
  late TextEditingController _unitController;

  late HabitType _selectedType;
  late bool _isNegative;
  String? _selectedStackId;
  String? _selectedContactId;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _targetController = TextEditingController(
      text: h != null
          ? (h.type == HabitType.timer ? (h.targetValue / 60).round().toString() : h.targetValue.toInt().toString())
          : '1',
    );
    _unitController = TextEditingController(text: h?.unit ?? 'veces');

    _selectedType = h?.type ?? HabitType.binary;
    _isNegative = h?.isNegative ?? false;
    _selectedStackId = h?.stackGroupId;
    _selectedContactId = h?.contactId ?? widget.initialContactId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final state = Provider.of<HabitosState>(context, listen: false);
    double targetVal = double.tryParse(_targetController.text.trim()) ?? 1.0;

    // Si es temporizador, guardamos en segundos
    if (_selectedType == HabitType.timer) {
      targetVal = targetVal * 60;
    }

    final contactId = _selectedContactId;
    final unit = (_selectedType == HabitType.quantitative || _selectedType == HabitType.counter)
        ? (_unitController.text.trim().isNotEmpty ? _unitController.text.trim() : 'veces')
        : (_selectedType == HabitType.timer ? 'min' : null);

    // El hábito guardado se devuelve al cerrar (acciones rápidas, «Ver»). El
    // guardado sigue sin esperarse, como antes: addHabit lo añade a la lista
    // antes de su primer await.
    final HabitModel saved;
    if (widget.habit == null) {
      final id = const Uuid().v4();
      state.addHabit(
        id: id,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        type: _selectedType,
        isNegative: _isNegative,
        targetValue: targetVal,
        unit: unit,
        stackGroupId: _selectedStackId,
        contactId: contactId,
      );
      saved = state.habits.firstWhere((h) => h.id == id);
    } else {
      final desc = _descController.text.trim();

      saved = widget.habit!.copyWith(
        title: _titleController.text.trim(),
        description: desc.isNotEmpty ? desc : null,
        clearDescription: desc.isEmpty,
        type: _selectedType,
        isNegative: _isNegative,
        targetValue: targetVal,
        unit: unit,
        clearUnit: unit == null || unit.isEmpty,
        stackGroupId: _selectedStackId,
        clearStackGroupId: _selectedStackId == null,
        contactId: contactId,
        clearContactId: contactId == null,
      );
      state.updateHabit(saved);
    }

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final isEditing = widget.habit != null;

    return Dialog(
      backgroundColor: HabitosColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Minimalista
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
                      color: HabitosColors.primary,
                      size: OrtizIconSize.md,
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Hábito' : 'Nuevo Hábito',
                      style: const TextStyle(
                        fontSize: OrtizFontSize.title,
                        fontWeight: FontWeight.w900,
                        color: HabitosColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: HabitosColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: HabitosColors.cardBorder),

            // Formulario
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.xl, OrtizSpace.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo de hábito (Construir vs Romper)
                      const Text(
                        'NATURALEZA DEL HÁBITO',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: OrtizSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _natureRadioCard(
                              title: 'Positivo',
                              subtitle: 'Construir rutina',
                              icon: Icons.check_circle_outline_rounded,
                              isSelected: !_isNegative,
                              onTap: () {
                                setState(() {
                                  _isNegative = false;
                                  if (_selectedType == HabitType.negative) _selectedType = HabitType.binary;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: _natureRadioCard(
                              title: 'Negativo',
                              subtitle: 'Romper / Dejar',
                              icon: Icons.shield_outlined,
                              isSelected: _isNegative,
                              onTap: () {
                                setState(() {
                                  _isNegative = true;
                                  if (_selectedType != HabitType.counter) {
                                    _selectedType = HabitType.negative;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: OrtizSpace.lg),

                      // Título
                      const Text(
                        'NOMBRE DEL HÁBITO',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: OrtizSpace.sm),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration(hint: 'Ej. Decir groserías, Leer 20 páginas...'),
                        style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w700),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del hábito' : null,
                      ),

                      const SizedBox(height: OrtizSpace.lg),

                      // Descripción
                      const Text(
                        'NOTAS O MOTIVACIÓN (OPCIONAL)',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: OrtizSpace.sm),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: _inputDecoration(hint: '¿Por qué es importante para ti?'),
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm),
                      ),

                      // Método de seguimiento
                      const SizedBox(height: OrtizSpace.lg),
                      const Text(
                        'MÉTODO DE SEGUIMIENTO',
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: OrtizSpace.sm),
                      if (!_isNegative)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _typeChip(HabitType.binary, 'Sí / No (Check)'),
                            _typeChip(HabitType.counter, 'Contador Infinito (+)'),
                            _typeChip(HabitType.quantitative, 'Meta Numérica'),
                            _typeChip(HabitType.timer, 'Temporizador'),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _typeChip(HabitType.negative, 'Días Limpios (Evitar)'),
                            _typeChip(HabitType.counter, 'Contador Infinito (Sumar ocurrencias)'),
                          ],
                        ),

                      if (_selectedType == HabitType.counter) ...[
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          'UNIDAD O ETIQUETA (OPCIONAL)',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: OrtizSpace.xs),
                        TextFormField(
                          controller: _unitController,
                          decoration: _inputDecoration(hint: 'veces, groserías, cafés, vasos...'),
                          style: const TextStyle(fontSize: OrtizFontSize.body),
                        ),
                      ],

                      if (_selectedType == HabitType.quantitative) ...[
                        const SizedBox(height: OrtizSpace.lg),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'META DIARIA',
                                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                                  ),
                                  const SizedBox(height: OrtizSpace.xs),
                                  TextFormField(
                                    controller: _targetController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputDecoration(hint: '2000'),
                                    style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'UNIDAD',
                                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                                  ),
                                  const SizedBox(height: OrtizSpace.xs),
                                  TextFormField(
                                    controller: _unitController,
                                    decoration: _inputDecoration(hint: 'ml, págs, flexiones...'),
                                    style: const TextStyle(fontSize: OrtizFontSize.body),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_selectedType == HabitType.timer) ...[
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          'TIEMPO OBJETIVO (MINUTOS)',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: OrtizSpace.xs),
                        TextFormField(
                          controller: _targetController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(hint: '25'),
                          style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w800),
                        ),
                      ],

                      // Vincular contacto del diario (opcional)
                      if (diarioState.contacts.isNotEmpty) ...[
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          'VINCULAR CONTACTO DEL DIARIO (OPCIONAL)',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _contactChip(null, 'Ninguno / Personal', null),
                              ...diarioState.contacts.map((c) => _contactChip(c.id, c.name, c.avatarUrl)),
                            ],
                          ),
                        ),
                      ],

                      // Rutina / Stack
                      if (state.stacks.isNotEmpty) ...[
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          'ASIGNAR A UNA RUTINA (OPCIONAL)',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        Wrap(
                          spacing: 8,
                          children: [
                            _stackChip(null, 'Ninguna'),
                            ...state.stacks.map((s) => _stackChip(s.id, s.name)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Botones de acción inferiores
            const Divider(height: 1, color: HabitosColors.cardBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: HabitosColors.textSecondary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HabitosColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    child: Text(
                      isEditing ? 'Guardar Cambios' : 'Crear Hábito',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _natureRadioCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrtizRadius.field),
      child: Container(
        padding: const EdgeInsets.all(OrtizSpace.md),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.field),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: OrtizIconSize.md,
              color: isSelected ? HabitosColors.primary : HabitosColors.textSecondary,
            ),
            const SizedBox(width: OrtizSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? HabitosColors.primary : HabitosColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: OrtizFontSize.caption, color: HabitosColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(HabitType type, String label) {
    final isSelected = _selectedType == type;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedType = type);
      },
      selectedColor: HabitosColors.primary,
      backgroundColor: HabitosColors.surface,
      labelStyle: TextStyle(
        fontSize: OrtizFontSize.bodySm,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? OrtizPalette.onAccent : HabitosColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        side: BorderSide(
          color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
        ),
      ),
    );
  }

  Widget _stackChip(String? stackId, String label) {
    final isSelected = _selectedStackId == stackId;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedStackId = stackId);
      },
      selectedColor: HabitosColors.primary,
      backgroundColor: HabitosColors.surface,
      labelStyle: TextStyle(
        fontSize: OrtizFontSize.bodySm,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? OrtizPalette.onAccent : HabitosColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        side: BorderSide(
          color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
        ),
      ),
    );
  }

  Widget _contactChip(String? contactId, String name, String? avatarUrl) {
    final isSelected = _selectedContactId == contactId;

    return Padding(
      padding: const EdgeInsets.only(right: OrtizSpace.sm),
      child: InkWell(
        onTap: () {
          setState(() => _selectedContactId = contactId);
        },
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
          decoration: BoxDecoration(
            color: isSelected ? HabitosColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(
              color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (contactId != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: HabitosColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: DiarioImageHelper.buildImageWidget(
                            avatarUrl,
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.bold,
                            color: HabitosColors.primary,
                          ),
                        ),
                ),
                const SizedBox(width: OrtizSpace.xs),
              ],
              Text(
                name,
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? HabitosColors.primary : HabitosColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.textMuted),
      filled: true,
      fillColor: HabitosColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        borderSide: const BorderSide(color: HabitosColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        borderSide: const BorderSide(color: HabitosColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        borderSide: const BorderSide(color: HabitosColors.primary, width: 1.5),
      ),
    );
  }
}
