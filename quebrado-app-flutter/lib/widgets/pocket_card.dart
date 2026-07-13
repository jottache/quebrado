import 'dart:io';
import 'package:flutter/material.dart';
import '../models/saving_pocket.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/helpers.dart';
import '../theme/colors.dart';

class PocketCard extends StatelessWidget {
  final SavingPocket pocket;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool? isFeasible;
  final DateTime? viableTargetDate;

  const PocketCard({
    super.key,
    required this.pocket,
    required this.onAdd,
    required this.onWithdraw,
    this.onTap,
    this.backgroundColor,
    this.isFeasible,
    this.viableTargetDate,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = backgroundColor ?? parseHexColor(pocket.colorHex);
    final isLightCard = themeColor == Colors.white ||
        themeColor == AppColors.cardBackground ||
        HSLColor.fromColor(themeColor).lightness >= 0.75;
    final pocketAccentColor = parseHexColor(pocket.colorHex);

    final textColor = isLightCard ? AppColors.cardText : Colors.white;
    final subtitleColor = isLightCard
        ? AppColors.cardSubtitleText
        : Colors.white.withOpacity(0.9);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClaymorphicCard(
        cornerRadius: 20,
        padding: EdgeInsets.all(16.0),
        backgroundColor: themeColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Header (if imageUrl exists)
            if (pocket.imageUrl != null && pocket.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: pocket.imageUrl!.startsWith('http')
                    ? Image.network(
                        pocket.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          width: double.infinity,
                          color: isLightCard ? Colors.grey[200] : Colors.white.withOpacity(0.12),
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: isLightCard ? Colors.grey[400] : Colors.white.withOpacity(0.5),
                            size: 28,
                          ),
                        ),
                      )
                    : Image.file(
                        File(pocket.imageUrl!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          width: double.infinity,
                          color: isLightCard ? Colors.grey[200] : Colors.white.withOpacity(0.12),
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: isLightCard ? Colors.grey[400] : Colors.white.withOpacity(0.5),
                            size: 28,
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 12),
            ],

            Row(
              children: [
                // Icon Badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isLightCard
                        ? pocketAccentColor.withOpacity(0.12)
                        : Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    getIconData(pocket.icon),
                    color: isLightCard ? pocketAccentColor : Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pocket.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        pocket.targetAmountUSD > 0
                            ? "${(pocket.progress * 100).toInt()}% Completado"
                            : "Sin meta fija",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: onWithdraw,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isLightCard
                              ? pocketAccentColor.withOpacity(0.12)
                              : Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 16,
                          color: isLightCard ? pocketAccentColor : Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isLightCard ? pocketAccentColor : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: isLightCard ? Colors.white : themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Description (if description exists)
            if (pocket.description != null && pocket.description!.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(
                pocket.description!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isLightCard ? AppColors.cardSubtitleText : Colors.white.withOpacity(0.85),
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            if (pocket.targetAmountUSD > 0) ...[
              SizedBox(height: 14),
              AnimatedProgressBar(
                progress: pocket.progress,
                fillColor: isLightCard ? pocketAccentColor : Colors.white,
                height: 10.0,
              ),
            ],

            // Target date indicator & feasibility warnings
            if (pocket.targetDate != null) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: isLightCard ? AppColors.cardSubtitleText : Colors.white.withOpacity(0.9),
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Fecha límite: ${formatDate(pocket.targetDate!)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLightCard ? AppColors.cardSubtitleText : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              if (isFeasible != null && !isFeasible!) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.expense.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Fecha límite no viable (saldo negativo proyectado)",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.expense,
                              ),
                            ),
                            Text(
                              viableTargetDate != null
                                  ? "Fecha viable recalculada: ${formatDate(viableTargetDate!)}"
                                  : "Sin flujos suficientes para estimar.",
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            // Automatic saving rule indicator
            if (pocket.fundingRuleType != 'none') ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: isLightCard ? pocketAccentColor : Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    pocket.fundingRuleType == 'percentage'
                        ? "Ahorro auto: ${pocket.fundingRuleValue?.toStringAsFixed(0)}% por ingreso"
                        : "Ahorro auto: \$${pocket.fundingRuleValue?.toStringAsFixed(0)} (ingreso \u2265 \$${pocket.fundingRuleThreshold?.toStringAsFixed(0)})",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLightCard ? AppColors.cardSubtitleText : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 14),

            // Amounts & Priority Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ahorrado",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: subtitleColor.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      formatUSD(pocket.currentAmountUSD),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                
                // Priority Badge in same row
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLightCard
                        ? pocketAccentColor.withOpacity(0.08)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: isLightCard ? pocketAccentColor : Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Prioridad ${pocket.priority}",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (pocket.targetAmountUSD > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Meta",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: subtitleColor.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        formatUSD(pocket.targetAmountUSD),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
