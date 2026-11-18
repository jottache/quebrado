// Cara de Ortiz (spec 02, paso 7; PA-01: versión vectorial «Pantalla»).
// Especificación: docs/design/ortiz-face.md §2.
//
// `OrtizFace` es la interfaz estable: ánimo, tamaño y seguimiento del cursor.
// El dibujo vive en `_VectorOrtizFace`; cuando exista el personaje de Rive,
// `OrtizFace` elegirá entre ese renderizador y uno de Rive (mismo ánimo,
// tamaño y mirada) sin que cambie quien usa `OrtizFace` (§1.4).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/ortiz_motion.dart';
import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';

/// Ánimo de Ortiz.
enum OrtizMood { idle, thinking, talking, happy }

/// Cara de Ortiz. Es decorativa: el estado se anuncia como texto en otro
/// sitio. Con [followPointer], la mirada sigue al cursor del ratón por toda
/// la ventana (web y escritorio; el tacto no cuenta). Con reducir movimiento
/// no se mueve nada, pero cada ánimo se ve distinto (CA-12).
class OrtizFace extends StatefulWidget {
  const OrtizFace({
    super.key,
    required this.mood,
    required this.size,
    this.followPointer = true,
  });

  final OrtizMood mood;
  final double size;
  final bool followPointer;

  @override
  State<OrtizFace> createState() => OrtizFaceState();
}

/// Estado de [OrtizFace]: escucha el cursor y elige el renderizador.
class OrtizFaceState extends State<OrtizFace> {
  /// Distancia (px) a la que la mirada ya se desplaza del todo (§2.4).
  static const double _followReach = 260;

  final ValueNotifier<Offset> _follow = ValueNotifier<Offset>(Offset.zero);
  bool _listening = false;

  /// Hacia dónde mira por el cursor: dirección × `min(1, distancia / 260)`.
  @visibleForTesting
  Offset get debugFollow => _follow.value;

  @override
  void initState() {
    super.initState();
    _syncPointerRoute();
  }

  @override
  void didUpdateWidget(OrtizFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPointerRoute();
  }

  void _syncPointerRoute() {
    final router = GestureBinding.instance.pointerRouter;
    if (widget.followPointer && !_listening) {
      router.addGlobalRoute(_onPointer);
      _listening = true;
    } else if (!widget.followPointer && _listening) {
      router.removeGlobalRoute(_onPointer);
      _listening = false;
      _follow.value = Offset.zero;
    }
  }

