import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'rich_editor_colors.dart';
import 'custom_blocks.dart';

/// Barra de formato estilo Notion que aparece al seleccionar texto:
///   A (color) · B · I · U · Tx (quitar formato) · enlace · S · </> · …
/// Las acciones se comparten entre la barra flotante de escritorio ([notionToolbarItems])
/// y la de móvil ([NoteFormatBar]).

/// Bloques donde se puede dar formato al texto (además de los estándar).
void registerFormatToolbarBlocks() {
  toolbarItemWhiteList.addAll({ToggleBlockKeys.type, CalloutBlockKeys.type});
}

class NoteTextColor {
  final String label;
  final Color color;
  const NoteTextColor(this.label, this.color);

  String get hex => '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// Paleta tipo Notion: colores de texto y de fondo.
const List<NoteTextColor> noteTextColors = [
  NoteTextColor('Gris', Color(0xFF787774)),
  NoteTextColor('Marrón', Color(0xFF9F6B53)),
  NoteTextColor('Naranja', Color(0xFFD9730D)),
  NoteTextColor('Amarillo', Color(0xFFCB912F)),
  NoteTextColor('Verde', Color(0xFF448361)),
  NoteTextColor('Azul', Color(0xFF337EA9)),
  NoteTextColor('Morado', Color(0xFF9065B0)),
  NoteTextColor('Rosado', Color(0xFFC14C8A)),
  NoteTextColor('Rojo', Color(0xFFD44C47)),
];

const List<NoteTextColor> noteBackgroundColors = [
  NoteTextColor('Gris', Color(0xFFF1F1EF)),
  NoteTextColor('Marrón', Color(0xFFF4EEEE)),
  NoteTextColor('Naranja', Color(0xFFFBECDD)),
  NoteTextColor('Amarillo', Color(0xFFFBF3DB)),
  NoteTextColor('Verde', Color(0xFFEDF3EC)),
  NoteTextColor('Azul', Color(0xFFE7F3F8)),
  NoteTextColor('Morado', Color(0xFFF6F3F9)),
  NoteTextColor('Rosado', Color(0xFFFAF1F5)),
  NoteTextColor('Rojo', Color(0xFFFDEBEC)),
];

class NoteFormatActions {
  const NoteFormatActions._();

  static Selection? _selection(EditorState s) {
    final selection = s.selection;
    if (selection == null || selection.isCollapsed) return null;
    return selection;
  }

  /// ¿Todo el texto seleccionado tiene la marca [key] (negrita, cursiva…)?
  static bool isMarkActive(EditorState s, String key) {
    final selection = _selection(s);
    if (selection == null) return false;
    final nodes = s.getNodesInSelection(selection);
    return nodes.allSatisfyInSelection(
      selection,
      (delta) => delta.isNotEmpty && delta.everyAttributes((attr) => attr[key] == true),
    );
  }

  /// Valor de un atributo si todo lo seleccionado lo comparte (color, enlace).
  static String? sharedValue(EditorState s, String key) {
    final selection = _selection(s);
    if (selection == null) return null;
    String? value;
    var first = true;
    final nodes = s.getNodesInSelection(selection);
    final same = nodes.allSatisfyInSelection(selection, (delta) {
      return delta.everyAttributes((attr) {
        final v = attr[key]?.toString();
        if (first) {
          value = v;
          first = false;
          return true;
        }
        return v == value;
      });
    });
    return same ? value : null;
  }

  static Future<void> toggleMark(EditorState s, String key) async {
    final selection = _selection(s);
    if (selection == null) return;
    await s.toggleAttribute(key, selection: selection);
  }

  /// Quita negrita, cursiva, subrayado, tachado, código, enlace y colores.
  static Future<void> clearFormatting(EditorState s) async {
    final selection = _selection(s);
    if (selection == null) return;
    await s.formatDelta(selection, {
      AppFlowyRichTextKeys.bold: null,
      AppFlowyRichTextKeys.italic: null,
      AppFlowyRichTextKeys.underline: null,
      AppFlowyRichTextKeys.strikethrough: null,
      AppFlowyRichTextKeys.code: null,
      AppFlowyRichTextKeys.href: null,
      AppFlowyRichTextKeys.textColor: null,
      AppFlowyRichTextKeys.backgroundColor: null,
    });
  }

