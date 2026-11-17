import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/diario_state.dart';
import '../widgets/diario_rich_editing.dart';
import '../../notas/notas.dart';
import '../../rich_editor/rich_document_editor.dart';

/// Nota personal rápida: editor enriquecido a pantalla grande, dictado por voz,
/// menciones (@ personas, # notas) y borrador automático.
class QuickNoteDialog extends StatefulWidget {
  final bool autoStartVoice;

  const QuickNoteDialog({
    super.key,
    this.autoStartVoice = false,
  });

  static const draftScope = 'diario:quick';

  @override
  State<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends State<QuickNoteDialog> with DiarioRichEditing<QuickNoteDialog> {
  bool _isSaving = false;
  bool _autoStartDone = false;

  @override
  String get draftScope => QuickNoteDialog.draftScope;

  @override
  DateTime? get savedVersionAt => null;

  @override
  Document buildInitialDocument() => Document.blank(withInitialText: true);

  @override
  void initState() {
    super.initState();
    initRichEditing();
  }

  @override
  void dispose() {
    disposeRichEditing();
    super.dispose();
  }

  Future<void> _saveQuickNote() async {
    final text = plainText;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe o dicta algún texto para registrar la nota.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await stopDictation();
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      final state = Provider.of<DiarioState>(context, listen: false);
      final notasState = Provider.of<NotasState>(context, listen: false);
      final mentionsList = state.extractMentionedContactIds(text);
      final noteMentionsList = state.extractMentionedNoteIds(text, notasState.notes);
      final document = documentJson;
      await discardDraftAfterSave();
      await state.addPersonalEntry(
        title: '',
        contentText: text,
        richDocument: document,
        mentionedContactIds: mentionsList,
        mentionedNoteIds: noteMentionsList,
        isPinned: false,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Nota rápida registrada exitosamente.'),
            backgroundColor: DiarioColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: DiarioColors.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = DiarioEditorFrame.isDesktop(context);
    final state = editorState;

    if (widget.autoStartVoice && !_autoStartDone && state != null) {
      _autoStartDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toggleVoiceDictation();
      });
    }

    final banner = buildDraftBanner();
    final horizontal = desktop ? 32.0 : 16.0;

    return DiarioEditorFrame(
      onEscape: closeKeepingDraft,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(desktop ? 20 : 8, 12, desktop ? 16 : 8, 12),
                child: Row(
                  children: [
                    if (!desktop)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        tooltip: 'Cerrar (se guarda como borrador)',
                        onPressed: closeKeepingDraft,
                      ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: DiarioColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nota Rápida',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: DiarioColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Guarda una idea o pensamiento al instante',
                            style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    buildDictationButton(compact: !desktop),
                    const SizedBox(width: 8),
                    if (desktop)
                      TextButton(
                        key: const ValueKey('quick_note_cancel'),
                        onPressed: cancelAndDiscardDraft,
                        child: const Text('Cancelar', style: TextStyle(color: DiarioColors.textSecondary)),
                      ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      key: const ValueKey('quick_note_save'),
                      onPressed: _isSaving ? null : _saveQuickNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DiarioColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: desktop ? 18 : 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Guardando...' : (desktop ? 'Registrar Nota' : 'Guardar'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (desktop) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22, color: DiarioColors.textMuted),
                        tooltip: 'Cerrar (se guarda como borrador)',
                        onPressed: closeKeepingDraft,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: DiarioColors.cardBorder),
              Expanded(
                child: state == null
                    ? const Center(child: CircularProgressIndicator())
                    : RichDocumentEditor(
                        key: ObjectKey(state),
                        editorState: state,
                        accentColor: DiarioColors.primary,
                        mentions: mentionSources(),
                        onEscape: closeKeepingDraft,
                        autofocus: !widget.autoStartVoice,
                        placeholder: '¿Qué estás pensando? Escribe (@ personas, # notas, / bloques) o dicta…',
                        header: Padding(
                          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?banner,
                              if (isListening)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: DiarioColors.rose.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: DiarioColors.rose.withValues(alpha: 0.35)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fiber_manual_record_rounded, size: 10, color: DiarioColors.rose),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Escuchando… lo que digas se escribe donde está el cursor.',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DiarioColors.rose),
                                        ),
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
          ),
        ),
      ),
    );
  }
}
