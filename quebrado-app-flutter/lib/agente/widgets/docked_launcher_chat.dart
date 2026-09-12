import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import 'chat_message_bubble.dart';

class DockedLauncherChat extends StatefulWidget {
  final VoidCallback onToggleSuite;
  final bool isSuiteVisible;

  const DockedLauncherChat({
    super.key,
    required this.onToggleSuite,
    required this.isSuiteVisible,
  });

  @override
  State<DockedLauncherChat> createState() => _DockedLauncherChatState();
}

class _DockedLauncherChatState extends State<DockedLauncherChat> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _quickPrompts = [
    '¿Cuáles son los próximos 3 cumpleaños?',
    '¿Cuánto dinero tengo en total?',
    '¿Qué pagos o tareas tengo hoy?',
    '¿Cuál es la tasa oficial del BCV?',
    '¿Cómo voy con mis hábitos hoy?',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.isSuiteVisible) {
        widget.onToggleSuite();
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
    if (widget.isSuiteVisible) {
      widget.onToggleSuite();
    }

    agenteState.sendMessage(prompt);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final messages = agenteState.messages;

    if (agenteState.isGenerating) {
      _scrollToBottom();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, -6),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Barra de Control Superior (Toggle suite / Nueva charla)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón Píldora: Mostrar / Ocultar Suite de Apps
                InkWell(
                  onTap: widget.onToggleSuite,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isSuiteVisible
                          ? AgenteColors.primaryLight
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isSuiteVisible
                            ? AgenteColors.primary.withOpacity(0.3)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isSuiteVisible
                              ? Icons.expand_more_rounded
                              : Icons.grid_view_rounded,
                          size: 16,
                          color: widget.isSuiteVisible
                              ? AgenteColors.primaryDark
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isSuiteVisible
                              ? 'Ocultar apps'
                              : 'Mostrar suite de apps',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: widget.isSuiteVisible
                                ? AgenteColors.primaryDark
                                : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón: Nueva Conversación
                if (messages.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      agenteState.startNewSession();
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 15, color: AgenteColors.primary),
                    label: const Text(
                      'Nueva charla',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AgenteColors.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // 2. Feed de Mensajes cuando el chat está expandido o hay mensajes
          if (!widget.isSuiteVisible)
            Container(
              height: MediaQuery.of(context).size.height * 0.52,
              color: const Color(0xFFF8FAFC),
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AgenteColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 32,
                              color: AgenteColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '¿En qué te puedo ayudar hoy?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pregúntame sobre tus finanzas, contactos, hábitos o tareas.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return ChatMessageBubble(message: messages[index]);
                      },
                    ),
            ),

          // 3. Indicador de estado ("Consultando cumpleaños...")
          if (agenteState.isGenerating && agenteState.statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AgenteColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    agenteState.statusMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AgenteColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),

          // 4. Quick Prompts (si el chat está visible y no hay demasiados mensajes)
          if (widget.isSuiteVisible || messages.isEmpty)
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return InkWell(
                    onTap: () => _submitPrompt(agenteState, prompt),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 5. Input Bar Dockeada
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? AgenteColors.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (val) => _submitPrompt(agenteState, val),
                      decoration: const InputDecoration(
                        hintText: 'Pregúntale al Agente Ortiz...',
                        hintStyle: TextStyle(fontSize: 13.5, color: Colors.black45),
                        prefixIcon: Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AgenteColors.primary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AgenteColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: agenteState.isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    onPressed: agenteState.isGenerating
                        ? null
                        : () => _submitPrompt(agenteState, _textController.text),
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
