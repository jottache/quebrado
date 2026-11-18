import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodels/agente_state.dart';
import 'chat_message_bubble.dart';

import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

/// Chat con Ortiz sin `Scaffold` (docs/design/ortiz-home.md §2.4–2.5): la
/// lista de mensajes de [AgenteState] y el campo «Pregúntale algo a Ortiz…».
///
/// Lo usan el inicio de Ortiz y `ChatConversationScreen`. Lee [AgenteState]
/// del árbol de providers.
class OrtizChatView extends StatefulWidget {
  const OrtizChatView({
    super.key,
    this.emptyBuilder,
    this.aboveInput,
    this.enabled = true,
    this.focusNode,
    this.showShortcutHint = false,
  });

  /// Lo que se ve cuando la conversación no tiene mensajes. Sin él, el
  /// centro queda vacío.
  final WidgetBuilder? emptyBuilder;

  /// Fila sobre el campo (p. ej. los chips de acción rápida). Se oculta
  /// mientras el campo tiene texto y vuelve cuando queda vacío.
  final Widget? aboveInput;

  /// Con `false` (Ortiz sin conectar) el campo y el botón quedan
  /// deshabilitados.
  final bool enabled;

  /// Foco del campo, para quien quiera llevarlo ahí desde fuera (atajo `/`,
  /// «Nueva conversación»). Sin él, la vista usa uno propio.
  final FocusNode? focusNode;

  /// Muestra el distintivo `/` dentro del campo (solo en escritorio).
  final bool showShortcutHint;

  @override
  State<OrtizChatView> createState() => _OrtizChatViewState();
}

class _OrtizChatViewState extends State<OrtizChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  FocusNode? _ownFocusNode;
  int _lastMessageCount = 0;
  bool _hadText = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.isNotEmpty;
    if (hasText != _hadText) setState(() => _hadText = hasText);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      final duration = OrtizMotion.of(context, OrtizMotion.base);
      // Con reducir movimiento la duración es cero: se salta sin animar.
      if (duration == Duration.zero) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(end, duration: duration, curve: OrtizMotion.ease);
      }
    });
  }

  void _send(AgenteState agenteState) {
    if (!widget.enabled || agenteState.isGenerating) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    agenteState.sendMessage(text);
    _scrollToBottom();
  }

  /// `Enter` envía; `Shift+Enter` deja el salto de línea al campo.
  KeyEventResult _onKey(AgenteState agenteState, KeyEvent event) {
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is! KeyDownEvent || !isEnter) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _send(agenteState);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final agenteState = context.watch<AgenteState>();
    final messages = agenteState.messages;

    if (agenteState.isGenerating || messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? (widget.emptyBuilder?.call(context) ?? const SizedBox.shrink())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _ReadingColumn(
                    padding: OrtizSpace.lg,
                    child: ChatMessageBubble(message: messages[index]),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: _ReadingColumn(
            padding: OrtizSpace.md,
            child: Padding(
              padding: const EdgeInsets.only(bottom: OrtizSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAboveInput(context),
                  _buildInput(context, agenteState),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// [OrtizChatView.aboveInput], que se pliega mientras el campo tiene texto.
  Widget _buildAboveInput(BuildContext context) {
    final child = widget.aboveInput != null && !_hadText
        ? Padding(
            padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
            child: widget.aboveInput,
          )
        : const SizedBox(width: double.infinity);
    final duration = OrtizMotion.of(context, OrtizMotion.fast);
    // `AnimatedSize` con duración cero falla al cambiar de tamaño: con
    // reducir movimiento el cambio es directo.
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: OrtizMotion.ease,
      alignment: Alignment.bottomCenter,
      child: child,
    );
  }

  Widget _buildInput(BuildContext context, AgenteState agenteState) {
    final t = OrtizTokens.of(context);
    final isGenerating = agenteState.isGenerating;
    final canSend = widget.enabled && !isGenerating;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(OrtizRadius.sheet),
      borderSide: BorderSide(color: t.line, width: OrtizStroke.hairline),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) => _onKey(agenteState, event),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(agenteState),
              decoration: InputDecoration(
                hintText: 'Pregúntale algo a Ortiz…',
                hintStyle: TextStyle(color: t.muted),
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                disabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: t.accent, width: OrtizStroke.focus),
                ),
                suffixIcon: widget.showShortcutHint ? _ShortcutBadge(tokens: t) : null,
                suffixIconConstraints: const BoxConstraints(),
              ),
            ),
          ),
        ),
        const SizedBox(width: OrtizSpace.sm),
        IconButton.filled(
          tooltip: 'Enviar',
          onPressed: canSend ? () => _send(agenteState) : null,
          style: IconButton.styleFrom(
            backgroundColor: t.fg,
            foregroundColor: t.bg,
            disabledBackgroundColor: t.fg.withValues(alpha: 0.38),
            disabledForegroundColor: t.bg,
            fixedSize: const Size.square(OrtizSize.minTouch - OrtizSpace.sm),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: isGenerating
              ? SizedBox.square(
                  dimension: OrtizIconSize.md,
                  child: CircularProgressIndicator(
                      strokeWidth: OrtizStroke.focus, color: t.bg),
                )
              : const Icon(Icons.arrow_upward_rounded, size: OrtizIconSize.md),
        ),
      ],
    );
  }
}

/// Centra [child] en la columna de lectura del chat
/// (`OrtizSize.chatMaxWidth`) con un margen lateral de [padding].
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({required this.child, required this.padding});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OrtizSize.chatMaxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Distintivo `/` que recuerda el atajo del campo en escritorio.
class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.tokens});

  final OrtizTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(right: OrtizSpace.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line, width: OrtizStroke.hairline),
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
            child: Text('/', style: OrtizType.caption.copyWith(color: tokens.muted)),
          ),
        ),
      ),
    );
  }
}
