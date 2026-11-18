import 'package:flutter/material.dart';

import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Barra de progreso de Quebrado. Desde la spec 05 es la barra fina de la
/// suite: redirige a [OrtizProgressBar] (alto, pista y animación del design
/// system, respetando reducir movimiento).
class AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color fillColor;
  final String? semanticsLabel;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    required this.fillColor,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return OrtizProgressBar(
      value: progress,
      color: fillColor,
      semanticsLabel: semanticsLabel,
    );
  }
}
