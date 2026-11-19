import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class ContactEditorDialog extends StatefulWidget {
  final DiarioContact? contact;

  const ContactEditorDialog({super.key, this.contact});

  @override
  State<ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<ContactEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _relationshipController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  DateTime? _selectedBirthdate;
  late String _selectedColor;
  String? _avatarUrl;
  bool _isFavorite = false;

  final List<String> _suggestedRelationships = [
    'Familia', 'Sobrina', 'Sobrino', 'Novia', 'Novio', 'Esposa', 'Esposo',
    'Papá', 'Mamá', 'Hermano/a', 'Hijo/a', 'Amigo/a', 'Colega', 'Cliente'
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?.name ?? '');
    _nicknameController = TextEditingController(text: c?.nickname ?? '');
    _relationshipController = TextEditingController(text: c?.relationship ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _selectedBirthdate = c?.birthdate;
    _selectedColor = c?.avatarColor ?? 'teal';
    _avatarUrl = c?.avatarUrl;
    _isFavorite = c?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await DiarioImageHelper.pickAvatarWithSourceModal(
      context,
      hasExistingAvatar: _avatarUrl != null && _avatarUrl!.isNotEmpty,
    );
    if (result == null) return;
    if (result.isEmpty) {
      setState(() => _avatarUrl = null);
    } else {
      setState(() => _avatarUrl = result);
    }
  }

  Future<void> _pasteAvatarFromClipboard() async {
    final result = await DiarioImageHelper.pickImageFromClipboard(
      context,
      successMessage: 'Foto pegada del portapapeles con éxito',
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _avatarUrl = result);
    }
  }

  void _handleShortcutPaste() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) {
      return;
    }
    _pasteAvatarFromClipboard();
  }

  void _removeAvatar() {
    setState(() => _avatarUrl = null);
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Fecha de Nacimiento',
      confirmText: 'Seleccionar',
      cancelText: 'Cancelar',
    );
    if (picked != null) {
      setState(() => _selectedBirthdate = picked);
    }
  }

  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final state = Provider.of<DiarioState>(context, listen: false);
      // El contacto guardado se devuelve al cerrar (acciones rápidas, «Ver»).
      final DiarioContact saved;
      if (widget.contact == null) {
        saved = await state.addContact(
          name: _nameController.text.trim(),
          nickname: _nicknameController.text.trim().isNotEmpty ? _nicknameController.text.trim() : null,
          relationship: _relationshipController.text.trim().isNotEmpty ? _relationshipController.text.trim() : null,
          avatarUrl: _avatarUrl,
          avatarColor: _selectedColor,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          birthdate: _selectedBirthdate,
          isFavorite: _isFavorite,
        );
      } else {
        final nickname = _nicknameController.text.trim();
        final rel = _relationshipController.text.trim();
        final phone = _phoneController.text.trim();
        final notes = _notesController.text.trim();

        final edited = widget.contact!.copyWith(
          name: _nameController.text.trim(),
          nickname: nickname.isNotEmpty ? nickname : null,
          clearNickname: nickname.isEmpty,
          relationship: rel.isNotEmpty ? rel : null,
          clearRelationship: rel.isEmpty,
          avatarUrl: _avatarUrl,
          clearAvatar: _avatarUrl == null,
          avatarColor: _selectedColor,
          phone: phone.isNotEmpty ? phone : null,
          clearPhone: phone.isEmpty,
          notes: notes.isNotEmpty ? notes : null,
          clearNotes: notes.isEmpty,
          birthdate: _selectedBirthdate,
          clearBirthdate: _selectedBirthdate == null,
          isFavorite: _isFavorite,
        );
        saved = await state.updateContact(edited);
      }

      if (mounted) {
        Navigator.of(context).pop(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.contact == null
                  ? 'Contacto creado con éxito'
                  : 'Contacto actualizado correctamente',
            ),
            backgroundColor: DiarioColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar contacto: $e'),
            backgroundColor: OrtizPalette.bad,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final isMobile = screenWidth < 600;
    final keyboardHeight = media.viewInsets.bottom;

    final modalHeight = isMobile ? (screenHeight * 0.90) : 680.0;
    final modalWidth = isMobile ? (screenWidth * 0.94) : 500.0;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handleShortcutPaste,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handleShortcutPaste,
      },
      child: FocusScope(
        autofocus: true,
        child: MediaQuery.removeViewInsets(
          removeBottom: true,
          context: context,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
            backgroundColor: OrtizPalette.surface,
            clipBehavior: Clip.antiAlias,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? (screenWidth * 0.03) : OrtizSpace.xl,
              vertical: isMobile ? (screenHeight * 0.05) : OrtizSpace.xxl,
            ),
            child: SizedBox(
          width: modalWidth,
          height: isMobile ? modalHeight : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: modalHeight,
            ),
            child: Column(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Fijado en la parte superior)
                Padding(
                  padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.md, OrtizSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: DiarioColors.primaryLight,
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: DiarioColors.primary, size: OrtizIconSize.lg),
                      ),
                      const SizedBox(width: OrtizSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Editar Contacto' : 'Nuevo Contacto',
                              style: const TextStyle(
                                fontSize: OrtizFontSize.titleSm,
                                fontWeight: FontWeight.w900,
                                color: DiarioColors.textPrimary,
                              ),
                            ),
                            Text(
                              isEditing ? 'Actualiza los datos de la persona' : 'Registra una persona en Diario Jottache',
                              style: const TextStyle(fontSize: OrtizFontSize.caption, color: DiarioColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isMobile)
                        TextButton(
                          onPressed: _isSaving ? null : _save,
                          style: TextButton.styleFrom(
                            foregroundColor: DiarioColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                          ),
                          child: const Text(
                            'Guardar',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: OrtizIconSize.lg),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: DiarioColors.cardBorder),

                // Form fields (Scroll interno resiliente)
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          OrtizSpace.lg,
                          OrtizSpace.lg,
                          OrtizSpace.lg,
                          isMobile ? (keyboardHeight + OrtizSpace.xxxl) : OrtizSpace.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Avatar Photo Picker
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: _pickAvatar,
                                        child: Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            color: DiarioColors.primaryLight,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: DiarioColors.primary.withValues(alpha: 0.3),
                                              width: 2,
                                            ),
                                          ),
                                          child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                              ? ClipOval(
                                                  child: DiarioImageHelper.buildImageWidget(
                                                    _avatarUrl!,
                                                    width: 76,
                                                    height: 76,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.add_a_photo_rounded,
                                                  color: DiarioColors.primary,
                                                  size: OrtizIconSize.xl,
                                                ),
                                        ),
                                      ),
                                      if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: GestureDetector(
                                            onTap: _removeAvatar,
                                            child: Container(
                                              padding: const EdgeInsets.all(OrtizSpace.xs),
                                              decoration: const BoxDecoration(
                                                color: OrtizPalette.bad,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                color: OrtizPalette.onAccent,
                                                size: OrtizIconSize.xs,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(OrtizSpace.xs),
                                            decoration: const BoxDecoration(
                                              color: DiarioColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded,
                                              color: OrtizPalette.onAccent,
                                              size: OrtizIconSize.xs,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: OrtizSpace.xs),
                                  InkWell(
                                    onTap: _pasteAvatarFromClipboard,
                                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.content_paste_rounded, size: OrtizIconSize.xs, color: DiarioColors.primary),
                                          SizedBox(width: OrtizSpace.xs),
                                          Text(
                                            'Pegar foto copiada (Cmd+V)',
                                            style: TextStyle(
                                              fontSize: OrtizFontSize.caption,
                                              fontWeight: FontWeight.w700,
                                              color: DiarioColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        const SizedBox(height: OrtizSpace.lg),
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre Completo *',
                            hintText: 'Ej: Camila Ortiz',
                            prefixIcon: const Icon(Icons.badge_outlined, size: OrtizIconSize.md),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                        ),

                        const SizedBox(height: OrtizSpace.md),

                        // Nickname & Relationship Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nicknameController,
                                decoration: InputDecoration(
                                  labelText: 'Apodo / Alias',
                                  hintText: 'Ej: Sobrini',
                                  prefixIcon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: OrtizIconSize.md),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.md),
                            Expanded(
                              child: TextFormField(
                                controller: _relationshipController,
                                decoration: InputDecoration(
                                  labelText: 'Relación / Rol',
                                  hintText: 'Ej: Sobrina',
                                  prefixIcon: const Icon(Icons.diversity_3_outlined, size: OrtizIconSize.md),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: OrtizSpace.sm),

                        // Suggested Relationship chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _suggestedRelationships.map((rel) {
                            return ActionChip(
                              label: Text(rel, style: const TextStyle(fontSize: OrtizFontSize.caption)),
                              backgroundColor: DiarioColors.background,
                              side: const BorderSide(color: OrtizPalette.line),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
                              onPressed: () {
                                setState(() => _relationshipController.text = rel);
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: OrtizSpace.md),

                        // Phone & Birthday Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Teléfono',
                                  hintText: '+58 414...',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: OrtizIconSize.md),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.md),
                            Expanded(
                              child: InkWell(
                                onTap: _pickBirthdate,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Cumpleaños',
                                    prefixIcon: const Icon(Icons.cake_outlined, size: OrtizIconSize.md),
                                    suffixIcon: _selectedBirthdate != null
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, size: OrtizIconSize.sm),
                                            tooltip: 'Borrar fecha',
                                            onPressed: () => setState(() => _selectedBirthdate = null),
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                    filled: true,
                                    fillColor: DiarioColors.background,
                                  ),
                                  child: Text(
                                    _selectedBirthdate != null
                                        ? '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}'
                                        : 'Seleccionar',
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      color: _selectedBirthdate != null ? DiarioColors.textPrimary : OrtizPalette.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),



                        // General Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notas Generales',
                            hintText: 'Gustos rápidos, recordatorios, detalles...',
                            prefixIcon: const Icon(Icons.notes_rounded, size: OrtizIconSize.md),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                        ),

                        const SizedBox(height: OrtizSpace.sm),

                        // Favorite Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Marcar como Favorito / Frecuente',
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600),
                          ),
                          value: _isFavorite,
                          activeColor: DiarioColors.primary,
                          onChanged: (val) => setState(() => _isFavorite = val),
                        ),

                        const SizedBox(height: OrtizSpace.xl),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: OrtizPalette.onAccent),
                                    )
                                  : const Icon(Icons.check_rounded, size: OrtizIconSize.md),
                              label: Text(
                                _isSaving
                                    ? 'Guardando...'
                                    : (isEditing ? 'Guardar Cambios' : 'Crear Contacto'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DiarioColors.primary,
                                foregroundColor: OrtizPalette.onAccent,
                                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
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
),
),
);
}
}
