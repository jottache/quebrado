import 'package:flutter/material.dart';
import '../theme/agente_colors.dart';
import 'agente_chat_bottom_sheet.dart';

class DockedLauncherChat extends StatelessWidget {
  const DockedLauncherChat({super.key});

  static const List<String> _quickPrompts = [
    '¿Cuáles son los próximos 3 cumpleaños?',
    '¿Cuánto dinero tengo en total?',
    '¿Qué pagos o tareas tengo hoy?',
    '¿Cuál es la tasa oficial del BCV?',
    '¿Cómo voy con mis hábitos hoy?',
    'Calcular 50 USD a Bs',
  ];

  @override
  Widget build(BuildContext context) {
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
              // 1. Quick Prompts Horizontal Scroll
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final prompt = _quickPrompts[index];
                    return ActionChip(
                      label: Text(
                        prompt,
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
                        AgenteChatBottomSheet.show(context, initialPrompt: prompt);
                      },
                    );
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
