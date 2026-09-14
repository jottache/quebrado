import 'package:flutter/material.dart';
import '../models/chat_artifact_model.dart';
import '../theme/agente_colors.dart';
import 'action_proposal_card_view.dart';

class ArtifactCardView extends StatelessWidget {
  final ChatArtifactModel artifact;

  const ArtifactCardView({super.key, required this.artifact});

  IconData _getIcon() {
    switch (artifact.type) {
      case ArtifactType.actionProposal:
        return Icons.pending_actions_rounded;
      case ArtifactType.financialSummary:
        return Icons.account_balance_wallet_outlined;
      case ArtifactType.calculation:
        return Icons.calculate_outlined;
      case ArtifactType.contactCard:
        return Icons.badge_outlined;
      case ArtifactType.reminderList:
        return Icons.check_box_outlined;
      case ArtifactType.habitReport:
        return Icons.track_changes_outlined;
      case ArtifactType.table:
        return Icons.table_chart_outlined;
      case ArtifactType.note:
        return Icons.description_outlined;
    }
  }

  Color _getColor() {
    switch (artifact.type) {
      case ArtifactType.actionProposal:
        return const Color(0xFF6366F1);
      case ArtifactType.financialSummary:
        return const Color(0xFF10B981);
      case ArtifactType.calculation:
        return const Color(0xFF0EA5E9);
      case ArtifactType.contactCard:
        return const Color(0xFF8B5CF6);
      case ArtifactType.reminderList:
        return const Color(0xFFF97316);
      case ArtifactType.habitReport:
        return const Color(0xFFEC4899);
      case ArtifactType.table:
      case ArtifactType.note:
        return AgenteColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (artifact.type == ArtifactType.actionProposal) {
      return ActionProposalCardView(artifact: artifact);
    }
    final color = _getColor();

    return Container(
      margin: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_getIcon(), size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    artifact.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.2), width: 1),
                  ),
                  child: Text(
                    artifact.type.label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Text(
              artifact.content,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
