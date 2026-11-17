import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diario_entry.dart';
import '../models/diario_template.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';
import '../widgets/diario_rich_editing.dart';
import '../../notas/notas.dart';
import '../../rich_editor/plain_text.dart';
import '../../rich_editor/rich_document_editor.dart';

/// Editor de entradas de Diario (registro de un contacto o nota personal).
/// Ocupa el 90 % de la pantalla en escritorio, usa el editor enriquecido
/// (formato, listas, "/" para bloques, @ contactos, # notas) y guarda borrador.
class EntryEditorDialog extends StatefulWidget {
  final String? contactId;
  final String? categoryId;
  final DiarioEntry? entry;

  const EntryEditorDialog({
    super.key,
    this.contactId,
    this.categoryId,
    this.entry,
  });

  /// Un borrador por entrada existente, y uno por contacto + sección para las nuevas.
  static String draftScopeFor({DiarioEntry? entry, String? contactId, String? categoryId}) {
    if (entry != null) return 'diario:edit:${entry.id}';
    return 'diario:new:${contactId ?? 'personal'}:${categoryId ?? 'default'}';
  }

  @override
  State<EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<EntryEditorDialog> with DiarioRichEditing<EntryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late bool _isPinned;
  late DateTime _selectedDate;
  String? _photoUrl;