  void _onPointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event is PointerRemovedEvent) {
      // El cursor salió de la ventana: la mirada vuelve al centro.
      _follow.value = Offset.zero;
      return;
    }
    if (event is! PointerHoverEvent && event is! PointerMoveEvent) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final delta = event.position - center;
    final distance = delta.distance;
    _follow.value = distance == 0
        ? Offset.zero
        : delta / distance * math.min(1, distance / _followReach);
  }

  @override
  void dispose() {
    if (_listening) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    }
    _follow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: _VectorOrtizFace(
            mood: widget.mood,
            size: widget.size,
            follow: _follow,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tiempos propios del personaje (§2.3). Las transiciones salen de OrtizMotion.

/// Parpadeo cada 5 s ± hasta 1,5 s al azar.
const Duration _blinkEvery = Duration(seconds: 5);
const Duration _blinkJitter = Duration(milliseconds: 1500);

/// Ciclo de la deriva de la mirada en reposo.
const Duration _driftCycle = Duration(seconds: 8);

/// Periodo del vaivén de los ojos al pensar.
const Duration _thinkCycle = Duration(milliseconds: 1300);

/// Fracción del salto en la que se alcanza el pico.
const double _hopPeak = 0.4;

// Geometría en una caja de 100 × 100 unidades (`u = size / 100`), §2.2.
abstract final class _U {
  static const double box = 100;
  static const Rect screen = Rect.fromLTWH(3, 9, 94, 82);
  static const double screenRadius = 26;
  static const double border = 3;
  static const double stroke = 5.5;
  static const Offset eyeLeft = Offset(35, 45);
  static const Offset eyeRight = Offset(65, 45);
  static const double eyeRx = 6.5;
  static const double eyeRy = 9;
  // Arcos «^ ^»: inicio, control relativo y fin relativo.
  static const Offset arcLeft = Offset(28, 48);
  static const Offset arcRight = Offset(58, 48);
  static const Offset arcControl = Offset(7, -10);
  static const Offset arcEnd = Offset(14, 0);
  // Sonrisa: M38 63 q12 11 24 0.
  static const Offset smileStart = Offset(38, 63);
  static const Offset smileControl = Offset(12, 11);
  static const Offset smileEnd = Offset(24, 0);
  // Boca plana: M43 67 h14.
  static const Offset flatStart = Offset(43, 67);
  static const double flatWidth = 14;
  // Boca hablando.
  static const Offset talkCenter = Offset(50, 66);
  static const double talkRx = 7.5;
  static const double talkRy = 6;
  // Movimiento.
  static const double follow = 6; // máximo desplazamiento por el cursor
  static const Offset driftLeft = Offset(-4, 1);
  static const Offset driftRight = Offset(4, -1);
  static const double thinkSway = 5;
  static const double thinkUp = -6;
}

/// Escala vertical mínima de los ojos al parpadear.
const double _blinkMinScale = 0.08;

/// Escala vertical de la boca al hablar: mínimo y valor fijo sin animación.
const double _talkMinScale = 0.3;
const double _talkRestScale = 0.65;

/// Altura del saltito, en fracción del tamaño.
const double _hopFraction = 0.14;

/// Brillo: σ = max(1, 0.025 · size), alfa 0.55.
const double _glowSigmaFactor = 0.025;
const double _glowMinSigma = 1;
const double _glowAlpha = 0.55;

enum _Eyes { ellipses, arcs }

enum _Mouth { smile, flat, open }

_Eyes _eyesOf(OrtizMood m) => m == OrtizMood.happy ? _Eyes.arcs : _Eyes.ellipses;

_Mouth _mouthOf(OrtizMood m) => switch (m) {
      OrtizMood.thinking => _Mouth.flat,
      OrtizMood.talking => _Mouth.open,
      OrtizMood.idle || OrtizMood.happy => _Mouth.smile,
    };

/// Postura del ánimo en un instante, sin parpadeo ni cursor (los añade la
/// cara). `look` en unidades de la caja de 100; `hop` en fracción del tamaño
/// (negativo = arriba).
@immutable
class OrtizFacePose {
  const OrtizFacePose({
    this.look = Offset.zero,
    this.mouthScale = 1,
    this.hop = 0,
  });

  final Offset look;
  final double mouthScale;
  final double hop;
}

double _seconds(Duration d) => d.inMicroseconds / Duration.microsecondsPerSecond;

double _ease(double t) => OrtizMotion.ease.transform(t.clamp(0.0, 1.0));

/// Deriva de la mirada en la fracción [f] de su ciclo de 8 s (§2.3).
Offset _driftAt(double f) {
  Offset seg(double from, double to, Offset a, Offset b) =>
      Offset.lerp(a, b, _ease((f - from) / (to - from)))!;
  if (f < 0.28) return Offset.zero;
  if (f < 0.38) return seg(0.28, 0.38, Offset.zero, _U.driftLeft);
  if (f < 0.52) return _U.driftLeft;
  if (f < 0.62) return seg(0.52, 0.62, _U.driftLeft, _U.driftRight);
  if (f < 0.78) return _U.driftRight;
  return seg(0.78, 1, _U.driftRight, Offset.zero);
}

/// Postura de [mood] en el instante [t] (reloj continuo de la cara) y a
/// [sinceMood] de haber entrado en el ánimo. Con [reduced], la imagen fija
/// del ánimo (§2.5).
@visibleForTesting
OrtizFacePose ortizFacePose(
  OrtizMood mood, {
  Duration t = Duration.zero,
  Duration sinceMood = Duration.zero,
  bool reduced = false,
}) {
  if (reduced) {
    return switch (mood) {
      OrtizMood.thinking => const OrtizFacePose(look: Offset(0, _U.thinkUp)),
      OrtizMood.talking => const OrtizFacePose(mouthScale: _talkRestScale),
      OrtizMood.idle || OrtizMood.happy => const OrtizFacePose(),
    };
  }
  final drift =
      _driftAt((_seconds(t) / _seconds(_driftCycle)) % 1);
  switch (mood) {
    case OrtizMood.idle:
      return OrtizFacePose(look: drift);
    case OrtizMood.thinking:
      final turn = 2 * math.pi * _seconds(t) / _seconds(_thinkCycle);
      return OrtizFacePose(
          look: Offset(_U.thinkSway * math.sin(turn), _U.thinkUp));
    case OrtizMood.talking:
      final turn = 2 * math.pi * _seconds(t) / _seconds(OrtizMotion.fast);
      final open = 0.5 - 0.5 * math.cos(turn);
      return OrtizFacePose(
        look: drift,
        mouthScale: _talkMinScale + (1 - _talkMinScale) * open,
      );
    case OrtizMood.happy:
      final p = _seconds(sinceMood) / _seconds(OrtizMotion.slow);
      final h = p >= 1
          ? 0.0
          : p < _hopPeak
              ? _ease(p / _hopPeak)
              : 1 - _ease((p - _hopPeak) / (1 - _hopPeak));
      return OrtizFacePose(hop: -_hopFraction * h);
  }
}

/// Escala vertical de los ojos a [sinceBlink] de empezar un parpadeo.
@visibleForTesting
double ortizBlinkScale(Duration sinceBlink) {
  final p = _seconds(sinceBlink) / _seconds(OrtizMotion.fast);
  if (p <= 0 || p >= 1) return 1;
  return 1 - (1 - _blinkMinScale) * math.sin(math.pi * p);
}

/// Renderizador vectorial «Pantalla». Un solo ticker por cara; se pausa
/// fuera de pantalla con `TickerMode`.
class _VectorOrtizFace extends StatefulWidget {
  const _VectorOrtizFace({
    required this.mood,
    required this.size,
    required this.follow,
  });

  final OrtizMood mood;
  final double size;
  final ValueListenable<Offset> follow;

  @override
  State<_VectorOrtizFace> createState() => _VectorOrtizFaceState();
}

class _VectorOrtizFaceState extends State<_VectorOrtizFace>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _repaint = ValueNotifier<int>(0); // un tic por fotograma
  final _rng = math.Random();

  // Reloj de la cara con fase inicial al azar (cada cara a su ritmo).
  late final Duration _phase =
      Duration(microseconds: _rng.nextInt(_driftCycle.inMicroseconds));
  Duration _now = Duration.zero;
  bool _reduced = false;

  // Cambio de ánimo: cross-fade de ojos/boca e interpolación de la mirada.
  OrtizMood? _prevMood;
  Duration _moodSince = Duration.zero;
  Offset _lookFrom = Offset.zero;

  // Parpadeo.
  late Duration _nextBlink = _now + _blinkDelay();
  Duration? _blinkStart;

  // Seguimiento del cursor, suavizado en OrtizMotion.base.
  Offset _followFrom = Offset.zero;
  Offset _followTo = Offset.zero;
  Duration _followSince = Duration.zero;

  Duration get _t => _now + _phase;

  Duration _blinkDelay() {
    final jitter = (_rng.nextDouble() * 2 - 1) * _blinkJitter.inMicroseconds;
    return _blinkEvery + Duration(microseconds: jitter.round());
  }

  @override
  void initState() {
    super.initState();
    widget.follow.addListener(_onFollow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = OrtizMotion.reduced(context);
    if (_reduced) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(_VectorOrtizFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.follow != widget.follow) {
      oldWidget.follow.removeListener(_onFollow);
      widget.follow.addListener(_onFollow);
    }
    if (oldWidget.mood != widget.mood) {
      _lookFrom = _currentLook(oldWidget.mood);
      _prevMood = oldWidget.mood;
      _moodSince = _now;
    }
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    if (_blinkStart != null && _now - _blinkStart! >= OrtizMotion.fast) {
      _blinkStart = null;
    }
    if (_blinkStart == null && _now >= _nextBlink) {
      _blinkStart = _now;
      _nextBlink = _now + _blinkDelay();
    }
    _repaint.value++;
  }

  void _onFollow() {
    if (_reduced) return;
    _followFrom = _currentFollow();
    _followTo = widget.follow.value;
    _followSince = _now;
  }

  double _progress(Duration since, Duration d) =>
      d == Duration.zero ? 1 : (_seconds(_now - since) / _seconds(d)).clamp(0.0, 1.0);

  Offset _currentFollow() {
    if (_reduced) return Offset.zero;
    final p = _ease(_progress(_followSince, OrtizMotion.base));
    return Offset.lerp(_followFrom, _followTo, p)! * _U.follow;
  }

  Offset _currentLook([OrtizMood? mood]) {
    final target = ortizFacePose(mood ?? widget.mood,
            t: _t, sinceMood: _now - _moodSince, reduced: _reduced)
        .look;
    if (_reduced || _prevMood == null) return target;
    final p = _ease(_progress(_moodSince, OrtizMotion.fast));
    return Offset.lerp(_lookFrom, target, p)!;
  }

  _FaceFrame _frame() {
    final pose = ortizFacePose(widget.mood,
        t: _t, sinceMood: _now - _moodSince, reduced: _reduced);
    final fade =
        _reduced || _prevMood == null ? 1.0 : _progress(_moodSince, OrtizMotion.fast);
    final blinking = !_reduced && _blinkStart != null;
    return _FaceFrame(
      mood: widget.mood,
      prevMood: fade < 1 ? _prevMood : null,
      fade: fade,
      look: _currentLook(),
      follow: _currentFollow(),
      eyeScale: blinking ? ortizBlinkScale(_now - _blinkStart!) : 1,
      mouthScale: pose.mouthScale,
      hop: pose.hop,
    );
  }

  @override
  void dispose() {
    widget.follow.removeListener(_onFollow);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _ScreenFacePainter(
        frame: _frame,
        mood: widget.mood,
        reduced: _reduced,
        surface: t.surfaceHigh,
        border: t.line,
        accent: t.accent,
        repaint: _repaint,
      ),
    );
  }
}

