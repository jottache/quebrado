import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_template.dart';
import '../viewmodels/diario_state.dart';
import '../../widgets/ortiz/ortiz.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

/// Color de identidad del Diario (spec 05: vía `SuiteApp`).
Color get _diario => SuiteApp.diario.color;

class TemplateManagerScreen extends StatelessWidget {
  final bool isDrawer;

  const TemplateManagerScreen({super.key, this.isDrawer = false});

  void _openCreateTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _TemplateEditorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final templates = state.templates;

    return Scaffold(
      backgroundColor: OrtizPalette.bg,
      appBar: AppBar(
        backgroundColor: OrtizPalette.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: isDrawer
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: OrtizIconSize.lg),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'Modelos Reutilizables',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.title, color: OrtizPalette.fg),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Crear Nuevo Modelo',
            onPressed: () => _openCreateTemplateDialog(context),
          ),
          if (isDrawer) const SizedBox(width: OrtizSpace.xs),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(OrtizSpace.xl),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
          child: Divider(height: OrtizStroke.hairline),
        ),
        itemBuilder: (context, index) {
          final tpl = templates[index];
          // Sin tarjeta (spec 05, C4): el modelo va sobre el fondo y los
          // modelos se separan con una línea fina.
          return ortizStaggered(
            context,
            index,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tpl.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      child: Icon(tpl.iconData, color: tpl.color, size: OrtizIconSize.md),
                    ),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tpl.name,
                            style: const TextStyle(
                              fontSize: OrtizFontSize.titleSm,
                              fontWeight: FontWeight.w900,
                              color: OrtizPalette.fg,
                            ),
                          ),
                          if (tpl.description != null && tpl.description!.isNotEmpty)
                            Text(
                              tpl.description!,
                              style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                            ),
                        ],
                      ),
                    ),
                    if (tpl.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                        decoration: BoxDecoration(
                          color: OrtizPalette.surfaceHigh,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        child: const Text(
                          'Sistema',
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: OrtizPalette.bad, size: OrtizIconSize.md),
                        onPressed: () => state.deleteTemplate(tpl.id),
                      ),
                  ],
                ),

                const SizedBox(height: OrtizSpace.md),

                // Fields Badges
                const Text(
                  'CAMPOS ESTRUCTURADOS:',
                  style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: OrtizPalette.muted, letterSpacing: 0.5),
                ),
                const SizedBox(height: OrtizSpace.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tpl.fields.map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        border: Border.all(color: OrtizPalette.line),
                      ),
                      child: Text(
                        '${f.label} (${f.type.rawValue})',
                        style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w600, color: OrtizPalette.fg),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTemplateDialog(context),
        backgroundColor: _diario,
        foregroundColor: OrtizPalette.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear Modelo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog();

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<TemplateField> _fields = [];

  // Temporary field inputs
  final _fieldLabelController = TextEditingController();
  TemplateFieldType _selectedType = TemplateFieldType.text;
  bool _fieldRequired = false;

  void _addField() {
    final label = _fieldLabelController.text.trim();
    if (label.isEmpty) return;

    final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    setState(() {
      _fields.add(TemplateField(
        key: key,
        label: label,
        type: _selectedType,
        required: _fieldRequired,
      ));
      _fieldLabelController.clear();
      _fieldRequired = false;
      _selectedType = TemplateFieldType.text;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un campo al modelo')),
      );
      return;
    }

    final state = Provider.of<DiarioState>(context, listen: false);
    state.addTemplate(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      icon: 'extension',
      colorHex: '#1F6F5F',
      fields: _fields,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      backgroundColor: OrtizPalette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SuiteApp.diario.tint,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: Icon(Icons.dashboard_customize_rounded, color: _diario, size: OrtizIconSize.md),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  const Expanded(
                    child: Text(
                      'Nuevo Modelo Reutilizable',
                      style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.w900, color: OrtizPalette.fg),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.lg),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del Modelo *',
                            hintText: 'Ej: Dispositivo, Suscripción, Propiedad...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: OrtizPalette.bg,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: OrtizSpace.md),
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Para qué sirve este modelo...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: OrtizPalette.bg,
                          ),
                        ),
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          'Añadir Campos al Modelo',
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800, color: OrtizPalette.fg),
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _fieldLabelController,
                                decoration: InputDecoration(
                                  labelText: 'Etiqueta del Campo',
                                  hintText: 'Ej: Marca, Serial, Precio',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<TemplateFieldType>(
                                value: _selectedType,
                                isDense: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.md),
                                ),
                                items: TemplateFieldType.values.map((t) {
                                  return DropdownMenuItem(value: t, child: Text(t.rawValue, style: const TextStyle(fontSize: OrtizFontSize.bodySm)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            IconButton.filled(
                              icon: const Icon(Icons.add, size: OrtizIconSize.sm),
                              style: IconButton.styleFrom(backgroundColor: _diario, foregroundColor: OrtizPalette.onAccent),
                              onPressed: _addField,
                            ),
                          ],
                        ),
                        const SizedBox(height: OrtizSpace.md),
                        if (_fields.isNotEmpty) ...[
                          const Text('Campos configurados:', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted)),
                          const SizedBox(height: OrtizSpace.xs),
                          ..._fields.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final f = entry.value;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.drag_indicator_rounded, size: OrtizIconSize.sm, color: OrtizPalette.muted),
                              title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
                              subtitle: Text('Tipo: ${f.type.rawValue}', style: const TextStyle(fontSize: OrtizFontSize.caption)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: OrtizIconSize.sm, color: OrtizPalette.bad),
                                onPressed: () => setState(() => _fields.removeAt(idx)),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: OrtizSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: OrtizPalette.muted)),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _diario,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
                    ),
                    child: const Text('Guardar Modelo'),
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
