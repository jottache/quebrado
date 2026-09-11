import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_category.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';

class CategoryEditorDialog extends StatefulWidget {
  final String? contactId;
  final String? parentId;
  final DiarioCategory? category;

  const CategoryEditorDialog({
    super.key,
    this.contactId,
    this.parentId,
    this.category,
  });

  @override
  State<CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  final List<Map<String, dynamic>> _availableIcons = [
    {'key': 'restaurant', 'icon': Icons.restaurant_rounded, 'name': 'Comida'},
    {'key': 'thumb_up', 'icon': Icons.thumb_up_alt_rounded, 'name': 'Me Gusta'},
    {'key': 'thumb_down', 'icon': Icons.thumb_down_alt_rounded, 'name': 'No Gusta'},
    {'key': 'card_giftcard', 'icon': Icons.card_giftcard_rounded, 'name': 'Regalos'},
    {'key': 'cake', 'icon': Icons.cake_rounded, 'name': 'Cumple'},
    {'key': 'shopping_bag', 'icon': Icons.shopping_bag_rounded, 'name': 'Compras'},
    {'key': 'directions_car', 'icon': Icons.directions_car_rounded, 'name': 'Autos'},
    {'key': 'favorite', 'icon': Icons.favorite_rounded, 'name': 'Salud'},
    {'key': 'straighten', 'icon': Icons.straighten_rounded, 'name': 'Tallas'},
    {'key': 'medical_services', 'icon': Icons.medical_services_rounded, 'name': 'Médico'},
    {'key': 'account_balance', 'icon': Icons.account_balance_rounded, 'name': 'Banco'},
    {'key': 'credit_card', 'icon': Icons.credit_card_rounded, 'name': 'Pagos'},
    {'key': 'pets', 'icon': Icons.pets_rounded, 'name': 'Mascotas'},
    {'key': 'sports_soccer', 'icon': Icons.sports_soccer_rounded, 'name': 'Deportes'},
    {'key': 'music_note', 'icon': Icons.music_note_rounded, 'name': 'Música'},
    {'key': 'laptop', 'icon': Icons.laptop_mac_rounded, 'name': 'Tecno'},
    {'key': 'book', 'icon': Icons.auto_stories_rounded, 'name': 'Libros'},
    {'key': 'work', 'icon': Icons.work_outline_rounded, 'name': 'Trabajo'},
    {'key': 'star', 'icon': Icons.star_rounded, 'name': 'Favorito'},
    {'key': 'folder_outlined', 'icon': Icons.folder_open_rounded, 'name': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedIcon = cat?.icon ?? (widget.parentId != null ? 'folder_outlined' : 'star');
    _selectedColor = cat?.colorHex ?? '#1F6F5F';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final state = Provider.of<DiarioState>(context, listen: false);

    if (widget.category == null) {
      state.addCategory(
        name: _nameController.text.trim(),
        contactId: widget.contactId,
        parentId: widget.parentId,
        icon: _selectedIcon,
        colorHex: _selectedColor,
      );
    } else {
      state.updateCategory(
        widget.category!.copyWith(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          colorHex: _selectedColor,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final isSubcategory = widget.parentId != null || widget.category?.parentId != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSubcategory ? Icons.subdirectory_arrow_right_rounded : Icons.create_new_folder_outlined,
                      color: DiarioColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Editar Categoría'
                              : (isSubcategory ? 'Nueva Subcategoría' : 'Nueva Categoría Raíz'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.textPrimary,
                          ),
                        ),
                        Text(
                          isSubcategory
                              ? 'Crea una sección dentro de esta categoría'
                              : 'Crea una sección para clasificar datos',
                          style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Categoría *',
                        hintText: isSubcategory ? 'Ej: Me Gusta, Deseos, Tallas...' : 'Ej: Alimentos, Regalos...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: DiarioColors.background,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                    ),

                    const SizedBox(height: 16),

                    // Icon Picker Grid
                    const Text(
                      'Selecciona un Icono',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DiarioColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 130),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableIcons.map((item) {
                            final key = item['key'] as String;
                            final iconData = item['icon'] as IconData;
                            final isSelected = _selectedIcon == key;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedIcon = key),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected ? DiarioColors.primaryLight : DiarioColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? DiarioColors.primary : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  iconData,
                                  color: isSelected ? DiarioColors.primary : Colors.grey[700],
                                  size: 19,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),


                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(isEditing ? 'Actualizar' : 'Crear Categoría'),
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
