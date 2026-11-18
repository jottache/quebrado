import 'package:flutter/material.dart';

import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

/// Fondo de las pantallas de Quebrado: solo el `bg` del tema (spec 05).
class ClaymorphicBackground extends StatelessWidget {
  final Widget? child;

  const ClaymorphicBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: OrtizTokens.of(context).bg,
      child: child,
    );
  }
}
