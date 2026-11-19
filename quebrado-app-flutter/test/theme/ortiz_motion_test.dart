import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';

/// Monta un contexto con `disableAnimations` y devuelve el `BuildContext`.
Future<BuildContext> contextoCon(WidgetTester tester, {required bool reducir}) async {
  late BuildContext capturado;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducir),
      child: Builder(builder: (c) {
        capturado = c;
        return const SizedBox();
      }),
    ),
  );
  return capturado;
}

void main() {
  test('las duraciones y la curva son las de la spec', () {
    expect(OrtizMotion.fast, const Duration(milliseconds: 180));
    expect(OrtizMotion.base, const Duration(milliseconds: 320));
    expect(OrtizMotion.slow, const Duration(milliseconds: 450));
    expect(OrtizMotion.stagger, const Duration(milliseconds: 60));
    expect(OrtizMotion.ease, const Cubic(0.2, 0.8, 0.2, 1));
  });

  test('scanMax es el tope de 1,5 s del escaneo de la spec 04 y deja ver la secuencia', () {
    expect(OrtizMotion.scanMax, const Duration(milliseconds: 1500));
    // 5 píldoras a `fast` + pausa `base` (U3 de resumen-del-dia.md) caben en el tope.
    expect(OrtizMotion.fast * 5 + OrtizMotion.base, lessThanOrEqualTo(OrtizMotion.scanMax));
  });

  testWidgets('con disableAnimations devuelve cero (CA-06)', (tester) async {
    final c = await contextoCon(tester, reducir: true);
    expect(OrtizMotion.reduced(c), isTrue);
    for (final d in [OrtizMotion.fast, OrtizMotion.base, OrtizMotion.slow]) {
      expect(OrtizMotion.of(c, d), Duration.zero);
    }
    expect(OrtizMotion.staggerOf(c, 3), Duration.zero);
  });

  testWidgets('sin disableAnimations devuelve la duración pedida', (tester) async {
    final c = await contextoCon(tester, reducir: false);
    expect(OrtizMotion.reduced(c), isFalse);
    expect(OrtizMotion.of(c, OrtizMotion.base), OrtizMotion.base);
    expect(OrtizMotion.staggerOf(c, 3), const Duration(milliseconds: 180));
  });
}
