import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color fillColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    required this.fillColor,
    this.height = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 0.0;
        final progressWidth = maxWidth * progress.clamp(0.0, 1.0);

        return Stack(
          children: [
            // Background bar track
            Container(
              height: height,
              width: maxWidth,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Animating progress overlay bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack, // Playful bouncy feel matching iOS springs
              height: height,
              width: progressWidth,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        );
      },
    );
  }
}
