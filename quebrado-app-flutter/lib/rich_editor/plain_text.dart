import 'package:appflowy_editor/appflowy_editor.dart';
import 'custom_blocks.dart';
import 'rich_editor_colors.dart';

/// Texto plano legible de un documento: se usa para buscar, detectar menciones
/// (@contacto, #nota), las vistas previas y el agente.
String documentToPlainText(Document document) {
  final lines = <String>[];
  void visit(Node node, int depth) {
    final indent = '  ' * depth;
    final text = node.delta?.toPlainText() ?? '';
    switch (node.type) {
      case 'bulleted_list':
        lines.add('$indent• $text');
        break;
      case 'numbered_list':
        final siblings = node.parent?.children.toList() ?? [node];
        var number = 1;
        for (final sibling in siblings) {
          if (identical(sibling, node)) break;
          number = sibling.type == 'numbered_list' ? number + 1 : 1;
        }
        lines.add('$indent$number. $text');
        break;
      case 'todo_list':
        final checked = node.attributes['checked'] == true;
        lines.add('$indent${checked ? '☑' : '☐'} $text');
        break;
      case 'divider':
        lines.add('$indent———');
        break;
      case CalloutBlockKeys.type:
        final icon = node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡';
        lines.add('$indent$icon $text');
        break;
      default:
        if (node.delta != null) lines.add('$indent$text');
    }
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  for (final node in document.root.children) {
    visit(node, 0);
  }
  // Sin líneas vacías al final
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// Documento a partir de texto plano (entradas anteriores al editor enriquecido):
/// un párrafo por línea. Las [mentions] que aparezcan (por ejemplo "@Mariana") se
/// resaltan igual que al insertarlas desde el menú.
Document documentFromPlainText(String text, {Iterable<String> mentions = const []}) {
  final tokens = mentions.where((m) => m.length > 1).toList()..sort((a, b) => b.length.compareTo(a.length));
  final nodes = <Node>[];
  for (final line in text.split('\n')) {
    nodes.add(paragraphNode(delta: _highlight(line, tokens)));
  }
  if (nodes.isEmpty) nodes.add(paragraphNode());
  return Document(root: pageNode(children: nodes));
}

Delta _highlight(String line, List<String> tokens) {
  final delta = Delta();
  if (tokens.isEmpty || line.isEmpty) return delta..insert(line);
  final lower = line.toLowerCase();
  final accent = '0x${RichEditorColors.accent.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  var i = 0;
  var plainStart = 0;
  while (i < line.length) {
    String? match;
    for (final token in tokens) {
      if (lower.startsWith(token.toLowerCase(), i)) {
        match = token;
        break;
      }
    }
    if (match == null) {
      i++;
      continue;
    }
    if (i > plainStart) delta.insert(line.substring(plainStart, i));
    delta.insert(line.substring(i, i + match.length), attributes: {
      AppFlowyRichTextKeys.bold: true,
      AppFlowyRichTextKeys.textColor: accent,
    });
    i += match.length;
    plainStart = i;
  }
  if (plainStart < line.length) delta.insert(line.substring(plainStart));
  return delta;
}
