import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'rich_editor_colors.dart';

/// Una opción mencionable: un contacto (@) o una nota (#).
class MentionOption {
  final String id;
  final String label;
  final String? subtitle;

  const MentionOption({required this.id, required this.label, this.subtitle});
}

/// Fuentes de menciones del editor. Cada lista se pide al abrir el menú.
class RichEditorMentions {
  final List<MentionOption> Function()? contacts;
  final List<MentionOption> Function()? notes;

  const RichEditorMentions({this.contacts, this.notes});
}

const _mentionTypes = {'paragraph', 'heading', 'todo_list', 'bulleted_list', 'numbered_list', 'quote', 'toggle_list', 'callout'};

/// Inserta "@Nombre " o "#Título " en lugar de lo escrito desde el disparador.
/// Se guarda como texto plano resaltado: la detección de menciones de Diario
/// (extractMentionedContactIds / parseMentionedNoteIds) sigue funcionando igual.
Future<void> insertMention(EditorState editorState, String trigger, MentionOption option) async {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) return;
  final node = editorState.getNodeAtPath(selection.end.path);
  final delta = node?.delta;
  if (node == null || delta == null) return;

  final text = delta.toPlainText();
  final end = selection.end.offset.clamp(0, text.length);
  final start = text.substring(0, end).lastIndexOf(trigger);
  if (start == -1) return;

  final mention = '$trigger${option.label}';
  final replace = editorState.transaction
    ..replaceText(node, start, end - start, mention, attributes: {
      AppFlowyRichTextKeys.bold: true,
      AppFlowyRichTextKeys.textColor: _hex(RichEditorColors.accent),
    });
  await editorState.apply(replace);

  // El espacio va en otra transacción: dentro de la misma, la posición se calcularía
  // sobre el texto anterior al reemplazo y el espacio no se insertaba.
  final updated = editorState.getNodeAtPath(node.path);
  if (updated == null) return;
  final afterMention = start + mention.length;
  final space = editorState.transaction
    ..insertText(updated, afterMention, ' ', attributes: {})
    ..afterSelection = Selection.collapsed(Position(path: updated.path, offset: afterMention + 1));
  await editorState.apply(space);
}

String _hex(Color c) => '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

SelectionMenuService? _mentionMenu;

Future<bool> _showMentionMenu(
  EditorState editorState,
  String trigger,
  List<MentionOption> Function() source, {
  bool Function(String textBefore)? allow,
}) async {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.delta == null || !_mentionTypes.contains(node.type)) return false;

  final textBefore = node.delta!.toPlainText().substring(0, selection.start.offset);
  if (allow != null && !allow(textBefore)) return false;

  final options = source();
  keepEditorFocusNotifier.increase();
  await editorState.insertTextAtPosition(trigger, position: selection.start);

  final context = node.context;
  if (options.isNotEmpty && context != null && context.mounted) {
    _mentionMenu = SelectionMenu(
      context: context,
      editorState: editorState,
      deleteSlashByDefault: false,
      singleColumn: true,
      selectionMenuItems: [
        for (final option in options.take(40))
          SelectionMenuItem(
            getName: () => option.label,
            icon: (editorState, isSelected, style) => Icon(
              trigger == '@' ? Icons.person_outline_rounded : Icons.sticky_note_2_outlined,
              size: 18,
              color: isSelected ? style.selectionMenuItemSelectedIconColor : style.selectionMenuItemIconColor,
            ),
            keywords: [option.label.toLowerCase(), if (option.subtitle != null) option.subtitle!.toLowerCase()],
            deleteSlash: false,
            handler: (editorState, menuService, context) => insertMention(editorState, trigger, option),
          ),
      ],
    );
    // Igual que el menú "/" del paquete: se muestra sin esperar.
    unawaited(_mentionMenu?.show());
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => keepEditorFocusNotifier.decrease());
  return true;
}

/// Atajos de teclado para "@" y "#". El "#" solo abre el menú dentro de una línea
/// (al inicio, "# " sigue siendo el atajo de título).
List<CharacterShortcutEvent> mentionShortcutEvents(RichEditorMentions mentions) => [
      if (mentions.contacts != null)
        CharacterShortcutEvent(
          key: 'mention contact',
          character: '@',
          handler: (editorState) => _showMentionMenu(editorState, '@', mentions.contacts!),
        ),
      if (mentions.notes != null)
        CharacterShortcutEvent(
          key: 'mention note',
          character: '#',
          handler: (editorState) => _showMentionMenu(
            editorState,
            '#',
            mentions.notes!,
            allow: (textBefore) => textBefore.trim().isNotEmpty,
          ),
        ),
    ];
