import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import 'chat_message_bubble.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class AgenteChatBottomSheet extends StatefulWidget {
  final String? initialPrompt;
  final bool autoFocus;

  const AgenteChatBottomSheet({
    super.key,
    this.initialPrompt,
    this.autoFocus = true,
  });

  /// Abre el BottomSheetModal del chat cubriendo el 95% de la pantalla
  static Future<void> show(
    BuildContext context, {
    String? initialPrompt,
    bool autoFocus = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: OrtizPalette.bg.withValues(alpha: 0.6),
      useSafeArea: true,
      builder: (context) => AgenteChatBottomSheet(
        initialPrompt: initialPrompt,
        autoFocus: autoFocus,
      ),
    );
  }

  @override
  State<AgenteChatBottomSheet> createState() => _AgenteChatBottomSheetState();
}

class _AgenteChatBottomSheetState extends State<AgenteChatBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
        final agenteState = Provider.of<AgenteState>(context, listen: false);
        _submitPrompt(agenteState, widget.initialPrompt!);
      } else if (widget.autoFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submitPrompt(AgenteState agenteState, String text) {
    final prompt = text.trim();
    if (prompt.isEmpty) return;

    _textController.clear();
    agenteState.sendMessage(prompt);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final messages = agenteState.messages;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    if (agenteState.isGenerating) {
      _scrollToBottom();
    }

    return FractionallySizedBox(
      heightFactor: 0.95,
      child: Container(
        // Hoja: flota sobre `surface`, sin sombra.
        decoration: const BoxDecoration(
          color: OrtizPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
        ),
        child: Column(
          children: [
            // 1. Drag Handle
            Container(
              margin: const EdgeInsets.only(top: OrtizSpace.md, bottom: OrtizSpace.xs),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: OrtizPalette.line,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
            ),

            // 2. Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xs, OrtizSpace.lg, OrtizSpace.md),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AgenteColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      border: Border.all(
                        color: AgenteColors.primary.withValues(alpha: 0.20),
                        width: OrtizStroke.hairline,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AgenteColors.primary,
                      size: OrtizIconSize.md,
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agente Ortiz',
                          style: TextStyle(
                            fontSize: OrtizFontSize.titleSm,
                            fontWeight: FontWeight.w900,
                            color: OrtizPalette.fg,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'ASISTENTE PERSONAL CON RAG',
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w800,
                            color: AgenteColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botón Nueva Charla
                  TextButton.icon(
                    onPressed: () async {
                      await agenteState.startNewSession();
                      _textController.clear();
                      _focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.add_rounded, size: OrtizIconSize.sm, color: AgenteColors.primary),
                    label: const Text(
                      'Nueva charla',
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.w700,
                        color: AgenteColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AgenteColors.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.xs),

                  // Botón Cerrar
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: OrtizIconSize.lg, color: OrtizPalette.muted),
                    tooltip: 'Cerrar chat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: OrtizStroke.hairline, color: OrtizPalette.line),

            // 3. Message Feed
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyWelcome(agenteState)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.lg),
                      itemCount: messages.length + (agenteState.isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          return ChatMessageBubble(message: messages[index]);
                        }
                        return _buildGeneratingIndicator(agenteState);
                      },
                    ),
            ),

            // 4. Quick Prompts Bar (si no está escribiendo o en mensaje inicial y hay prompts)
            if (messages.isEmpty && agenteState.quickPrompts.isNotEmpty)
              Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
                  itemCount: agenteState.quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: OrtizSpace.sm),
                  itemBuilder: (context, index) {
                    final prompt = agenteState.quickPrompts[index];
                    return ActionChip(
                      label: Text(
                        prompt.displayName,
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: OrtizPalette.fg),
                      ),
                      backgroundColor: OrtizPalette.surfaceHigh,
                      side: const BorderSide(color: OrtizPalette.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                      onPressed: () => _submitPrompt(agenteState, prompt.text),
                    );
                  },
                ),
              ),

            // 5. Bottom Input Dock (Padded with keyboard height)
            Container(
              padding: EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.sm, OrtizSpace.lg, OrtizSpace.md + keyboardHeight),
              decoration: const BoxDecoration(
                color: OrtizPalette.surface,
                border: Border(top: BorderSide(color: OrtizPalette.line, width: OrtizStroke.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: OrtizPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(OrtizRadius.sheet),
                        border: Border.all(
                          color: _focusNode.hasFocus ? AgenteColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: OrtizSpace.md),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: OrtizIconSize.sm,
                            color: AgenteColors.primary,
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (text) => _submitPrompt(agenteState, text),
                              style: const TextStyle(fontSize: OrtizFontSize.body, color: OrtizPalette.fg),
                              decoration: const InputDecoration(
                                hintText: 'Pregúntale al Agente Ortiz...',
                                hintStyle: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.body),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                              ),
                            ),
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Container(
                    decoration: const BoxDecoration(
                      color: AgenteColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: OrtizPalette.onAccent, size: OrtizIconSize.md),
                      tooltip: 'Enviar',
                      onPressed: () => _submitPrompt(agenteState, _textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWelcome(AgenteState agenteState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(OrtizSpace.xxl),
      child: Column(
        children: [
          const SizedBox(height: OrtizSpace.xl),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AgenteColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AgenteColors.primary.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AgenteColors.primary, size: OrtizIconSize.xl),
          ),
          const SizedBox(height: OrtizSpace.lg),
          const Text(
            '¡Hola, José! Soy tu Agente Ortiz',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.w900, color: OrtizPalette.fg),
          ),
          const SizedBox(height: OrtizSpace.sm),
          const Text(
            'Tengo acceso en tiempo real a tus finanzas en Quebrado, contactos y cumpleaños en Diario Jottache, hábitos y tareas pendientes en Recordatorios.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, height: 1.4),
          ),
          const SizedBox(height: OrtizSpace.xxl),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGERENCIAS PARA COMENZAR:',
              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: OrtizPalette.muted, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: OrtizSpace.md),
          Wrap(
            spacing: OrtizSpace.sm,
            runSpacing: OrtizSpace.sm,
            children: agenteState.quickPrompts.map((prompt) {
              return ActionChip(
                label: Text(
                  prompt.displayName,
                  style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: OrtizPalette.fg),
                ),
                backgroundColor: OrtizPalette.surfaceHigh,
                side: const BorderSide(color: OrtizPalette.line),
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                onPressed: () => _submitPrompt(agenteState, prompt.text),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator(AgenteState agenteState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OrtizSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AgenteColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AgenteColors.primary.withValues(alpha: 0.3), width: OrtizStroke.hairline),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: OrtizIconSize.sm, color: AgenteColors.primary),
          ),
          const SizedBox(width: OrtizSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
            decoration: BoxDecoration(
              color: AgenteColors.botBubble,
              borderRadius: BorderRadius.circular(OrtizRadius.block),
              border: Border.all(color: AgenteColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AgenteColors.primary),
                  ),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Text(
                  agenteState.statusMessage.isNotEmpty
                      ? agenteState.statusMessage
                      : 'Pensando...',
                  style: const TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.w600,
                    color: AgenteColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
