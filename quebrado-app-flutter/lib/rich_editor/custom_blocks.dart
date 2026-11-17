import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'rich_editor_colors.dart';

/// Bloques propios para AppFlowy Editor que no trae el paquete:
/// desplegable (toggle), destacado (callout) y código.

// =============================================================================
// DESPLEGABLE (TOGGLE)
// =============================================================================

class ToggleBlockKeys {
  const ToggleBlockKeys._();
  static const String type = 'toggle_list';
  static const String delta = blockComponentDelta;
  static const String collapsed = 'collapsed';
}

Node toggleNode({String? text, Delta? delta, bool collapsed = false, Iterable<Node> children = const []}) {
  return Node(
    type: ToggleBlockKeys.type,
    attributes: {
      ToggleBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson(),
      ToggleBlockKeys.collapsed: collapsed,
    },
    children: children,
  );
}

class ToggleBlockComponentBuilder extends BlockComponentBuilder {
  ToggleBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ToggleBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class ToggleBlockComponentWidget extends BlockComponentStatefulWidget {
  const ToggleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<ToggleBlockComponentWidget> createState() => _ToggleBlockComponentWidgetState();
}

class _ToggleBlockComponentWidgetState extends State<ToggleBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: ToggleBlockKeys.type);

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool get collapsed => node.attributes[ToggleBlockKeys.collapsed] == true;

  void _toggleCollapsed() {
    final transaction = editorState.transaction
      ..updateNode(node, {ToggleBlockKeys.collapsed: !collapsed});
    editorState.apply(transaction, withUpdateSelection: false);
  }

  @override
  Widget build(BuildContext context) {
    // Cerrado: solo el título; abierto: el título y sus bloques hijos
    if (collapsed || node.children.isEmpty) {
      return buildComponent(context, withBackgroundColor: true);
    }
    return buildComponentWithChildren(context);
  }

  @override
  Widget buildComponent(BuildContext context, {bool withBackgroundColor = true}) {
    final textDirection = calculateTextDirection(layoutDirection: Directionality.maybeOf(context));

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleCollapsed,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: AnimatedRotation(
                  turns: collapsed ? 0.0 : 0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.arrow_right_rounded, size: 24, color: RichEditorColors.accent),
                ),
              ),
            ),
          ),
          Flexible(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: 'Título del desplegable',
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan).merge(const TextStyle(fontWeight: FontWeight.w700)),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(placeholderTextStyleWithTextSpan(textSpan: textSpan)),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
          if (collapsed && node.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 3),
              child: Text(
                '${node.children.length}',
                style: const TextStyle(fontSize: 11, color: RichEditorColors.textMuted, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );

    child = Container(
      decoration: withBackgroundColor ? decoration : null,
      key: blockComponentKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }
}

/// Enter en el título del desplegable:
/// - vacío → se convierte en párrafo (para salir);
/// - al final y abierto → nuevo bloque DENTRO del desplegable;
/// - al final y cerrado → nuevo desplegable debajo.
final CharacterShortcutEvent toggleBlockEnter = CharacterShortcutEvent(
  key: 'toggle block enter',
  character: '\n',
  handler: (editorState) async {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return false;
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null || node.type != ToggleBlockKeys.type) return false;

    final text = node.delta?.toPlainText() ?? '';
    final collapsed = node.attributes[ToggleBlockKeys.collapsed] == true;
    final transaction = editorState.transaction;

    if (text.isEmpty) {
      transaction
        ..insertNode(node.path, paragraphNode(children: node.children.map((c) => c.deepCopy())))
        ..deleteNode(node)
        ..afterSelection = Selection.collapsed(Position(path: node.path));
    } else if (selection.end.offset < text.length) {
      return false; // en medio del texto: comportamiento normal (dividir)
    } else if (collapsed) {
      transaction
        ..insertNode(node.path.next, toggleNode())
        ..afterSelection = Selection.collapsed(Position(path: node.path.next));
    } else {
      final childPath = [...node.path, 0];
      transaction
        ..insertNode(childPath, paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: childPath));
    }
    await editorState.apply(transaction);
    return true;
  },
);

// =============================================================================
// DESTACADO (CALLOUT)
// =============================================================================

class CalloutBlockKeys {
  const CalloutBlockKeys._();
  static const String type = 'callout';
  static const String delta = blockComponentDelta;
  static const String icon = 'icon';
}

const List<String> calloutIcons = ['💡', '⚠️', '✅', '❗', '📌', '❤️', '💍'];

Node calloutNode({String? text, Delta? delta, String icon = '💡'}) {
  return Node(
    type: CalloutBlockKeys.type,
    attributes: {
      CalloutBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson(),
      CalloutBlockKeys.icon: icon,
    },
  );
}

