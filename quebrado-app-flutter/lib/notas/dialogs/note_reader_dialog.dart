import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../widgets/note_block_widget.dart';
import '../screens/note_editor_screen.dart';
import '../services/note_document_converter.dart';
import '../services/note_pdf_service.dart';
import '../../rich_editor/rich_document_viewer.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_entry.dart';
import '../../diario/dialogs/entry_reader_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Diálogo o Modal de visualización limpia de una Nota o Acuerdo.
/// Permite interactuar con casillas de verificación (to-dos) en tiempo real,
/// desplegar secciones plegables, exportar a Markdown y consultar backlinks del Diario.
class NoteReaderDialog extends StatelessWidget {
  final NoteItem? initialNote;
  final String? noteId;

  const NoteReaderDialog({super.key, this.initialNote, this.noteId}) : assert(initialNote != null || noteId != null);

  static Future<void> show(BuildContext context, {NoteItem? note, String? noteId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoteReaderDialog(initialNote: note, noteId: noteId ?? note?.id),
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

    NoteCategory? category;
    for (final c in notasState.categories) {
      if (c.id == note.categoryId) {
        category = c;
        break;
      }
    }
    category ??= notasState.categories.isNotEmpty ? notasState.categories.first : null;

    // Obtener backlinks desde DiarioState
    final diarioState = Provider.of<DiarioState>(context, listen: false);
    final backlinks = _findDiarioBacklinks(diarioState, note);

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
      backgroundColor: OrtizPalette.surface,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? OrtizSpace.xxxl + OrtizSpace.sm : OrtizSpace.lg,
        vertical: isDesktop ? OrtizSpace.xxxl : OrtizSpace.xxl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del lector
            _buildHeader(context, notasState, note, category),

            // Contenido con bloques interactivos
            Expanded(
              child: Builder(
                builder: (context) {
                  final top = <Widget>[
                    // Título principal con emoji
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          alignment: Alignment.center,
                          child: Text(note.emoji, style: const TextStyle(fontSize: OrtizFontSize.display)),
                        ),
                        const SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: const TextStyle(
                                  fontSize: OrtizFontSize.display,
                                  fontWeight: FontWeight.w900,
                                  color: NotasColors.textPrimary,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: OrtizSpace.xs),
                              Row(
                                children: [
                                  if (category != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                                      decoration: BoxDecoration(
                                        color: category.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(category.icon, style: const TextStyle(fontSize: OrtizFontSize.bodySm)),
                                          const SizedBox(width: OrtizSpace.xs),
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: OrtizFontSize.caption,
                                              fontWeight: FontWeight.bold,
                                              color: category.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: OrtizSpace.sm),
                                  ],
                                  Text(
                                    note.formattedDate,
                                    style: const TextStyle(fontSize: OrtizFontSize.caption, color: NotasColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Barra de progreso si tiene tareas
                    if (note.hasTodos) ...[const SizedBox(height: OrtizSpace.lg), _buildTodoProgressBar(note)],

                    const SizedBox(height: OrtizSpace.lg),
                    const Divider(height: 1),
                    const SizedBox(height: OrtizSpace.md),
                  ];
                  final bottom = <Widget>[
                    // Sección de Backlinks en Diario
                    if (backlinks.isNotEmpty) ...[
                      const SizedBox(height: OrtizSpace.xxl),
                      _buildBacklinksSection(context, backlinks),
                    ],

                    const SizedBox(height: OrtizSpace.xxxl),
                  ];

                  // Documento enriquecido (notas creadas con el editor nuevo): el visor es
                  // el scroll y el resto del lector va como encabezado y pie.
                  if (note.hasRichDocument) {
                    return RichDocumentViewer(
                      document: note.document!,
                      accentColor: NotasColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                      header: Padding(
                        padding: const EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.xl, OrtizSpace.xxl, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
                      ),
                      footer: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bottom),
                      ),
                      onTodoToggled: (document) => notasState.updateNoteDocument(
                        note.id,
                        document: document.toJson(),
                        blocks: NoteDocumentConverter.fromDocument(document),
                        contentText: NoteDocumentConverter.toMarkdown(document),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl, vertical: OrtizSpace.xl),
                    children: [
                      ...top,
                      // Lista de bloques (formato anterior)
                      if (note.blocks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.xl),
                          child: Text(
                            'Esta nota no tiene contenido.',
                            style: TextStyle(fontSize: OrtizFontSize.body, color: OrtizPalette.muted, fontStyle: FontStyle.italic),
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

                      ...bottom,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotasState notasState, NoteItem note, dynamic category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OrtizPalette.line)),
      ),
      child: Row(
        children: [
          if (note.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
              margin: const EdgeInsets.only(right: OrtizSpace.sm),
              decoration: BoxDecoration(color: OrtizPalette.warnTint, borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_rounded, size: OrtizIconSize.xs, color: OrtizPalette.warn),
                  SizedBox(width: OrtizSpace.xs),
                  Text(
                    'Fijada',
                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.warn),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Descargar PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: OrtizIconSize.md, color: OrtizPalette.fg),
            tooltip: 'Descargar como PDF',
            onPressed: () async {
              await NotePdfService.instance.downloadNotePdf(
                note: note,
                category: category is NoteCategory ? category : null,
                context: context,
              );
            },
          ),

          // Compartir
          IconButton(
            icon: const Icon(Icons.share_outlined, size: OrtizIconSize.md, color: OrtizPalette.fg),
            tooltip: 'Compartir nota',
            onPressed: () async {
              await NotePdfService.showShareModal(
                context: context,
                note: note,
                category: category is NoteCategory ? category : null,
              );
            },
          ),

          // Copiar Markdown
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
            tooltip: 'Copiar como Markdown',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: note.toMarkdown()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nota copiada en formato Markdown'), duration: Duration(seconds: 2)),
              );
            },
          ),

          // Editar nota
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: OrtizIconSize.md, color: OrtizPalette.fg),
            tooltip: 'Editar nota',
            onPressed: () async {
              Navigator.of(context).pop();
              await NoteEditorScreen.open(context, note: note);
            },
          ),

          // Eliminar nota
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: OrtizIconSize.md, color: OrtizPalette.bad),
            tooltip: 'Eliminar nota',
            onPressed: () => _confirmDelete(context, notasState, note),
          ),

          // Cerrar
          IconButton(
            icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
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

    // Sin tarjeta: texto y barra sobre el fondo del lector.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progreso de tareas ($completed de $total)',
              style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: OrtizPalette.muted),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800, color: NotasColors.primary),
            ),
          ],
        ),
        const SizedBox(height: OrtizSpace.sm),
        OrtizProgressBar(
          value: percent,
          color: percent == 1.0 ? OrtizPalette.ok : NotasColors.primary,
          semanticsLabel: 'Progreso de tareas',
        ),
      ],
    );
  }

  Widget _buildBacklinksSection(BuildContext context, List<DiarioEntry> backlinks) {
    // Grupo sin tarjeta: encabezado en `muted` y una fila por entrada.
    return OrtizSection(
      title: 'Mencionada en el Diario (${backlinks.length})',
      headerPadding: const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
      children: [
        for (final entry in backlinks)
          OrtizListRow(
            leading: const Icon(Icons.auto_stories_rounded, color: SuiteAppColors.diario),
            title: entry.title.isNotEmpty ? entry.title : 'Entrada del Diario',
            subtitle: entry.formattedDate,
            trailing: const Icon(Icons.chevron_right_rounded, size: OrtizIconSize.sm, color: OrtizPalette.muted),
            onTap: () => openEntryReader(context, entry),
          ),
      ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
        title: const Text('¿Eliminar esta nota?'),
        content: Text('Estás a punto de eliminar "${note.title}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OrtizPalette.bad, foregroundColor: OrtizPalette.onAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: OrtizPalette.onAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await notasState.deleteNote(note.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nota eliminada'), duration: Duration(seconds: 2)));
      }
    }
  }
}
