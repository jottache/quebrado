import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../dialogs/category_manager_dialog.dart';
import '../dialogs/note_reader_dialog.dart';
import '../services/note_pdf_service.dart';
import 'note_editor_screen.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Pantalla principal de la mini-app Notas & Acuerdos.
/// Integra filtros por categoría, búsqueda instantánea, notas fijadas,
/// progreso visual de tareas y diseño responsivo para móvil y escritorio.
class NotasHomeScreen extends StatefulWidget {
  const NotasHomeScreen({super.key});

  @override
  State<NotasHomeScreen> createState() => _NotasHomeScreenState();
}

class _NotasHomeScreenState extends State<NotasHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notasState = Provider.of<NotasState>(context, listen: false);
      notasState.loadNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notasState = Provider.of<NotasState>(context);
    final categories = notasState.categories;
    final filteredNotes = notasState.filteredNotes;

    final pinnedNotes = filteredNotes.where((n) => n.isPinned).toList();
    final otherNotes = filteredNotes.where((n) => !n.isPinned).toList();

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: NotasColors.background,
      appBar: _buildAppBar(context, notasState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NoteEditorScreen.open(
            context,
            initialCategoryId: notasState.selectedCategoryId,
          );
        },
        backgroundColor: NotasColors.primary,
        // Texto sobre el color de la app: `onAccent` (P-30).
        foregroundColor: OrtizPalette.onAccent,
        icon: const Icon(Icons.edit_note_rounded, size: OrtizIconSize.lg),
        label: const Text('Nueva Nota', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => notasState.loadNotes(),
        child: Column(
          children: [
            // Barra de Búsqueda (si está activa)
            if (_isSearching) _buildSearchBar(notasState),

            // Selector horizontal de Categorías
            _buildCategoryFilterBar(notasState, categories),

            // Lista o Grid de Notas
            Expanded(
              child: notasState.isLoading && notasState.notes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredNotes.isEmpty
                      ? _buildEmptyState(context, notasState)
                      : _buildNotesList(context, notasState, pinnedNotes, otherNotes, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, NotasState notasState) {
    return AppBar(
      backgroundColor: NotasColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas & Acuerdos',
            style: TextStyle(
              fontSize: OrtizFontSize.title,
              fontWeight: FontWeight.w900,
              color: OrtizPalette.fg,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'Acuerdos, ideas, direcciones y notas flexibles',
            style: TextStyle(
              fontSize: OrtizFontSize.caption,
              fontWeight: FontWeight.w600,
              color: NotasColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.search_off_rounded : Icons.search_rounded),
          tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar notas',
          color: OrtizPalette.muted,
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                notasState.setSearchQuery('');
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.folder_open_rounded),
          tooltip: 'Gestionar categorías',
          color: OrtizPalette.muted,
          onPressed: () => CategoryManagerDialog.show(context),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          tooltip: 'Sincronizar',
          color: OrtizPalette.muted,
          onPressed: () async {
            await notasState.loadNotes();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notas sincronizadas'),
                  duration: Duration(milliseconds: 900),
                ),
              );
            }
          },
        ),
        const SizedBox(width: OrtizSpace.sm),
      ],
    );
  }

  Widget _buildSearchBar(NotasState notasState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, 0, OrtizSpace.lg, OrtizSpace.md),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: notasState.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Buscar en títulos y contenido...',
          hintStyle: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
          prefixIcon: const Icon(Icons.search_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                  onPressed: () {
                    _searchController.clear();
                    notasState.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: OrtizPalette.surfaceHigh,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          isDense: true,
        ),
      ),
    );
  }

  /// Píldora de filtro. Lo activo va sobre `surfaceHigh` con borde de color
  /// (de la app o de la categoría) y texto `fg`.
  Widget _filterChip({
    required bool isSelected,
    required Color color,
    required Widget? avatar,
    required String label,
    required int count,
    required Color countColor,
    required Color countBg,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: OrtizSpace.sm),
      child: FilterChip(
        selected: isSelected,
        avatar: avatar,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
            const SizedBox(width: OrtizSpace.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
              decoration: BoxDecoration(
                color: countBg,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.bold,
                  color: countColor,
                ),
              ),
            ),
          ],
        ),
        onSelected: onSelected,
        backgroundColor: OrtizPalette.bg,
        selectedColor: OrtizPalette.surfaceHigh,
        labelStyle: TextStyle(color: isSelected ? OrtizPalette.fg : OrtizPalette.muted),
        side: BorderSide(color: isSelected ? color : OrtizPalette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildCategoryFilterBar(NotasState notasState, List<NoteCategory> categories) {
    final selectedCatId = notasState.selectedCategoryId;

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Píldora "Todas"
            final isSelected = selectedCatId == null;
            return _filterChip(
              isSelected: isSelected,
              color: NotasColors.primary,
              avatar: null,
              label: 'Todas',
              count: notasState.notes.length,
              countColor: OrtizPalette.fg,
              countBg: isSelected ? NotasColors.primaryLight : OrtizPalette.surfaceHigh,
              onSelected: (_) => notasState.setSelectedCategory(null),
            );
          }

          final cat = categories[index - 1];
          final isSelected = selectedCatId == cat.id;
          final catCount = notasState.notes.where((n) => n.categoryId == cat.id).length;

          return _filterChip(
            isSelected: isSelected,
            color: cat.color,
            avatar: Text(cat.icon, style: const TextStyle(fontSize: OrtizFontSize.body)),
            label: cat.name,
            count: catCount,
            countColor: cat.color,
            countBg: cat.color.withValues(alpha: 0.12),
            onSelected: (_) => notasState.setSelectedCategory(isSelected ? null : cat.id),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(IconData icon, Color iconColor, String text) {
    return Row(
      children: [
        Icon(icon, size: OrtizIconSize.xs, color: iconColor),
        const SizedBox(width: OrtizSpace.xs),
        Text(
          text,
          style: const TextStyle(
            fontSize: OrtizFontSize.caption,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: OrtizPalette.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    NotasState notasState,
    List<NoteItem> pinnedNotes,
    List<NoteItem> otherNotes,
    bool isDesktop,
  ) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? OrtizSpace.xxl : OrtizSpace.md,
        vertical: OrtizSpace.lg,
      ),
      children: [
        // Sección Notas Fijadas
        if (pinnedNotes.isNotEmpty) ...[
          _sectionLabel(Icons.push_pin_rounded, OrtizPalette.warn, 'FIJADAS'),
          const SizedBox(height: OrtizSpace.sm),
          _buildResponsiveGrid(context, notasState, pinnedNotes, isDesktop, 0),
          const SizedBox(height: OrtizSpace.xxl),
        ],

        // Sección Otras Notas
        if (otherNotes.isNotEmpty) ...[
          if (pinnedNotes.isNotEmpty) ...[
            _sectionLabel(Icons.notes_rounded, OrtizPalette.muted, 'OTRAS NOTAS'),
            const SizedBox(height: OrtizSpace.sm),
          ],
          _buildResponsiveGrid(context, notasState, otherNotes, isDesktop, pinnedNotes.length),
        ],

        const SizedBox(height: 90),
      ],
    );
  }

  /// [indexOffset]: posición de la primera nota en la lista completa, para
  /// que la entrada escalonada siga el orden visual.
  Widget _buildResponsiveGrid(
    BuildContext context,
    NotasState notasState,
    List<NoteItem> notes,
    bool isDesktop,
    int indexOffset,
  ) {
    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : 2;
          const gap = OrtizSpace.md;
          final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * gap) / crossAxisCount;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < notes.length; i++)
                SizedBox(
                  width: itemWidth,
                  child: ortizStaggered(context, indexOffset + i, _buildNoteItem(context, notasState, notes[i])),
                ),
            ],
          );
        },
      );
    }

    return Column(
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          ortizStaggered(context, indexOffset + i, _buildNoteItem(context, notasState, notes[i])),
        ],
      ],
    );
  }

  /// Nota sobre el fondo, sin tarjeta: al pasar el puntero o tocar se marca
  /// con `surfaceHigh`.
  Widget _buildNoteItem(BuildContext context, NotasState notasState, NoteItem note) {
    final cat = notasState.categories.firstWhere(
      (c) => c.id == note.categoryId,
      orElse: () => NoteCategory.defaultCategories().first,
    );

    // Resumen de texto de los primeros bloques
    final previewText = note.blocks
        .where((b) => b.content.trim().isNotEmpty)
        .take(3)
        .map((b) => b.content)
        .join(' • ');

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => NoteReaderDialog.show(context, note: note),
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        hoverColor: OrtizPalette.surfaceHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Categoría + Pin + Menú
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: OrtizFontSize.caption)),
                        const SizedBox(width: OrtizSpace.xs),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.bold,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (note.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: OrtizSpace.xs),
                      child: Icon(Icons.push_pin_rounded, size: OrtizIconSize.xs, color: OrtizPalette.warn),
                    ),
                  _buildCardPopupMenu(context, notasState, note),
                ],
              ),
              const SizedBox(height: OrtizSpace.sm),

              // Emoji + Título
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.emoji, style: const TextStyle(fontSize: OrtizFontSize.title)),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: OrtizFontSize.titleSm,
                        fontWeight: FontWeight.w800,
                        color: NotasColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Previsualización de texto si existe
              if (previewText.isNotEmpty) ...[
                const SizedBox(height: OrtizSpace.sm),
                Text(
                  previewText,
                  style: const TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: OrtizPalette.muted,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Barra de progreso de Tareas si tiene todos
              if (note.hasTodos) ...[
                const SizedBox(height: OrtizSpace.md),
                _buildMiniTodoProgress(note),
              ],

              const SizedBox(height: OrtizSpace.md),

              // Fecha y número de bloques
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    note.formattedDate,
                    style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                  ),
                  Text(
                    '${note.blocks.length} ${note.blocks.length == 1 ? 'bloque' : 'bloques'}',
                    style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTodoProgress(NoteItem note) {
    final progress = note.todoProgress;
    final total = progress.total;
    final completed = progress.completed;
    final percent = total > 0 ? (completed / total) : 0.0;
    final color = percent == 1.0 ? OrtizPalette.ok : NotasColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completed de $total tareas',
              style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: OrtizFontSize.caption,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: OrtizSpace.xs),
        OrtizProgressBar(value: percent, color: color, semanticsLabel: 'Tareas completadas'),
      ],
    );
  }

  Widget _buildCardPopupMenu(BuildContext context, NotasState notasState, NoteItem note) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
      onSelected: (val) async {
        final category = notasState.getCategoryById(note.categoryId);
        switch (val) {
          case 'pin':
            await notasState.togglePinNote(note.id);
            break;
          case 'edit':
            NoteEditorScreen.open(context, note: note);
            break;
          case 'pdf':
            await NotePdfService.instance.downloadNotePdf(
              note: note,
              category: category,
              context: context,
            );
            break;
          case 'share':
            await NotePdfService.showShareModal(
              context: context,
              note: note,
              category: category,
            );
            break;
          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                title: const Text('¿Eliminar nota?'),
                content: Text('Estás a punto de eliminar "${note.title}".'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: OrtizPalette.bad,
                      foregroundColor: OrtizPalette.onAccent,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Eliminar', style: TextStyle(color: OrtizPalette.onAccent)),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await notasState.deleteNote(note.id);
            }
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                size: OrtizIconSize.sm,
                color: OrtizPalette.muted,
              ),
              const SizedBox(width: OrtizSpace.sm),
              Text(note.isPinned ? 'Desfijar' : 'Fijar al inicio', style: const TextStyle(fontSize: OrtizFontSize.bodySm)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: OrtizIconSize.sm, color: OrtizPalette.muted),
              SizedBox(width: OrtizSpace.sm),
              Text('Editar', style: TextStyle(fontSize: OrtizFontSize.bodySm)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: OrtizIconSize.sm, color: OrtizPalette.muted),
              SizedBox(width: OrtizSpace.sm),
              Text('Descargar PDF', style: TextStyle(fontSize: OrtizFontSize.bodySm)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: OrtizIconSize.sm, color: OrtizPalette.muted),
              SizedBox(width: OrtizSpace.sm),
              Text('Compartir', style: TextStyle(fontSize: OrtizFontSize.bodySm)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: OrtizIconSize.sm, color: OrtizPalette.bad),
              SizedBox(width: OrtizSpace.sm),
              Text('Eliminar', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.bad)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, NotasState notasState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OrtizSpace.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: NotasColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.note_alt_outlined, size: OrtizIconSize.xxl, color: NotasColors.primary),
              ),
            ),
            const SizedBox(height: OrtizSpace.lg),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No se encontraron notas'
                  : 'No hay notas en esta categoría',
              style: const TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: OrtizPalette.fg),
            ),
            const SizedBox(height: OrtizSpace.sm),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Prueba con otra palabra clave o limpia el filtro de búsqueda'
                  : 'Empieza registrando acuerdos de pareja, ideas de proyectos o notas útiles',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
            ),
            const SizedBox(height: OrtizSpace.xl),
            FilledButton.icon(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _searchController.clear();
                  notasState.setSearchQuery('');
                } else {
                  NoteEditorScreen.open(
                    context,
                    initialCategoryId: notasState.selectedCategoryId,
                  );
                }
              },
              icon: Icon(
                _searchController.text.isNotEmpty ? Icons.clear_rounded : Icons.add_rounded,
                size: OrtizIconSize.md,
              ),
              label: Text(
                _searchController.text.isNotEmpty ? 'Limpiar búsqueda' : 'Crear primera nota',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: NotasColors.primary,
                foregroundColor: OrtizPalette.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
