// Atajos de teclado del shell de la suite (spec 02, CA-10;
// docs/design/ortiz-home.md §10).
//
// - `Ctrl/⌘+K`: abre la paleta, también con el foco en un campo. Con la
//   paleta abierta, la cierra la propia paleta (su `Focus` la recibe antes).
// - `/`: lleva el foco al campo del chat, solo si el foco NO está en un campo
//   de texto (dentro de un campo, `/` se escribe).
// - `Esc`: cierra lo que esté abierto en el shell (el drawer) o quita el foco
//   del chat. Las hojas, diálogos y la paleta van en el Navigator raíz, fuera
//   de este subárbol, y se cierran con su propio `Esc`.
//
// Va por el árbol de foco (un `Focus` alrededor del shell), no por
// `HardwareKeyboard.addHandler`: así un atajo propio de una app (p. ej. el
// `Ctrl+K` de Recordatorios) gana al de la suite, y no se procesa dos veces la
// misma tecla cuando hay una hoja o la paleta encima.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Si el foco está en un campo de texto editable.
bool suiteFocusIsInTextField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Envuelve el shell con los atajos de la suite. Cada callback devuelve si
/// atendió la tecla (si no, la tecla sigue su camino).
class SuiteShortcuts extends StatelessWidget {
  const SuiteShortcuts({
    super.key,
    required this.child,
    required this.onTogglePalette,
    this.onFocusChat,
    this.onEscape,
  });

  final Widget child;

  /// `Ctrl/⌘+K`.
  final VoidCallback onTogglePalette;

  /// `/` fuera de un campo de texto. Devuelve true si llevó el foco al chat.
  final bool Function()? onFocusChat;

  /// `Esc`. Devuelve true si cerró algo o quitó un foco.
  final bool Function()? onEscape;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final ctrlOrMeta = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (key == LogicalKeyboardKey.keyK && ctrlOrMeta) {
      onTogglePalette();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      return onEscape?.call() == true
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    final isSlash = key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide ||
        event.character == '/';
    if (isSlash &&
        !ctrlOrMeta &&
        !keyboard.isAltPressed &&
        !suiteFocusIsInTextField()) {
      return onFocusChat?.call() == true
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // `autofocus`: si nada del shell tiene el foco, lo toma este nodo para que
    // los atajos funcionen desde el primer momento. `skipTraversal`: el
    // tabulador no se detiene en él.
    return Focus(
      autofocus: true,
      skipTraversal: true,
      debugLabel: 'suiteShortcuts',
      onKeyEvent: _onKey,
      child: child,
    );
  }
}
