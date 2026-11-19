import 'dart:io';
import 'package:flutter/material.dart';
import '../models/saving_pocket.dart';
import '../widgets/helpers.dart';
import '../dialogs/pocket_details_bottom_sheet.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Un bolsillo de ahorro como fila, sin tarjeta (spec 05).
///
/// El color del bolsillo (hex elegido por la persona) va como punto de la fila
/// y como relleno de la barra de la meta, nunca como fondo (PA-02).
class PocketCard extends StatelessWidget {
  final SavingPocket pocket;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback? onTap;
  final bool? isFeasible;
  final DateTime? viableTargetDate;

  const PocketCard({
    super.key,
    required this.pocket,
    required this.onAdd,
    required this.onWithdraw,
    this.onTap,
    this.isFeasible,
    this.viableTargetDate,
  });

  /// Alto de la imagen de portada del bolsillo.
  static const double coverHeight = 120;

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PocketDetailsBottomSheet(
        pocket: pocket,
        onAdd: onAdd,
        onWithdraw: onWithdraw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final pocketColor = parseHexColor(pocket.colorHex);
    final hasImage = pocket.imageUrl != null && pocket.imageUrl!.isNotEmpty;
    final hasDescription =
        pocket.description != null && pocket.description!.isNotEmpty;
    final hasTarget = pocket.targetAmountUSD > 0;
    final captionMuted = OrtizType.bodySm.copyWith(
      color: t.muted,
      fontWeight: FontWeight.w600,
    );

    Widget brokenImage() => Container(
          height: coverHeight,
          width: double.infinity,
          color: t.surfaceHigh,
          child: Icon(
            Icons.broken_image_rounded,
            color: t.muted,
            size: OrtizIconSize.xl,
          ),
        );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Imagen de portada (si existe).
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(OrtizRadius.field),
              child: pocket.imageUrl!.startsWith('http')
                  ? Image.network(
                      pocket.imageUrl!,
                      height: coverHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => brokenImage(),
                    )
                  : Image.file(
                      File(pocket.imageUrl!),
                      height: coverHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => brokenImage(),
                    ),
            ),
            const SizedBox(height: OrtizSpace.xs),
          ],

          OrtizListRow(
            dotColor: pocketColor,
            leading: Icon(getIconData(pocket.icon)),
            title: pocket.name,
            subtitle: hasTarget
                ? "${(pocket.progress * 100).toInt()}% Completado"
                : "Sin meta fija",
            onTap: onTap,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Ahorrado",
                      style: OrtizType.caption.copyWith(color: t.muted),
                    ),
                    OrtizAmount(
                      value: pocket.currentAmountUSD,
                      currencySymbol: '\$',
                      format: formatUSD,
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Opciones del bolsillo',
                  icon: Icon(Icons.more_horiz_rounded, color: t.muted),
                  onPressed: () => _openDetails(context),
                ),
              ],
            ),
          ),

          // Detalles alineados con el texto de la fila.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDescription) ...[
                  Text(
                    pocket.description!,
                    style: OrtizType.bodySm.copyWith(color: t.muted, height: 1.35),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: OrtizSpace.sm),
                ],

                if (hasTarget) ...[
                  OrtizProgressBar(
                    value: pocket.progress,
                    color: pocketColor,
                    semanticsLabel: 'Meta del bolsillo',
                  ),
                  const SizedBox(height: OrtizSpace.sm),
                ],

                // Prioridad y meta.
                Row(
                  children: [
                    OrtizPill(
                      label: "Prioridad ${pocket.priority}",
                      icon: Icons.star_rounded,
                      color: pocketColor,
                    ),
                    const Spacer(),
                    if (hasTarget) ...[
                      Text(
                        "Meta",
                        style: OrtizType.caption.copyWith(color: t.muted),
                      ),
                      const SizedBox(width: OrtizSpace.xs),
                      Flexible(
                        child: OrtizAmount(
                          value: pocket.targetAmountUSD,
                          currencySymbol: '\$',
                          format: formatUSD,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ],
                ),

                // Fecha límite y viabilidad.
                if (pocket.targetDate != null) ...[
                  const SizedBox(height: OrtizSpace.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: OrtizIconSize.sm,
                        color: t.muted,
                      ),
                      const SizedBox(width: OrtizSpace.xs),
                      Text(
                        "Fecha límite: ${formatDate(pocket.targetDate!)}",
                        style: captionMuted,
                      ),
                    ],
                  ),
                  if (isFeasible != null && !isFeasible!) ...[
                    const SizedBox(height: OrtizSpace.sm),
                    Container(
                      padding: const EdgeInsets.all(OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: OrtizPalette.badTint,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: t.bad,
                            size: OrtizIconSize.sm,
                          ),
                          const SizedBox(width: OrtizSpace.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Fecha límite no viable (saldo negativo proyectado)",
                                  style: OrtizType.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: t.bad,
                                  ),
                                ),
                                Text(
                                  viableTargetDate != null
                                      ? "Fecha viable recalculada: ${formatDate(viableTargetDate!)}"
                                      : "Sin flujos suficientes para estimar.",
                                  style: OrtizType.caption.copyWith(color: t.bad),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                // Regla de ahorro automático.
                if (pocket.fundingRuleType != 'none') ...[
                  const SizedBox(height: OrtizSpace.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: OrtizIconSize.sm,
                        color: t.muted,
                      ),
                      const SizedBox(width: OrtizSpace.xs),
                      Flexible(
                        child: Text(
                          pocket.fundingRuleType == 'percentage'
                              ? "Ahorro auto: ${pocket.fundingRuleValue?.toStringAsFixed(0)}% por ingreso"
                              : "Ahorro auto: \$${pocket.fundingRuleValue?.toStringAsFixed(0)} (ingreso ≥ \$${pocket.fundingRuleThreshold?.toStringAsFixed(0)})",
                          style: captionMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
