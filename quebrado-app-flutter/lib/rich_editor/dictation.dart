import 'package:appflowy_editor/appflowy_editor.dart';

/// Escribe en el editor lo que reconoce el dictado por voz.
///
/// El reconocedor envía resultados parciales que se van corrigiendo ("hola" →
/// "hola cómo" → "hola, cómo estás"): cada resultado reemplaza al anterior en el
/// mismo lugar, para no duplicar texto.
class EditorDictationSession {
  final EditorState editorState;
  late final Path _path;
  late final int _offset;
  int _insertedLength = 0;
  bool _valid = false;

  EditorDictationSession(this.editorState) {
    final selection = editorState.selection;
    Node? node = selection != null ? editorState.getNodeAtPath(selection.end.path) : null;
    int offset = selection?.end.offset ?? 0;

    // Sin cursor (o en un bloque sin texto): al final del último bloque de texto
    if (node == null || node.delta == null) {
      node = _lastTextNode(editorState.document.root);
      offset = node?.delta?.length ?? 0;
    }
    if (node == null) return;
    _path = node.path;
    _offset = offset;
    _valid = true;
  }

  static Node? _lastTextNode(Node root) {
    for (final child in root.children.toList().reversed) {
      final nested = _lastTextNode(child);
      if (nested != null) return nested;
      if (child.delta != null) return child;
    }
    return null;
  }

  /// Reemplaza el texto dictado hasta ahora por [words].
  Future<void> update(String words) async {
    if (!_valid) return;
    final node = editorState.getNodeAtPath(_path);
    final delta = node?.delta;
    if (node == null || delta == null || _offset + _insertedLength > delta.length) {
      _valid = false;
      return;
    }

    final before = delta.toPlainText().substring(0, _offset);
    final needsSpace = before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n') && words.isNotEmpty;
    final text = '${needsSpace ? ' ' : ''}$words';

    final transaction = editorState.transaction;
    if (_insertedLength > 0) {
      transaction.replaceText(node, _offset, _insertedLength, text);
    } else {
      transaction.insertText(node, _offset, text);
    }
    transaction.afterSelection = Selection.collapsed(Position(path: _path, offset: _offset + text.length));
    _insertedLength = text.length;
    await editorState.apply(transaction);
  }
}
