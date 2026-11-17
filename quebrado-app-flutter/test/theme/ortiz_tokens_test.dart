import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('OrtizPalette — contraste (CA-04)', () {
    const fondos = {
      'bg': OrtizPalette.bg,
      'surface': OrtizPalette.surface,
      'surfaceHigh': OrtizPalette.surfaceHigh,
    };
    const textos = {'fg': OrtizPalette.fg, 'muted': OrtizPalette.muted};

    for (final texto in textos.entries) {
      for (final fondo in fondos.entries) {
        test('${texto.key} sobre ${fondo.key} llega a 4,5:1', () {
          expect(contraste(texto.value, fondo.value),
              greaterThanOrEqualTo(4.5));
        });
      }
    }

    test('onAccent sobre accent llega a 4,5:1', () {
      expect(contraste(OrtizPalette.onAccent, OrtizPalette.accent),
          greaterThanOrEqualTo(4.5));
    });

    test('ingreso y gasto son los colores de estado ok y bad (PA-02)', () {
      expect(OrtizPalette.income, OrtizPalette.ok);
      expect(OrtizPalette.expense, OrtizPalette.bad);
    });
  });

  group('OrtizTokens', () {
    // Extremo distinto de `dark` en todos los campos.
    const otro = OrtizTokens(
      bg: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFE),
      surfaceHigh: Color(0xFFFFFFFD),
      line: Color(0xFFFFFFFC),
      fg: Color(0xFF000000),
      muted: Color(0xFF000001),
      faint: Color(0xFF000002),
      accent: Color(0xFF000003),
      onAccent: Color(0xFF000004),
      ok: Color(0xFF000005),
      warn: Color(0xFF000006),
      bad: Color(0xFF000007),
      income: Color(0xFF000008),
      expense: Color(0xFF000009),
    );

    List<int> valores(OrtizTokens t) => [
          t.bg, t.surface, t.surfaceHigh, t.line, t.fg, t.muted, t.faint,
          t.accent, t.onAccent, t.ok, t.warn, t.bad, t.income, t.expense,
        ].map((c) => c.toARGB32()).toList();

    test('dark toma cada valor de OrtizPalette', () {
      expect(
        valores(OrtizTokens.dark),
        [
          OrtizPalette.bg, OrtizPalette.surface, OrtizPalette.surfaceHigh,
          OrtizPalette.line, OrtizPalette.fg, OrtizPalette.muted,
          OrtizPalette.faint, OrtizPalette.accent, OrtizPalette.onAccent,
          OrtizPalette.ok, OrtizPalette.warn, OrtizPalette.bad,
          OrtizPalette.income, OrtizPalette.expense,
        ].map((c) => c.toARGB32()).toList(),
      );
    });

    test('lerp en t=0 devuelve el origen y en t=1 el destino', () {
      expect(valores(OrtizTokens.dark.lerp(otro, 0)),
          valores(OrtizTokens.dark));
      expect(valores(OrtizTokens.dark.lerp(otro, 1)), valores(otro));
    });

    test('lerp en t=0,5 mezcla los extremos', () {
      final medio = OrtizTokens.dark.lerp(otro, 0.5);
      expect(medio.bg.toARGB32(),
          Color.lerp(OrtizPalette.bg, otro.bg, 0.5)!.toARGB32());
    });

    test('lerp con otra extensión nula devuelve los mismos tokens', () {
      expect(identical(OrtizTokens.dark.lerp(null, 0.5), OrtizTokens.dark),
          isTrue);
    });

    test('copyWith cambia solo los campos pedidos', () {
      const nuevo = Color(0xFF123456);
      final copia = OrtizTokens.dark.copyWith(accent: nuevo, line: nuevo);
      final esperado = valores(OrtizTokens.dark);
      esperado[3] = nuevo.toARGB32(); // line
      esperado[7] = nuevo.toARGB32(); // accent
      expect(valores(copia), esperado);
    });

    test('copyWith sin argumentos conserva todos los valores', () {
      expect(valores(OrtizTokens.dark.copyWith()), valores(OrtizTokens.dark));
    });

    testWidgets('of(context) devuelve dark si el tema no tiene la extensión',
        (tester) async {
      late OrtizTokens leidos;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(),
        home: Builder(builder: (context) {
          leidos = OrtizTokens.of(context);
          return const SizedBox();
        }),
      ));
      expect(identical(leidos, OrtizTokens.dark), isTrue);
    });

    testWidgets('of(context) devuelve la extensión registrada en el tema',
        (tester) async {
      late OrtizTokens leidos;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [otro]),
        home: Builder(builder: (context) {
          leidos = OrtizTokens.of(context);
          return const SizedBox();
        }),
      ));
      expect(valores(leidos), valores(otro));
    });
  });

  group('OrtizPalette — tonos derivados de estado', () {
    int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;
    int alpha(Color c) => c.toARGB32() >> 24;

    test('accent, warn y bad salen de su entero ARGB', () {
      expect(OrtizPalette.accent.toARGB32(), OrtizPalette.accentArgb);
      expect(OrtizPalette.accentArgb, 0xFFFF8466);
      expect(OrtizPalette.warn.toARGB32(), OrtizPalette.warnArgb);
      expect(OrtizPalette.bad.toARGB32(), OrtizPalette.badArgb);
    });

    test('accentTint, warnTint, warnBorder y badTint conservan el RGB del token',
        () {
      expect(rgb(OrtizPalette.accentTint), rgb(OrtizPalette.accent));
      expect(rgb(OrtizPalette.warnTint), rgb(OrtizPalette.warn));
      expect(rgb(OrtizPalette.warnBorder), rgb(OrtizPalette.warn));
      expect(rgb(OrtizPalette.badTint), rgb(OrtizPalette.bad));
    });

    test('usan los mismos alphas que los tonos de las apps', () {
      expect(alpha(OrtizPalette.accentTint), SuiteAppColors.tintAlpha);
      expect(alpha(OrtizPalette.warnTint), SuiteAppColors.tintAlpha);
      expect(alpha(OrtizPalette.badTint), SuiteAppColors.tintAlpha);
      expect(alpha(OrtizPalette.warnBorder), SuiteAppColors.borderAlpha);
    });
  });
}
