import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../notas/notas.dart';
import '../../rich_editor/draft_banner.dart';
import '../../rich_editor/draft_store.dart';
import '../../rich_editor/dictation.dart';
import '../../rich_editor/escape_to_close.dart';
import '../../rich_editor/mentions.dart';
import '../../rich_editor/plain_text.dart';
import '../../rich_editor/rich_document_editor.dart';
import '../services/speech_recognition_service.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/diario_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

/// Lógica común de los editores de Diario (entrada completa y nota rápida):
/// documento enriquecido, borrador automático, dictado por voz y menciones.
mixin DiarioRichEditing<T extends StatefulWidget> on State<T> {
  EditorState? editorState;
  EditorDraft? restoredDraft;
  bool hasChanges = false;
  bool isListening = false;

  late final DraftAutosaver _autosaver;
  StreamSubscription<EditorTransactionValue>? _transactionSub;
  EditorDictationSession? _dictation;
  bool _suspendChangeTracking = false;
  bool _saved = false;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  /// Clave del borrador de este editor.
  String get draftScope;

  /// Fecha de la versión guardada (null si es nueva): un borrador más viejo se ignora.
  DateTime? get savedVersionAt;

  /// Documento inicial cuando no hay borrador.
  Document buildInitialDocument();

  /// Campos propios del formulario que se guardan en el borrador.
  Map<String, dynamic> collectDraftFields() => const {};
  void restoreDraftFields(Map<String, dynamic> data) {}

  /// Vuelve los campos propios a los valores originales (al descartar el borrador).
  void resetFields() {}

  /// Llamar desde initState.
  void initRichEditing() {
    _autosaver = DraftAutosaver(scope: draftScope, collect: _collectDraft);
    _loadInitialContent();
  }

  /// Llamar desde dispose: lo no guardado queda como borrador (se cierre con la X,
  /// tocando fuera del modal o con Esc) y se avisa.
  void disposeRichEditing() {
    if (isListening) SpeechRecognitionService.instance.stopListening();
    _autosaver.flush();
    if (hasChanges && !_saved) {
      final messenger = _messenger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDraftSavedSnackBar(messenger, color: DiarioColors.primary);
      });
    }
    _autosaver.dispose();
    _transactionSub?.cancel();
    editorState?.dispose();
  }

  Future<void> _loadInitialContent() async {
    var document = _safeInitialDocument();
    final draft = await DraftStore.instance.load(draftScope);
    final savedAt = savedVersionAt;
    if (draft != null && (savedAt == null || draft.savedAt.isAfter(savedAt))) {
      try {
        final restored = Document.fromJson(Map<String, dynamic>.from(draft.data['document'] as Map));
        if (restored.root.children.isEmpty) restored.insert([0], [paragraphNode()]);
        document = restored;
        _suspendChangeTracking = true;
        restoreDraftFields(draft.data);
        _suspendChangeTracking = false;
        restoredDraft = draft;
        hasChanges = true;
      } catch (e) {
        _suspendChangeTracking = false;
        debugPrint('Diario: borrador ilegible, se ignora ($e)');
      }
    } else if (draft != null) {
      unawaited(DraftStore.instance.clear(draftScope));
    }
    if (!mounted) return;
    setState(() => _setEditorState(EditorState(document: document)));
  }

  Document _safeInitialDocument() {
    final document = buildInitialDocument();
    if (document.root.children.isEmpty) document.insert([0], [paragraphNode()]);
    return document;
  }

  void _setEditorState(EditorState state) {
    _transactionSub?.cancel();
    disposeEditorStateLater(editorState);
    editorState = state;
    _transactionSub = state.transactionStream.listen((event) {
      final (time, transaction, _) = event;
      if (time == TransactionTime.after && transaction.operations.isNotEmpty) markChanged();
    });
  }

  Map<String, dynamic>? _collectDraft() {
    final state = editorState;
    if (!hasChanges || state == null) return null;
    return {...collectDraftFields(), 'document': state.document.toJson()};
  }

  /// Avisar de cualquier cambio del formulario (el editor se detecta solo).
  void markChanged() {
    if (_suspendChangeTracking || editorState == null) return;
    if (!hasChanges) setState(() => hasChanges = true);
    _autosaver.schedule();
  }

  void discardDraft() {
    unawaited(DraftStore.instance.clear(draftScope));
    setState(() {
      restoredDraft = null;
      _suspendChangeTracking = true;
      resetFields();
      _suspendChangeTracking = false;
      hasChanges = false;
      _setEditorState(EditorState(document: _safeInitialDocument()));
    });
  }

  /// Tras guardar de verdad: borra el borrador.
  Future<void> discardDraftAfterSave() {
    _saved = true;
    return _autosaver.discard();
  }

  /// Cerrar sin guardar (X, Escape, tocar fuera): lo escrito queda como borrador
  /// (ver [disposeRichEditing]).
  void closeKeepingDraft() => Navigator.of(context).pop();

  /// Botón Cancelar: cierra y borra el borrador. El aviso permite deshacerlo.
  Future<void> cancelAndDiscardDraft() async {
    final data = _collectDraft();
    final scope = draftScope;
    final messenger = _messenger;
    _saved = true; // no mostrar "Borrador guardado"
    await stopDictation();
    await _autosaver.discard();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (data != null) {
      showDraftDiscardedSnackBar(messenger, onUndo: () => DraftStore.instance.save(scope, data));
    }
  }

  Widget? buildDraftBanner() {
    final draft = restoredDraft;
    if (draft == null) return null;
    return DraftRestoredBanner(
      savedAt: draft.savedAt,
      accent: DiarioColors.primary,
      onDiscard: discardDraft,
      onDismiss: () => setState(() => restoredDraft = null),
    );
  }

  /// Texto plano del documento (búsqueda, menciones, vistas previas).
  String get plainText {
    final state = editorState;
    return state == null ? '' : documentToPlainText(state.document).trim();
  }

  Map<String, dynamic>? get documentJson => editorState?.document.toJson();

  /// Menciones: @ contactos de Diario y # notas.
  RichEditorMentions mentionSources() => RichEditorMentions(
        contacts: () {
          if (!mounted) return const [];
          final contacts = Provider.of<DiarioState>(context, listen: false).contacts;
          return [
            for (final c in contacts)
              MentionOption(id: c.id, label: c.name.trim(), subtitle: c.nickname ?? c.relationship),
          ];
        },
        notes: () {
          if (!mounted) return const [];
          final notes = Provider.of<NotasState>(context, listen: false).notes;
          return [
            for (final n in notes.where((n) => !n.isArchived)) MentionOption(id: n.id, label: n.title.trim()),
          ];
        },
      );

  /// Palabras a resaltar al convertir texto antiguo (sin documento) al editor.
  List<String> knownMentionTokens() {
    final contacts = Provider.of<DiarioState>(context, listen: false).contacts;
    final notes = Provider.of<NotasState>(context, listen: false).notes;
    return [
      for (final c in contacts) ...[
        '@${c.name.trim()}',
        if (c.nickname != null && c.nickname!.trim().isNotEmpty) '@${c.nickname!.trim()}',
      ],
      for (final n in notes) '#${n.title.trim()}',
    ];
  }

  Future<void> toggleVoiceDictation() async {
    if (isListening) {
      await SpeechRecognitionService.instance.stopListening();
      _dictation = null;
      if (mounted) setState(() => isListening = false);
      return;
    }
    final state = editorState;
    if (state == null) return;
    _dictation = EditorDictationSession(state);
    final started = await SpeechRecognitionService.instance.startListening(
      onResult: (words, isFinal) {
        if (mounted) _dictation?.update(words);
      },
      onDone: () {
        _dictation = null;
        if (mounted) setState(() => isListening = false);
      },
    );
    if (!mounted) return;
    setState(() => isListening = started);
    if (!started) {
      _dictation = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo activar el micrófono o reconocimiento de voz.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> stopDictation() async {
    if (!isListening) return;
    await SpeechRecognitionService.instance.stopListening();
    _dictation = null;
    isListening = false;
  }

  Widget buildDictationButton({bool compact = false}) {
    final color = isListening ? DiarioColors.rose : DiarioColors.primary;
    return InkWell(
      key: const ValueKey('diario_dictation_button'),
      onTap: toggleVoiceDictation,
      borderRadius: BorderRadius.circular(OrtizRadius.block),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
        decoration: BoxDecoration(
          color: isListening ? DiarioColors.rose.withValues(alpha: 0.12) : DiarioColors.primaryLight,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          border: Border.all(color: color.withValues(alpha: isListening ? 1 : 0.35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isListening ? Icons.mic_rounded : Icons.mic_none_rounded, size: OrtizIconSize.sm, color: color),
            if (!compact) ...[
              const SizedBox(width: OrtizSpace.xs),
              Text(
                isListening ? 'Escuchando… toca para parar' : 'Dictar por voz',
                style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tamaño de los modales de escritura de Diario: 90 % de la pantalla en escritorio,
/// pantalla completa en móvil.
class DiarioEditorFrame extends StatelessWidget {
  final Widget child;

  /// Escape cierra el modal (conservando el borrador).
  final VoidCallback onEscape;

  const DiarioEditorFrame({super.key, required this.child, required this.onEscape});

  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 840;

  @override
  Widget build(BuildContext context) {
    final child = EscapeToClose(onEscape: onEscape, child: this.child);
    if (!isDesktop(context)) {
      return Dialog.fullscreen(backgroundColor: OrtizPalette.bg, child: child);
    }
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: OrtizPalette.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: size.width * 0.9, height: size.height * 0.9, child: child),
    );
  }
}
