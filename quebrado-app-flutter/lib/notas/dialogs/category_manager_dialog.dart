import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';

/// Diálogo para administrar categorías de Notas & Acuerdos.
/// Permite crear nuevas categorías, editarlas y eliminarlas de forma segura.
/// Si se elimina una categoría con notas, éstas se reasignan automáticamente
/// a la categoría predeterminada 'General' sin pérdida de información.
class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CategoryManagerDialog(),
    );
  }

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  bool _isCreating = false;
  NoteCategory? _editingCategory;

  final TextEditingController _nameController = TextEditingController();
  String _selectedIcon = '📁';
  Color _selectedColor = const Color(0xFF6366F1);

  final List<String> _availableIcons = [
    '📁', '💍', '💡', '📍', '📝', '🎯', '🚀', '❤️',
    '💼', '📚', '🏠', '✈️', '🛒', '🎨', '🔒', '⭐',
  ];

  final List<Color> _availableColors = const [
    Color(0xFFE11D48), // Rose / Acuerdos
    Color(0xFFD97706), // Amber / Ideas
    Color(0xFF2563EB), // Blue / Direcciones
    Color(0xFF059669), // Emerald
    Color(0xFF7C3AED), // Violet
    Color(0xFF0D9488), // Teal
    Color(0xFFEA580C), // Orange
    Color(0xFF64748B), // Slate / General
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startCreating() {
    setState(() {
      _isCreating = true;
      _editingCategory = null;
      _nameController.clear();
      _selectedIcon = '📁';
      _selectedColor = _availableColors.first;
    });
  }

  void _startEditing(NoteCategory category) {
    setState(() {
      _isCreating = true;
      _editingCategory = category;
      _nameController.text = category.name;
      _selectedIcon = category.icon;
      _selectedColor = category.color;
    });
  }

  void _cancelForm() {
    setState(() {
      _isCreating = false;
      _editingCategory = null;
      _nameController.clear();
    });
  }

  Future<void> _saveCategory(NotasState notasState) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final hexColor = '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    if (_editingCategory != null) {
      final updated = _editingCategory!.copyWith(
        name: name,
        icon: _selectedIcon,
        colorHex: hexColor,
      );
      await notasState.updateCategory(updated);
    } else {
      await notasState.createCategory(
        name: name,
        icon: _selectedIcon,
        colorHex: hexColor,
      );
    }

    _cancelForm();
  }

  Future<void> _confirmDelete(BuildContext context, NotasState notasState, NoteCategory category) async {
    final noteCount = notasState.notes.where((n) => n.categoryId == category.id).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¿Eliminar categoría?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de eliminar "${category.name}".',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (noteCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta categoría tiene $noteCount notas asociadas. Ninguna nota se perderá: se moverán automáticamente a la categoría "General".',
                        style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Esta categoría no tiene notas asociadas y se eliminará de forma permanente.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await notasState.deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notasState = Provider.of<NotasState>(context);
    final categories = notasState.categories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del diálogo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NotasColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.folder_special_rounded, color: NotasColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categorías de Notas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        Text(
                          'Organiza tus notas, acuerdos e ideas',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Formulario de creación/edición o Lista de categorías
            Expanded(
              child: _isCreating ? _buildForm(notasState) : _buildCategoryList(context, notasState, categories),
            ),

            // Footer con botón de acción
            if (!_isCreating)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: FilledButton.icon(
                  onPressed: _startCreating,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nueva Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: NotasColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, NotasState notasState, List<NoteCategory> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('No hay categorías registradas', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: categories.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[150]),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final noteCount = notasState.notes.where((n) => n.categoryId == cat.id).length;
        final isDefault = cat.isSystem || cat.id == NoteCategory.generalCategoryId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cat.color.withOpacity(0.3), width: 1.2),
            ),
            child: Center(
              child: Text(cat.icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Predeterminada',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                tooltip: 'Editar',
                onPressed: () => _startEditing(cat),
              ),
              if (!isDefault)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmDelete(context, notasState, cat),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForm(NotasState notasState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _editingCategory != null ? 'Editar Categoría' : 'Nueva Categoría',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelForm,
                child: const Text('Cancelar'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Campo de Nombre
          const Text('Nombre de la categoría', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej: Acuerdos de Pareja, Finanzas...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NotasColors.primary, width: 1.8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 18),

          // Selector de Emoji / Icono
          const Text('Icono representativo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableIcons.map((icon) {
              final isSelected = _selectedIcon == icon;
              return InkWell(
                onTap: () => setState(() => _selectedIcon = icon),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? NotasColors.primaryLight : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? NotasColors.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Selector de Color
          const Text('Color distintivo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableColors.map((color) {
              final isSelected = _selectedColor.value == color.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Botón Guardar
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _saveCategory(notasState),
              style: FilledButton.styleFrom(
                backgroundColor: NotasColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _editingCategory != null ? 'Actualizar Categoría' : 'Crear Categoría',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