  static Future<void> setColor(EditorState s, Selection selection, {String? text, String? background, bool clear = false}) async {
    await s.formatDelta(selection, {
      if (text != null || clear) AppFlowyRichTextKeys.textColor: text,
      if (background != null || clear) AppFlowyRichTextKeys.backgroundColor: background,
    });
  }

  /// Menú de colores: texto y fondo, como en Notion.
  static Future<void> pickColor(BuildContext context, EditorState s) async {
    final selection = _selection(s);
    if (selection == null) return;
    final currentText = sharedValue(s, AppFlowyRichTextKeys.textColor);
    final currentBg = sharedValue(s, AppFlowyRichTextKeys.backgroundColor);

    Widget swatch(BuildContext ctx, NoteTextColor c, {required bool background}) {
      final selected = (background ? currentBg : currentText) == c.hex;
      return Tooltip(
        message: c.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(ctx).pop();
            setColor(s, selection, text: background ? null : c.hex, background: background ? c.hex : null);
          },
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ? c.color : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? RichEditorColors.accent : RichEditorColors.border, width: selected ? 2 : 1),
            ),
            child: Text('A', style: TextStyle(fontWeight: FontWeight.w800, color: background ? RichEditorColors.textPrimary : c.color)),
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        title: const Text('Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Texto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RichEditorColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final c in noteTextColors) swatch(ctx, c, background: false)]),
              const SizedBox(height: 14),
              const Text('Fondo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RichEditorColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final c in noteBackgroundColors) swatch(ctx, c, background: true)]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setColor(s, selection, clear: true);
            },
            child: const Text('Por defecto'),
          ),
        ],
      ),
    );
  }

  /// Agregar, cambiar o quitar el enlace del texto seleccionado.
  static Future<void> editLink(BuildContext context, EditorState s) async {
    final selection = _selection(s);
    if (selection == null) return;
    final current = sharedValue(s, AppFlowyRichTextKeys.href);
    final controller = TextEditingController(text: current ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enlace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://…'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Quitar enlace', style: TextStyle(color: Color(0xFFD44C47))),
            ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: RichEditorColors.accent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    var url = result.trim();
    if (url.isNotEmpty && !url.contains('://') && !url.startsWith('mailto:')) url = 'https://$url';
    await s.formatDelta(selection, {AppFlowyRichTextKeys.href: url.isEmpty ? null : url});
  }

  /// "…": convertir el bloque y portapapeles.
  static Future<void> showMore(BuildContext context, EditorState s, {Offset? position}) async {
    final selection = s.selection;
    if (selection == null) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = position ?? (box != null ? box.localToGlobal(box.size.bottomLeft(Offset.zero)) : Offset.zero);

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(origin.dx, origin.dy, origin.dx + 1, origin.dy + 1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(enabled: false, height: 28, child: Text('Convertir en', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
        _menuItem('paragraph', Icons.notes_rounded, 'Texto'),
        _menuItem('h1', Icons.title_rounded, 'Título 1'),
        _menuItem('h2', Icons.title_rounded, 'Título 2'),
        _menuItem('h3', Icons.title_rounded, 'Título 3'),
        _menuItem('bulleted_list', Icons.format_list_bulleted_rounded, 'Viñeta'),
        _menuItem('numbered_list', Icons.format_list_numbered_rounded, 'Lista numerada'),
        _menuItem('todo_list', Icons.check_box_outlined, 'Tarea'),
        _menuItem('quote', Icons.format_quote_rounded, 'Cita'),
        const PopupMenuDivider(),
        _menuItem('copy', Icons.copy_rounded, 'Copiar'),
        _menuItem('cut', Icons.content_cut_rounded, 'Cortar'),
      ],
    );
    if (choice == null) return;

    switch (choice) {
      case 'copy':
        copyCommand.execute(s);
        return;
      case 'cut':
        cutCommand.execute(s);
        return;
    }

    await s.formatNode(selection, (node) {
      final attributes = <String, dynamic>{blockComponentDelta: (node.delta ?? Delta()).toJson()};
      switch (choice) {
        case 'h1':
        case 'h2':
        case 'h3':
          return node.copyWith(
            type: HeadingBlockKeys.type,
            attributes: {...attributes, HeadingBlockKeys.level: int.parse(choice.substring(1))},
          );
        case 'todo_list':
          return node.copyWith(type: TodoListBlockKeys.type, attributes: {...attributes, TodoListBlockKeys.checked: false});
        default:
          return node.copyWith(type: choice, attributes: attributes);
      }
    });
  }

  static PopupMenuItem<String> _menuItem(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 17, color: RichEditorColors.textSecondary),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

// =============================================================================
// DEFINICIÓN DE BOTONES
// =============================================================================

enum NoteFormatButton { color, bold, italic, underline, clear, link, strikethrough, code, more }

extension NoteFormatButtonX on NoteFormatButton {
  String get tooltip {
    switch (this) {
      case NoteFormatButton.color:
        return 'Color';
      case NoteFormatButton.bold:
        return 'Negrita (Ctrl+B)';
      case NoteFormatButton.italic:
        return 'Cursiva (Ctrl+I)';
      case NoteFormatButton.underline:
        return 'Subrayado (Ctrl+U)';
      case NoteFormatButton.clear:
        return 'Quitar formato';
      case NoteFormatButton.link:
        return 'Enlace';
      case NoteFormatButton.strikethrough:
        return 'Tachado';
      case NoteFormatButton.code:
        return 'Código en línea';
      case NoteFormatButton.more:
        return 'Más';
    }
  }

  IconData? get icon {
    switch (this) {
      case NoteFormatButton.color:
        return null; // se dibuja una "A" con el color actual
      case NoteFormatButton.bold:
        return Icons.format_bold_rounded;
      case NoteFormatButton.italic:
        return Icons.format_italic_rounded;
      case NoteFormatButton.underline:
        return Icons.format_underlined_rounded;
      case NoteFormatButton.clear:
        return Icons.format_clear_rounded;
      case NoteFormatButton.link:
        return Icons.link_rounded;
      case NoteFormatButton.strikethrough:
        return Icons.strikethrough_s_rounded;
      case NoteFormatButton.code:
        return Icons.code_rounded;
      case NoteFormatButton.more:
        return Icons.more_horiz_rounded;
    }
  }

  String? get markKey {
    switch (this) {
      case NoteFormatButton.bold:
        return AppFlowyRichTextKeys.bold;
      case NoteFormatButton.italic:
        return AppFlowyRichTextKeys.italic;
      case NoteFormatButton.underline:
        return AppFlowyRichTextKeys.underline;
      case NoteFormatButton.strikethrough:
        return AppFlowyRichTextKeys.strikethrough;
      case NoteFormatButton.code:
        return AppFlowyRichTextKeys.code;
      default:
        return null;
    }
  }

  bool isActive(EditorState s) {
    final key = markKey;
    if (key != null) return NoteFormatActions.isMarkActive(s, key);
    if (this == NoteFormatButton.link) return NoteFormatActions.sharedValue(s, AppFlowyRichTextKeys.href) != null;
    return false;
  }

  Future<void> run(BuildContext context, EditorState s) async {
    final key = markKey;
    if (key != null) return NoteFormatActions.toggleMark(s, key);
    switch (this) {
      case NoteFormatButton.color:
        return NoteFormatActions.pickColor(context, s);
      case NoteFormatButton.clear:
        return NoteFormatActions.clearFormatting(s);
      case NoteFormatButton.link:
        return NoteFormatActions.editLink(context, s);
      case NoteFormatButton.more:
        return NoteFormatActions.showMore(context, s);
      default:
        return;
    }
  }
}

/// Un botón de la barra (misma apariencia en escritorio y móvil).
class NoteFormatButtonWidget extends StatelessWidget {
  final NoteFormatButton button;
  final EditorState editorState;
  final double size;

  const NoteFormatButtonWidget({super.key, required this.button, required this.editorState, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final active = button.isActive(editorState);
    final Widget glyph;
    if (button == NoteFormatButton.color) {
      final hex = NoteFormatActions.sharedValue(editorState, AppFlowyRichTextKeys.textColor);
      final bgHex = NoteFormatActions.sharedValue(editorState, AppFlowyRichTextKeys.backgroundColor);
      glyph = Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgHex?.tryToColor() ?? Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFD3D1CB)),
        ),
        child: Text(
          'A',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: hex?.tryToColor() ?? RichEditorColors.textPrimary),
        ),
      );
    } else {
      glyph = Icon(button.icon, size: 20, color: active ? RichEditorColors.accent : RichEditorColors.icon);
    }

    return Tooltip(
      message: button.tooltip,
      child: Material(
        color: active ? RichEditorColors.accentLight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('note_format_${button.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => button.run(context, editorState),
          child: SizedBox(width: size, height: size, child: Center(child: glyph)),
        ),
      ),
    );
  }
}

