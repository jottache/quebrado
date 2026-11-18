import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Intl;
import 'block_menu.dart';
import 'custom_blocks.dart';
import 'format_toolbar.dart';
import 'mentions.dart';
import 'rich_editor_colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
/// Preparación única del editor: bloques propios, barra de formato y textos internos
/// de AppFlowy. Los textos se cargan en inglés (los menús visibles son propios y en
/// español) y se restaura Intl.defaultLocale para no alterar fechas ni números de la app.
class RichEditorSetup {
  RichEditorSetup._();

  static Future<void>? _ready;
  static bool isReady = false;

  static Future<void> ensureInitialized() => _ready ??= _init();

  static Future<void> _init() async {
    registerCustomBlockBehaviors();
    registerFormatToolbarBlocks();
    final previous = Intl.defaultLocale;
    try {
      await AppFlowyEditorLocalizations.load(const Locale('en'));
    } catch (e) {
      debugPrint('Editor: no se pudieron cargar los textos internos ($e)');
    } finally {
      Intl.defaultLocale = previous;
      isReady = true;
    }
  }
}

/// Editor de documentos enriquecidos compartido por Notas y Diario.
///
/// - Escritorio (≥ 840 px): barra flotante estilo Notion al seleccionar texto y menú "/".
/// - Móvil: barra de formato sobre la selección y barra de bloques sobre el teclado.
/// - Solo lectura ([editable] = false): para lectores de notas y entradas.
class RichDocumentEditor extends StatefulWidget {
  final EditorState editorState;
  final bool editable;
  final Widget? header;
  final Widget? footer;
  final RichEditorMentions? mentions;
  final Color? accentColor;
  final String placeholder;
  final bool autofocus;

  /// En lectura dentro de otro scroll: el editor ocupa solo lo que necesita.
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final double maxWidth;

  /// Solo lectura: permite marcar/desmarcar tareas. Se llama con el documento ya
  /// actualizado para que la pantalla lo guarde.
  final void Function(Document document)? onTodoToggled;

  /// Escape dentro del editor (por defecto solo quita la selección). Los modales lo
  /// usan para cerrarse.
  final VoidCallback? onEscape;

  const RichDocumentEditor({
    super.key,
    required this.editorState,
    this.editable = true,
    this.header,
    this.footer,
    this.mentions,
    this.accentColor,
    this.placeholder = 'Escribe, o usa "/" para insertar un bloque…',
    this.autofocus = false,
    this.shrinkWrap = false,
    this.padding,
    this.maxWidth = 820,
    this.onTodoToggled,
    this.onEscape,
  });

  @override
  State<RichDocumentEditor> createState() => _RichDocumentEditorState();
}

