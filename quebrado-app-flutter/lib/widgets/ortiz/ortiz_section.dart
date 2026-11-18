// Grupo de contenido SIN tarjeta (spec 05, decisión C4).
//
// Sustituye a `Card`/`ClaymorphicCard`: el contenido va sobre el fondo, con un
// encabezado en `caption` color `muted`, y los grupos se separan con espacio
// (`OrtizSpace.xxl`) y, si hace falta, con líneas finas (`divided`).
import 'package:flutter/material.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';

/// Grupo con título opcional, sin fondo, borde ni sombra.
///
/// - [trailing]: acción del encabezado (p. ej. un `TextButton` «Ver todo»).
/// - [divided]: intercala un `Divider` (color `line`) entre los hijos.
/// - [surface]: caso raro de un bloque que sí debe destacarse: fondo
///   `surfaceHigh` y radio `OrtizRadius.block`, sin sombra. No lo uses con
///   filas seleccionables (lo seleccionado también va sobre `surfaceHigh`).
/// - [padding]: margen de toda la sección; debajo siempre deja
///   `OrtizSpace.xxl` hasta el siguiente grupo.
/// - [headerPadding]: margen solo del encabezado, para alinear el título con
///   el texto de las filas (`OrtizListRow.inset`).
class OrtizSection extends StatelessWidget {
  const OrtizSection({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.divided = false,
    this.surface = false,
    this.padding,
    this.headerPadding,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final bool divided;
  final bool surface;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? headerPadding;

  /// Separación hasta el grupo siguiente.
  static const EdgeInsets gap = EdgeInsets.only(bottom: OrtizSpace.xxl);

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final hasHeader = title != null || trailing != null;

    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (divided && i > 0) {
        items.add(const Divider(height: OrtizStroke.hairline));
      }
      items.add(children[i]);
    }

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
    if (surface) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.lg),
          child: body,
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Padding(
        padding: gap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader)
              Padding(
                padding: headerPadding ?? EdgeInsets.zero,
                child: _Header(title: title, trailing: trailing, color: t.muted),
              ),
            if (hasHeader) const SizedBox(height: OrtizSpace.sm),
            body,
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing, required this.color});

  final String? title;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: title == null
              ? const SizedBox.shrink()
              : Semantics(
                  header: true,
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OrtizType.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        ?trailing,
      ],
    );
  }
}