// =============================================================================
// ESCRITORIO: items para FloatingToolbar
// =============================================================================

List<ToolbarItem> notionToolbarItems() {
  ToolbarItem item(NoteFormatButton b, int group) => ToolbarItem(
        id: 'note_format.${b.name}',
        group: group,
        isActive: onlyShowInTextType,
        builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) =>
            NoteFormatButtonWidget(button: b, editorState: editorState, size: 30),
      );

  return [
    item(NoteFormatButton.color, 1),
    item(NoteFormatButton.bold, 2),
    item(NoteFormatButton.italic, 2),
    item(NoteFormatButton.underline, 2),
    item(NoteFormatButton.clear, 2),
    item(NoteFormatButton.link, 3),
    item(NoteFormatButton.strikethrough, 3),
    item(NoteFormatButton.code, 3),
    item(NoteFormatButton.more, 4),
  ];
}

FloatingToolbarStyle get notionToolbarStyle => FloatingToolbarStyle(
  backgroundColor: Colors.white,
  toolbarActiveColor: RichEditorColors.accent,
  toolbarIconColor: RichEditorColors.icon,
  toolbarShadowColor: const Color(0x33000000),
  toolbarElevation: 6,
);

// =============================================================================
// MÓVIL: barra que aparece sobre la selección (2 filas, como Notion)
// =============================================================================

