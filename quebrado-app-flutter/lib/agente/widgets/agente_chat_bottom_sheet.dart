import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import 'chat_message_bubble.dart';

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
      barrierColor: Colors.black.withOpacity(0.55),
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

  final List<String> _quickPrompts = [
    '¿Cuáles son los próximos 3 cumpleaños?',
    '¿Cuánto dinero tengo en total?',
    '¿Qué pagos o tareas tengo hoy?',
    '¿Cuál es la tasa oficial del BCV?',
    '¿Cómo voy con mis hábitos hoy?',
    'Calcular 50 USD a Bs',
  ];

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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 30,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // 2. Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AgenteColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AgenteColors.primary.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AgenteColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agente Ortiz',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'ASISTENTE PERSONAL CON RAG',
                          style: TextStyle(
                            fontSize: 10,
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
                    icon: const Icon(Icons.add_rounded, size: 16, color: AgenteColors.primary),
                    label: const Text(
                      'Nueva charla',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AgenteColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AgenteColors.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Botón Cerrar
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Colors.black54),
                    tooltip: 'Cerrar chat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // 3. Message Feed
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyWelcome(agenteState)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: messages.length + (agenteState.isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          return ChatMessageBubble(message: messages[index]);
                        }
                        return _buildGeneratingIndicator(agenteState);
                      },
                    ),
            ),

            // 4. Quick Prompts Bar (si no está escribiendo o en mensaje inicial)
            if (messages.isEmpty)
              Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final prompt = _quickPrompts[index];
                    return ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _submitPrompt(agenteState, prompt),
                    );
                  },
                ),
              ),

            // 5. Bottom Input Dock (Padded with keyboard height)
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + keyboardHeight),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _focusNode.hasFocus ? AgenteColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: AgenteColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (text) => _submitPrompt(agenteState, text),
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Pregúntale al Agente Ortiz...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      color: AgenteColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AgenteColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AgenteColors.primary.withOpacity(0.25), width: 1.5),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AgenteColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Hola, José! Soy tu Agente Ortiz',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Tengo acceso en tiempo real a tus finanzas en Quebrado, contactos y cumpleaños en Diario Jottache, hábitos y tareas pendientes en Recordatorios.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGERENCIAS PARA COMENZAR:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPrompts.map((prompt) {
              return ActionChip(
                label: Text(
                  prompt,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () => _submitPrompt(agenteState, prompt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator(AgenteState agenteState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AgenteColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AgenteColors.primary.withOpacity(0.3), width: 1),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AgenteColors.primary),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
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
                const SizedBox(width: 10),
                Text(
                  agenteState.statusMessage.isNotEmpty
                      ? agenteState.statusMessage
                      : 'Pensando...',
                  style: const TextStyle(
                    fontSize: 13,
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
