import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/pin_verification_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/services/pin_attempt_limiter.dart';

// Auditoría spec 02, A6 y A8: límite de 5 intentos con 30 s de espera, y el
// título lo decide quien abre el diálogo.
void main() {
  late DateTime now;
  late PinAttemptLimiter limiter;

  setUp(() {
    now = DateTime(2026, 11, 18, 10);
    limiter = PinAttemptLimiter(clock: () => now);
  });

  Future<List<bool?>> abrir(WidgetTester tester) async {
    final resultados = <bool?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultados.add(await showDialog<bool>(
            context: context,
            builder: (_) => PinVerificationDialog(
              correctPin: '2580',
              title: 'Desbloquear',
              limiter: limiter,
            ),
          )),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resultados;
  }

  Future<void> teclear(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('muestra el título que recibe', (tester) async {
    await abrir(tester);

    expect(find.text('Desbloquear'), findsOneWidget);
  });

  testWidgets('un PIN incorrecto dice cuántos intentos quedan', (tester) async {
    await abrir(tester);

    await teclear(tester, '1111');

    expect(find.text('PIN incorrecto. Te quedan 4 intentos.'), findsOneWidget);
  });

  testWidgets('tras 5 fallos bloquea el teclado 30 s y luego deja intentarlo', (tester) async {
    final resultados = await abrir(tester);

    for (var i = 0; i < 5; i++) {
      await teclear(tester, '1111');
    }
    expect(find.text('Demasiados intentos. Espera 30 s.'), findsOneWidget);

    // Durante la espera el teclado no responde, ni con el PIN correcto.
    await teclear(tester, '2580');
    expect(resultados, isEmpty);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Demasiados intentos'), findsNothing);

    await teclear(tester, '2580');
    await tester.pumpAndSettle();
    expect(resultados, [true]);
  });

  testWidgets('cerrar y abrir el diálogo no reinicia la espera', (tester) async {
    await abrir(tester);
    for (var i = 0; i < 5; i++) {
      await teclear(tester, '1111');
    }
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pump();

    expect(find.textContaining('Demasiados intentos'), findsOneWidget);

    // Cierra para no dejar el Timer de la cuenta atrás vivo.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
