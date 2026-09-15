import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diario_entry.dart';
import '../models/diario_template.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';

class EntryEditorDialog extends StatefulWidget {
  final String contactId;
  final String categoryId;
  final DiarioEntry? entry;

  const EntryEditorDialog({
    super.key,
    required this.contactId,
    required this.categoryId,
    this.entry,
  });

  @override
  State<EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<EntryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _textController;
  late bool _isPinned;
  late DateTime _selectedDate;
  String? _photoUrl;

  String? _selectedTemplateId;
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _textController = TextEditingController(text: e?.contentText ?? '');
    _isPinned = e?.isPinned ?? false;
    _selectedDate = e?.createdAt ?? DateTime.now();
    _selectedTemplateId = e?.templateId;
    _photoUrl = e?.photoUrl;

    if (e != null && e.contentData.isNotEmpty) {
      _formData.addAll(e.contentData);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String key, String? initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue ?? '');
    }
    return _controllers[key]!;
  }

  void _onTemplateSelected(String? templateId, List<DiarioTemplate> templates) {
    setState(() {
      _selectedTemplateId = templateId;
      if (templateId != null && _titleController.text.isEmpty) {
        final tpl = templates.firstWhere((t) => t.id == templateId, orElse: () => templates.first);
        _titleController.text = tpl.name;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha del Registro',
      confirmText: 'Seleccionar',
      cancelText: 'Cancelar',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final dateStr = '${date.day} de ${months[date.month - 1]} de ${date.year}';
    if (isToday) return 'Hoy ($dateStr)';
    if (isYesterday) return 'Ayer ($dateStr)';
    return dateStr;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Collect data from controllers
    for (final entry in _controllers.entries) {
      _formData[entry.key] = entry.value.text.trim();
    }

    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    final hasFormData = _formData.values.any((v) => v != null && v.toString().trim().isNotEmpty);
    final hasPhoto = _photoUrl != null && _photoUrl!.trim().isNotEmpty;

    if (title.isEmpty && text.isEmpty && !hasFormData && !hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una nota o adjunta algún contenido antes de guardar')),
      );
      return;
    }

    final state = Provider.of<DiarioState>(context, listen: false);
    final hasTemplate = _selectedTemplateId != null && _selectedTemplateId!.isNotEmpty;

    if (widget.entry == null) {
      state.addEntry(
        contactId: widget.contactId,
        categoryId: widget.categoryId,
        templateId: _selectedTemplateId,
        entryType: hasTemplate ? 'template_instance' : 'simple_text',
        title: _titleController.text.trim(),
        contentText: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
        photoUrl: _photoUrl,
        contentData: _formData,
        isPinned: _isPinned,
        createdAt: _selectedDate,
      );
    } else {
      final text = _textController.text.trim();
      state.updateEntry(
        widget.entry!.copyWith(
          templateId: _selectedTemplateId,
          clearTemplate: _selectedTemplateId == null || _selectedTemplateId!.isEmpty,
          entryType: hasTemplate ? 'template_instance' : 'simple_text',
          title: _titleController.text.trim(),
          contentText: text.isNotEmpty ? text : null,
          clearContentText: text.isEmpty,
          photoUrl: _photoUrl,
          clearPhoto: _photoUrl == null || _photoUrl!.isEmpty,
          contentData: _formData,
          isPinned: _isPinned,
          createdAt: _selectedDate,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await DiarioImageHelper.pickImage(source);
    if (path != null) {
      setState(() {
        _photoUrl = path;
      });
    }
  }

  Future<void> _pickImageModal() async {
    final path = await DiarioImageHelper.pickImageWithSourceModal(context);
    if (path != null) {
      setState(() {
        _photoUrl = path;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final templates = state.templates;
    final isEditing = widget.entry != null;

    DiarioTemplate? activeTemplate;
    if (_selectedTemplateId != null) {
      try {
        activeTemplate = templates.firstWhere((t) => t.id == _selectedTemplateId);
      } catch (_) {}
    }

    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final isMobile = screenWidth < 600;
    final keyboardHeight = media.viewInsets.bottom;

    final modalHeight = isMobile ? (screenHeight * 0.90) : 720.0;
    final modalWidth = isMobile ? (screenWidth * 0.94) : 550.0;

    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? (screenWidth * 0.03) : 16,
          vertical: isMobile ? (screenHeight * 0.05) : 20,
        ),
        child: SizedBox(
          width: modalWidth,
          height: isMobile ? modalHeight : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 550,
              maxHeight: modalHeight,
            ),
            child: Column(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Fijado en la parte superior)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: DiarioColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          activeTemplate != null ? activeTemplate.iconData : Icons.post_add_rounded,
                          color: DiarioColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Editar Registro' : 'Nuevo Registro',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: DiarioColors.textPrimary,
                              ),
                            ),
                            Text(
                              activeTemplate != null
                                  ? 'Modelo: ${activeTemplate.name}'
                                  : 'Registro libre o usando un modelo predefinido',
                              style: const TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isMobile)
                        TextButton(
                          onPressed: _save,
                          style: TextButton.styleFrom(
                            foregroundColor: DiarioColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text(
                            'Guardar',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: DiarioColors.cardBorder),

                // Form Scrollable Area (Scroll interno resiliente ante teclado)
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          16,
                          18,
                          isMobile ? (keyboardHeight + 32) : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Model Selector Dropdown
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Seleccionar Modelo / Plantilla Reutilizable',
                                prefixIcon: const Icon(Icons.extension_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: DiarioColors.background,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _selectedTemplateId,
                                  hint: const Text('Nota simple / Elemento libre (Sin modelo)', style: TextStyle(fontSize: 13)),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Nota simple / Elemento libre (Sin modelo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                    ...templates.map((tpl) {
                                      return DropdownMenuItem<String?>(
                                        value: tpl.id,
                                        child: Row(
                                          children: [
                                            Icon(tpl.iconData, size: 18, color: tpl.color),
                                            const SizedBox(width: 8),
                                            Text(tpl.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) => _onTemplateSelected(val, templates),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Date Selector Field
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha del Registro',
                                  prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: DiarioColors.primary),
                                  suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 18, color: DiarioColors.textSecondary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                child: Text(
                                  _formatSelectedDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: DiarioColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Title Field (Opcional)
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Título o Resumen (Opcional)',
                                hintText: activeTemplate != null
                                    ? 'Ej: Toyota Corolla, Pasta con crema... (Opcional)'
                                    : 'Ej: Comida favorita, Regalo... (Opcional)',
                                prefixIcon: const Icon(Icons.title_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: DiarioColors.background,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Dynamic Fields based on active template
                            if (activeTemplate != null && activeTemplate.fields.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: activeTemplate.color.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: activeTemplate.color.withOpacity(0.20)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(activeTemplate.iconData, size: 16, color: activeTemplate.color),
                                        const SizedBox(width: 6),
                                        Text(
                                          'CAMPOS DEL MODELO (${activeTemplate.name.toUpperCase()})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: activeTemplate.color,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...activeTemplate.fields.map((f) => _buildDynamicField(f)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Content / Notes Textarea
                            TextFormField(
                              controller: _textController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: activeTemplate != null ? 'Notas Adicionales / Observaciones' : 'Detalle o Contenido de la Nota',
                                hintText: 'Escribe cualquier detalle relevante...',
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 50.0),
                                  child: Icon(Icons.notes_rounded, size: 20),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: DiarioColors.background,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Section: Foto Adjunta (Cámara / Galería)
                            _buildPhotoAttachmentSection(),

                            const SizedBox(height: 10),

                            // Pin to Top Switch
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Fijar al inicio de la sección', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Aparecerá destacado en la parte superior', style: TextStyle(fontSize: 11)),
                              value: _isPinned,
                              activeColor: DiarioColors.primary,
                              onChanged: (val) => setState(() => _isPinned = val),
                            ),

                            const SizedBox(height: 20),

                            // Botones de acción inferiores
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _save,
                                  icon: const Icon(Icons.save_rounded, size: 18),
                                  label: Text(isEditing ? 'Guardar Cambios' : 'Registrar Entrada'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DiarioColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicField(TemplateField field) {
    final existingValue = _formData[field.key]?.toString();

    switch (field.type) {
      case TemplateFieldType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: DropdownButtonFormField<String>(
            value: field.options.contains(existingValue) ? existingValue : null,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: field.options.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _formData[field.key] = val);
              }
            },
            validator: field.required ? (val) => val == null || val.isEmpty ? 'Campo requerido' : null : null,
          ),
        );

      case TemplateFieldType.number:
        final ctrl = _getController(field.key, existingValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              hintText: field.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: field.required ? (val) => val == null || val.trim().isEmpty ? 'Campo requerido' : null : null,
          ),
        );

      case TemplateFieldType.multiline:
        final ctrl = _getController(field.key, existingValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextFormField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              hintText: field.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: field.required ? (val) => val == null || val.trim().isEmpty ? 'Campo requerido' : null : null,
          ),
        );

      case TemplateFieldType.boolean:
        final bool isChecked = _formData[field.key] == true || _formData[field.key] == 'true';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(field.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: isChecked,
            activeColor: DiarioColors.primary,
            onChanged: (val) => setState(() => _formData[field.key] = val),
          ),
        );

      case TemplateFieldType.text:
      default:
        final ctrl = _getController(field.key, existingValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              hintText: field.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: field.required ? (val) => val == null || val.trim().isEmpty ? 'Campo requerido' : null : null,
          ),
        );
    }
  }

  Widget _buildPhotoAttachmentSection() {
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_camera_outlined, size: 16, color: DiarioColors.primary),
                SizedBox(width: 6),
                Text(
                  'FOTOGRAFÍA DEL REGISTRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DiarioColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            if (hasPhoto)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: DiarioColors.rose),
                label: const Text(
                  'Quitar foto',
                  style: TextStyle(color: DiarioColors.rose, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _removePhoto,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasPhoto)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DiarioColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DiarioColors.cardBorder, width: 1.2),
            ),
            child: Column(
              children: [
                const Text(
                  '¿Deseas adjuntar una foto a este registro?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DiarioColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fotografía de la comida, prenda, artículo, lugar o recuerdo',
                  style: TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Cámara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DiarioColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DiarioColors.primary,
                          side: const BorderSide(color: DiarioColors.primary, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: DiarioColors.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: GestureDetector(
                    onTap: () => DiarioImageHelper.openFullScreenImage(
                      context,
                      _photoUrl!,
                      title: _titleController.text.isNotEmpty ? _titleController.text : 'Foto del Registro',
                    ),
                    child: DiarioImageHelper.buildImageWidget(_photoUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
              // Botones de acción flotantes sobre la foto
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _imageOverlayAction(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Ver a pantalla completa',
                      onTap: () => DiarioImageHelper.openFullScreenImage(
                        context,
                        _photoUrl!,
                        title: _titleController.text.isNotEmpty ? _titleController.text : 'Foto del Registro',
                      ),
                    ),
                    const SizedBox(width: 6),
                    _imageOverlayAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Cambiar fotografía',
                      onTap: _pickImageModal,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _imageOverlayAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: onTap,
      ),
    );
  }
}
