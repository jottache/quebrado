// Entrada escalonada de listas (spec 05) con `OrtizMotion`.
//
// No usa `flutter_animate`: su `Animate` siempre programa un `Future.delayed`
// (aunque el retraso sea cero) que no se cancela al desmontar y deja Timers
// pendientes. Aquí el retraso es un `Interval` dentro de un único
// `AnimationController` que se libera en `dispose`: sin temporizadores.
// Con «reducir movimiento» se devuelve el hijo tal cual.
//
// La entrada se ve una sola vez por lista. En listas perezosas
// (`ListView.builder`, `SliverList.builder`) las filas se destruyen al salir
// de la vista y se vuelven a crear al volver; sin control, la animación se
// repetía en cada scroll. Por eso, dentro de un `Scrollable`, solo animan las
// filas que se crean mientras dura la primera entrada de esa lista; las que
// aparecen después (al hacer scroll) salen ya visibles.
import 'package:flutter/widgets.dart';

import '../../theme/ortiz_motion.dart';

/// Envuelve [child] en un fundido + deslizamiento corto hacia arriba,
/// retrasado `OrtizMotion.stagger × index`. A partir de
/// `OrtizMotion.staggerMaxIndex` los elementos entran a la vez.
Widget ortizStaggered(BuildContext context, int index, Widget child) =>
    _staggered(context, index, child);

/// Atajo: `fila.ortizStaggered(context, i)`.
extension OrtizStaggered on Widget {
  Widget ortizStaggered(BuildContext context, int index) =>
      _staggered(context, index, this);
}

Widget _staggered(BuildContext context, int index, Widget child) {
  if (OrtizMotion.reduced(context)) return child;
  final step = index.clamp(0, OrtizMotion.staggerMaxIndex);
  return OrtizStaggeredEntry(delay: OrtizMotion.stagger * step, child: child);
}

/// Entrada de un elemento: espera [delay] y luego fundido + deslizamiento de
/// `OrtizMotion.base`, todo en un mismo controlador.
class OrtizStaggeredEntry extends StatefulWidget {
  const OrtizStaggeredEntry({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<OrtizStaggeredEntry> createState() => _OrtizStaggeredEntryState();
}

/// Primera entrada de las filas de un `Scrollable`: abierta mientras alguna
/// fila de esa tanda sigue animando; al terminar la última, se cierra para
/// siempre (mientras viva ese `Scrollable`).
class _EntranceWindow {
  int running = 0;
  bool closed = false;
}

final Expando<_EntranceWindow> _entranceWindows =
    Expando<_EntranceWindow>('ortizStaggered');

class _OrtizStaggeredEntryState extends State<OrtizStaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  _EntranceWindow? _window;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + OrtizMotion.base;
    _controller = AnimationController(vsync: this, duration: total);
    final start = total.inMicroseconds == 0
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: OrtizMotion.ease),
    );

    final scrollable = context.findAncestorStateOfType<ScrollableState>();
    final window = scrollable == null
        ? null
        : (_entranceWindows[scrollable] ??= _EntranceWindow());
    if (window != null && window.closed) {
      _controller.value = 1; // ya entró la lista: la fila sale visible
      return;
    }
    _window = window?..running += 1;
    _controller.forward().whenCompleteOrCancel(_release);
  }

  /// Esta fila terminó (o se desmontó): si era la última de la primera
  /// entrada, la lista ya no vuelve a animar.
  void _release() {
    final window = _window;
    if (window == null) return;
    _window = null;
    window.running -= 1;
    if (window.running <= 0) window.closed = true;
  }

  @override
  void dispose() {
    _release();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, OrtizMotion.entryOffset),
          end: Offset.zero,
        ).animate(_progress),
        child: widget.child,
      ),
    );
  }
}
