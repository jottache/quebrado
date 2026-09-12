import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';

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
  late bool _isFavorite;
  String? _avatarUrl;

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
    _selectedColor = c?.avatarColor ?? '#1F6F5F';
    _isFavorite = c?.isFavorite ?? false;
    _avatarUrl = c?.avatarUrl;
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
    final path = await DiarioImageHelper.pickImageWithSourceModal(context);
    if (path != null) {
      setState(() => _avatarUrl = path);
    }
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
      if (widget.contact == null) {
        await state.addContact(
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

        await state.updateContact(
          widget.contact!.copyWith(
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
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: DiarioColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Contacto' : 'Nuevo Contacto',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEditing ? 'Actualiza los datos de la persona' : 'Registra una persona en Diario Jottache',
                          style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Form fields
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar Photo Picker
                        Center(
                          child: Stack(
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
                                      color: DiarioColors.primary.withOpacity(0.3),
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
                                          size: 30,
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
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: DiarioColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre Completo *',
                            hintText: 'Ej: Camila Ortiz',
                            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                        ),

                        const SizedBox(height: 14),

                        // Nickname & Relationship Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nicknameController,
                                decoration: InputDecoration(
                                  labelText: 'Apodo / Alias',
                                  hintText: 'Ej: Sobrini',
                                  prefixIcon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _relationshipController,
                                decoration: InputDecoration(
                                  labelText: 'Relación / Rol',
                                  hintText: 'Ej: Sobrina',
                                  prefixIcon: const Icon(Icons.diversity_3_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Suggested Relationship chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _suggestedRelationships.map((rel) {
                            return ActionChip(
                              label: Text(rel, style: const TextStyle(fontSize: 11)),
                              backgroundColor: DiarioColors.background,
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onPressed: () {
                                setState(() => _relationshipController.text = rel);
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 14),

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
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: DiarioColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickBirthdate,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Cumpleaños',
                                    prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                                    suffixIcon: _selectedBirthdate != null
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 16),
                                            tooltip: 'Borrar fecha',
                                            onPressed: () => setState(() => _selectedBirthdate = null),
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    filled: true,
                                    fillColor: DiarioColors.background,
                                  ),
                                  child: Text(
                                    _selectedBirthdate != null
                                        ? '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}'
                                        : 'Seleccionar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedBirthdate != null ? DiarioColors.textPrimary : Colors.grey[500],
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
                            prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: DiarioColors.background,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Favorite Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Marcar como Favorito / Frecuente',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          value: _isFavorite,
                          activeColor: DiarioColors.primary,
                          onChanged: (val) => setState(() => _isFavorite = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving
                          ? 'Guardando...'
                          : (isEditing ? 'Guardar Cambios' : 'Crear Contacto'),
                    ),
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
    );
  }
}