class NoteFormatBar extends StatefulWidget {
  final EditorState editorState;

  const NoteFormatBar({super.key, required this.editorState});

  @override
  State<NoteFormatBar> createState() => _NoteFormatBarState();
}

class _NoteFormatBarState extends State<NoteFormatBar> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Repintar al aplicar un formato (para marcar el botón activo)
    _subscription = widget.editorState.transactionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<NoteFormatButton> buttons) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in buttons)
              Padding(
                padding: const EdgeInsets.all(2),
                child: NoteFormatButtonWidget(button: b, editorState: widget.editorState, size: 38),
              ),
          ],
        );

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(const [
              NoteFormatButton.color,
              NoteFormatButton.bold,
              NoteFormatButton.italic,
              NoteFormatButton.underline,
              NoteFormatButton.clear,
            ]),
            row(const [
              NoteFormatButton.link,
              NoteFormatButton.strikethrough,
              NoteFormatButton.code,
              NoteFormatButton.more,
            ]),
          ],
        ),
      ),
    );
  }
}

/// Coloca [NoteFormatBar] encima de la selección (o debajo si no cabe arriba).
Widget buildMobileFormatBar(BuildContext context, Offset anchor, EditorState editorState) {
  return CustomSingleChildLayout(
    delegate: TextSelectionToolbarLayoutDelegate(
      anchorAbove: anchor - const Offset(0, 8),
      anchorBelow: anchor + const Offset(0, 36),
    ),
    child: NoteFormatBar(editorState: editorState),
  );
}
