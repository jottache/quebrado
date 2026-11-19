// Botón ☰ de cada app (spec 02, pasos 3c/3d; docs/design/rutas.md §3–§4).
//
// Sustituye a los «atrás» que hacían `Navigator.pop()` esperando el launcher
// debajo: en la raíz de una rama del router no hay nada que cerrar. Abre el
// menú del shell (`SuiteShellScope.openMenu`).
import 'package:flutter/material.dart';

import '../theme/ortiz_space.dart';
import 'responsive_breakpoints.dart';
import 'responsive_suite_scaffold.dart';

class SuiteMenuButton extends StatelessWidget {
  const SuiteMenuButton({super.key, this.color});

  /// Color del icono; por defecto, el de la barra.
  final Color? color;

  static const String tooltip = 'Abrir menú';

  /// True si hay que mostrar el ☰: la pantalla está dentro del shell y el
  /// menú es un drawer (`< 840`). En `≥ 840` el menú es el riel, siempre
  /// visible, y el ☰ sobra.
  static bool isVisible(BuildContext context) =>
      SuiteShellScope.maybeOf(context) != null &&
      !ResponsiveBreakpoints.isDesktop(context);

  /// El ☰ para `AppBar.leading`, o null si no se muestra (así la barra puede
  /// poner su «atrás» automático cuando la pantalla está apilada).
  static Widget? leading(BuildContext context, {Color? color}) =>
      isVisible(context) ? SuiteMenuButton(color: color) : null;

  @override
  Widget build(BuildContext context) {
    final scope = SuiteShellScope.maybeOf(context);
    if (scope == null || ResponsiveBreakpoints.isDesktop(context)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.menu_rounded, size: OrtizIconSize.md),
      color: color,
      tooltip: tooltip,
      onPressed: scope.openMenu,
    );
  }
}
