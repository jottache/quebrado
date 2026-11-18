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
import '../widgets/mention_text_field.dart';
import '../widgets/mood_quick_bar.dart';
import '../screens/animo_dashboard_screen.dart';
import '../../notas/notas.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class PersonalNotesView extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const PersonalNotesView({
    super.key,
    // Abajo deja sitio al FAB (48 + 32 + 8 = 88).
    this.padding = const EdgeInsets.fromLTRB(
      OrtizSpace.lg,
      OrtizSpace.lg,
      OrtizSpace.lg,
      OrtizSize.minTouch + OrtizSpace.xxxl + OrtizSpace.sm,
    ),
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
        // 0. Check-in de ánimo (no se dibuja si AnimoState no está registrado)
        MoodTodayCard(
          margin: const EdgeInsets.only(bottom: OrtizSpace.md),
          onOpenDashboard: () => openAnimoDashboard(context),
        ),

        // 1. Header Banner: Quick Action & Stats
        _buildHeaderBanner(context, allPersonal.length),

        const SizedBox(height: OrtizSpace.md),

        // 2. Search Field
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Buscar en mis notas personales...',
            prefixIcon: const Icon(Icons.search_rounded, size: OrtizIconSize.md, color: DiarioColors.textMuted),
            filled: true,
            fillColor: OrtizPalette.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(OrtizRadius.block),
              borderSide: const BorderSide(color: DiarioColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(OrtizRadius.block),
              borderSide: const BorderSide(color: DiarioColors.cardBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
          ),
        ),

        const SizedBox(height: OrtizSpace.sm),

        // 3. Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: OrtizSpace.sm),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: DiarioColors.primary,
                  backgroundColor: OrtizPalette.bg,
                  labelStyle: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? OrtizPalette.onAccent : DiarioColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
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

        const SizedBox(height: OrtizSpace.md),

        // 4. Notes List or Empty State
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ...filtered.map((entry) => _buildPersonalNoteCard(context, entry, state)),
      ],
    );
  }

  Widget _buildHeaderBanner(BuildContext context, int totalCount) {
    // Sin tarjeta (spec 05): encabezado sobre el fondo, sin degradado ni sombra.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: DiarioColors.primaryLight,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
                child: const Icon(Icons.note_alt_rounded, color: DiarioColors.primary, size: OrtizIconSize.md),
              ),
              const SizedBox(width: OrtizSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Notas Personales',
                      style: TextStyle(
                        fontSize: OrtizFontSize.titleSm,
                        fontWeight: FontWeight.w900,
                        color: OrtizPalette.fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '$totalCount ${totalCount == 1 ? "nota guardada" : "notas guardadas"}',
                      style: const TextStyle(
                        fontSize: OrtizFontSize.caption,
                        color: OrtizPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openQuickNoteDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DiarioColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: OrtizIconSize.md),
                  label: const Text(
                    'Nota Rápida',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
                  ),
                ),
              ),
              const SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNewNoteDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DiarioColors.primary,
                    side: const BorderSide(color: DiarioColors.primaryBorder),
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: OrtizIconSize.md),
                  label: const Text(
                    'Nota Completa',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
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
    // Sin tarjeta (spec 05): estado vacío sobre el fondo.
    return Container(
      margin: const EdgeInsets.only(top: OrtizSpace.xl),
      padding: const EdgeInsets.all(OrtizSpace.xxxl),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: DiarioColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.note_alt_outlined, size: OrtizIconSize.xl, color: DiarioColors.primary),
          ),
          const SizedBox(height: OrtizSpace.md),
          const Text(
            'Sin notas personales aún',
            style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
          ),
          const SizedBox(height: OrtizSpace.xs),
          const Text(
            'Guarda ideas, recordatorios rápidos o notas por voz sin tener que asociarlas a ningún contacto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: DiarioColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: OrtizSpace.md),
          ElevatedButton.icon(
            onPressed: () => _openNewNoteDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: DiarioColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
            ),
            icon: const Icon(Icons.add_rounded, size: OrtizIconSize.md),
            label: const Text('Crear Primera Nota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
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

    // Sin tarjeta (spec 05): fila sobre el fondo; la fijada va sobre `surfaceHigh`.
    return Container(
      margin: const EdgeInsets.only(bottom: OrtizSpace.md),
      decoration: BoxDecoration(
        color: entry.isPinned ? OrtizPalette.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openEntryReader(context, entry),
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          child: Padding(
            padding: const EdgeInsets.all(OrtizSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Badge + Date + Pin + Options Menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            template != null ? template.iconData : Icons.note_alt_rounded,
                            size: OrtizIconSize.xs,
                            color: DiarioColors.primary,
                          ),
                          const SizedBox(width: OrtizSpace.xs),
                          Text(
                            template != null ? template.name : 'Nota Personal',
                            style: const TextStyle(
                              fontSize: OrtizFontSize.caption,
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
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: DiarioColors.background,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        border: Border.all(color: DiarioColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: OrtizIconSize.xs, color: DiarioColors.textMuted),
                          const SizedBox(width: OrtizSpace.xs),
                          Text(
                            entry.formattedDate,
                            style: const TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w700,
                              color: DiarioColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: OrtizSpace.xs),

                    if (entry.isPinned)
                      IconButton(
                        icon: const Icon(Icons.push_pin_rounded, color: DiarioColors.primary, size: OrtizIconSize.md),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Nota fijada',
                        onPressed: () => state.togglePinEntry(entry.id),
                      ),

                    if (entry.isPinned) const SizedBox(width: OrtizSpace.xs),

                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: OrtizIconSize.md, color: DiarioColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
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
                              Icon(entry.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: OrtizIconSize.md),
                              const SizedBox(width: OrtizSpace.sm),
                              Text(entry.isPinned ? 'Desfijar' : 'Fijar al inicio'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: OrtizIconSize.md),
                              SizedBox(width: OrtizSpace.sm),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: DiarioColors.rose, size: OrtizIconSize.md),
                              SizedBox(width: OrtizSpace.sm),
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
                  const SizedBox(height: OrtizSpace.sm),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.w900,
                      color: DiarioColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],

                // Content text
                if (entry.contentText != null && entry.contentText!.isNotEmpty) ...[
                  const SizedBox(height: OrtizSpace.xs),
                  Text.rich(
                    TextSpan(
                      children: MentionTextSpanHelper.buildSpans(
                        text: entry.contentText!,
                        contacts: state.contacts,
                        notes: Provider.of<NotasState>(context, listen: false).notes,
                        baseStyle: const TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: DiarioColors.textSecondary,
                          height: 1.4,
                        ),
                        onContactTap: (clickedContact) {
                          state.selectContact(clickedContact.id);
                        },
                        onNoteTap: (clickedNote) {
                          NoteReaderDialog.show(context, note: clickedNote);
                        },
                      ),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Dynamic template fields badges
                if (entry.contentData.isNotEmpty) ...[
                  const SizedBox(height: OrtizSpace.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.contentData.entries.where((e) => e.value != null && e.value.toString().trim().isNotEmpty).map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                        decoration: BoxDecoration(
                          color: DiarioColors.background,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          border: Border.all(color: DiarioColors.cardBorder),
                        ),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(
                            fontSize: OrtizFontSize.caption,
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
                  const SizedBox(height: OrtizSpace.md),
                  GestureDetector(
                    onTap: () => DiarioImageHelper.openFullScreenImage(
                      context,
                      entry.photoUrl!,
                      title: entry.title.isNotEmpty ? entry.title : 'Nota Personal',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
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
