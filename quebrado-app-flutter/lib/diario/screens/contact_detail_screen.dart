import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../models/diario_category.dart';
import '../models/diario_template.dart';
import '../models/diario_entry.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../dialogs/contact_editor_dialog.dart';
import '../dialogs/category_editor_dialog.dart';
import 'entry_editor_dialog.dart';
import '../widgets/diario_image_helper.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../habitos/models/habit_model.dart';
import '../../habitos/dialogs/habit_terminal_editor_dialog.dart';
import '../../habitos/dialogs/habit_detail_cli_dialog.dart';
import '../../habitos/theme/habitos_terminal_theme.dart';

class ContactDetailScreen extends StatefulWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  String? _selectedRootCategoryId;
  String? _selectedSubcategoryId;

  @override
  void initState() {
    super.initState();
    // Inicia en null para mostrar 'Todos los registros' por defecto
  }

  void _openEntryEditor([DiarioEntry? entry]) {
    final state = Provider.of<DiarioState>(context, listen: false);
    final catId = entry?.categoryId ??
        _selectedSubcategoryId ??
        _selectedRootCategoryId ??
        state.getRootCategories(widget.contactId).firstOrNull?.id;

    if (catId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona o crea una categoría primero')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EntryEditorDialog(
        contactId: widget.contactId,
        categoryId: catId,
        entry: entry,
      ),
    );
  }

  void _openSubcategoryEditor(String parentId) {
    showDialog(
      context: context,
      builder: (context) => CategoryEditorDialog(
        contactId: widget.contactId,
        parentId: parentId,
      ),
    );
  }

  void _openContactEditor(DiarioContact contact) {
    showDialog(
      context: context,
      builder: (context) => ContactEditorDialog(contact: contact),
    );
  }

  void _confirmDeleteContact(DiarioContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar Contacto?'),
        content: Text('Se eliminará permanentemente a ${contact.name} y todos los registros asociados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<DiarioState>(context, listen: false).deleteContact(contact.id);
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: DiarioColors.rose),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final contact = state.getContactById(widget.contactId);

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contacto')),
        body: const Center(child: Text('El contacto no existe o fue eliminado.')),
      );
    }

    final rootCategories = state.getRootCategories(widget.contactId);

    final subcategories = _selectedRootCategoryId != null
        ? state.getSubcategories(_selectedRootCategoryId!, widget.contactId)
        : <DiarioCategory>[];

    // Get entries for current view: if _selectedRootCategoryId is null, show all entries for this contact
    final effectiveCategoryId = _selectedSubcategoryId ?? _selectedRootCategoryId;
    final entries = _selectedRootCategoryId == null
        ? state.getEntriesForContact(contact.id)
        : (effectiveCategoryId != null
            ? state.getEntriesForCategory(contact.id, effectiveCategoryId)
            : <DiarioEntry>[]);

    return Scaffold(
      backgroundColor: DiarioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          contact.name,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DiarioColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              contact.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: contact.isFavorite ? DiarioColors.primary : DiarioColors.textMuted,
            ),
            tooltip: contact.isFavorite ? 'Quitar de favoritos' : 'Marcar favorito',
            onPressed: () => state.toggleFavoriteContact(contact.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar datos personales',
            onPressed: () => _openContactEditor(contact),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'delete') _confirmDeleteContact(contact);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: DiarioColors.rose, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar Contacto', style: TextStyle(color: DiarioColors.rose, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Profile Header Card
          SliverToBoxAdapter(
            child: _buildContactHeaderCard(context, contact, state),
          ),

          // 2. Linked Habits Section
          SliverToBoxAdapter(
            child: _buildLinkedHabitsSection(context, contact),
          ),

          // 3. Root Categories Selector (Horizontal Bar)
          SliverToBoxAdapter(
            child: _buildRootCategoriesBar(rootCategories, state),
          ),

          // 3. Subcategories Pills Bar
          if (_selectedRootCategoryId != null)
            SliverToBoxAdapter(
              child: _buildSubcategoriesBar(subcategories),
            ),

          // 4. Entries List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Registros y Detalles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entries.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DiarioColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Entries List or Empty State
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyEntriesState(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    return _buildEntryCard(context, entry, state);
                  },
                  childCount: entries.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryEditor(),
        backgroundColor: DiarioColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: CONTACT HEADER CARD
  // ===========================================================================
  Widget _buildContactHeaderCard(BuildContext context, DiarioContact contact, DiarioState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DiarioColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Interactive Avatar
              GestureDetector(
                onTap: () => _updateAvatarDirectly(contact, state),
                child: Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DiarioColors.primary.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: DiarioImageHelper.buildImageWidget(
                                contact.avatarUrl!,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              contact.initials,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: DiarioColors.primary,
                              ),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: DiarioColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Name & Nickname
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: DiarioColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (contact.nickname != null && contact.nickname!.isNotEmpty)
                      Text(
                        'Conocido como "${contact.nickname}"',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (contact.relationship != null && contact.relationship!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DiarioColors.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              contact.relationship!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        InkWell(
                          onTap: () => _openContactEditor(contact),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DiarioColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: DiarioColors.primary.withOpacity(0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 12, color: DiarioColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: DiarioColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Birthday & Phone section
          if (contact.birthdate != null || (contact.phone != null && contact.phone!.isNotEmpty)) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: DiarioColors.cardBorder),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (contact.birthdate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cake_outlined, size: 16, color: DiarioColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${contact.formattedBirthdate} (${contact.daysUntilBirthday == 0 ? "¡HOY!" : "en ${contact.daysUntilBirthday}d"})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DiarioColors.primary),
                        ),
                      ],
                    ),
                  ),
                if (contact.phone != null && contact.phone!.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: contact.phone!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Teléfono copiado: ${contact.phone}')),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: DiarioColors.surfaceHover,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, size: 16, color: DiarioColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            contact.phone!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DiarioColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 13, color: DiarioColors.textMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Quick Notes preview
          if (contact.notes != null && contact.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DiarioColors.surfaceHover,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contact.notes!,
                style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET: ROOT CATEGORIES SELECTOR
  // ===========================================================================
  Widget _buildRootCategoriesBar(List<DiarioCategory> categories, DiarioState state) {
    final totalEntriesCount = state.getEntriesForContact(widget.contactId).length;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 2,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedRootCategoryId == null;
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(Icons.grid_view_rounded, size: 16, color: isSelected ? Colors.white : DiarioColors.primary),
              label: Text(
                'Todos ($totalEntriesCount)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : DiarioColors.textPrimary,
                ),
              ),
              backgroundColor: Colors.white,
              selectedColor: DiarioColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder,
                ),
              ),
              onSelected: (val) {
                setState(() {
                  _selectedRootCategoryId = null;
                  _selectedSubcategoryId = null;
                });
              },
            );
          }

          if (index == categories.length + 1) {
            // Button to add custom root category
            return IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: DiarioColors.primary),
              tooltip: 'Nueva Categoría Raíz',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CategoryEditorDialog(contactId: widget.contactId),
                );
              },
            );
          }

          final cat = categories[index - 1];
          final isSelected = cat.id == _selectedRootCategoryId;
          final catEntriesCount = state.getEntriesForCategory(widget.contactId, cat.id).length;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(cat.iconData, size: 16, color: isSelected ? Colors.white : cat.color),
            label: Text(
              catEntriesCount > 0 ? '${cat.name} ($catEntriesCount)' : cat.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? Colors.white : DiarioColors.textPrimary,
              ),
            ),
            backgroundColor: Colors.white,
            selectedColor: DiarioColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder,
              ),
            ),
            onSelected: (val) {
              setState(() {
                _selectedRootCategoryId = cat.id;
                _selectedSubcategoryId = null; // Reset subcategory
              });
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // WIDGET: SUBCATEGORIES PILLS BAR
  // ===========================================================================
  Widget _buildSubcategoriesBar(List<DiarioCategory> subcategories) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "Todos" Pill
            ChoiceChip(
              label: const Text('Todos los registros', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              selected: _selectedSubcategoryId == null,
              selectedColor: DiarioColors.primaryLight,
              labelStyle: TextStyle(
                color: _selectedSubcategoryId == null ? DiarioColors.primary : DiarioColors.textSecondary,
              ),
              onSelected: (val) {
                setState(() => _selectedSubcategoryId = null);
              },
            ),
            const SizedBox(width: 8),

            // Subcategories chips
            ...subcategories.map((sub) {
              final isSelected = sub.id == _selectedSubcategoryId;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  avatar: Icon(sub.iconData, size: 14, color: isSelected ? Colors.white : sub.color),
                  label: Text(sub.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: sub.color,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  onSelected: (val) {
                    setState(() => _selectedSubcategoryId = isSelected ? null : sub.id);
                  },
                ),
              );
            }),

            // Add Subcategory Button (+)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 14, color: DiarioColors.primary),
              label: const Text('Subcategoría', style: TextStyle(fontSize: 11, color: DiarioColors.primary, fontWeight: FontWeight.w700)),
              backgroundColor: DiarioColors.primaryLight,
              side: BorderSide.none,
              onPressed: () => _openSubcategoryEditor(_selectedRootCategoryId!),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: ENTRY CARD (RICH TEMPLATE / SIMPLE NOTE)
  // ===========================================================================
  Widget _buildEntryCard(BuildContext context, DiarioEntry entry, DiarioState state) {
    DiarioTemplate? template;
    if (entry.templateId != null) {
      template = state.getTemplateById(entry.templateId!);
    }

    final category = state.getCategoryById(entry.categoryId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isPinned ? DiarioColors.primary.withOpacity(0.35) : DiarioColors.cardBorder,
          width: entry.isPinned ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Model / Category Badge + Pin + Context Menu
            Row(
              children: [
                if (template != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: template.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(template.iconData, size: 13, color: template.color),
                        const SizedBox(width: 4),
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: template.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 13, color: DiarioColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Nota simple',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Fecha del registro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: DiarioColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DiarioColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 10, color: DiarioColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        entry.formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: DiarioColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Pin indicator
                if (entry.isPinned)
                  IconButton(
                    icon: const Icon(Icons.push_pin_rounded, color: DiarioColors.primary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => state.togglePinEntry(entry.id),
                  ),

                if (entry.isPinned) const SizedBox(width: 6),

                // Popup menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20, color: DiarioColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'edit') _openEntryEditor(entry);
                    if (val == 'pin') state.togglePinEntry(entry.id);
                    if (val == 'delete') state.deleteEntry(entry.id);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(entry.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(entry.isPinned ? 'Desfijar' : 'Fijar al inicio'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: DiarioColors.rose, size: 18),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: DiarioColors.rose)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Title
            Text(
              entry.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: DiarioColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),

            // Content Data (Structured Model Fields Display)
            if (entry.contentData.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DiarioColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: entry.contentData.entries
                      .where((e) => e.key != 'photo_url' && e.key != 'photo_path')
                      .map((dataEntry) {
                    final key = dataEntry.key;
                    final val = dataEntry.value?.toString() ?? '';
                    if (val.isEmpty) return const SizedBox.shrink();

                    // Find field label if template available
                    String label = key.toUpperCase();
                    if (template != null) {
                      try {
                        label = template.fields.firstWhere((f) => f.key == key).label;
                      } catch (_) {}
                    }

                    // Highlight for license plate or key values
                    final isHighlight = key.toLowerCase().contains('placa') || key.toLowerCase().contains('talla');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[500],
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        isHighlight
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: DiarioColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  val,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: DiarioColors.primary,
                                  ),
                                ),
                              )
                            : Text(
                                val,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: DiarioColors.textPrimary,
                                ),
                              ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            // Content Text (Notes)
            if (entry.contentText != null && entry.contentText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.contentText!,
                style: const TextStyle(
                  fontSize: 13,
                  color: DiarioColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],

            // Photo Attachment Display
            if (entry.hasPhoto) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => DiarioImageHelper.openFullScreenImage(
                  context,
                  entry.photoUrl!,
                  title: entry.title,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        DiarioImageHelper.buildImageWidget(
                          entry.photoUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Ver foto',
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEntriesState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.note_add_outlined, size: 30, color: DiarioColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'No hay registros en esta sección',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Guarda un gusto, una idea de regalo o aplica un modelo como auto o talla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openEntryEditor(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar Registro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DiarioColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAvatarDirectly(DiarioContact contact, DiarioState state) async {
    final result = await DiarioImageHelper.pickAvatarWithSourceModal(
      context,
      hasExistingAvatar: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty,
    );
    if (result == null) return;

    if (result.isEmpty) {
      await state.updateContact(contact.copyWith(avatarUrl: null, clearAvatar: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil eliminada')),
        );
      }
    } else {
      await state.updateContact(contact.copyWith(avatarUrl: result));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada con éxito')),
        );
      }
    }
  }

  Widget _buildLinkedHabitsSection(BuildContext context, DiarioContact contact) {
    final habitosState = Provider.of<HabitosState>(context);
    final linkedHabits = habitosState.getHabitsForContact(contact.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.track_changes_rounded, size: 16, color: HabitosColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hábitos Vinculados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${linkedHabits.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.primary),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showLinkHabitBottomSheet(context, contact, habitosState),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HabitosColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HabitosColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: HabitosColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Vincular',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HabitosColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (linkedHabits.isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DiarioColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No tienes hábitos vinculados a este contacto aún.',
                style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...linkedHabits.map((habit) {
              final isCompleted = habitosState.isCompleted(habit.id);
              final val = habitosState.getValue(habit.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DiarioColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DiarioColors.cardBorder),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => HabitDetailCliDialog(habit: habit),
                        );
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: habit.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          habit.isNegative ? Icons.shield_outlined : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => HabitDetailCliDialog(habit: habit),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DiarioColors.textPrimary),
                            ),
                            Text(
                              habit.type == HabitType.counter
                                  ? '${val.toInt()} ${habit.unit ?? "veces"} hoy'
                                  : (habit.type == HabitType.quantitative
                                      ? '${val.toInt()} / ${habit.targetValue.toInt()} ${habit.unit ?? ""}'
                                      : (isCompleted ? 'Completado hoy' : 'Pendiente hoy')),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (isCompleted || val > 0) ? HabitosColors.primary : DiarioColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (habit.type == HabitType.counter) ...[
                      if (val > 0)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          color: DiarioColors.textMuted,
                          onPressed: () => habitosState.updateHabitValue(habit.id, -1),
                        ),
                      ElevatedButton(
                        onPressed: () => habitosState.incrementCounter(habit.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HabitosColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(36, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('+1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isCompleted ? HabitosColors.primary : DiarioColors.textMuted,
                          size: 22,
                        ),
                        onPressed: () => habitosState.toggleHabitCompletion(habit.id),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showLinkHabitBottomSheet(BuildContext context, DiarioContact contact, HabitosState habitosState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final availableHabits = habitosState.allHabits.where((h) => h.contactId != contact.id).toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Hábitos para ${contact.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DiarioColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Elige cómo vincular hábitos con este contacto',
                  style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: HabitosColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_task_rounded, color: HabitosColors.primary, size: 20),
                  ),
                  title: const Text('Crear Nuevo Hábito', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: const Text('Configura un hábito nuevo asignado a este contacto', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: DiarioColors.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: DiarioColors.background,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (_) => HabitTerminalEditorDialog(initialContactId: contact.id),
                    );
                  },
                ),
                if (availableHabits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'O VINCULAR HÁBITO EXISTENTE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: DiarioColors.textSecondary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableHabits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (c, idx) {
                        final h = availableHabits[idx];
                        return ListTile(
                          dense: true,
                          title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(h.type.label, style: const TextStyle(fontSize: 10)),
                          trailing: const Text(
                            '+ Vincular',
                            style: TextStyle(color: HabitosColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          tileColor: DiarioColors.background,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await habitosState.linkHabitToContact(h.id, contact.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hábito "${h.title}" vinculado a ${contact.name}')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
