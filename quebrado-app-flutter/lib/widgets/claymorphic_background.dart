import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ClaymorphicBackground extends StatelessWidget {
  final Widget? child;

  const ClaymorphicBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: child,
    );
  }
}
