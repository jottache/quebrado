import 'package:appflowy_editor/appflowy_editor.dart';
import '../models/note_block.dart';
import '../../rich_editor/custom_blocks.dart';

/// Convierte entre el formato actual de Notas ([NoteBlock]) y el documento de AppFlowy.
///
/// NoteBlock → Document no pierde nada. Document → NoteBlock es aproximado mientras
/// el modelo actual no tenga formato en línea (negrita, código en línea…) ni bloques
/// de código: el texto se conserva como texto plano.
class NoteDocumentConverter {
  const NoteDocumentConverter._();

  static Document toDocument(List<NoteBlock> blocks) {
    final nodes = blocks.map(_toNode).toList();
    if (nodes.isEmpty) nodes.add(paragraphNode());
    return Document(root: pageNode(children: nodes));
  }

  static Node _toNode(NoteBlock block) {
    final text = block.content;
    switch (block.type) {
      case BlockType.heading1:
        return headingNode(level: 1, text: text);
      case BlockType.heading2:
        return headingNode(level: 2, text: text);
      case BlockType.heading3:
        return headingNode(level: 3, text: text);
      case BlockType.todo:
        return todoListNode(checked: block.isChecked, text: text);
      case BlockType.bulletList:
        return bulletedListNode(text: text);
      case BlockType.numberedList:
        return numberedListNode(delta: Delta()..insert(text));
      case BlockType.toggle:
        return toggleNode(
          text: text,
          children: block.children.map(_toNode).toList(),
        );
      case BlockType.callout:
        return calloutNode(text: text, icon: block.calloutIcon ?? '💡');
      case BlockType.divider:
        return dividerNode();
      case BlockType.paragraph:
        return paragraphNode(text: text);
    }
  }

  static List<NoteBlock> fromDocument(Document document) {
    final result = <NoteBlock>[];
    for (final node in document.root.children) {
      result.addAll(_fromNode(node));
    }
    return result;
  }

  /// Devuelve el bloque y, si tenía hijos (y no es un desplegable), los agrega
  /// a continuación para no perder contenido.
  static List<NoteBlock> _fromNode(Node node) {
    final text = node.delta?.toPlainText() ?? '';
    NoteBlock block;
    var childrenHandled = false;

    switch (node.type) {
      case 'heading':
        final level = (node.attributes['level'] as num?)?.toInt() ?? 1;
        block = NoteBlock(
          type: level <= 1 ? BlockType.heading1 : (level == 2 ? BlockType.heading2 : BlockType.heading3),
          content: text,
        );
        break;
      case 'todo_list':
        block = NoteBlock(type: BlockType.todo, content: text, isChecked: node.attributes['checked'] == true);
        break;
      case 'bulleted_list':
        block = NoteBlock(type: BlockType.bulletList, content: text);
        break;
      case 'numbered_list':
        block = NoteBlock(type: BlockType.numberedList, content: text);
        break;
      case ToggleBlockKeys.type:
        block = NoteBlock(
          type: BlockType.toggle,
          content: text,
          children: node.children.expand(_fromNode).toList(),
        );
        childrenHandled = true;
        break;
      case CalloutBlockKeys.type:
        block = NoteBlock(
          type: BlockType.callout,
          content: text,
          calloutIcon: node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡',
        );
        break;
      case 'quote':
        block = NoteBlock(type: BlockType.callout, content: text, calloutIcon: '💬');
        break;
      case 'divider':
        block = NoteBlock(type: BlockType.divider);
        break;
      case CodeBlockKeys.type:
      case 'paragraph':
      default:
        block = NoteBlock(type: BlockType.paragraph, content: text);
    }

    return [
      block,
      if (!childrenHandled) ...node.children.expand(_fromNode),
    ];
  }

  static String toMarkdown(Document document) =>
      documentToMarkdown(document, customParsers: customMarkdownParsers);
}
