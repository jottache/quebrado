import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_contact.dart';
import '../../diario/theme/diario_colors.dart';
import '../../diario/widgets/diario_image_helper.dart';

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

    if (widget.habit == null) {
      state.addHabit(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        type: _selectedType,
        isNegative: _isNegative,
        targetValue: targetVal,
        unit: unit,
        stackGroupId: _selectedStackId,
        contactId: contactId,
      );
    } else {
      final desc = _descController.text.trim();

      state.updateHabit(
        widget.habit!.copyWith(
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
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final isEditing = widget.habit != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
                      color: HabitosColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Hábito' : 'Nuevo Hábito',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: HabitosColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
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

            // Formulario
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo de hábito (Construir vs Romper)
                      const Text(
                        'NATURALEZA DEL HÁBITO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
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
                          const SizedBox(width: 10),
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

                      const SizedBox(height: 18),

                      // Título
                      const Text(
                        'NOMBRE DEL HÁBITO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration(hint: 'Ej. Decir groserías, Leer 20 páginas...'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del hábito' : null,
                      ),

                      const SizedBox(height: 16),

                      // Descripción
                      const Text(
                        'NOTAS O MOTIVACIÓN (OPCIONAL)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: _inputDecoration(hint: '¿Por qué es importante para ti?'),
                        style: const TextStyle(fontSize: 13),
                      ),

                      // Método de seguimiento
                      const SizedBox(height: 18),
                      const Text(
                        'MÉTODO DE SEGUIMIENTO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
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
                        const SizedBox(height: 16),
                        const Text(
                          'UNIDAD O ETIQUETA (OPCIONAL)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unitController,
                          decoration: _inputDecoration(hint: 'veces, groserías, cafés, vasos...'),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],

                      if (_selectedType == HabitType.quantitative) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'META DIARIA',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _targetController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputDecoration(hint: '2000'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'UNIDAD',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _unitController,
                                    decoration: _inputDecoration(hint: 'ml, págs, flexiones...'),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_selectedType == HabitType.timer) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'TIEMPO OBJETIVO (MINUTOS)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _targetController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(hint: '25'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],

                      // Vincular contacto del diario (opcional)
                      if (diarioState.contacts.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'VINCULAR CONTACTO DEL DIARIO (OPCIONAL)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 18),
                        const Text(
                          'ASIGNAR A UNA RUTINA (OPCIONAL)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: HabitosColors.textSecondary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HabitosColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? HabitosColors.primary : HabitosColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? HabitosColors.primary : HabitosColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: HabitosColors.textSecondary),
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
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : HabitosColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : HabitosColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
        ),
      ),
    );
  }

  Widget _contactChip(String? contactId, String name, String? avatarUrl) {
    final isSelected = _selectedContactId == contactId;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedContactId = contactId);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? HabitosColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: HabitosColors.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
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
      hintStyle: const TextStyle(fontSize: 13, color: HabitosColors.textMuted),
      filled: true,
      fillColor: HabitosColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HabitosColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HabitosColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HabitosColors.primary, width: 1.5),
      ),
    );
  }
}