/// Lo que se pinta en un fotograma.
class _FaceFrame {
  const _FaceFrame({
    required this.mood,
    required this.prevMood,
    required this.fade,
    required this.look,
    required this.follow,
    required this.eyeScale,
    required this.mouthScale,
    required this.hop,
  });

  final OrtizMood mood;
  final OrtizMood? prevMood; // durante el cross-fade
  final double fade; // 0 → 1: del ánimo anterior al actual
  final Offset look; // solo ojos, en unidades
  final Offset follow; // ojos y boca, en unidades
  final double eyeScale;
  final double mouthScale;
  final double hop; // fracción del tamaño
}

class _ScreenFacePainter extends CustomPainter {
  _ScreenFacePainter({
    required this.frame,
    required this.mood,
    required this.reduced,
    required this.surface,
    required this.border,
    required this.accent,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _FaceFrame Function() frame;
  final OrtizMood mood;
  final bool reduced;
  final Color surface;
  final Color border;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final u = s / _U.box;
    final f = frame();

    canvas.save();
    canvas.translate(0, f.hop * s);

    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(_U.screen.left * u, _U.screen.top * u,
          _U.screen.width * u, _U.screen.height * u),
      Radius.circular(_U.screenRadius * u),
    );
    canvas.drawRRect(screen, Paint()..color = surface);
    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(OrtizStroke.hairline, _U.border * u)
        ..color = border,
    );

