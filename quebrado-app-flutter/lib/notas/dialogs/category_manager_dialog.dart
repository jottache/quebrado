import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

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
  Color _selectedColor = NotasColors.categoryDefault;

  final List<String> _availableIcons = [
    '📁', '💍', '💡', '📍', '📝', '🎯', '🚀', '❤️',
    '💼', '📚', '🏠', '✈️', '🛒', '🎨', '🔒', '⭐',
  ];

  final List<Color> _availableColors = NotasColors.categoryPalette;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: OrtizPalette.warn, size: OrtizIconSize.lg),
            const SizedBox(width: OrtizSpace.sm),
            const Expanded(
              child: Text(
                '¿Eliminar categoría?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.title),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.body),
            ),
            const SizedBox(height: OrtizSpace.sm),
            if (noteCount > 0)
              Container(
                padding: const EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: OrtizPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  border: Border.all(color: OrtizPalette.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: NotasColors.primary, size: OrtizIconSize.md),
                    const SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        'Esta categoría tiene $noteCount notas asociadas. Ninguna nota se perderá: se moverán automáticamente a la categoría "General".',
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.fg, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Esta categoría no tiene notas asociadas y se eliminará de forma permanente.',
                style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: OrtizPalette.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OrtizPalette.bad,
              foregroundColor: OrtizPalette.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: OrtizPalette.onAccent, fontWeight: FontWeight.bold)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
      backgroundColor: OrtizPalette.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del diálogo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.lg),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OrtizPalette.line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NotasColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Center(
                      child: Icon(Icons.folder_special_rounded, color: NotasColors.primary, size: OrtizIconSize.md),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categorías de Notas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm, color: OrtizPalette.fg),
                        ),
                        Text(
                          'Organiza tus notas, acuerdos e ideas',
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
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
                padding: const EdgeInsets.all(OrtizSpace.lg),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: OrtizPalette.line)),
                ),
                child: FilledButton.icon(
                  onPressed: _startCreating,
                  icon: const Icon(Icons.add_rounded, size: OrtizIconSize.sm),
                  label: const Text('Nueva Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: NotasColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
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
        child: Text('No hay categorías registradas', style: TextStyle(color: OrtizPalette.muted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.md),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final noteCount = notasState.notes.where((n) => n.categoryId == cat.id).length;
        final isDefault = cat.isSystem || cat.id == NoteCategory.generalCategoryId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(OrtizRadius.chip),
              border: Border.all(color: cat.color.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Center(
              child: Text(cat.icon, style: const TextStyle(fontSize: OrtizFontSize.title)),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: OrtizFontSize.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: OrtizSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: const Text(
                    'Predeterminada',
                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: OrtizIconSize.sm, color: OrtizPalette.muted),
                tooltip: 'Editar',
                onPressed: () => _startEditing(cat),
              ),
              if (!isDefault)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: OrtizIconSize.sm, color: OrtizPalette.bad),
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
      padding: const EdgeInsets.all(OrtizSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _editingCategory != null ? 'Editar Categoría' : 'Nueva Categoría',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelForm,
                child: const Text('Cancelar'),
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.md),

          // Campo de Nombre
          const Text('Nombre de la categoría', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.bodySm)),
          const SizedBox(height: OrtizSpace.xs),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej: Acuerdos de Pareja, Finanzas...',
              hintStyle: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
              filled: true,
              fillColor: OrtizPalette.surfaceHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip), borderSide: const BorderSide(color: OrtizPalette.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip), borderSide: const BorderSide(color: OrtizPalette.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip), borderSide: const BorderSide(color: NotasColors.primary, width: 1.8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
            ),
          ),
          const SizedBox(height: OrtizSpace.lg),

          // Selector de Emoji / Icono
          const Text('Icono representativo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.bodySm)),
          const SizedBox(height: OrtizSpace.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableIcons.map((icon) {
              final isSelected = _selectedIcon == icon;
              return InkWell(
                onTap: () => setState(() => _selectedIcon = icon),
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? NotasColors.primaryLight : OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    border: Border.all(
                      color: isSelected ? NotasColors.primary : OrtizPalette.line,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: OrtizFontSize.title)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: OrtizSpace.lg),

          // Selector de Color
          const Text('Color distintivo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.bodySm)),
          const SizedBox(height: OrtizSpace.sm),
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
                    border: Border.all(
                      color: isSelected ? OrtizPalette.fg : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: OrtizPalette.onAccent, size: OrtizIconSize.sm)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: OrtizSpace.xxl),

          // Botón Guardar
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _saveCategory(notasState),
              style: FilledButton.styleFrom(
                backgroundColor: NotasColors.primary,
                foregroundColor: OrtizPalette.onAccent,
                padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
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
