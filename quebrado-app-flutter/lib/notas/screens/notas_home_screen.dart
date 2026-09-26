import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../dialogs/category_manager_dialog.dart';
import '../dialogs/note_reader_dialog.dart';
import 'note_editor_screen.dart';

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
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded, size: 22),
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
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas & Acuerdos',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'Acuerdos, ideas, direcciones y notas flexibles',
            style: TextStyle(
              fontSize: 11,
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
          color: Colors.black54,
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
          color: Colors.black54,
          onPressed: () => CategoryManagerDialog.show(context),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          tooltip: 'Sincronizar',
          color: Colors.black54,
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar(NotasState notasState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: notasState.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Buscar en títulos y contenido...',
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    notasState.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar(NotasState notasState, List<NoteCategory> categories) {
    final selectedCatId = notasState.selectedCategoryId;

    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Píldora "Todas"
            final isSelected = selectedCatId == null;
            final totalCount = notasState.notes.length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Todas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalCount',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                onSelected: (_) => notasState.setSelectedCategory(null),
                backgroundColor: const Color(0xFFF8FAFC),
                selectedColor: NotasColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                side: BorderSide(
                  color: isSelected ? NotasColors.primary : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
            );
          }

          final cat = categories[index - 1];
          final isSelected = selectedCatId == cat.id;
          final catCount = notasState.notes.where((n) => n.categoryId == cat.id).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              avatar: Text(cat.icon, style: const TextStyle(fontSize: 14)),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.3) : cat.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$catCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : cat.color,
                      ),
                    ),
                  ),
                ],
              ),
              onSelected: (_) => notasState.setSelectedCategory(isSelected ? null : cat.id),
              backgroundColor: Colors.white,
              selectedColor: cat.color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
              side: BorderSide(
                color: isSelected ? cat.color : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        },
      ),
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
        horizontal: isDesktop ? 24 : 14,
        vertical: 16,
      ),
      children: [
        // Sección Notas Fijadas
        if (pinnedNotes.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber),
              SizedBox(width: 6),
              Text(
                'FIJADAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildResponsiveGrid(context, notasState, pinnedNotes, isDesktop),
          const SizedBox(height: 24),
        ],

        // Sección Otras Notas
        if (otherNotes.isNotEmpty) ...[
          if (pinnedNotes.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'OTRAS NOTAS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _buildResponsiveGrid(context, notasState, otherNotes, isDesktop),
        ],

        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildResponsiveGrid(
    BuildContext context,
    NotasState notasState,
    List<NoteItem> notes,
    bool isDesktop,
  ) {
    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: notes.map((note) {
              final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;
              return SizedBox(
                width: itemWidth,
                child: _buildNoteCard(context, notasState, note),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      children: notes.map((note) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildNoteCard(context, notasState, note),
        );
      }).toList(),
    );
  }

  Widget _buildNoteCard(BuildContext context, NotasState notasState, NoteItem note) {
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

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned ? Colors.amber.withOpacity(0.5) : const Color(0xFFE2E8F0),
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => NoteReaderDialog.show(context, note: note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Categoría + Pin + Menú
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 11,
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
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber),
                    ),
                  _buildCardPopupMenu(context, notasState, note),
                ],
              ),
              const SizedBox(height: 10),

              // Emoji + Título
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 16,
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
                const SizedBox(height: 8),
                Text(
                  previewText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Barra de progreso de Tareas si tiene todos
              if (note.hasTodos) ...[
                const SizedBox(height: 12),
                _buildMiniTodoProgress(note),
              ],

              const SizedBox(height: 12),

              // Fecha en pie de tarjeta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    note.formattedDate,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    '${note.blocks.length} ${note.blocks.length == 1 ? 'bloque' : 'bloques'}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed de $total tareas',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              Text(
                '${(percent * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: percent == 1.0 ? const Color(0xFF10B981) : NotasColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 1.0 ? const Color(0xFF10B981) : NotasColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPopupMenu(BuildContext context, NotasState notasState, NoteItem note) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
      onSelected: (val) async {
        switch (val) {
          case 'pin':
            await notasState.togglePinNote(note.id);
            break;
          case 'edit':
            NoteEditorScreen.open(context, note: note);
            break;
          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('¿Eliminar nota?'),
                content: Text('Estás a punto de eliminar "${note.title}".'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
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
              Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(note.isPinned ? 'Desfijar' : 'Fijar al inicio', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text('Editar', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, NotasState notasState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: NotasColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.note_alt_outlined, size: 40, color: NotasColors.primary),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No se encontraron notas'
                  : 'No hay notas en esta categoría',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Prueba con otra palabra clave o limpia el filtro de búsqueda'
                  : 'Empieza registrando acuerdos de pareja, ideas de proyectos o notas útiles',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
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
              icon: Icon(_searchController.text.isNotEmpty ? Icons.clear_rounded : Icons.add_rounded, size: 18),
              label: Text(
                _searchController.text.isNotEmpty ? 'Limpiar búsqueda' : 'Crear primera nota',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: NotasColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
