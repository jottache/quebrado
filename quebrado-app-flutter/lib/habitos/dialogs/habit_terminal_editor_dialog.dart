import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';

class HabitTerminalEditorDialog extends StatefulWidget {
  final HabitModel? habit;

  const HabitTerminalEditorDialog({super.key, this.habit});

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

    if (widget.habit == null) {
      state.addHabit(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        type: _selectedType,
        isNegative: _isNegative,
        targetValue: targetVal,
        unit: _selectedType == HabitType.quantitative ? _unitController.text.trim() : (_selectedType == HabitType.timer ? 'min' : null),
        stackGroupId: _selectedStackId,
      );
    } else {
      state.updateHabit(
        widget.habit!.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
          type: _selectedType,
          isNegative: _isNegative,
          targetValue: targetVal,
          unit: _selectedType == HabitType.quantitative ? _unitController.text.trim() : (_selectedType == HabitType.timer ? 'min' : null),
          stackGroupId: _selectedStackId,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final isEditing = widget.habit != null;

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
                                  _selectedType = HabitType.negative;
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
                        decoration: _inputDecoration(hint: 'Ej. Leer 20 páginas, Meditar...'),
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

                      // Tipo de Registro (solo si es hábito positivo)
                      if (!_isNegative) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'MÉTODO DE SEGUIMIENTO',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _typeChip(HabitType.binary, 'Sí / No (Check)'),
                            _typeChip(HabitType.quantitative, 'Numérico (Contador)'),
                            _typeChip(HabitType.timer, 'Temporizador'),
                          ],
                        ),

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
