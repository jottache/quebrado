import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';

import '../../helpers/pump_app.dart';

/// Envuelve [child] pidiendo reducir el movimiento.
Widget _reducedMotion(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

Future<void> _pumpFace(
  WidgetTester tester,
  OrtizMood mood, {
  double size = OrtizIconSize.xl,
  bool reduced = false,
  bool followPointer = true,
  WindowClass window = WindowClass.compact,
}) async {
  final face = Center(
    child: OrtizFace(mood: mood, size: size, followPointer: followPointer),
  );
  await pumpApp(tester, reduced ? _reducedMotion(face) : face,
      window: window, settle: false);
}

Finder get _painter => find.descendant(
    of: find.byType(OrtizFace), matching: find.byType(CustomPaint));

Duration _part(Duration d, double f) =>
    Duration(microseconds: (d.inMicroseconds * f).round());

void main() {
  group('ortizFacePose sin animación (CA-12)', () {
    test('cada ánimo tiene su imagen fija', () {
      final idle = ortizFacePose(OrtizMood.idle, reduced: true);
      final thinking = ortizFacePose(OrtizMood.thinking, reduced: true);
      final talking = ortizFacePose(OrtizMood.talking, reduced: true);
      final happy = ortizFacePose(OrtizMood.happy, reduced: true);

      expect(idle.look, Offset.zero);
      expect(thinking.look, const Offset(0, -6));
      expect(talking.mouthScale, 0.65);
      expect(happy.hop, 0);
    });

    test('no se mueve con el tiempo', () {
      for (final mood in OrtizMood.values) {
        final a = ortizFacePose(mood, reduced: true);
        final b = ortizFacePose(mood,
            t: const Duration(seconds: 3),
            sinceMood: OrtizMotion.fast,
            reduced: true);
        expect(b.look, a.look);
        expect(b.mouthScale, a.mouthScale);
        expect(b.hop, a.hop);
      }
    });
  });

  group('ortizFacePose animado', () {
    const drift = Duration(seconds: 8);

    test('en reposo la mirada deriva en un ciclo de 8 s', () {
      expect(ortizFacePose(OrtizMood.idle, t: _part(drift, 0.1)).look, Offset.zero);
      expect(ortizFacePose(OrtizMood.idle, t: _part(drift, 0.45)).look,
          const Offset(-4, 1));
      expect(ortizFacePose(OrtizMood.idle, t: _part(drift, 0.7)).look,
          const Offset(4, -1));
    });

    test('pensando, los ojos miran arriba y oscilan de lado a lado', () {
      const cycle = Duration(milliseconds: 1300);
      final right = ortizFacePose(OrtizMood.thinking, t: _part(cycle, 0.25)).look;
      final left = ortizFacePose(OrtizMood.thinking, t: _part(cycle, 0.75)).look;
      expect(right.dx, closeTo(5, 1e-9));
      expect(left.dx, closeTo(-5, 1e-9));
      expect(right.dy, -6);
    });

    test('hablando, la boca abre y cierra entre 0,3 y 1', () {
      expect(ortizFacePose(OrtizMood.talking).mouthScale, closeTo(0.3, 1e-9));
      expect(
          ortizFacePose(OrtizMood.talking, t: _part(OrtizMotion.fast, 0.5))
              .mouthScale,
          closeTo(1, 1e-9));
    });

    test('contento da un saltito al entrar, con pico al 40 %, y luego se queda', () {
      expect(ortizFacePose(OrtizMood.happy).hop, 0);
      expect(
          ortizFacePose(OrtizMood.happy,
                  sinceMood: _part(OrtizMotion.slow, 0.4))
              .hop,
          closeTo(-0.14, 1e-3)); // la curva Cubic se resuelve con error ≤ 0,001
      expect(ortizFacePose(OrtizMood.happy, sinceMood: OrtizMotion.slow * 2).hop, 0);
    });

    test('el parpadeo cierra los ojos a 0,08 y los vuelve a abrir', () {
      expect(ortizBlinkScale(Duration.zero), 1);
      expect(ortizBlinkScale(_part(OrtizMotion.fast, 0.5)), closeTo(0.08, 1e-9));
      expect(ortizBlinkScale(OrtizMotion.fast), 1);
    });
  });

  group('OrtizFollowEase', () {
    test('llega al destino en OrtizMotion.base, pasando por en medio', () {
      final ease = OrtizFollowEase()..retarget(const Offset(1, 0), Duration.zero);
      expect(ease.at(Duration.zero), Offset.zero);
      final mid = ease.at(_part(OrtizMotion.base, 0.5)).dx;
      expect(mid, inExclusiveRange(0, 1));
      expect(ease.at(OrtizMotion.base), const Offset(1, 0));
    });

    test('muchos movimientos seguidos del ratón no hacen que la mirada se dispare',
        () {
      // Regresión: el punto de partida se guardaba ya multiplicado por el
      // desplazamiento máximo y crecía ×6 en cada evento del ratón.
      final ease = OrtizFollowEase();
      var now = Duration.zero;
      for (var i = 0; i < 200; i++) {
        ease.retarget(Offset(i.isEven ? 1 : -1, 0.5), now);
        now += const Duration(milliseconds: 4);
        expect(ease.at(now).distance, lessThanOrEqualTo(1.2));
      }
      final rest = ease.at(now + OrtizMotion.base);
      expect(rest.dx, closeTo(-1, 1e-9));
      expect(rest.dy, closeTo(0.5, 1e-9));
    });

    test('un nuevo destino arranca desde donde va la mirada', () {
      final ease = OrtizFollowEase()..retarget(const Offset(1, 0), Duration.zero);
      final half = _part(OrtizMotion.base, 0.5);
      final there = ease.at(half);
      ease.retarget(const Offset(-1, 0), half);
      expect(ease.at(half), there);
    });
  });

  group('OrtizFace', () {
    for (final window in [WindowClass.compact, WindowClass.expanded]) {
      testWidgets('dibuja los cuatro ánimos a 32 y a 96 sin excepciones (${window.name})',
          (tester) async {
        for (final size in [OrtizIconSize.xl, 96.0]) {
          for (final mood in OrtizMood.values) {
            await _pumpFace(tester, mood, size: size, window: window);
            await tester.pump(const Duration(seconds: 7));
            expect(tester.takeException(), isNull);
            expect(tester.getSize(find.byType(OrtizFace)), Size.square(size));
          }
        }
      });
    }

    testWidgets('anima cuando no se pide reducir el movimiento', (tester) async {
      await _pumpFace(tester, OrtizMood.talking);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets(
        'con reducir movimiento no hay animación pendiente, pero el ánimo se ve',
        (tester) async {
      await _pumpFace(tester, OrtizMood.idle, reduced: true);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // En reposo, ojos en elipse: 2 ojos × (brillo + trazo).
      expect(_painter, paintsExactlyCountTimes(#drawOval, 4));

      await _pumpFace(tester, OrtizMood.happy, reduced: true);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Contento: ojos en arco «^ ^», sin elipses.
      expect(_painter, paintsExactlyCountTimes(#drawOval, 0));
      expect(_painter, paintsExactlyCountTimes(#drawPath, 6)); // 2 arcos + sonrisa, ×2
    });

    testWidgets('al desmontarse no deja animaciones ni temporizadores', (tester) async {
      await _pumpFace(tester, OrtizMood.thinking);
      await _pumpFace(tester, OrtizMood.happy);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('la mirada sigue al cursor, limitada, y vuelve al centro al salir',
        (tester) async {
      await _pumpFace(tester, OrtizMood.idle);
      final state = tester.state<OrtizFaceState>(find.byType(OrtizFace));
      expect(state.debugFollow, Offset.zero);

      final center = tester.getCenter(find.byType(OrtizFace));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: center);
      await mouse.moveTo(center + const Offset(1000, 0));
      await tester.pump();
      expect(state.debugFollow.dx, closeTo(1, 1e-9));
      expect(state.debugFollow.dy, closeTo(0, 1e-9));

      await mouse.moveTo(center + const Offset(0, -130));
      await tester.pump();
      expect(state.debugFollow.dy, closeTo(-0.5, 1e-9));

      await mouse.removePointer();
      await tester.pump();
      expect(state.debugFollow, Offset.zero);

      // Desmontada, deja de escuchar el cursor.
      await tester.pumpWidget(const SizedBox.shrink());
      final again = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await again.addPointer(location: center);
      await again.moveTo(center + const Offset(50, 0));
      await again.removePointer();
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin followPointer ignora el cursor', (tester) async {
      await _pumpFace(tester, OrtizMood.idle, followPointer: false);
      final center = tester.getCenter(find.byType(OrtizFace));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: center);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center + const Offset(200, 0));
      await tester.pump();
      expect(tester.state<OrtizFaceState>(find.byType(OrtizFace)).debugFollow,
          Offset.zero);
    });

    testWidgets('el tacto no mueve la mirada', (tester) async {
      await _pumpFace(tester, OrtizMood.idle);
      final center = tester.getCenter(find.byType(OrtizFace));
      final finger = await tester.startGesture(center);
      await finger.moveTo(center + const Offset(200, 0));
      await finger.up();
      await tester.pump();
      expect(tester.state<OrtizFaceState>(find.byType(OrtizFace)).debugFollow,
          Offset.zero);
    });
  });
}
