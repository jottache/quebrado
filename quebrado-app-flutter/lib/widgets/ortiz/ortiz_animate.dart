// Entrada escalonada de listas (spec 05) con `OrtizMotion`.
//
// No usa `flutter_animate`: su `Animate` siempre programa un `Future.delayed`
// (aunque el retraso sea cero) que no se cancela al desmontar y deja Timers
// pendientes. Aquí el retraso es un `Interval` dentro de un único
// `AnimationController` que se libera en `dispose`: sin temporizadores.
// Con «reducir movimiento» se devuelve el hijo tal cual.
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

class _OrtizStaggeredEntryState extends State<OrtizStaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

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
    _controller.forward();
  }

  @override
  void dispose() {
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