    // Unidades → píxeles.
    canvas.scale(u);
    final glow = MaskFilter.blur(
        BlurStyle.normal, math.max(_glowMinSigma, _glowSigmaFactor * s) / u);
    for (final blur in [glow, null]) {
      final base = blur == null ? accent : accent.withValues(alpha: _glowAlpha);
      _parts(canvas, f, base, blur);
    }
    canvas.restore();
  }

  void _parts(Canvas canvas, _FaceFrame f, Color base, MaskFilter? blur) {
    Paint fill(double alpha) => Paint()
      ..color = base.withValues(alpha: base.a * alpha)
      ..maskFilter = blur;
    Paint line(double alpha) => fill(alpha)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _U.stroke;

    canvas.save();
    canvas.translate(f.follow.dx, f.follow.dy);

    // Ojos (grupo `look`).
    final prevEyes = f.prevMood == null ? null : _eyesOf(f.prevMood!);
    final eyes = _eyesOf(f.mood);
    canvas.save();
    canvas.translate(f.look.dx, f.look.dy);
    if (prevEyes == null || prevEyes == eyes) {
      _eyes(canvas, eyes, f.eyeScale, fill(1), line(1));
    } else {
      _eyes(canvas, prevEyes, f.eyeScale, fill(1 - f.fade), line(1 - f.fade));
      _eyes(canvas, eyes, f.eyeScale, fill(f.fade), line(f.fade));
    }
    canvas.restore();

    // Boca.
    final prevMouth = f.prevMood == null ? null : _mouthOf(f.prevMood!);
    final mouth = _mouthOf(f.mood);
    if (prevMouth == null || prevMouth == mouth) {
      _mouth(canvas, mouth, f.mouthScale, fill(1), line(1));
    } else {
      _mouth(canvas, prevMouth, f.mouthScale, fill(1 - f.fade), line(1 - f.fade));
      _mouth(canvas, mouth, f.mouthScale, fill(f.fade), line(f.fade));
    }
    canvas.restore();
  }

  void _eyes(Canvas canvas, _Eyes kind, double scaleY, Paint fill, Paint line) {
    switch (kind) {
      case _Eyes.ellipses:
        for (final c in const [_U.eyeLeft, _U.eyeRight]) {
          canvas.drawOval(
            Rect.fromCenter(
                center: c, width: 2 * _U.eyeRx, height: 2 * _U.eyeRy * scaleY),
            fill,
          );
        }
      case _Eyes.arcs:
        for (final a in const [_U.arcLeft, _U.arcRight]) {
          canvas.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..relativeQuadraticBezierTo(_U.arcControl.dx, _U.arcControl.dy,
                  _U.arcEnd.dx, _U.arcEnd.dy),
            line,
          );
        }
    }
  }

  void _mouth(Canvas canvas, _Mouth kind, double scaleY, Paint fill, Paint line) {
    switch (kind) {
      case _Mouth.smile:
        canvas.drawPath(
          Path()
            ..moveTo(_U.smileStart.dx, _U.smileStart.dy)
            ..relativeQuadraticBezierTo(_U.smileControl.dx, _U.smileControl.dy,
                _U.smileEnd.dx, _U.smileEnd.dy),
          line,
        );
      case _Mouth.flat:
        canvas.drawLine(
          _U.flatStart,
          _U.flatStart.translate(_U.flatWidth, 0),
          line,
        );
      case _Mouth.open:
        canvas.drawOval(
          Rect.fromCenter(
            center: _U.talkCenter,
            width: 2 * _U.talkRx,
            height: 2 * _U.talkRy * scaleY,
          ),
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(_ScreenFacePainter old) =>
      old.mood != mood ||
      old.reduced != reduced ||
      old.surface != surface ||
      old.border != border ||
      old.accent != accent;
}
