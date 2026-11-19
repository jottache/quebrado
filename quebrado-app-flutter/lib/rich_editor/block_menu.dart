import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import '../theme/ortiz_space.dart';
import 'custom_blocks.dart';

/// Bloques que se pueden insertar, en español. Se usan en el menú "/" (escritorio
/// y navegador) y en el botón "Bloques" de la barra móvil.
class EditorBlockOption {
  final String label;
  final IconData icon;
  final List<String> keywords;
  final Node Function() build;

  const EditorBlockOption(this.label, this.icon, this.keywords, this.build);
}

final List<EditorBlockOption> editorBlockOptions = [
  EditorBlockOption('Texto', Icons.notes_rounded, const ['texto', 'parrafo', 'text'], () => paragraphNode()),
  EditorBlockOption('Título 1', Icons.title_rounded, const ['titulo', 'h1', 'heading'], () => headingNode(level: 1)),
  EditorBlockOption('Título 2', Icons.title_rounded, const ['titulo', 'h2', 'heading'], () => headingNode(level: 2)),
  EditorBlockOption('Título 3', Icons.title_rounded, const ['titulo', 'h3', 'heading'], () => headingNode(level: 3)),
  EditorBlockOption('Viñeta', Icons.format_list_bulleted_rounded, const ['viñeta', 'lista', 'bullet'], () => bulletedListNode()),
  EditorBlockOption('Lista numerada', Icons.format_list_numbered_rounded, const ['numerada', 'lista', 'numero'],
      () => numberedListNode()),
  EditorBlockOption('Tarea', Icons.check_box_outlined, const ['tarea', 'todo', 'check', 'pendiente'],
      () => todoListNode(checked: false)),
  EditorBlockOption('Cita', Icons.format_quote_rounded, const ['cita', 'quote'], () => quoteNode()),
  EditorBlockOption('Desplegable', Icons.arrow_right_rounded, const ['desplegable', 'toggle', 'expandible'],
      () => toggleNode()),
  EditorBlockOption('Destacado', Icons.lightbulb_outline_rounded, const ['destacado', 'callout', 'importante', 'acuerdo'],
      () => calloutNode()),
  EditorBlockOption('Código', Icons.code_rounded, const ['codigo', 'código', 'code'], () => codeNode()),
  EditorBlockOption('Separador', Icons.horizontal_rule_rounded, const ['separador', 'linea', 'divider'],
      () => dividerNode()),
];

/// Inserta [node] en la posición del cursor: reemplaza el bloque si está vacío o lo
/// agrega debajo. Tras un separador agrega un párrafo para seguir escribiendo.
void insertBlockAtCursor(EditorState editorState, Node node) {
  final selection = editorState.selection;
  if (selection == null) return;
  final current = editorState.getNodeAtPath(selection.end.path);
  if (current == null) return;

  final replace = (current.delta?.isEmpty ?? false) && current.children.isEmpty;
  final path = replace ? current.path : current.path.next;
  final transaction = editorState.transaction..insertNode(path, node);
  if (replace) transaction.deleteNode(current);

  if (node.type == DividerBlockKeys.type) {
    transaction
      ..insertNode(path.next, paragraphNode())
      ..afterSelection = Selection.collapsed(Position(path: path.next));
  } else {
    transaction.afterSelection = Selection.collapsed(Position(path: path));
  }
  editorState.apply(transaction);
}

/// Ítems del menú "/".
List<SelectionMenuItem> get slashMenuItems => [
      for (final option in editorBlockOptions)
        SelectionMenuItem(
          getName: () => option.label,
          icon: (editorState, isSelected, style) => Icon(
            option.icon,
            size: OrtizIconSize.md,
            color: isSelected ? style.selectionMenuItemSelectedIconColor : style.selectionMenuItemIconColor,
          ),
          keywords: option.keywords,
          handler: (editorState, menuService, context) => insertBlockAtCursor(editorState, option.build()),
        ),
    ];
