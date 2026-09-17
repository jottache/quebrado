import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_template.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';

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
      backgroundColor: DiarioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: isDrawer
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'Modelos Reutilizables',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DiarioColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Crear Nuevo Modelo',
            onPressed: () => _openCreateTemplateDialog(context),
          ),
          if (isDrawer) const SizedBox(width: 4),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final tpl = templates[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DiarioColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tpl.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tpl.iconData, color: tpl.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tpl.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: DiarioColors.textPrimary,
                              ),
                            ),
                            if (tpl.description != null && tpl.description!.isNotEmpty)
                              Text(
                                tpl.description!,
                                style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (tpl.isSystem)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Sistema',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: DiarioColors.rose, size: 20),
                          onPressed: () => state.deleteTemplate(tpl.id),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: DiarioColors.cardBorder),
                  const SizedBox(height: 12),

                  // Fields Badges
                  const Text(
                    'CAMPOS ESTRUCTURADOS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: DiarioColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tpl.fields.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DiarioColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          '${f.label} (${f.type.rawValue})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textPrimary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTemplateDialog(context),
        backgroundColor: DiarioColors.primary,
        foregroundColor: Colors.white,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
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
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: DiarioColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Nuevo Modelo Reutilizable',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Para qué sirve este modelo...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Añadir Campos al Modelo',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DiarioColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _fieldLabelController,
                                decoration: InputDecoration(
                                  labelText: 'Etiqueta del Campo',
                                  hintText: 'Ej: Marca, Serial, Precio',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<TemplateFieldType>(
                                value: _selectedType,
                                isDense: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                items: TemplateFieldType.values.map((t) {
                                  return DropdownMenuItem(value: t, child: Text(t.rawValue, style: const TextStyle(fontSize: 12)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add, size: 18),
                              style: IconButton.styleFrom(backgroundColor: DiarioColors.primary),
                              onPressed: _addField,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_fields.isNotEmpty) ...[
                          const Text('Campos configurados:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DiarioColors.textMuted)),
                          const SizedBox(height: 6),
                          ..._fields.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final f = entry.value;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey),
                              title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Tipo: ${f.type.rawValue}', style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: DiarioColors.rose),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DiarioColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
