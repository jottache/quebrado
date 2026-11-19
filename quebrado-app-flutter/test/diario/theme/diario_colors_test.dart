import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/theme/diario_colors.dart';
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

void main() {
  group('DiarioColors — primario (CA-02, CA-03)', () {
    test('el primario y sus variantes salen de SuiteAppColors.diario', () {
      expect(DiarioColors.primary, SuiteAppColors.diario);
      expect(DiarioColors.primary, const Color(SuiteAppColors.diarioArgb));
      expect(DiarioColors.primaryDark, SuiteAppColors.diario);
      expect(DiarioColors.primaryLight, SuiteAppColors.diarioTint);
      expect(DiarioColors.primaryBorder, SuiteAppColors.diarioBorder);
    });

    test('los alias de acento siguen apuntando al primario', () {
      for (final c in [
        DiarioColors.accent,
        DiarioColors.secondary,
        DiarioColors.amber,
        DiarioColors.emerald,
        DiarioColors.purple,
        DiarioColors.blue,
        DiarioColors.cyan,
        DiarioColors.avatarText,
        DiarioColors.getAvatarColor('ana'),
      ]) {
        expect(c, DiarioColors.primary);
      }
      for (final c in [
        DiarioColors.secondaryLight,
        DiarioColors.emeraldLight,
        DiarioColors.purpleLight,
        DiarioColors.blueLight,
        DiarioColors.cyanLight,
        DiarioColors.avatarBackground,
      ]) {
        expect(c, SuiteAppColors.diarioTint);
      }
    });

    test('primaryGlow es el primario con alpha 0,18', () {
      expect(DiarioColors.primaryGlow.toARGB32() & 0x00FFFFFF,
          SuiteAppColors.diarioArgb & 0x00FFFFFF);
      expect(DiarioColors.primaryGlow.a, closeTo(0.18, 0.01));
    });
  });

  group('DiarioColors — neutrales', () {
    test('fondos, superficies, bordes y texto leen OrtizPalette', () {
      expect(DiarioColors.background, OrtizPalette.bg);
      expect(DiarioColors.surface, OrtizPalette.surface);
      expect(DiarioColors.surfaceHover, OrtizPalette.surfaceHigh);
      expect(DiarioColors.amberLight, OrtizPalette.surfaceHigh);
      expect(DiarioColors.cardBorder, OrtizPalette.line);
      expect(DiarioColors.textPrimary, OrtizPalette.fg);
      expect(DiarioColors.textSecondary, OrtizPalette.muted);
      expect(DiarioColors.textMuted, OrtizPalette.muted);
    });
  });

  group('DiarioColors — destructivo', () {
    test('rose es el token bad y roseLight es bad con alpha de tinte', () {
      expect(DiarioColors.rose, OrtizPalette.bad);
      expect(DiarioColors.roseLight.toARGB32() & 0x00FFFFFF,
          OrtizPalette.bad.toARGB32() & 0x00FFFFFF);
      expect(DiarioColors.roseLight.toARGB32() >>> 24, SuiteAppColors.tintAlpha);
    });

    test('rose se lee sobre el fondo (≥ 4,5:1)', () {
      expect(contraste(DiarioColors.rose, OrtizPalette.bg),
          greaterThanOrEqualTo(4.5));
    });
  });

  test('ningún color es uno de los verdes viejos', () {
    final todos = <Color>[
      DiarioColors.primary,
      DiarioColors.primaryDark,
      DiarioColors.primaryLight,
      DiarioColors.primaryBorder,
      DiarioColors.primaryGlow,
      DiarioColors.accent,
      DiarioColors.secondary,
      DiarioColors.secondaryLight,
      DiarioColors.background,
      DiarioColors.surface,
      DiarioColors.surfaceHover,
      DiarioColors.cardBorder,
      DiarioColors.amber,
      DiarioColors.amberLight,
      DiarioColors.emerald,
      DiarioColors.emeraldLight,
      DiarioColors.rose,
      DiarioColors.roseLight,
      DiarioColors.purple,
      DiarioColors.purpleLight,
      DiarioColors.blue,
      DiarioColors.blueLight,
      DiarioColors.cyan,
      DiarioColors.cyanLight,
      DiarioColors.textPrimary,
      DiarioColors.textSecondary,
      DiarioColors.textMuted,
      DiarioColors.avatarBackground,
      DiarioColors.avatarText,
    ];
    for (final c in todos) {
      expect(verdesViejos, isNot(contains(c.toARGB32())),
          reason: 'color 0x${c.toARGB32().toRadixString(16)}');
    }
  });
}
