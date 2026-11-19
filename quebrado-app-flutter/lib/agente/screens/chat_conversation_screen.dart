import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import '../widgets/chat_message_bubble.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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

  void _sendMessage(AgenteState agenteState) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    agenteState.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final messages = agenteState.messages;
    final sessionTitle = agenteState.currentSession?.title ?? 'Conversación';

    if (agenteState.isGenerating) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AgenteColors.background,
      appBar: AppBar(
        backgroundColor: AgenteColors.background,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionTitle,
              style: const TextStyle(
                fontSize: OrtizFontSize.titleSm,
                fontWeight: FontWeight.w900,
                color: OrtizPalette.fg,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: OrtizSize.dot,
                  height: OrtizSize.dot,
                  decoration: const BoxDecoration(
                    color: AgenteColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: OrtizSpace.xs),
                const Text(
                  'Gemini AI • Conectado a la suite',
                  style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Status banner si está pensando o ejecutando tool
          if (agenteState.isGenerating && agenteState.statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xs),
              color: AgenteColors.primaryLight,
              child: Row(
                children: [
                  const SizedBox(
                    width: OrtizIconSize.xs,
                    height: OrtizIconSize.xs,
                    child: CircularProgressIndicator(strokeWidth: OrtizStroke.focus, color: AgenteColors.primary),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Text(
                    agenteState.statusMessage,
                    style: const TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.bold,
                      color: AgenteColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.lg),
                          decoration: const BoxDecoration(
                            color: AgenteColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: OrtizIconSize.xl, color: AgenteColors.primary),
                        ),
                        const SizedBox(height: OrtizSpace.md),
                        const Text(
                          'Inicia la conversación',
                          style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: OrtizPalette.fg),
                        ),
                        const SizedBox(height: OrtizSpace.xs),
                        const Text(
                          'Escribe lo que deseas saber sobre tus cuentas, personas o hábitos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return ChatMessageBubble(message: messages[index]);
                    },
                  ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.sm, OrtizSpace.lg, OrtizSpace.xxl),
            decoration: const BoxDecoration(
              color: AgenteColors.background,
              border: Border(top: BorderSide(color: OrtizPalette.line)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    // Campo del chat: flota sobre `surface`.
                    child: Container(
                      decoration: BoxDecoration(
                        color: AgenteColors.surface,
                        borderRadius: BorderRadius.circular(OrtizRadius.sheet),
                        border: Border.all(color: OrtizPalette.line),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(agenteState),
                        decoration: const InputDecoration(
                          hintText: 'Pregúntale al Agente Ortiz...',
                          hintStyle: TextStyle(fontSize: OrtizFontSize.body, color: OrtizPalette.muted),
                          prefixIcon: Icon(Icons.auto_awesome_rounded, size: OrtizIconSize.md, color: AgenteColors.primary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                        ),
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
                      tooltip: 'Enviar',
                      icon: agenteState.isGenerating
                          ? const SizedBox(
                              width: OrtizIconSize.md,
                              height: OrtizIconSize.md,
                              child: CircularProgressIndicator(strokeWidth: OrtizStroke.focus, color: OrtizPalette.onAccent),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: OrtizPalette.onAccent, size: OrtizIconSize.md),
                      onPressed: agenteState.isGenerating ? null : () => _sendMessage(agenteState),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
