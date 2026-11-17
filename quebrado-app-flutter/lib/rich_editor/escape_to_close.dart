import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cierra el modal con la tecla Escape cuando el foco está en cualquier parte del
/// modal (título, campos, botones o en ningún lado). Dentro del editor, Escape lo
/// maneja [RichDocumentEditor.onEscape]; los menús ("/", "@", "#") y los selectores
/// que se abren encima se cierran primero porque reciben la tecla antes.
class EscapeToClose extends StatefulWidget {
  final VoidCallback onEscape;
  final Widget child;

  const EscapeToClose({super.key, required this.onEscape, required this.child});

  @override
  State<EscapeToClose> createState() => _EscapeToCloseState();
}

class _EscapeToCloseState extends State<EscapeToClose> {
  final _node = FocusNode(debugLabel: 'escape_to_close', skipTraversal: true);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  /// Si el foco queda "en el aire" (por encima del modal, por ejemplo al hacer clic
  /// en una zona vacía), se recupera para que Escape siga funcionando.
  void _onFocusChange(bool hasFocus) {
    if (hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _node.hasFocus) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return; // hay otro diálogo encima
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || _node.ancestors.contains(primary)) _node.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: true,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onEscape();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
