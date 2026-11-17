import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'rich_document_editor.dart';

/// Muestra un documento enriquecido en solo lectura (lectores de Notas y Diario).
///
/// El editor de AppFlowy necesita un alto acotado (usa su propio Overlay), así que
/// no puede ir dentro de un ListView: el visor ES el scroll, y lo que va antes y
/// después del documento se pasa como [header] y [footer].
/// Si se pasa [onTodoToggled], las tareas se pueden marcar y se recibe el
/// documento actualizado para guardarlo.
class RichDocumentViewer extends StatefulWidget {
  final Map<String, dynamic> document;
  final Color accentColor;
  final void Function(Document document)? onTodoToggled;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets padding;

  const RichDocumentViewer({
    super.key,
    required this.document,
    required this.accentColor,
    this.onTodoToggled,
    this.header,
    this.footer,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<RichDocumentViewer> createState() => _RichDocumentViewerState();
}

class _RichDocumentViewerState extends State<RichDocumentViewer> {
  late EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = _build(widget.document);
  }

  @override
  void didUpdateWidget(covariant RichDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al marcar una tarea, el documento guardado vuelve igual al mostrado: no se
    // reconstruye (así no se pierde la posición del scroll).
    if (!identical(oldWidget.document, widget.document) &&
        jsonEncode(widget.document) != jsonEncode(_editorState.document.toJson())) {
      final old = _editorState;
      _editorState = _build(widget.document);
      disposeEditorStateLater(old);
    }
  }

  static EditorState _build(Map<String, dynamic> json) {
    Document document;
    try {
      document = Document.fromJson(json);
    } catch (_) {
      document = Document.blank(withInitialText: true);
    }
    return EditorState(document: document);
  }

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichDocumentEditor(
      key: ObjectKey(_editorState),
      editorState: _editorState,
      editable: false,
      padding: widget.padding,
      maxWidth: double.infinity,
      accentColor: widget.accentColor,
      onTodoToggled: widget.onTodoToggled,
      header: widget.header,
      footer: widget.footer,
    );
  }
}
