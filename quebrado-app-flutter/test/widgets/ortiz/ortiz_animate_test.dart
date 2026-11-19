import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_animate.dart';

import '../../helpers/pump_app.dart';

Widget _lista({required bool reducir, int desde = 0}) => Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reducir),
        child: Builder(
          builder: (context) => Column(
            children: [
              for (var i = desde; i < desde + 3; i++) ortizStaggered(context, i, Text('Fila $i')),
            ],
          ),
        ),
      ),
    );

/// Avanza el reloj en cuadros de 10 ms, como una app real.
Future<void> _avanzar(WidgetTester tester, Duration total) async {
  const paso = Duration(milliseconds: 10);
  for (var t = Duration.zero; t < total; t += paso) {
    await tester.pump(paso);
  }
}

/// Opacidad actual del fundido de entrada del texto [texto].
double _opacidad(WidgetTester tester, String texto) {
  final fade = tester.widget<FadeTransition>(
    find.ancestor(of: find.text(texto), matching: find.byType(FadeTransition)).first,
  );
  return fade.opacity.value;
}

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('las filas entran y quedan visibles en ${window.name}', (tester) async {
      await pumpApp(tester, _lista(reducir: false), window: window);
      expect(tester.takeException(), isNull);
      expect(find.byType(OrtizStaggeredEntry), findsNWidgets(3));
      expect(_opacidad(tester, 'Fila 2'), 1);
    });
  }

  testWidgets('con reducir movimiento devuelve el hijo sin animar', (tester) async {
    await pumpApp(tester, _lista(reducir: true), settle: false);
    expect(find.byType(OrtizStaggeredEntry), findsNothing);
    expect(find.text('Fila 0'), findsOneWidget);
  });

  testWidgets('el retraso crece con el índice y se detiene en staggerMaxIndex', (tester) async {
    final max = OrtizMotion.staggerMaxIndex;
    // Filas con índices max-1, max y max+1: retrasos (max-1)·s, max·s y max·s.
    await pumpApp(tester, _lista(reducir: false, desde: max - 1), settle: false);
    // Medio paso después del retraso de la primera: ya empezó; las otras dos no.
    await _avanzar(tester, OrtizMotion.stagger * (max - 1) + OrtizMotion.stagger ~/ 2);
    expect(_opacidad(tester, 'Fila ${max - 1}'), greaterThan(0));
    expect(_opacidad(tester, 'Fila $max'), 0);
    expect(_opacidad(tester, 'Fila ${max + 1}'), 0);
    // Pasado el retraso tope: las dos últimas avanzan igual (mismo retraso).
    await _avanzar(tester, OrtizMotion.stagger);
    expect(_opacidad(tester, 'Fila $max'), greaterThan(0));
    expect(_opacidad(tester, 'Fila ${max + 1}'), _opacidad(tester, 'Fila $max'));
    await tester.pumpAndSettle();
    expect(_opacidad(tester, 'Fila ${max + 1}'), 1);
  });

  testWidgets('la extensión hace lo mismo que la función', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => const Text('Hola').ortizStaggered(context, 2)),
      settle: false,
    );
    // Retraso de índice 2: invisible justo antes, visible al final.
    await _avanzar(tester, OrtizMotion.stagger * 2 - const Duration(milliseconds: 10));
    expect(_opacidad(tester, 'Hola'), 0);
    await tester.pumpAndSettle();
    expect(_opacidad(tester, 'Hola'), 1);
    expect(tester.widget<OrtizStaggeredEntry>(find.byType(OrtizStaggeredEntry)).delay,
        OrtizMotion.stagger * 2);
  });

  testWidgets('montar y desmontar sin avanzar el reloj no deja Timers pendientes', (tester) async {
    // Antes (con flutter_animate) cualquier entrada dejaba un `Future.delayed`
    // vivo y el test fallaba con «A Timer is still pending…».
    await pumpApp(tester, _lista(reducir: false, desde: 5), settle: false);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(OrtizStaggeredEntry), findsNothing);
  });
}