class _RichDocumentEditorState extends State<RichDocumentEditor> {
  late EditorScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = EditorScrollController(editorState: widget.editorState, shrinkWrap: widget.shrinkWrap);
  }

  @override
  void didUpdateWidget(covariant RichDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      _scrollController.dispose();
      _scrollController = EditorScrollController(editorState: widget.editorState, shrinkWrap: widget.shrinkWrap);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, BlockComponentBuilder> get _builders => {
        ...standardBlockComponentBuilderMap,
        ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
          configuration: BlockComponentConfiguration(
            placeholderText: (node) => widget.editable ? widget.placeholder : '',
          ),
        ),
        if (!widget.editable && widget.onTodoToggled != null)
          TodoListBlockKeys.type: TodoListBlockComponentBuilder(iconBuilder: _readOnlyTodoIcon),
        ToggleBlockKeys.type: ToggleBlockComponentBuilder(),
        CalloutBlockKeys.type: CalloutBlockComponentBuilder(),
        CodeBlockKeys.type: CodeBlockComponentBuilder(),
      };

  List<CommandShortcutEvent> get _commandShortcuts {
    final onEscape = widget.onEscape;
    if (onEscape == null) return standardCommandShortcutEvents;
    return [
      for (final event in standardCommandShortcutEvents)
        if (event == exitEditingCommand)
          CommandShortcutEvent(
            key: 'cerrar el modal',
            getDescription: () => 'Cerrar',
            command: 'escape',
            handler: (editorState) {
              onEscape();
              return KeyEventResult.handled;
            },
          )
        else
          event,
    ];
  }

  /// En lectura el editor ignora transacciones; se habilita solo para marcar la tarea.
  Widget _readOnlyTodoIcon(BuildContext context, Node node, VoidCallback onCheck) {
    final checked = node.attributes[TodoListBlockKeys.checked] == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toggleTodoReadOnly(widget.editorState, node).then((_) {
        widget.onTodoToggled?.call(widget.editorState.document);
      }),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.only(right: OrtizSpace.xs, top: OrtizSpace.xxs),
          child: Icon(
            checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: OrtizIconSize.md,
            color: checked ? RichEditorColors.accent : RichEditorColors.textMuted,
          ),
        ),
      ),
    );
  }

  List<CharacterShortcutEvent> get _characterShortcuts => [
        codeBlockEnter,
        toggleBlockEnter,
        if (widget.mentions != null) ...mentionShortcutEvents(widget.mentions!),
        ...standardCharacterShortcutEvents.where((e) => e != slashCommand),
        customSlashCommand(
          slashMenuItems,
          supportSlashMenuNodeTypes: {
            ParagraphBlockKeys.type,
            HeadingBlockKeys.type,
            TodoListBlockKeys.type,
            BulletedListBlockKeys.type,
            NumberedListBlockKeys.type,
            QuoteBlockKeys.type,
            ToggleBlockKeys.type,
          },
        ),
      ];

  EditorStyle _style({required bool mobile}) {
    final accent = RichEditorColors.accent;
    final textConfig = TextStyleConfiguration(
      text: const TextStyle(fontSize: OrtizFontSize.body, color: RichEditorColors.textPrimary, height: 1.5),
      code: const TextStyle(
        fontFamily: OrtizType.fontMono,
        backgroundColor: RichEditorColors.inlineCodeBg,
        color: RichEditorColors.inlineCodeFg,
      ),
      bold: const TextStyle(fontWeight: FontWeight.w800),
      href: TextStyle(color: accent, decoration: TextDecoration.underline),
    );
    final padding = widget.padding ?? EdgeInsets.symmetric(horizontal: mobile ? OrtizSpace.lg : OrtizSpace.xxxl);
    if (mobile) {
      return EditorStyle.mobile(
        cursorColor: accent,
        dragHandleColor: accent,
        selectionColor: accent.withValues(alpha: 0.18),
        textStyleConfiguration: textConfig,
        padding: padding,
      );
    }
    return EditorStyle.desktop(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.18),
      textStyleConfiguration: textConfig,
      padding: padding,
      maxWidth: widget.maxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accentColor != null) RichEditorColors.accent = widget.accentColor!;

    Widget content() {
      final mobile = MediaQuery.of(context).size.width < 840;
      if (!widget.editable) return _buildEditor(mobile: mobile);
      return mobile ? _buildMobile() : _buildDesktop();
    }

    if (RichEditorSetup.isReady) return content();
    return FutureBuilder<void>(
      future: RichEditorSetup.ensureInitialized(),
      builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done
          ? content()
          : const Center(child: Padding(padding: EdgeInsets.all(OrtizSpace.xxl), child: CircularProgressIndicator())),
    );
  }

  Widget _buildEditor({required bool mobile}) {
    return AppFlowyEditor(
      editorState: widget.editorState,
      editorScrollController: _scrollController,
      editable: widget.editable,
      shrinkWrap: widget.shrinkWrap,
      autoFocus: widget.autofocus,
      editorStyle: _style(mobile: mobile),
      blockComponentBuilders: _builders,
      characterShortcutEvents: _characterShortcuts,
      commandShortcutEvents: _commandShortcuts,
      header: widget.header,
      footer: widget.footer ?? (widget.editable ? const SizedBox(height: 120) : null),
    );
  }

  Widget _buildDesktop() {
    return FloatingToolbar(
      items: notionToolbarItems(),
      style: notionToolbarStyle,
      floatingToolbarHeight: 38,
      editorState: widget.editorState,
      editorScrollController: _scrollController,
      textDirection: TextDirection.ltr,
      child: _buildEditor(mobile: false),
    );
  }

  Widget _buildMobile() {
    return MobileToolbarV2(
      editorState: widget.editorState,
      toolbarHeight: 48,
      primaryColor: RichEditorColors.accent,
      toolbarItems: [
        _blocksMobileItem,
        _indentMobileItem,
        _outdentMobileItem,
        dividerMobileToolbarItem,
      ],
      child: Column(
        children: [
          Expanded(
            child: MobileFloatingToolbar(
              editorState: widget.editorState,
              editorScrollController: _scrollController,
              floatingToolbarHeight: 32,
              toolbarBuilder: (context, anchor, closeToolbar) => buildMobileFormatBar(context, anchor, widget.editorState),
              child: _buildEditor(mobile: true),
            ),
          ),
        ],
      ),
    );
  }

  /// "Bloques": cuadrícula con todos los bloques en español.
  MobileToolbarItem get _blocksMobileItem => MobileToolbarItem.withMenu(
        itemIconBuilder: (context, editorState, service) =>
            const Icon(Icons.add_box_outlined, color: RichEditorColors.textPrimary),
        itemMenuBuilder: (context, editorState, service) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in editorBlockOptions)
              ActionChip(
                avatar: Icon(option.icon, size: OrtizIconSize.sm),
                label: Text(option.label, style: const TextStyle(fontSize: OrtizFontSize.bodySm)),
                onPressed: () {
                  insertBlockAtCursor(editorState, option.build());
                  service.closeItemMenu();
                },
              ),
          ],
        ),
      );

  /// Meter el bloque dentro del anterior (por ejemplo, dentro de un desplegable).
  MobileToolbarItem get _indentMobileItem => MobileToolbarItem.action(
        itemIconBuilder: (context, editorState, service) =>
            const Icon(Icons.format_indent_increase_rounded, color: RichEditorColors.textPrimary),
        actionHandler: (context, editorState) => indentCommand.handler(editorState),
      );

  MobileToolbarItem get _outdentMobileItem => MobileToolbarItem.action(
        itemIconBuilder: (context, editorState, service) =>
            const Icon(Icons.format_indent_decrease_rounded, color: RichEditorColors.textPrimary),
        actionHandler: (context, editorState) => outdentCommand.handler(editorState),
      );
}

/// Marca o desmarca una tarea aunque el editor esté en solo lectura.
Future<void> toggleTodoReadOnly(EditorState editorState, Node node) async {
  final wasEditable = editorState.editable;
  editorState.editable = true;
  try {
    final checked = node.attributes[TodoListBlockKeys.checked] == true;
    final transaction = editorState.transaction..updateNode(node, {TodoListBlockKeys.checked: !checked});
    await editorState.apply(transaction, withUpdateSelection: false);
  } finally {
    editorState.editable = wasEditable;
  }
}

/// Libera un [EditorState] reemplazado cuando termina el frame actual: AppFlowy deja
/// callbacks de fin de frame que todavía lo usan (por ejemplo, al tocar fuera del texto).
void disposeEditorStateLater(EditorState? editorState) {
  if (editorState == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!editorState.isDisposed) editorState.dispose();
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}
