import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/agente_colors.dart';
import '../viewmodels/agente_state.dart';
import '../dialogs/prompt_editor_dialog.dart';
import 'agente_chat_bottom_sheet.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class DockedLauncherChat extends StatelessWidget {
  const DockedLauncherChat({super.key});

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final prompts = agenteState.quickPrompts;

    return Container(
      // Campo del chat anclado: flota sobre `surface`, sin sombra.
      decoration: const BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.sm, OrtizSpace.lg, OrtizSpace.md),
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
                            avatar: const Icon(Icons.add_rounded, size: OrtizIconSize.sm, color: AgenteColors.primary),
                            label: const Text(
                              'Personalizar atajos de consulta',
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: AgenteColors.primary,
                              ),
                            ),
                            backgroundColor: AgenteColors.primaryLight,
                            side: BorderSide(color: AgenteColors.primary.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.block),
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
                        separatorBuilder: (_, __) => const SizedBox(width: OrtizSpace.sm),
                        itemBuilder: (context, index) {
                          if (index < prompts.length) {
                            final prompt = prompts[index];
                            final displayText = prompt.label != null && prompt.label!.isNotEmpty
                                ? '${prompt.label!}: ${prompt.text}'
                                : prompt.text;
                            return ActionChip(
                              avatar: prompt.label != null
                                  ? const Icon(Icons.bolt_rounded, size: OrtizIconSize.sm, color: AgenteColors.primary)
                                  : null,
                              label: Text(
                                displayText,
                                style: const TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w600,
                                  color: OrtizPalette.fg,
                                ),
                              ),
                              backgroundColor: OrtizPalette.surfaceHigh,
                              side: const BorderSide(color: OrtizPalette.line),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.block),
                              ),
                              onPressed: () {
                                AgenteChatBottomSheet.show(context, initialPrompt: prompt.text);
                              },
                            );
                          } else {
                            // Chip rápido para agregar otro prompt
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: OrtizIconSize.sm, color: AgenteColors.primary),
                              label: const Text(
                                'Nuevo',
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w700,
                                  color: AgenteColors.primary,
                                ),
                              ),
                              backgroundColor: AgenteColors.primaryLight,
                              side: BorderSide(color: AgenteColors.primary.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.block),
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
              const SizedBox(height: OrtizSpace.sm),

              // 2. Input Pill Launcher Trigger (Tapping opens the 95% bottom sheet modal)
              InkWell(
                onTap: () {
                  AgenteChatBottomSheet.show(context, autoFocus: true);
                },
                borderRadius: BorderRadius.circular(OrtizRadius.sheet),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.sheet),
                    border: Border.all(color: OrtizPalette.line, width: OrtizStroke.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(OrtizSpace.xs),
                        decoration: const BoxDecoration(
                          color: AgenteColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: OrtizIconSize.sm,
                          color: AgenteColors.primary,
                        ),
                      ),
                      const SizedBox(width: OrtizSpace.md),
                      const Expanded(
                        child: Text(
                          'Pregúntale al Agente Ortiz...',
                          style: TextStyle(
                            color: OrtizPalette.muted,
                            fontSize: OrtizFontSize.body,
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
                          color: OrtizPalette.onAccent,
                          size: OrtizIconSize.sm,
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
