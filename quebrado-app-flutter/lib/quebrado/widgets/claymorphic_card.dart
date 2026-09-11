import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ClaymorphicCard extends StatelessWidget {
  final double cornerRadius;
  final Color backgroundColor;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Color? borderColor;
  final double? borderWidth;

  const ClaymorphicCard({
    super.key,
    this.cornerRadius = 20.0,
    this.backgroundColor = AppColors.cardBackground,
    this.padding = const EdgeInsets.all(16.0),
    this.width,
    this.height,
    this.alignment,
    this.borderColor,
    this.borderWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(backgroundColor);

    // Dynamic volumetric gradient stops
    final Color darkColor = hsl
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .toColor();

    // Determine content colors based on background color lightness
    final bool isLightCard = hsl.lightness >= 0.75;
    final Color contentColor = isLightCard ? AppColors.cardText : Colors.white;
    final Color resolvedBorderColor = borderColor ?? (isLightCard
        ? AppColors.cardBorderColor
        : Colors.white.withOpacity(isLightCard ? 0.5 : 0.25));
    final double resolvedBorderWidth = borderWidth ?? (isLightCard ? AppColors.cardBorderWidth : 1.5);

    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: resolvedBorderColor, width: resolvedBorderWidth),
        boxShadow: isLightCard
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: Offset(0, 4),
                  blurRadius: 12.0,
                ),
              ]
            : [
                // 3D Soft outer dark shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  offset: Offset(6, 6),
                  blurRadius: 16.0,
                ),
                // Subsurface scattering glow/colored ambient shadow
                BoxShadow(
                  color: darkColor.withOpacity(0.35),
                  offset: Offset(3, 3),
                  blurRadius: 10.0,
                ),
                // 3D Soft outer light highlight
                BoxShadow(
                  color: Colors.white.withOpacity(0.15),
                  offset: Offset(-6, -6),
                  blurRadius: 16.0,
                ),
              ],
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: contentColor,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        child: IconTheme(
          data: IconThemeData(color: contentColor),
          child: child,
        ),
      ),
    );
  }
}
