// Fila de lista SIN tarjeta (spec 05): punto o icono, texto y acción.
//
// En reposo es transparente sobre el fondo; con el puntero encima o con foco
// de teclado se resalta sobre `surface` (y el foco añade el anillo de 2 px en
// `fg`, como los botones del tema); seleccionada, sobre `surfaceHigh`.
import 'package:flutter/material.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';

/// Fila de lista de la suite.
///
/// - [dotColor]: punto de `OrtizSize.dot` con el color de la app, el bolsillo
///   o la categoría (se dibuja antes de [leading] si hay ambos).
/// - [trailing]: monto (`OrtizAmount`), píldora (`OrtizPill`) o acción. Un
///   botón solo-icono aquí necesita su `tooltip`.
/// - [onTap]: si es null, la fila no es interactiva (sin hover ni foco).
/// - [autofocus]: la fila toma el foco al aparecer (p. ej. la opción vigente
///   de un selector, para que el teclado empiece ahí). Solo tiene efecto si
///   hay [onTap].
class OrtizListRow extends StatefulWidget {
  const OrtizListRow({
    super.key,
    this.leading,
    this.dotColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.autofocus = false,
  });

  final Widget? leading;
  final Color? dotColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool autofocus;

  /// Margen horizontal interno de la fila. Úsalo como `headerPadding` de la
  /// `OrtizSection` que la contiene para alinear título y filas.
  static const double inset = OrtizSpace.md;

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: inset,
    vertical: OrtizSpace.sm,
  );

  @override
  State<OrtizListRow> createState() => _OrtizListRowState();
}

class _OrtizListRowState extends State<OrtizListRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final w = widget;
    final radius = BorderRadius.circular(OrtizRadius.field);
    // Anillo solo con foco de teclado (como Material), no tras un toque.
    final showFocus = _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    final Color background;
    if (w.selected) {
      background = t.surfaceHigh;
    } else if (_hovered || showFocus) {
      background = t.surface;
    } else {
      background = Colors.transparent;
    }

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
      child: Padding(
        padding: OrtizListRow._padding,
        child: Row(
          children: [
            if (w.dotColor != null) ...[
              _Dot(color: w.dotColor!),
              const SizedBox(width: OrtizSpace.md),
            ],
            if (w.leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: t.muted, size: OrtizIconSize.md),
                child: w.leading!,
              ),
              const SizedBox(width: OrtizSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OrtizType.body.copyWith(
                      color: t.fg,
                      fontWeight: w.selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (w.subtitle != null)
                    Text(
                      w.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OrtizType.bodySm.copyWith(color: t.muted),
                    ),
                ],
              ),
            ),
            if (w.trailing != null) ...[
              const SizedBox(width: OrtizSpace.md),
              w.trailing!,
            ],
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        selected: w.selected,
        button: w.onTap != null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: w.onTap,
            autofocus: w.autofocus,
            borderRadius: radius,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            onHover: (v) => setState(() => _hovered = v),
            onFocusChange: (v) => setState(() => _focused = v),
            child: Ink(
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
                border: showFocus
                    ? Border.all(color: t.fg, width: OrtizStroke.focus)
                    : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: OrtizSize.dot,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
