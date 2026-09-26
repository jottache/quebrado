import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../widgets/note_block_widget.dart';
import '../screens/note_editor_screen.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_entry.dart';
import '../../diario/dialogs/entry_reader_dialog.dart';

/// Diálogo o Modal de visualización limpia de una Nota o Acuerdo.
/// Permite interactuar con casillas de verificación (to-dos) en tiempo real,
/// desplegar secciones plegables, exportar a Markdown y consultar backlinks del Diario.
class NoteReaderDialog extends StatelessWidget {
  final NoteItem? initialNote;
  final String? noteId;

  const NoteReaderDialog({
    super.key,
    this.initialNote,
    this.noteId,
  }) : assert(initialNote != null || noteId != null);

  static Future<void> show(BuildContext context, {NoteItem? note, String? noteId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoteReaderDialog(
        initialNote: note,
        noteId: noteId ?? note?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notasState = Provider.of<NotasState>(context);
    final targetId = noteId ?? initialNote!.id;
    
    // Buscar la versión viva de la nota en el estado para reflejar cambios reactivos
    final note = notasState.notes.firstWhere(
      (n) => n.id == targetId,
      orElse: () => initialNote ?? NoteItem(id: targetId, title: 'Nota no encontrada'),
    );

    final category = notasState.categories.firstWhere(
      (c) => c.id == note.categoryId,
      orElse: () => notasState.categories.isNotEmpty
          ? notasState.categories.first
          : null as dynamic,
    );

    // Obtener backlinks desde DiarioState
    final diarioState = Provider.of<DiarioState>(context, listen: false);
    final backlinks = _findDiarioBacklinks(diarioState, note);

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 16,
        vertical: isDesktop ? 32 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del lector
            _buildHeader(context, notasState, note, category),

            // Contenido con bloques interactivos
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // Título principal con emoji
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Text(note.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: NotasColors.textPrimary,
                                letterSpacing: -0.4,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (category != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: category.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(category.icon, style: const TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        Text(
                                          category.name,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: category.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Text(
                                  note.formattedDate,
                                  style: const TextStyle(fontSize: 11.5, color: NotasColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Barra de progreso si tiene tareas
                  if (note.hasTodos) ...[
                    const SizedBox(height: 18),
                    _buildTodoProgressBar(note),
                  ],

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Lista de bloques
                  if (note.blocks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Esta nota no tiene contenido.',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...note.blocks.map((block) {
                      return NoteBlockWidget(
                        key: ValueKey(block.id),
                        block: block,
                        isEditable: false,
                        onToggleTodo: (checked) {
                          notasState.toggleTodoBlock(note.id, block.id, checked);
                        },
                      );
                    }),

                  // Sección de Backlinks en Diario
                  if (backlinks.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildBacklinksSection(context, backlinks),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotasState notasState, NoteItem note, dynamic category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (note.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_rounded, size: 12, color: Colors.amber),
                  SizedBox(width: 4),
                  Text('Fijada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            ),

          const Spacer(),

          // Copiar Markdown
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.black54),
            tooltip: 'Copiar como Markdown',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: note.toMarkdown()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nota copiada en formato Markdown'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // Editar nota
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 19, color: Colors.black87),
            tooltip: 'Editar nota',
            onPressed: () async {
              Navigator.of(context).pop();
              await NoteEditorScreen.open(context, note: note);
            },
          ),

          // Eliminar nota
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
            tooltip: 'Eliminar nota',
            onPressed: () => _confirmDelete(context, notasState, note),
          ),

          // Cerrar
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoProgressBar(NoteItem note) {
    final progress = note.todoProgress;
    final total = progress.total;
    final completed = progress.completed;
    final percent = total > 0 ? (completed / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso de tareas ($completed de $total)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              Text(
                '${(percent * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NotasColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
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

  Widget _buildBacklinksSection(BuildContext context, List<DiarioEntry> backlinks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 18, color: NotasColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mencionada en el Diario (${backlinks.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: NotasColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...backlinks.map((entry) {
            return InkWell(
              onTap: () {
                openEntryReader(context, entry);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded, size: 15, color: Color(0xFF1F6F5F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.title.isNotEmpty ? entry.title : 'Entrada del Diario',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.formattedDate,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<DiarioEntry> _findDiarioBacklinks(DiarioState diarioState, NoteItem note) {
    final titleTag = '#${note.title.trim().toLowerCase()}';
    return diarioState.allEntries.where((entry) {
      // 1. Verificación por ID explícito en mentioned_note_ids
      if (entry.mentionedNoteIds.contains(note.id)) return true;
      // 2. Verificación por texto #TituloNota
      final body = (entry.contentText ?? '').toLowerCase();
      final title = entry.title.toLowerCase();
      if (body.contains(titleTag) || title.contains(titleTag)) return true;
      return false;
    }).toList();
  }

  Future<void> _confirmDelete(BuildContext context, NotasState notasState, NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar esta nota?'),
        content: Text('Estás a punto de eliminar "${note.title}". Esta acción no se puede deshacer.'),
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

    if (confirmed == true && context.mounted) {
      await notasState.deleteNote(note.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota eliminada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
