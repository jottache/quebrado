import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import '../widgets/ortiz_chat_view.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class ChatConversationScreen extends StatelessWidget {
  const ChatConversationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final sessionTitle = agenteState.currentSession?.title ?? 'Conversación';

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

          // Lista de mensajes + campo (compartidos con el inicio de Ortiz).
          Expanded(
            child: OrtizChatView(
              emptyBuilder: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AgenteColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(OrtizSpace.lg),
                        child: Icon(Icons.auto_awesome_rounded, size: OrtizIconSize.xl, color: AgenteColors.primary),
                      ),
                    ),
                    SizedBox(height: OrtizSpace.md),
                    Text(
                      'Inicia la conversación',
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: OrtizPalette.fg),
                    ),
                    SizedBox(height: OrtizSpace.xs),
                    Text(
                      'Escribe lo que deseas saber sobre tus cuentas, personas o hábitos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
