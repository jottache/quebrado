import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../widgets/briefing_actions.dart';
import '../models/chat_artifact_model.dart';
import '../models/chat_message_model.dart';
import '../models/daily_briefing.dart';
import '../theme/agente_colors.dart';
import '../viewmodels/agente_state.dart';
import 'action_proposal_card_view.dart';
import 'artifact_card_view.dart';
import 'briefing_block.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  /// Ancho máximo de una burbuja de Ortiz con contenido propio (resumen del
  /// día y «Revisando tus apps»): el mismo 85 % que el resto de burbujas.
  static double maxWidthOf(BuildContext context) => MediaQuery.sizeOf(context).width * 0.85;

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
    if (!isUser) {
      for (final art in message.artifacts) {
        if (art.type == ArtifactType.dailyBriefing) {
          return _BriefingMessage(message: message, artifact: art);
        }
      }
    }
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
              constraints: BoxConstraints(maxWidth: maxWidthOf(context)),
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
              constraints: BoxConstraints(maxWidth: maxWidthOf(context)),
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
                    else if (art.type != ArtifactType.dailyBriefing)
                      ArtifactCardView(artifact: art),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mensaje de Ortiz con el resumen del día (spec 04, U2.1): burbuja de bot
/// con el mismo ancho máximo que la de «Revisando tus apps», el texto de
/// Ortiz encima y las filas de [BriefingBlock].
///
/// Solo el mensaje [AgenteState.liveBriefingMessageId] tiene las acciones
/// activas; los demás son resúmenes viejos con su línea de fecha (y, si se
/// recargaron del historial, sin filas).
class _BriefingMessage extends StatefulWidget {
  const _BriefingMessage({required this.message, required this.artifact});

  final ChatMessageModel message;
  final ChatArtifactModel artifact;

  /// Texto del anuncio único al aparecer las filas (U8). Sin cosas que contar
  /// (y sin estar todo al día) no se anuncia «0 cosas».
  static String announcement(DailyBriefing b) {
    if (b.isAllClear) return DailyBriefing.allClearLabel;
    final n = b.itemCount;
    if (n == 0) return 'Resumen listo';
    return 'Resumen listo: $n ${n == 1 ? 'cosa' : 'cosas'} para hoy';
  }

  @override
  State<_BriefingMessage> createState() => _BriefingMessageState();
}

class _BriefingMessageState extends State<_BriefingMessage> {
  /// Mensajes ya anunciados por cada `AgenteState`: la lista del chat
  /// destruye y recrea la burbuja al hacer scroll, y el anuncio no se repite
  /// (ni al volver a verla ni al cambiar el número de cosas).
  static final Expando<Set<String>> _announcedBy = Expando<Set<String>>('briefingAnnounced');

  void _announceOnce(AgenteState agente, DailyBriefing briefing) {
    final announced = _announcedBy[agente] ??= <String>{};
    if (!announced.add(widget.message.id)) return;
    final text = _BriefingMessage.announcement(briefing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final artifact = widget.artifact;
    final liveId = context.select<AgenteState?, String?>((s) => s?.liveBriefingMessageId);
    final bookId = context.select<AppState?, String?>((s) => s?.activeDbName);
    final bookName = context.select<AppState?, String?>((s) => s?.activeProfileName);
    final liveBriefing = context.select<AgenteState?, DailyBriefing?>((s) => s?.liveBriefing);
    final isLive = liveId != null && liveId == message.id;
    // El vivo se pinta con el estado de `AgenteState`: la metadata recargada
    // del historial viene recortada (sin filas).
    final briefing =
        (isLive ? liveBriefing : null) ?? DailyBriefing.fromArtifactMetadata(artifact.metadata);
    final content = message.content;
    if (isLive) _announceOnce(context.read<AgenteState>(), briefing);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs, horizontal: OrtizSpace.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          constraints: BoxConstraints(maxWidth: ChatMessageBubble.maxWidthOf(context)),
          padding: ChatMessageBubble.bubblePadding,
          decoration: ChatMessageBubble.bubbleDecoration(isUser: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (content.isNotEmpty) ...[
                MarkdownBody(data: content, styleSheet: ChatMessageBubble.botMarkdownStyle()),
                const SizedBox(height: OrtizSpace.md),
              ],
              BriefingBlock(
                key: ValueKey('briefing-${artifact.id}'),
                briefing: briefing,
                actionsEnabled: isLive,
                activeBookId: bookId,
                activeBookName: bookName,
                onAction: isLive ? (action) => runBriefingAction(context, action) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
