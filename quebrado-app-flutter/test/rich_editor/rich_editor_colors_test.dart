import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/rich_editor/rich_editor_colors.dart';
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
  // `accent` es mutable y global: cada test lo deja como lo encontró.
  late Color accentOriginal;
  setUp(() => accentOriginal = RichEditorColors.accent);
  tearDown(() => RichEditorColors.accent = accentOriginal);

  group('RichEditorColors — identidad (CA-03)', () {
    test('el acento por defecto es el de la suite', () {
      expect(RichEditorColors.accent, OrtizPalette.accent);
    });

    test('accentLight sigue al acento fijado por la app con el alpha de tinte',
        () {
      RichEditorColors.accent = SuiteAppColors.diario;
      expect(rgb(RichEditorColors.accentLight), rgb(SuiteAppColors.diario));
      expect(alpha(RichEditorColors.accentLight), SuiteAppColors.tintAlpha);
    });

    test('los neutrales salen de los tokens', () {
      expect(RichEditorColors.textPrimary, OrtizPalette.fg);
      expect(RichEditorColors.textSecondary, OrtizPalette.muted);
      expect(RichEditorColors.textMuted, OrtizPalette.muted);
      expect(RichEditorColors.border, OrtizPalette.line);
      expect(RichEditorColors.icon, OrtizPalette.fg);
    });

    test('el destacado usa el token warn con fondo lavado y borde medio', () {
      expect(rgb(RichEditorColors.calloutBg), rgb(OrtizPalette.warn));
      expect(rgb(RichEditorColors.calloutBorder), rgb(OrtizPalette.warn));
      expect(alpha(RichEditorColors.calloutBg), SuiteAppColors.tintAlpha);
      expect(alpha(RichEditorColors.calloutBorder), SuiteAppColors.borderAlpha);
    });

    test('ningún color es el índigo ni el verde viejos', () {
      final todos = <String, Color>{
        'accent': RichEditorColors.accent,
        'accentLight': RichEditorColors.accentLight,
        'textPrimary': RichEditorColors.textPrimary,
        'textSecondary': RichEditorColors.textSecondary,
        'textMuted': RichEditorColors.textMuted,
        'border': RichEditorColors.border,
        'calloutBg': RichEditorColors.calloutBg,
        'calloutBorder': RichEditorColors.calloutBorder,
        'icon': RichEditorColors.icon,
      };
      todos.forEach((nombre, color) {
        expect(coloresViejos, isNot(contains(color.toARGB32())),
            reason: '$nombre conserva un color del tema anterior');
      });
    });
  });

  test('los colores usados como texto o icono tienen contraste ≥ 4,5:1 sobre bg',
      () {
    final texto = <String, Color>{
      'accent': RichEditorColors.accent,
      'textPrimary': RichEditorColors.textPrimary,
      'textSecondary': RichEditorColors.textSecondary,
      'textMuted': RichEditorColors.textMuted,
      'icon': RichEditorColors.icon,
    };
    texto.forEach((nombre, color) {
      expect(contraste(color, OrtizPalette.bg), greaterThanOrEqualTo(4.5),
          reason: '$nombre no es legible sobre bg');
    });
  });
}
