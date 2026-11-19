import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/agente_prompt_model.dart';
import '../theme/agente_colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      backgroundColor: AgenteColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xl),
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
                      padding: const EdgeInsets.all(OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: AgenteColors.primaryLight,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AgenteColors.primary, size: OrtizIconSize.md),
                    ),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar Prompt Rápido' : 'Nuevo Prompt Rápido',
                            style: const TextStyle(
                              fontSize: OrtizFontSize.titleSm,
                              fontWeight: FontWeight.w900,
                              color: OrtizPalette.fg,
                            ),
                          ),
                          const Text(
                            'Aparecerá en el dock inferior del launcher',
                            style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: OrtizSpace.lg),

                // Prompt Text
                const Text(
                  'CONTENIDO DEL PROMPT *',
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: AgenteColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: OrtizSpace.xs),
                TextFormField(
                  controller: _textController,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ej: ¿Cuáles son los próximos 3 cumpleaños?',
                    hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.body),
                    filled: true,
                    fillColor: AgenteColors.background,
                    contentPadding: const EdgeInsets.all(OrtizSpace.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.primary, width: OrtizStroke.focus),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el texto del prompt';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: OrtizSpace.md),

                // Alias / Label (Opcional)
                const Text(
                  'ALIAS / ETIQUETA CORTA (OPCIONAL)',
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: OrtizPalette.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: OrtizSpace.xs),
                TextFormField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: OrtizFontSize.body),
                  decoration: InputDecoration(
                    hintText: 'Ej: Cumpleaños, Finanzas, Gastos',
                    hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                    filled: true,
                    fillColor: AgenteColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: const BorderSide(color: AgenteColors.primary, width: OrtizStroke.focus),
                    ),
                  ),
                ),

                const SizedBox(height: OrtizSpace.xl),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          side: const BorderSide(color: AgenteColors.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w700, color: OrtizPalette.muted),
                        ),
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AgenteColors.primary,
                          foregroundColor: OrtizPalette.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        ),
                        child: Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Prompt',
                          style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w800),
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