  String? _selectedTemplateId;
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};

  /// Móvil: sección "Detalles" (modelo, fecha, foto…) desplegada.
  bool _detailsExpanded = false;

  @override
  String get draftScope => EntryEditorDialog.draftScopeFor(
        entry: widget.entry,
        contactId: widget.contactId,
        categoryId: widget.categoryId,
      );

  @override
  DateTime? get savedVersionAt => widget.entry?.updatedAt;

  @override
  Document buildInitialDocument() {
    final e = widget.entry;
    if (e != null && e.hasRichDocument) {
      try {
        return Document.fromJson(e.richDocument!);
      } catch (_) {}
    }
    return documentFromPlainText(e?.contentText ?? '', mentions: knownMentionTokens());
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _applyEntryValues();
    _titleController.addListener(markChanged);
    final e = widget.entry;
    _detailsExpanded = e != null && (e.templateId != null || e.hasPhoto);
    initRichEditing();
  }

  void _applyEntryValues() {
    final e = widget.entry;
    _titleController.text = e?.title ?? '';
    _isPinned = e?.isPinned ?? false;
    _selectedDate = e?.createdAt ?? DateTime.now();
    _selectedTemplateId = e?.templateId;
    _photoUrl = e?.photoUrl;
    _formData
      ..clear()
      ..addAll(e?.contentData ?? const {});
    for (final entry in _controllers.entries) {
      entry.value.text = _formData[entry.key]?.toString() ?? '';
    }
  }

  @override
  void resetFields() => _applyEntryValues();

  @override
  Map<String, dynamic> collectDraftFields() {
    final photo = _photoUrl;
    return {
      'title': _titleController.text,
      'template_id': _selectedTemplateId,
      'form_data': {
        ..._formData,
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      },
      'date': _selectedDate.toIso8601String(),
      'is_pinned': _isPinned,
      // Las fotos locales en la web pueden venir como data URI enormes: esas no se guardan
      if (photo != null && photo.length < 300000) 'photo_url': photo,
    };
  }

  @override
  void restoreDraftFields(Map<String, dynamic> data) {
    _titleController.text = data['title']?.toString() ?? '';
    _selectedTemplateId = data['template_id']?.toString();
    final form = data['form_data'];
    if (form is Map) {
      _formData
        ..clear()
        ..addAll(Map<String, dynamic>.from(form));
    }
    _selectedDate = DateTime.tryParse(data['date']?.toString() ?? '') ?? _selectedDate;
    _isPinned = data['is_pinned'] == true;
    final photo = data['photo_url']?.toString();
    if (photo != null && photo.isNotEmpty) _photoUrl = photo;
    if (_selectedTemplateId != null || _photoUrl != null) _detailsExpanded = true;
  }

  @override
  void dispose() {
    disposeRichEditing();
    _titleController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String key, String? initialValue) {
    return _controllers.putIfAbsent(key, () {
      final controller = TextEditingController(text: initialValue ?? '');
      controller.addListener(markChanged);
      return controller;
    });
  }

  void _update(VoidCallback change) {
    setState(change);
    markChanged();
  }

  void _onTemplateSelected(String? templateId, List<DiarioTemplate> templates) {
    _update(() {
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
      _update(() => _selectedDate = picked);
    }
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final dateStr = '${date.day} de ${months[date.month - 1]} de ${date.year}';
    if (isToday) return 'Hoy ($dateStr)';
    if (isYesterday) return 'Ayer ($dateStr)';
    return dateStr;
  }

  DiarioTemplate? _activeTemplate(List<DiarioTemplate> templates) {
    if (_selectedTemplateId == null) return null;
    for (final t in templates) {
      if (t.id == _selectedTemplateId) return t;
    }
    return null;
  }

  Future<void> _save() async {
    if (editorState == null) return;
    for (final entry in _controllers.entries) {
      _formData[entry.key] = entry.value.text.trim();
    }

    final state = Provider.of<DiarioState>(context, listen: false);
    final activeTemplate = _activeTemplate(state.templates);

    // Campos obligatorios del modelo (en móvil pueden estar plegados en "Detalles")
    final missing = <String>[
      for (final f in activeTemplate?.fields ?? const <TemplateField>[])
        if (f.required && (_formData[f.key] == null || _formData[f.key].toString().trim().isEmpty)) f.label,
    ];
    if (missing.isNotEmpty) {
      setState(() => _detailsExpanded = true);
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completa los campos obligatorios: ${missing.join(', ')}')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final text = plainText;
    final hasFormData = _formData.values.any((v) => v != null && v.toString().trim().isNotEmpty);
    final hasPhoto = _photoUrl != null && _photoUrl!.trim().isNotEmpty;

    if (title.isEmpty && text.isEmpty && !hasFormData && !hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una nota o adjunta algún contenido antes de guardar')),
      );
      return;
    }

    await stopDictation();
    if (!mounted) return;

    final hasTemplate = _selectedTemplateId != null && _selectedTemplateId!.isNotEmpty;
    final effectiveContactId = widget.entry?.contactId ?? widget.contactId ?? 'personal';
    final effectiveCategoryId = widget.entry?.categoryId ?? widget.categoryId ?? 'cat_notas_personales';
    final notasState = Provider.of<NotasState>(context, listen: false);
    final mentionsList = text.isNotEmpty ? state.extractMentionedContactIds(text) : <String>[];
    final noteMentionsList = text.isNotEmpty ? state.extractMentionedNoteIds(text, notasState.notes) : <String>[];
    final document = text.isNotEmpty ? documentJson : null;

    if (widget.entry == null) {
      state.addEntry(
        contactId: effectiveContactId,
        categoryId: effectiveCategoryId,
        templateId: _selectedTemplateId,
        entryType: hasTemplate ? 'template_instance' : 'simple_text',
        title: title,
        contentText: text.isNotEmpty ? text : null,
        richDocument: document,
        photoUrl: _photoUrl,
        contentData: Map<String, dynamic>.from(_formData),
        mentionedContactIds: mentionsList,
        mentionedNoteIds: noteMentionsList,
        isPinned: _isPinned,
        createdAt: _selectedDate,
      );
    } else {
      state.updateEntry(
        widget.entry!.copyWith(
          templateId: _selectedTemplateId,
          clearTemplate: !hasTemplate,
          entryType: hasTemplate ? 'template_instance' : 'simple_text',
          title: title,
          contentText: text.isNotEmpty ? text : null,
          clearContentText: text.isEmpty,
          richDocument: document,
          clearRichDocument: document == null,
          photoUrl: _photoUrl,
          clearPhoto: _photoUrl == null || _photoUrl!.isEmpty,
          contentData: Map<String, dynamic>.from(_formData),
          mentionedContactIds: mentionsList,
          mentionedNoteIds: noteMentionsList,
          isPinned: _isPinned,
          createdAt: _selectedDate,
        ),
      );
    }

    await discardDraftAfterSave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await DiarioImageHelper.pickImage(source);
    if (path != null) _update(() => _photoUrl = path);
  }

  Future<void> _pickImageModal() async {
    final path = await DiarioImageHelper.pickImageWithSourceModal(context);
    if (path != null) _update(() => _photoUrl = path);
  }

  void _removePhoto() => _update(() => _photoUrl = null);

  bool get _isPersonal =>
      widget.entry?.contactId == 'personal' ||
      ((widget.contactId == null || widget.contactId == 'personal') && widget.entry == null);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final templates = state.templates;
    final activeTemplate = _activeTemplate(templates);
    final desktop = DiarioEditorFrame.isDesktop(context);

    return DiarioEditorFrame(
      onEscape: closeKeepingDraft,
      child: Form(
        key: _formKey,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(activeTemplate, desktop: desktop),
                const Divider(height: 1, thickness: 1, color: DiarioColors.cardBorder),
                Expanded(
                  child: editorState == null
                      ? const Center(child: CircularProgressIndicator())
                      : desktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildEditor(activeTemplate, desktop: true)),
                                const VerticalDivider(width: 1, thickness: 1, color: DiarioColors.cardBorder),
                                SizedBox(
                                  width: 360,
                                  child: ColoredBox(
                                    color: DiarioColors.background,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(18),
                                      child: _buildDetails(templates, activeTemplate),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildEditor(activeTemplate, desktop: false, templates: templates),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(DiarioTemplate? activeTemplate, {required bool desktop}) {
    final isEditing = widget.entry != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(desktop ? 20 : 8, 12, desktop ? 16 : 8, 12),
      child: Row(
        children: [
          if (!desktop)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              tooltip: 'Cerrar (se guarda como borrador)',
              onPressed: closeKeepingDraft,
            ),
          if (desktop) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isPersonal
                    ? Icons.note_alt_rounded
                    : (activeTemplate != null ? activeTemplate.iconData : Icons.post_add_rounded),
                color: DiarioColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? (_isPersonal ? 'Editar Nota Personal' : 'Editar Registro')
                      : (_isPersonal ? 'Nueva Nota Personal' : 'Nuevo Registro'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isPersonal
                      ? 'Nota privada e independiente de contactos'
                      : (activeTemplate != null
                          ? 'Modelo: ${activeTemplate.name}'
                          : 'Registro libre o usando un modelo predefinido'),
                  style: const TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          buildDictationButton(compact: !desktop),
          const SizedBox(width: 8),
          if (desktop)
            TextButton(
              key: const ValueKey('diario_entry_cancel'),
              onPressed: cancelAndDiscardDraft,
              child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
            ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            key: const ValueKey('diario_entry_save'),
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(desktop ? (isEditing ? 'Guardar Cambios' : 'Registrar Entrada') : 'Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DiarioColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: desktop ? 20 : 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              tooltip: 'Cerrar (se guarda como borrador)',
              onPressed: closeKeepingDraft,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor(DiarioTemplate? activeTemplate, {required bool desktop, List<DiarioTemplate>? templates}) {
    final banner = buildDraftBanner();
    final horizontal = desktop ? 32.0 : 16.0;
    return RichDocumentEditor(
      key: ObjectKey(editorState),
      editorState: editorState!,
      accentColor: DiarioColors.primary,
      mentions: mentionSources(),
      onEscape: closeKeepingDraft,
      autofocus: widget.entry == null && restoredDraft == null && desktop,
      placeholder: activeTemplate != null
          ? 'Notas adicionales… (@ personas, # notas, / bloques)'
          : 'Escribe o dicta… (@ personas, # notas, / bloques)',
      header: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            if (!desktop && templates != null) ...[
              _buildMobileDetails(templates, activeTemplate),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('diario_entry_title'),
              controller: _titleController,
              maxLines: null,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: DiarioColors.textPrimary,
                letterSpacing: -0.4,
              ),
              decoration: InputDecoration(
                hintText: activeTemplate != null ? 'Título (opcional): Toyota Corolla, Pasta…' : 'Título (opcional)',
                hintStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFCBD5E1)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (isListening) ...[
              const SizedBox(height: 8),
              _buildListeningHint(),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.fiber_manual_record_rounded, size: 10, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dictado activo: lo que digas se escribe donde está el cursor.',
              style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Móvil: los detalles van plegados encima del texto para dejarle espacio.
  Widget _buildMobileDetails(List<DiarioTemplate> templates, DiarioTemplate? activeTemplate) {
    final summary = [
      activeTemplate?.name ?? 'Sin modelo',
      _formatSelectedDate(_selectedDate),
      if (_photoUrl != null && _photoUrl!.isNotEmpty) 'con foto',
      if (_isPinned) 'fijada',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: DiarioColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: DiarioColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DiarioColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _detailsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: DiarioColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_detailsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildDetails(templates, activeTemplate),
            ),
        ],
      ),
    );
  }

  /// Modelo, fecha, campos del modelo, foto y fijado.
  Widget _buildDetails(List<DiarioTemplate> templates, DiarioTemplate? activeTemplate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Modelo / Plantilla',
            prefixIcon: const Icon(Icons.extension_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: activeTemplate?.id,
              hint: const Text('Nota simple (sin modelo)', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Nota simple (sin modelo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ...templates.map((tpl) {
                  return DropdownMenuItem<String?>(
                    value: tpl.id,
                    child: Row(
                      children: [
                        Icon(tpl.iconData, size: 18, color: tpl.color),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tpl.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(
              _formatSelectedDate(_selectedDate),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DiarioColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (activeTemplate != null && activeTemplate.fields.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: activeTemplate.color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activeTemplate.color.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(activeTemplate.iconData, size: 16, color: activeTemplate.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CAMPOS DEL MODELO (${activeTemplate.name.toUpperCase()})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: activeTemplate.color,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
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
        _buildPhotoAttachmentSection(),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fijar al inicio de la sección', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Aparecerá destacado en la parte superior', style: TextStyle(fontSize: 11)),
          value: _isPinned,
          activeThumbColor: DiarioColors.primary,
          onChanged: (val) => _update(() => _isPinned = val),
        ),
      ],
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
                _update(() => _formData[field.key] = val);
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
            onChanged: (val) => _update(() => _formData[field.key] = val),
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
