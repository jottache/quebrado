import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/notas/theme/notas_colors.dart';
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

int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;
int alpha(Color c) => c.toARGB32() >>> 24;

const List<int> coloresViejos = [
  0xFF6366F1, // índigo
  0xFF4F46E5, // índigo oscuro
  0xFFEEF2FF, // índigo claro
  0xFF1F6F5F, // verde viejo
];

void main() {
  const todos = <String, Color>{
    'primary': NotasColors.primary,
    'primaryLight': NotasColors.primaryLight,
    'primaryDark': NotasColors.primaryDark,
    'acuerdosPink': NotasColors.acuerdosPink,
    'acuerdosPinkLight': NotasColors.acuerdosPinkLight,
    'ideasAmber': NotasColors.ideasAmber,
    'ideasAmberLight': NotasColors.ideasAmberLight,
    'datosGreen': NotasColors.datosGreen,
    'datosGreenLight': NotasColors.datosGreenLight,
    'background': NotasColors.background,
    'cardSurface': NotasColors.cardSurface,
    'cardBorder': NotasColors.cardBorder,
    'surfaceHover': NotasColors.surfaceHover,
    'textPrimary': NotasColors.textPrimary,
    'textSecondary': NotasColors.textSecondary,
    'textMuted': NotasColors.textMuted,
    'calloutInfoBg': NotasColors.calloutInfoBg,
    'calloutInfoBorder': NotasColors.calloutInfoBorder,
    'calloutWarnBg': NotasColors.calloutWarnBg,
    'calloutWarnBorder': NotasColors.calloutWarnBorder,
    'calloutPinkBg': NotasColors.calloutPinkBg,
    'calloutPinkBorder': NotasColors.calloutPinkBorder,
  };

  group('NotasColors — identidad (CA-03)', () {
    test('el primario y sus variantes salen del color de la app Notas', () {
      expect(NotasColors.primary, SuiteAppColors.notas);
      expect(NotasColors.primaryLight, SuiteAppColors.notasTint);
      expect(NotasColors.primaryDark, SuiteAppColors.notas);
    });

    test('los neutrales salen de los tokens', () {
      expect(NotasColors.background, OrtizPalette.bg);
      expect(NotasColors.cardSurface, OrtizPalette.surface);
      expect(NotasColors.cardBorder, OrtizPalette.line);
      expect(NotasColors.surfaceHover, OrtizPalette.surfaceHigh);
      expect(NotasColors.textPrimary, OrtizPalette.fg);
      expect(NotasColors.textSecondary, OrtizPalette.muted);
      expect(NotasColors.textMuted, OrtizPalette.muted);
    });

    test('ningún color es el índigo ni el verde viejos', () {
      todos.forEach((nombre, color) {
        expect(coloresViejos, isNot(contains(color.toARGB32())),
            reason: '$nombre conserva un color del tema anterior');
      });
    });
  });

  group('NotasColors — derivados lavados', () {
    test('los fondos de categoría son su color con el alpha de tinte', () {
      const pares = [
        (NotasColors.acuerdosPink, NotasColors.acuerdosPinkLight),
        (NotasColors.ideasAmber, NotasColors.ideasAmberLight),
        (NotasColors.datosGreen, NotasColors.datosGreenLight),
      ];
      for (final (base, lavado) in pares) {
        expect(rgb(lavado), rgb(base));
        expect(alpha(lavado), SuiteAppColors.tintAlpha);
      }
    });

    test('el callout de aviso usa el token warn sin desviarse', () {
      expect(rgb(NotasColors.calloutWarnBg), rgb(OrtizPalette.warn));
      expect(rgb(NotasColors.calloutWarnBorder), rgb(OrtizPalette.warn));
    });

    test('los callouts tienen fondo de alpha bajo y borde de alpha medio', () {
      for (final bg in [
        NotasColors.calloutInfoBg,
        NotasColors.calloutWarnBg,
        NotasColors.calloutPinkBg,
      ]) {
        expect(alpha(bg), SuiteAppColors.tintAlpha);
      }
      for (final borde in [
        NotasColors.calloutInfoBorder,
        NotasColors.calloutWarnBorder,
        NotasColors.calloutPinkBorder,
      ]) {
        expect(alpha(borde), SuiteAppColors.borderAlpha);
      }
      expect(rgb(NotasColors.calloutInfoBorder), rgb(NotasColors.datosGreen));
      expect(rgb(NotasColors.calloutPinkBorder), rgb(NotasColors.acuerdosPink));
    });
  });

  group('NotasColors — contraste sobre bg', () {
    const texto = <String, Color>{
      'primary': NotasColors.primary,
      'primaryDark': NotasColors.primaryDark,
      'acuerdosPink': NotasColors.acuerdosPink,
      'ideasAmber': NotasColors.ideasAmber,
      'datosGreen': NotasColors.datosGreen,
      'textPrimary': NotasColors.textPrimary,
      'textSecondary': NotasColors.textSecondary,
      'textMuted': NotasColors.textMuted,
    };

    test('los colores usados como texto tienen contraste ≥ 4,5:1', () {
      texto.forEach((nombre, color) {
        expect(contraste(color, OrtizPalette.bg), greaterThanOrEqualTo(4.5),
            reason: '$nombre no es legible sobre bg');
      });
    });
  });
}
