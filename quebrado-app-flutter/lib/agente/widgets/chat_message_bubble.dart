import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/chat_artifact_model.dart';
import '../models/chat_message_model.dart';
import '../theme/agente_colors.dart';
import 'action_proposal_card_view.dart';
import 'artifact_card_view.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  /// Relleno interior de la burbuja (persona y Ortiz).
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md);

  /// Forma de la burbuja. P-27: Ortiz va sobre `surface` con borde `line`;
  /// la persona, sobre `surfaceHigh`. Sin sombra. La usa también el
  /// resultado de un registro (spec 03, U2.1), que es un mensaje de Ortiz.
  static BoxDecoration bubbleDecoration({required bool isUser}) => BoxDecoration(
        color: isUser ? AgenteColors.userBubble : AgenteColors.botBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(OrtizRadius.dialog),
          topRight: const Radius.circular(OrtizRadius.dialog),
          bottomLeft: Radius.circular(isUser ? OrtizRadius.dialog : OrtizRadius.chip),
          bottomRight: Radius.circular(isUser ? OrtizRadius.chip : OrtizRadius.dialog),
        ),
        border: isUser ? null : Border.all(color: AgenteColors.cardBorder),
      );

  /// Estilo del Markdown de Ortiz (también encima del resultado de un registro).
  static MarkdownStyleSheet botMarkdownStyle() => MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: OrtizFontSize.body,
          color: AgenteColors.botText,
          height: 1.45,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w800),
        tableBody: const TextStyle(fontSize: OrtizFontSize.bodySm),
        tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
      );

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final proposals = message.artifacts
        .where((a) => a.type == ArtifactType.actionProposal)
        .toList();
    final hasActionProposal = proposals.isNotEmpty;
    // El texto que añada Ortiz va encima de la línea 1 del primer resultado
    // (U2.1); con solo tarjetas de propuesta, se omite como antes.
    String? resultLeadingId;
    for (final a in proposals) {
      if (ActionProposalCardView.isResultStatus(a.metadata['status'])) {
        resultLeadingId = a.id;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs, horizontal: OrtizSpace.md),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Tool Calls Badges (si hubo)
          if (!isUser && message.toolCalls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
              child: Builder(
                builder: (context) {
                  final toolCounts = <String, int>{};
                  for (final t in message.toolCalls) {
                    final name = t['name']?.toString() ?? 'Herramienta';
                    toolCounts[name] = (toolCounts[name] ?? 0) + 1;
                  }

                  return Wrap(
                    spacing: OrtizSpace.sm,
                    runSpacing: OrtizSpace.xs,
                    children: toolCounts.entries.map((entry) {
                      final name = entry.key;
                      final count = entry.value;
                      final badgeText = count > 1 ? 'Tool: $name ($count)' : 'Tool: $name';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                        decoration: BoxDecoration(
                          color: AgenteColors.toolExec.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          border: Border.all(
                            color: AgenteColors.toolExec.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: OrtizIconSize.xs, color: AgenteColors.toolExec),
                            const SizedBox(width: OrtizSpace.xs),
                            Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: AgenteColors.toolExec,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

          // Message Bubble (se omite si ya existe una tarjeta interactiva de propuesta de acción, para mostrar únicamente la tarjeta con su resumen y botones)
          if (isUser || !hasActionProposal)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: bubblePadding,
              decoration: bubbleDecoration(isUser: isUser),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUser)
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: OrtizFontSize.body,
                      color: AgenteColors.userText,
                      height: 1.4,
                    ),
                  )
                else
                  MarkdownBody(
                    data: message.content.isEmpty && message.isStreaming
                        ? 'Pensando...'
                        : message.content,
                    styleSheet: botMarkdownStyle(),
                  ),

                // Indicador de streaming
                if (message.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: OrtizSpace.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: OrtizIconSize.xs,
                          height: OrtizIconSize.xs,
                          child: CircularProgressIndicator(
                            strokeWidth: OrtizStroke.focus,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUser ? OrtizPalette.muted : AgenteColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.xs),
                        const Text(
                          'Escribiendo...',
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontStyle: FontStyle.italic,
                            color: OrtizPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Artefactos adjuntos
          if (message.artifacts.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final art in message.artifacts)
                    if (art.type == ArtifactType.actionProposal)
                      ActionProposalCardView(
                        key: ValueKey(art.id),
                        artifact: art,
                        leadingText: art.id == resultLeadingId ? message.content : null,
                      )
                    else
                      ArtifactCardView(artifact: art),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