class CalloutBlockComponentBuilder extends BlockComponentBuilder {
  CalloutBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CalloutBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class CalloutBlockComponentWidget extends BlockComponentStatefulWidget {
  const CalloutBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CalloutBlockComponentWidget> createState() => _CalloutBlockComponentWidgetState();
}

class _CalloutBlockComponentWidgetState extends State<CalloutBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: CalloutBlockKeys.type);

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  String get icon => node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡';

  /// Tocar el emoji lo cambia por el siguiente de la lista.
  void _cycleIcon() {
    final index = calloutIcons.indexOf(icon);
    final next = calloutIcons[(index + 1) % calloutIcons.length];
    final transaction = editorState.transaction..updateNode(node, {CalloutBlockKeys.icon: next});
    editorState.apply(transaction, withUpdateSelection: false);
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = calculateTextDirection(layoutDirection: Directionality.maybeOf(context));

    Widget child = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: RichEditorColors.calloutBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RichEditorColors.calloutBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: textDirection,
        children: [
          GestureDetector(
            onTap: _cycleIcon,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
          Flexible(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: 'Acuerdo o nota importante…',
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan).merge(const TextStyle(fontWeight: FontWeight.w600)),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(placeholderTextStyleWithTextSpan(textSpan: textSpan)),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    child = Container(key: blockComponentKey, padding: padding, child: child);

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }
}

// =============================================================================
// CÓDIGO
// =============================================================================

class CodeBlockKeys {
  const CodeBlockKeys._();
  static const String type = 'code_block';
  static const String delta = blockComponentDelta;
}

Node codeNode({String? text, Delta? delta}) {
  return Node(
    type: CodeBlockKeys.type,
    attributes: {CodeBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson()},
  );
}

class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CodeBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class CodeBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CodeBlockComponentWidget> createState() => _CodeBlockComponentWidgetState();
}

class _CodeBlockComponentWidgetState extends State<CodeBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: CodeBlockKeys.type);

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.robotoMono(fontSize: 13, color: const Color(0xFF1F2937), height: 1.45);

    Widget child = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 40, 12),
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              placeholderText: 'Código…',
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(mono),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(mono.copyWith(color: RichEditorColors.textMuted)),
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: 'Copiar código',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, color: RichEditorColors.textMuted),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: node.delta?.toPlainText() ?? ''));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ),
        ],
      ),
    );

    child = Container(key: blockComponentKey, padding: padding, child: child);

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }
}

/// En un bloque de código, Enter agrega un salto de línea dentro del bloque.
/// Enter sobre una línea vacía al final sale del bloque (nuevo párrafo debajo).
final CharacterShortcutEvent codeBlockEnter = CharacterShortcutEvent(
  key: 'code block enter',
  character: '\n',
  handler: (editorState) async {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return false;
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null || node.type != CodeBlockKeys.type) return false;

    final text = node.delta?.toPlainText() ?? '';
    final offset = selection.end.offset;
    final transaction = editorState.transaction;

    if (offset == text.length && text.endsWith('\n')) {
      transaction
        ..deleteText(node, text.length - 1, 1)
        ..insertNode(node.path.next, paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: node.path.next));
    } else {
      transaction.insertText(node, offset, '\n');
    }
    await editorState.apply(transaction);
    return true;
  },
);

// =============================================================================
// MENÚ "/" Y MARKDOWN
// =============================================================================

bool _isEmptyTextNode(EditorState editorState, Node node) => node.delta?.isEmpty ?? false;

Selection? _cursorAt(EditorState editorState, Path path, bool replaced, bool insertedBefore) =>
    Selection.collapsed(Position(path: path));

final SelectionMenuItem toggleSlashMenuItem = SelectionMenuItem.node(
  getName: () => 'Desplegable',
  iconData: Icons.arrow_right_rounded,
  keywords: ['desplegable', 'toggle', 'expandible', 'plegable'],
  nodeBuilder: (editorState, context) => toggleNode(),
  replace: _isEmptyTextNode,
  updateSelection: _cursorAt,
);

final SelectionMenuItem calloutSlashMenuItem = SelectionMenuItem.node(
  getName: () => 'Destacado',
  iconData: Icons.lightbulb_outline_rounded,
  keywords: ['destacado', 'callout', 'nota', 'acuerdo', 'importante'],
  nodeBuilder: (editorState, context) => calloutNode(),
  replace: _isEmptyTextNode,
  updateSelection: _cursorAt,
);

final SelectionMenuItem codeSlashMenuItem = SelectionMenuItem.node(
  getName: () => 'Código',
  iconData: Icons.code_rounded,
  keywords: ['codigo', 'código', 'code', 'snippet'],
  nodeBuilder: (editorState, context) => codeNode(),
  replace: _isEmptyTextNode,
  updateSelection: _cursorAt,
);

class ToggleMarkdownParser extends NodeParser {
  const ToggleMarkdownParser();

  @override
  String get id => ToggleBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final title = DeltaMarkdownEncoder().convert(node.delta ?? Delta());
    final children = encoder?.convertNodes(node.children) ?? '';
    return '<details><summary>$title</summary>\n\n$children</details>\n';
  }
}

class CalloutMarkdownParser extends NodeParser {
  const CalloutMarkdownParser();

  @override
  String get id => CalloutBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final icon = node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡';
    return '> $icon ${DeltaMarkdownEncoder().convert(node.delta ?? Delta())}\n';
  }
}

class CodeMarkdownParser extends NodeParser {
  const CodeMarkdownParser();

  @override
  String get id => CodeBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    return '```\n${node.delta?.toPlainText() ?? ''}\n```\n';
  }
}

const List<NodeParser> customMarkdownParsers = [
  ToggleMarkdownParser(),
  CalloutMarkdownParser(),
  CodeMarkdownParser(),
];

/// Permite que Tab meta bloques dentro de un desplegable.
void registerCustomBlockBehaviors() {
  indentableBlockTypes.add(ToggleBlockKeys.type);
}
