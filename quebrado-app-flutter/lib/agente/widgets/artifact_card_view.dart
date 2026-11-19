import 'package:flutter/material.dart';
import '../models/chat_artifact_model.dart';
import '../theme/agente_colors.dart';
import 'action_proposal_card_view.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

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
      case ArtifactType.dailyBriefing:
        return Icons.today_outlined;
      case ArtifactType.note:
        return Icons.description_outlined;
    }
  }

  /// Color del artefacto: el de la app de la que habla; Ortiz (acento) si no
  /// pertenece a ninguna.
  Color _getColor() {
    switch (artifact.type) {
      case ArtifactType.financialSummary:
        return SuiteAppColors.finanzas;
      case ArtifactType.contactCard:
        return SuiteAppColors.diario;
      case ArtifactType.reminderList:
        return SuiteAppColors.recordatorios;
      case ArtifactType.habitReport:
        return SuiteAppColors.habitos;
      case ArtifactType.note:
        return SuiteAppColors.notas;
      case ArtifactType.actionProposal:
      case ArtifactType.calculation:
      case ArtifactType.table:
      case ArtifactType.dailyBriefing:
        return AgenteColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (artifact.type == ArtifactType.actionProposal) {
      return ActionProposalCardView(artifact: artifact);
    }
    final color = _getColor();

    // Bloque del chat sobre `surface` con borde `line`; sin sombra.
    return Container(
      margin: const EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xs),
      decoration: BoxDecoration(
        color: AgenteColors.artifactBg,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: Border.all(color: AgenteColors.artifactBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
            color: color.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(_getIcon(), size: OrtizIconSize.sm, color: color),
                const SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    artifact.title,
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    artifact.type.label,
                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(OrtizSpace.md),
            child: Text(
              artifact.content,
              style: const TextStyle(
                fontSize: OrtizFontSize.bodySm,
                height: 1.45,
                color: AgenteColors.botText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
