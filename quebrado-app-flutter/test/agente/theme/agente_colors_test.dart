import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/theme/agente_colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

const List<int> coloresViejos = [
  0xFF6366F1, // índigo
  0xFF4F46E5, // índigo oscuro
  0xFFEEF2FF, // índigo claro
  0xFF1F6F5F, // verde viejo
];

void main() {
  const todos = <String, Color>{
    'primary': AgenteColors.primary,
    'primaryLight': AgenteColors.primaryLight,
    'primaryDark': AgenteColors.primaryDark,
    'background': AgenteColors.background,
    'surface': AgenteColors.surface,
    'cardBorder': AgenteColors.cardBorder,
    'userBubble': AgenteColors.userBubble,
    'userText': AgenteColors.userText,
    'botBubble': AgenteColors.botBubble,
    'botText': AgenteColors.botText,
    'artifactBg': AgenteColors.artifactBg,
    'artifactBorder': AgenteColors.artifactBorder,
    'artifactHeader': AgenteColors.artifactHeader,
    'thinking': AgenteColors.thinking,
    'toolExec': AgenteColors.toolExec,
    'success': AgenteColors.success,
    'error': AgenteColors.error,
  };

  group('AgenteColors — identidad de Ortiz (CA-03)', () {
    test('el primario es el acento de la suite', () {
      expect(AgenteColors.primary, OrtizPalette.accent);
      expect(AgenteColors.primaryDark, OrtizPalette.accent);
      expect(AgenteColors.primaryLight, OrtizPalette.accentTint);
    });

    test('los neutrales y las burbujas salen de los tokens', () {
      expect(AgenteColors.background, OrtizPalette.bg);
      expect(AgenteColors.surface, OrtizPalette.surface);
      expect(AgenteColors.cardBorder, OrtizPalette.line);
      expect(AgenteColors.userBubble, OrtizPalette.surfaceHigh);
      expect(AgenteColors.userText, OrtizPalette.fg);
      expect(AgenteColors.botBubble, OrtizPalette.surface);
      expect(AgenteColors.botText, OrtizPalette.fg);
      expect(AgenteColors.artifactBg, OrtizPalette.surface);
      expect(AgenteColors.artifactBorder, OrtizPalette.line);
      expect(AgenteColors.artifactHeader, OrtizPalette.fg);
    });

    test('éxito y error usan los tokens ok y bad', () {
      expect(AgenteColors.success, OrtizPalette.ok);
      expect(AgenteColors.error, OrtizPalette.bad);
    });

    test('ningún color es el índigo ni el verde viejos', () {
      todos.forEach((nombre, color) {
        expect(coloresViejos, isNot(contains(color.toARGB32())),
            reason: '$nombre conserva un color del tema anterior');
      });
    });
  });

  group('AgenteColors — contraste', () {
    test('los colores usados como texto tienen contraste ≥ 4,5:1 sobre bg', () {
      const texto = <String, Color>{
        'primary': AgenteColors.primary,
        'primaryDark': AgenteColors.primaryDark,
        'userText': AgenteColors.userText,
        'botText': AgenteColors.botText,
        'artifactHeader': AgenteColors.artifactHeader,
        'thinking': AgenteColors.thinking,
        'toolExec': AgenteColors.toolExec,
        'success': AgenteColors.success,
        'error': AgenteColors.error,
      };
      texto.forEach((nombre, color) {
        expect(contraste(color, OrtizPalette.bg), greaterThanOrEqualTo(4.5),
            reason: '$nombre no es legible sobre bg');
      });
    });

    test('el texto de cada burbuja es legible sobre su fondo', () {
      expect(contraste(AgenteColors.userText, AgenteColors.userBubble),
          greaterThanOrEqualTo(4.5));
      expect(contraste(AgenteColors.botText, AgenteColors.botBubble),
          greaterThanOrEqualTo(4.5));
    });

    // `primaryLight` es translúcido: se mide ya compuesto sobre cada fondo
    // en que se pinta.
    for (final fondo in const {
      'bg': OrtizPalette.bg,
      'surface': OrtizPalette.surface,
      'surfaceHigh': OrtizPalette.surfaceHigh,
    }.entries) {
      test('primaryDark y fg se leen sobre primaryLight compuesto en '
          '${fondo.key}', () {
        final lavado = Color.alphaBlend(AgenteColors.primaryLight, fondo.value);
        expect(contraste(AgenteColors.primaryDark, lavado),
            greaterThanOrEqualTo(4.5));
        expect(contraste(OrtizPalette.fg, lavado), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
