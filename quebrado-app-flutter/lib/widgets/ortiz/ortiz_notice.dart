// Aviso breve de la suite (spec 05, avanza P-24): SnackBar flotante del tema
// (fondo `fg`, texto `bg`), con acción opcional y marca de éxito opcional.
import 'package:flutter/material.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';

/// Muestra [message] en un SnackBar del tema y cierra el anterior.
///
/// - [actionLabel] + [onAction]: botón de acción («Deshacer», «Ver»). El aviso
///   se cierra solo igualmente (salvo con navegación accesible activa, que
///   Flutter mantiene hasta que se pulse).
/// - [success]: antepone una marca `ok` (círculo `ok` con el check en
///   `onAccent`: el verde suelto no contrasta sobre el fondo claro del aviso).
///
/// Devuelve null si no hay `ScaffoldMessenger` arriba.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showOrtizNotice(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool success = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final t = OrtizTokens.of(context);
  final hasAction = actionLabel != null && onAction != null;

  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      persist: false,
      content: Row(
        children: [
          if (success) ...[
            _SuccessMark(tokens: t),
            const SizedBox(width: OrtizSpace.sm),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      action: hasAction
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.tokens});

  final OrtizTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hecho',
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.ok, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxs),
          child: Icon(
            Icons.check_rounded,
            size: OrtizIconSize.sm,
            color: tokens.onAccent,
          ),
        ),
      ),
    );
  }
}
