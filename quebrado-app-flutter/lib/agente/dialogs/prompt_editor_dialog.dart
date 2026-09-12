import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/agente_prompt_model.dart';
import '../theme/agente_colors.dart';

class PromptEditorDialog extends StatefulWidget {
  final AgentePromptModel? initialPrompt;

  const PromptEditorDialog({super.key, this.initialPrompt});

  static Future<AgentePromptModel?> show(BuildContext context, {AgentePromptModel? prompt}) {
    return showDialog<AgentePromptModel>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PromptEditorDialog(initialPrompt: prompt),
    );
  }

  @override
  State<PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<PromptEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _textController;
  late TextEditingController _labelController;

  bool get isEditing => widget.initialPrompt != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialPrompt?.text ?? '');
    _labelController = TextEditingController(text: widget.initialPrompt?.label ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final text = _textController.text.trim();
    final label = _labelController.text.trim();

    final result = widget.initialPrompt != null
        ? widget.initialPrompt!.copyWith(
            text: text,
            label: label.isNotEmpty ? label : null,
            updatedAt: DateTime.now(),
          )
        : AgentePromptModel(
            id: const Uuid().v4(),
            text: text,
            label: label.isNotEmpty ? label : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AgenteColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AgenteColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar Prompt Rápido' : 'Nuevo Prompt Rápido',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            'Aparecerá en el dock inferior del launcher',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Prompt Text
                const Text(
                  'CONTENIDO DEL PROMPT *',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AgenteColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _textController,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ej: ¿Cuáles son los próximos 3 cumpleaños?',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AgenteColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el texto del prompt';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Alias / Label (Opcional)
                const Text(
                  'ALIAS / ETIQUETA CORTA (OPCIONAL)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Ej: Cumpleaños, Finanzas, Gastos',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AgenteColors.primary, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AgenteColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Prompt',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
