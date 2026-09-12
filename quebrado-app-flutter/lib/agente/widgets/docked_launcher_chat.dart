import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/agente_colors.dart';
import '../viewmodels/agente_state.dart';
import '../dialogs/prompt_editor_dialog.dart';
import 'agente_chat_bottom_sheet.dart';

class DockedLauncherChat extends StatelessWidget {
  const DockedLauncherChat({super.key});

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final prompts = agenteState.quickPrompts;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Quick Prompts Horizontal Scroll (Dinámico desde Agente Ortiz)
              SizedBox(
                height: 34,
                child: prompts.isEmpty
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 16, color: AgenteColors.primary),
                            label: const Text(
                              'Personalizar atajos de consulta',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AgenteColors.primary,
                              ),
                            ),
                            backgroundColor: AgenteColors.primaryLight,
                            side: BorderSide(color: AgenteColors.primary.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onPressed: () async {
                              final newPrompt = await PromptEditorDialog.show(context);
                              if (newPrompt != null) {
                                agenteState.saveQuickPrompt(newPrompt);
                              }
                            },
                          ),
                        ],
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: prompts.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index < prompts.length) {
                            final prompt = prompts[index];
                            final displayText = prompt.label != null && prompt.label!.isNotEmpty
                                ? '${prompt.label!}: ${prompt.text}'
                                : prompt.text;
                            return ActionChip(
                              avatar: prompt.label != null
                                  ? const Icon(Icons.bolt_rounded, size: 14, color: AgenteColors.primary)
                                  : null,
                              label: Text(
                                displayText,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onPressed: () {
                                AgenteChatBottomSheet.show(context, initialPrompt: prompt.text);
                              },
                            );
                          } else {
                            // Chip rápido para agregar otro prompt
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 14, color: AgenteColors.primary),
                              label: const Text(
                                'Nuevo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AgenteColors.primary,
                                ),
                              ),
                              backgroundColor: AgenteColors.primaryLight,
                              side: BorderSide(color: AgenteColors.primary.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onPressed: () async {
                                final newPrompt = await PromptEditorDialog.show(context);
                                if (newPrompt != null) {
                                  agenteState.saveQuickPrompt(newPrompt);
                                }
                              },
                            );
                          }
                        },
                      ),
              ),
              const SizedBox(height: 10),

              // 2. Input Pill Launcher Trigger (Tapping opens the 95% bottom sheet modal)
              InkWell(
                onTap: () {
                  AgenteChatBottomSheet.show(context, autoFocus: true);
                },
                borderRadius: BorderRadius.circular(26),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AgenteColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AgenteColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pregúntale al Agente Ortiz...',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AgenteColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
