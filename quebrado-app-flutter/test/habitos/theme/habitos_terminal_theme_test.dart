import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/habitos/theme/habitos_terminal_theme.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

const verdesViejos = <int>[0xFF1F6F5F, 0xFF154C41, 0xFFE8F3F0, 0xFF2FA084];

int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;

void main() {
  group('HabitosColors — primario (CA-03)', () {
    test('el primario y sus variantes salen de SuiteAppColors.habitos', () {
      expect(HabitosColors.primary, SuiteAppColors.habitos);
      expect(HabitosColors.primaryDark, SuiteAppColors.habitos);
      expect(HabitosColors.primaryLight, SuiteAppColors.habitosTint);
      expect(HabitosColors.primaryBorder, SuiteAppColors.habitosBorder);
    });

    test('los alias de primario siguen apuntando al primario', () {
      expect(HabitosColors.green, HabitosColors.primary);
      expect(HabitosColors.cyan, HabitosColors.primary);
      expect(HabitosColors.borderActive, HabitosColors.primary);
      expect(HabitosColors.textGreen, HabitosColors.primary);
      expect(HabitosColors.dimGreen, HabitosColors.primaryLight);
    });
  });

  group('HabitosColors — neutrales', () {
    test('fondos, superficies, bordes y texto leen OrtizPalette', () {
      expect(HabitosColors.background, OrtizPalette.bg);
      expect(HabitosColors.surface, OrtizPalette.surface);
      expect(HabitosColors.windowBackground, OrtizPalette.surface);
      expect(HabitosColors.cardBackground, OrtizPalette.surface);
      expect(HabitosColors.surfaceHover, OrtizPalette.surfaceHigh);
      expect(HabitosColors.cardBorder, OrtizPalette.line);
      expect(HabitosColors.borderMuted, OrtizPalette.line);
      expect(HabitosColors.borderSubtle, OrtizPalette.line);
      expect(HabitosColors.textPrimary, OrtizPalette.fg);
      expect(HabitosColors.textLight, OrtizPalette.fg);
      expect(HabitosColors.textSecondary, OrtizPalette.muted);
      expect(HabitosColors.textMuted, OrtizPalette.muted);
    });
  });

  group('HabitosColors — estados', () {
    test('rachas usan warn y recaídas usan bad', () {
      expect(HabitosColors.amber, OrtizPalette.warn);
      expect(HabitosColors.textAmber, OrtizPalette.warn);
      expect(HabitosColors.rose, OrtizPalette.bad);
      expect(HabitosColors.red, OrtizPalette.bad);
    });

    test('los fondos lavados son su estado con alpha de tinte', () {
      expect(rgb(HabitosColors.amberLight), rgb(OrtizPalette.warn));
      expect(rgb(HabitosColors.roseLight), rgb(OrtizPalette.bad));
      expect(HabitosColors.amberLight.toARGB32() >>> 24,
          SuiteAppColors.tintAlpha);
      expect(HabitosColors.roseLight.toARGB32() >>> 24,
          SuiteAppColors.tintAlpha);
    });

    test('ámbar y rojo se leen sobre el fondo (≥ 4,5:1)', () {
      for (final c in [HabitosColors.amber, HabitosColors.rose]) {
        expect(contraste(c, OrtizPalette.bg), greaterThanOrEqualTo(4.5));
      }
    });
  });

  test('ningún color es uno de los verdes viejos', () {
    final todos = <Color>[
      HabitosColors.primary,
      HabitosColors.primaryDark,
      HabitosColors.primaryLight,
      HabitosColors.primaryBorder,
      HabitosColors.background,
      HabitosColors.surface,
      HabitosColors.surfaceHover,
      HabitosColors.cardBorder,
      HabitosColors.textPrimary,
      HabitosColors.textSecondary,
      HabitosColors.textMuted,
      HabitosColors.amber,
      HabitosColors.amberLight,
      HabitosColors.rose,
      HabitosColors.roseLight,
      HabitosColors.green,
      HabitosColors.red,
      HabitosColors.cyan,
      HabitosColors.dimGreen,
      HabitosColors.borderMuted,
      HabitosColors.borderSubtle,
      HabitosColors.borderActive,
      HabitosColors.windowBackground,
      HabitosColors.cardBackground,
      HabitosColors.textLight,
      HabitosColors.textGreen,
      HabitosColors.textAmber,
    ];
    for (final c in todos) {
      expect(verdesViejos, isNot(contains(c.toARGB32())),
          reason: 'color 0x${c.toARGB32().toRadixString(16)}');
    }
  });

  group('HabitosStyles', () {
    test('los estilos por defecto usan los colores del tema oscuro', () {
      expect(HabitosStyles.title().color, OrtizPalette.fg);
      expect(HabitosStyles.body().color, OrtizPalette.fg);
      expect(HabitosStyles.caption().color, OrtizPalette.muted);
      expect(HabitosStyles.badge().color, SuiteAppColors.habitos);
      expect(HabitosStyles.prompt().color, SuiteAppColors.habitos);
    });
  });
}
