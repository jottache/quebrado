import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../rich_editor/draft_banner.dart';
import '../../rich_editor/draft_store.dart';
import '../../rich_editor/escape_to_close.dart';
import '../../rich_editor/rich_document_editor.dart';
import '../models/note_item.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../dialogs/category_manager_dialog.dart';
import '../services/note_document_converter.dart';
import '../services/note_pdf_service.dart';

/// Pantalla / Modal de edición de Notas & Acuerdos al estilo Notion, con el editor
/// enriquecido (formato en línea, "/" para bloques) y borrador automático.
class NoteEditorScreen extends StatefulWidget {
  final NoteItem? note;
  final String? initialCategoryId;
  final bool isModalDialog;

  const NoteEditorScreen({super.key, this.note, this.initialCategoryId, this.isModalDialog = false});

  static Future<bool?> open(BuildContext context, {NoteItem? note, String? initialCategoryId}) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 768;

    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dialogWidth = size.width * 0.90;
          final dialogHeight = size.height * 0.90;
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            child: Center(
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, 10)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: NoteEditorScreen(note: note, initialCategoryId: initialCategoryId, isModalDialog: true),
              ),
            ),
          );
        },
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note, initialCategoryId: initialCategoryId, isModalDialog: false),
      ),
    );
  }

  /// Clave del borrador: uno para "nueva nota" y uno por nota existente.
  static String draftScopeFor(NoteItem? note) => note == null ? 'nota:new' : 'nota:${note.id}';

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late String _selectedEmoji;
  late String _selectedCategoryId;
  late bool _isPinned;

  EditorState? _editorState;
  StreamSubscription<EditorTransactionValue>? _transactionSub;
  late final DraftAutosaver _autosaver;

  /// Borrador recuperado al abrir (muestra el aviso con "Descartar").
  EditorDraft? _restoredDraft;

  bool _isSaving = false;
  bool _hasChanges = false;
  bool _saved = false;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  final List<String> _emojiOptions = [
    '📝',
    '💍',
    '💡',
    '📍',
    '🎯',
    '🚀',
    '❤️',
    '💼',
    '📚',
    '🏠',
    '✈️',
    '🛒',
    '🎨',
    '🔒',
    '⭐',
    '🔥',
    '📌',
    '🗓️',
    '🤝',
    '💰',
    '🧠',
    '✨',
    '⚡',
    '☕',
  ];

  String get _draftScope => NoteEditorScreen.draftScopeFor(widget.note);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _applyNoteValues();
    _autosaver = DraftAutosaver(scope: _draftScope, collect: _collectDraft);
    _titleController.addListener(_markChanged);
    _loadInitialContent();
  }

  void _applyNoteValues() {
    final n = widget.note;
    _titleController.text = n?.title ?? '';
    _selectedEmoji = n?.emoji ?? '📝';
    _selectedCategoryId = n?.categoryId ?? widget.initialCategoryId ?? NoteCategory.generalCategoryId;
    _isPinned = n?.isPinned ?? false;
  }

  Document _documentFromNote() {
    final n = widget.note;
    final doc = n?.richDocument ?? NoteDocumentConverter.toDocument(n?.blocks ?? const []);
    if (doc.root.children.isEmpty) doc.insert([0], [paragraphNode()]);
    return doc;
  }

  Future<void> _loadInitialContent() async {
    Document document = _documentFromNote();
    final draft = await DraftStore.instance.load(_draftScope);
    final note = widget.note;
    final draftIsNewer = draft != null && (note == null || draft.savedAt.isAfter(note.updatedAt));
    if (draftIsNewer) {
      try {
        final data = draft.data;
        final restoredDoc = Document.fromJson(Map<String, dynamic>.from(data['document'] as Map));
        if (restoredDoc.root.children.isEmpty) restoredDoc.insert([0], [paragraphNode()]);
        document = restoredDoc;
        _titleController.text = data['title']?.toString() ?? _titleController.text;
        _selectedEmoji = data['emoji']?.toString() ?? _selectedEmoji;
        _selectedCategoryId = data['category_id']?.toString() ?? _selectedCategoryId;
        _isPinned = data['is_pinned'] == true;
        _restoredDraft = draft;
        _hasChanges = true;
      } catch (e) {
        debugPrint('Notas: borrador ilegible, se ignora ($e)');
      }
    } else if (draft != null) {
      // Borrador más viejo que la nota guardada: ya no sirve
      unawaited(DraftStore.instance.clear(_draftScope));
    }
    if (!mounted) return;
    setState(() => _setEditorState(EditorState(document: document)));
  }

  void _setEditorState(EditorState state) {
    _transactionSub?.cancel();
    disposeEditorStateLater(_editorState);
    _editorState = state;
    _transactionSub = state.transactionStream.listen((event) {
      final (time, transaction, _) = event;
      if (time == TransactionTime.after && transaction.operations.isNotEmpty) _markChanged();
    });
  }

  Map<String, dynamic>? _collectDraft() {
    final editorState = _editorState;
    if (!_hasChanges || editorState == null) return null;
    return {
      'title': _titleController.text,
      'emoji': _selectedEmoji,
      'category_id': _selectedCategoryId,
      'is_pinned': _isPinned,
      'document': editorState.document.toJson(),
    };
  }

  void _markChanged() {
    if (_editorState == null) return; // todavía cargando el contenido inicial
    if (!_hasChanges) setState(() => _hasChanges = true);
    _autosaver.schedule();
  }

  void _discardDraft() {
    unawaited(DraftStore.instance.clear(_draftScope));
    setState(() {
      _restoredDraft = null;
      _titleController.removeListener(_markChanged);
      _applyNoteValues();
      _titleController.addListener(_markChanged);
      _hasChanges = false;
      _setEditorState(EditorState(document: _documentFromNote()));
    });
  }

  @override
  void dispose() {
    // Si se cierra sin guardar (X, atrás o Esc), lo escrito queda como borrador
    _autosaver.flush();
    if (_hasChanges && !_saved) {
      final messenger = _messenger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDraftSavedSnackBar(messenger, color: NotasColors.primary);
      });
    }
    _autosaver.dispose();
    _transactionSub?.cancel();
    _editorState?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final editorState = _editorState;
    if (editorState == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un título para la nota'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    final notasState = Provider.of<NotasState>(context, listen: false);

    try {
      final document = editorState.document;
      final documentJson = document.toJson();
      final blocks = NoteDocumentConverter.fromDocument(document);
      final contentText = NoteDocumentConverter.toMarkdown(document);

      if (widget.note != null) {
        final updated = widget.note!.copyWith(
          title: title,
          emoji: _selectedEmoji,
          categoryId: _selectedCategoryId,
          isPinned: _isPinned,
          blocks: blocks,
          document: documentJson,
          contentText: contentText,
        );
        await notasState.updateNote(updated);
      } else {
        await notasState.createNote(
          title: title,
          emoji: _selectedEmoji,
          categoryId: _selectedCategoryId,
          isPinned: _isPinned,
          blocks: blocks,
          document: documentJson,
          contentText: contentText,
        );
      }
      _saved = true;
      await _autosaver.discard();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(widget.note != null ? 'Nota actualizada' : 'Nota creada exitosamente'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _currentMarkdown() {
    final editorState = _editorState;
    final title = _titleController.text.trim().isEmpty ? 'Sin título' : _titleController.text.trim();
    final body = editorState == null ? '' : NoteDocumentConverter.toMarkdown(editorState.document);
    return '# $_selectedEmoji $title\n\n$body';
  }

  void _copyMarkdown() {
    Clipboard.setData(ClipboardData(text: _currentMarkdown()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Contenido copiado en formato Markdown'),
          ],
        ),
        backgroundColor: NotasColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Cerrar (X, Escape, atrás) nunca pierde lo escrito: queda como borrador (ver dispose).
  void _close() => Navigator.of(context).pop();

  /// Botón Cancelar: cierra y borra el borrador. El aviso permite deshacerlo.
  Future<void> _cancel() async {
    final data = _collectDraft();
    final messenger = _messenger;
    _saved = true; // no mostrar "Borrador guardado"
    await _autosaver.discard();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (data != null) {
      showDraftDiscardedSnackBar(messenger, onUndo: () => DraftStore.instance.save(_draftScope, data));
    }
  }

  void _focusEditor() {
    final editorState = _editorState;
    if (editorState == null) return;
    editorState.selection = Selection.collapsed(Position(path: [0]));
  }

  @override
  Widget build(BuildContext context) {
    final notasState = Provider.of<NotasState>(context);
    final categories = notasState.categories;
    final editorState = _editorState;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _autosaver.flush();
      },
      child: EscapeToClose(
        onEscape: _close,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context, categories),
          body: editorState == null
              ? const Center(child: CircularProgressIndicator())
              : RichDocumentEditor(
                  key: ObjectKey(editorState),
                  editorState: editorState,
                  accentColor: NotasColors.primary,
                  autofocus: widget.note == null && _restoredDraft == null,
                  onEscape: _close,
                  header: _buildHeader(categories),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<NoteCategory> categories) {
    final mobile = MediaQuery.of(context).size.width < 840;
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 20, mobile ? 16 : 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_restoredDraft != null)
            DraftRestoredBanner(
              savedAt: _restoredDraft!.savedAt,
              accent: NotasColors.primary,
              onDiscard: _discardDraft,
              onDismiss: () => setState(() => _restoredDraft = null),
            ),
          _buildCategoryAndPinBar(categories),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmojiPickerButton(),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  key: const ValueKey('note_title_field'),
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusEditor(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: NotasColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Título de la nota...',
                    hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFCBD5E1)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  NoteItem _getCurrentNotePreview() {
    final editorState = _editorState;
    return NoteItem(
      id: widget.note?.id ?? 'preview',
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Sin título',
      categoryId: _selectedCategoryId,
      icon: _selectedEmoji,
      colorHex: widget.note?.colorHex ?? '#6366F1',
      blocks: editorState == null
          ? (widget.note?.blocks ?? const [])
          : NoteDocumentConverter.fromDocument(editorState.document),
      document: editorState?.document.toJson(),
      sharedTag: widget.note?.sharedTag,
      isPinned: _isPinned,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, List<NoteCategory> categories) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: Icon(widget.isModalDialog ? Icons.close_rounded : Icons.arrow_back_rounded, color: Colors.black87),
        tooltip: widget.isModalDialog ? 'Cerrar modal' : 'Volver',
        onPressed: _close,
      ),
      title: Text(
        widget.note != null ? 'Editar Nota' : 'Nueva Nota',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      actions: [
        // Descargar PDF
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.black54),
          tooltip: 'Descargar como PDF',
          onPressed: () async {
            final notePreview = _getCurrentNotePreview();
            final category = categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => categories.first);
            await NotePdfService.instance.downloadNotePdf(note: notePreview, category: category, context: context);
          },
        ),

        // Compartir nota
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 20, color: Colors.black54),
          tooltip: 'Compartir nota',
          onPressed: () async {
            final notePreview = _getCurrentNotePreview();
            final category = categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => categories.first);
            await NotePdfService.showShareModal(context: context, note: notePreview, category: category);
          },
        ),

        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.black54),
          tooltip: 'Copiar como Markdown',
          onPressed: _copyMarkdown,
        ),
        const SizedBox(width: 8),
        if (widget.isModalDialog)
          TextButton(
            key: const ValueKey('note_editor_cancel'),
            onPressed: _isSaving ? null : _cancel,
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveNote,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: NotasColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryAndPinBar(List<NoteCategory> categories) {
    final currentCat = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => NoteCategory.defaultCategories().first,
    );

    return Row(
      children: [
        // Selector de Categoría
        PopupMenuButton<String>(
          initialValue: _selectedCategoryId,
          onSelected: (val) {
            if (val == '__manage__') {
              CategoryManagerDialog.show(context);
            } else {
              setState(() {
                _selectedCategoryId = val;
                _hasChanges = true;
              });
            }
          },
          itemBuilder: (ctx) => [
            ...categories.map(
              (cat) => PopupMenuItem(
                value: cat.id,
                child: Row(
                  children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: '__manage__',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Administrar categorías...', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: currentCat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: currentCat.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentCat.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  currentCat.name,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: currentCat.color),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: currentCat.color),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Botón Pin
        InkWell(
          onTap: () {
            setState(() {
              _isPinned = !_isPinned;
              _hasChanges = true;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isPinned ? Colors.amber.withOpacity(0.15) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isPinned ? Colors.amber[700]!.withOpacity(0.4) : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 15,
                  color: _isPinned ? Colors.amber[800] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _isPinned ? 'Fijada' : 'Fijar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isPinned ? Colors.amber[800] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPickerButton() {
    return PopupMenuButton<String>(
      tooltip: 'Seleccionar icono',
      onSelected: (emoji) {
        setState(() {
          _selectedEmoji = emoji;
          _hasChanges = true;
        });
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((e) {
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _selectedEmoji = e;
                      _hasChanges = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
