import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/chat_artifact_model.dart';
import '../models/chat_message_model.dart';
import '../theme/agente_colors.dart';
import 'artifact_card_view.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final hasActionProposal =
        message.artifacts.any((a) => a.type == ArtifactType.actionProposal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Tool Calls Badges (si hubo)
          if (!isUser && message.toolCalls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Builder(
                builder: (context) {
                  final toolCounts = <String, int>{};
                  for (final t in message.toolCalls) {
                    final name = t['name']?.toString() ?? 'Herramienta';
                    toolCounts[name] = (toolCounts[name] ?? 0) + 1;
                  }

                  return Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: toolCounts.entries.map((entry) {
                      final name = entry.key;
                      final count = entry.value;
                      final badgeText = count > 1 ? 'Tool: $name ($count)' : 'Tool: $name';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AgenteColors.toolExec.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AgenteColors.toolExec.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 12, color: AgenteColors.toolExec),
                            const SizedBox(width: 4),
                            Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser ? AgenteColors.userBubble : Colors.white,
                borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: isUser
                  ? null
                  : Border.all(color: AgenteColors.cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUser)
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AgenteColors.userText,
                      height: 1.4,
                    ),
                  )
                else
                  MarkdownBody(
                    data: message.content.isEmpty && message.isStreaming
                        ? 'Pensando...'
                        : message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 14.5,
                        color: AgenteColors.botText,
                        height: 1.45,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w800),
                      tableBody: const TextStyle(fontSize: 12.5),
                      tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                // Indicador de streaming
                if (message.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUser ? Colors.white70 : AgenteColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Escribiendo...',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isUser ? Colors.white70 : Colors.grey[500],
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
                children: message.artifacts
                    .map((art) => ArtifactCardView(artifact: art))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
