// Estado vacío de la suite (spec 05): icono grande en `muted`, título y
// mensaje centrados, acción opcional (normalmente un `FilledButton`).
import 'package:flutter/material.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';

/// Vacío, sin resultados o sin datos locales. El texto no pasa de
/// `OrtizSize.readableWidth` en ventanas anchas.
class OrtizEmptyState extends StatelessWidget {
  const OrtizEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OrtizSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OrtizSize.readableWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: OrtizIconSize.xxl, color: t.muted),
              ),
              const SizedBox(height: OrtizSpace.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: OrtizType.titleSm.copyWith(color: t.fg),
              ),
              if (message != null) ...[
                const SizedBox(height: OrtizSpace.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: OrtizType.body.copyWith(color: t.muted),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: OrtizSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
