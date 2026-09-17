import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_entry.dart';
import '../models/diario_template.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../screens/entry_editor_dialog.dart';
import '../dialogs/quick_note_dialog.dart';
import '../dialogs/entry_reader_dialog.dart';
import '../widgets/diario_image_helper.dart';

class PersonalNotesView extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const PersonalNotesView({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 88),
  });

  @override
  State<PersonalNotesView> createState() => _PersonalNotesViewState();
}

class _PersonalNotesViewState extends State<PersonalNotesView> {
  String _searchQuery = '';
  String _selectedFilter = 'Todas'; // 'Todas', 'Fijadas', 'Con Foto', 'Recientes'

  final List<String> _filters = ['Todas', 'Fijadas', 'Con Foto', 'Recientes'];

  void _openQuickNoteDialog({bool autoStartVoice = false}) {
    showDialog(
      context: context,
      builder: (context) => QuickNoteDialog(autoStartVoice: autoStartVoice),
    );
  }

  void _openNewNoteDialog({bool startListening = false}) {
    showDialog(
      context: context,
      builder: (context) => const EntryEditorDialog(
        contactId: 'personal',
        categoryId: 'cat_notas_personales',
      ),
    );
  }

  void _openEditNoteDialog(DiarioEntry entry) {
    showDialog(
      context: context,
      builder: (context) => EntryEditorDialog(
        contactId: entry.contactId,
        categoryId: entry.categoryId,
        entry: entry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final allPersonal = state.personalEntries;

    // Filter logic
    final filtered = allPersonal.where((e) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchText = e.contentText?.toLowerCase().contains(q) ?? false;
        final matchData = e.contentData.values.any((v) => v != null && v.toString().toLowerCase().contains(q));
        if (!matchTitle && !matchText && !matchData) return false;
      }

      if (_selectedFilter == 'Fijadas') return e.isPinned;
      if (_selectedFilter == 'Con Foto') return e.hasPhoto;
      if (_selectedFilter == 'Recientes') {
        final difference = DateTime.now().difference(e.createdAt).inDays;
        return difference <= 7;
      }
      return true;
    }).toList();

    return ListView(
      padding: widget.padding,
      children: [
        // 1. Header Banner: Quick Action & Stats
        _buildHeaderBanner(context, allPersonal.length),

        const SizedBox(height: 14),

        // 2. Search Field
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Buscar en mis notas personales...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: DiarioColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DiarioColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DiarioColors.cardBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        const SizedBox(height: 10),

        // 3. Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: DiarioColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? Colors.white : DiarioColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder,
                    ),
                  ),
                  onSelected: (val) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Notes List or Empty State
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ...filtered.map((entry) => _buildPersonalNoteCard(context, entry, state)),
      ],
    );
  }

  Widget _buildHeaderBanner(BuildContext context, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6F5F), Color(0xFF164E43)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6F5F).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Notas Personales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '$totalCount ${totalCount == 1 ? "nota guardada" : "notas guardadas"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openQuickNoteDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F6F5F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text(
                    'Nota Rápida',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNewNoteDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Nota Completa',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: DiarioColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.note_alt_outlined, size: 28, color: DiarioColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin notas personales aún',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Guarda ideas, recordatorios rápidos o notas por voz sin tener que asociarlas a ningún contacto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openNewNoteDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: DiarioColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Crear Primera Nota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalNoteCard(BuildContext context, DiarioEntry entry, DiarioState state) {
    DiarioTemplate? template;
    if (entry.templateId != null) {
      template = state.getTemplateById(entry.templateId!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isPinned ? DiarioColors.primary.withOpacity(0.40) : DiarioColors.cardBorder,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openEntryReader(context, entry),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Badge + Date + Pin + Options Menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            template != null ? template.iconData : Icons.note_alt_rounded,
                            size: 13,
                            color: DiarioColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            template != null ? template.name : 'Nota Personal',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: DiarioColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Date
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

                    if (entry.isPinned)
                      IconButton(
                        icon: const Icon(Icons.push_pin_rounded, color: DiarioColors.primary, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Nota fijada',
                        onPressed: () => state.togglePinEntry(entry.id),
                      ),

                    if (entry.isPinned) const SizedBox(width: 6),

                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: DiarioColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (val) {
                        if (val == 'edit') _openEditNoteDialog(entry);
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

                // Title
                if (entry.hasTitle) ...[
                  const SizedBox(height: 10),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: DiarioColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],

                // Content text
                if (entry.contentText != null && entry.contentText!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.contentText!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DiarioColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Dynamic template fields badges
                if (entry.contentData.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.contentData.entries.where((e) => e.value != null && e.value.toString().trim().isNotEmpty).map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DiarioColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DiarioColors.cardBorder),
                        ),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: DiarioColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Photo Thumbnail
                if (entry.hasPhoto) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => DiarioImageHelper.openFullScreenImage(
                      context,
                      entry.photoUrl!,
                      title: entry.title.isNotEmpty ? entry.title : 'Nota Personal',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DiarioImageHelper.buildImageWidget(
                        entry.photoUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
