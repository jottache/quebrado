import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

void main() {
  // Verdes de marca del tema viejo: no deben quedar en los colores de la app.
  const verdesViejos = <Color>[
    Color(0xFF1F6F5F),
    Color(0xFF2FA084),
    Color(0xFF6FCF97),
    Color(0xFF5F8575), // ingreso viejo (salvia)
  ];

  // Colores de tema de AppColors. Quedan fuera `bookColor` y `creationColors`:
  // son datos que la persona elige, no colores de la app.
  final coloresDeTema = <String, Color>{
    'primary': AppColors.primary,
    'secondary': AppColors.secondary,
    'accent': AppColors.accent,
    'background': AppColors.background,
    'cardBackground': AppColors.cardBackground,
    'cardText': AppColors.cardText,
    'cardSubtitleText': AppColors.cardSubtitleText,
    'cardBorderColor': AppColors.cardBorderColor,
    'cardBorder': AppColors.cardBorder,
    'alternateCard': AppColors.getAlternateCardColor(1),
    'mainTabActiveBg': AppColors.mainTabActiveBg,
    'mainTabActiveText': AppColors.mainTabActiveText,
    'mainTabInactiveText': AppColors.mainTabInactiveText,
    'mainTabTrackBg': AppColors.mainTabTrackBg,
    'nestedTabTrackBg': AppColors.nestedTabTrackBg,
    'nestedTabActiveBg': AppColors.nestedTabActiveBg,
    'nestedTabActiveText': AppColors.nestedTabActiveText,
    'nestedTabInactiveText': AppColors.nestedTabInactiveText,
    'dialogBg': AppColors.dialogBg,
    'income': AppColors.income,
    'expense': AppColors.expense,
  };

  group('AppColors lee los tokens', () {
    test('primary es el acento de la suite', () {
      expect(AppColors.primary, OrtizPalette.accent);
    });

    test('background es el fondo de la suite', () {
      expect(AppColors.background, OrtizPalette.bg);
    });

    test('las tarjetas y diálogos usan superficie, texto y línea', () {
      expect(AppColors.cardBackground, OrtizPalette.surface);
      expect(AppColors.cardText, OrtizPalette.fg);
      expect(AppColors.cardSubtitleText, OrtizPalette.muted);
      expect(AppColors.cardBorderColor, OrtizPalette.line);
      expect(AppColors.dialogBg, OrtizPalette.surface);
    });

    test('las pestañas activas usan acento y las inactivas muted', () {
      expect(AppColors.mainTabActiveBg, OrtizPalette.accent);
      expect(AppColors.mainTabActiveText, OrtizPalette.onAccent);
      expect(AppColors.mainTabInactiveText, OrtizPalette.muted);
      expect(AppColors.mainTabTrackBg, OrtizPalette.surfaceHigh);
      expect(AppColors.nestedTabActiveText, OrtizPalette.onAccent);
      expect(AppColors.nestedTabInactiveText, OrtizPalette.muted);
      expect(AppColors.nestedTabTrackBg, OrtizPalette.surfaceHigh);
    });

    test('ingreso y gasto son los tokens de dinero', () {
      expect(AppColors.income, OrtizPalette.income);
      expect(AppColors.expense, OrtizPalette.expense);
    });

    test('ningún color de tema es uno de los verdes viejos', () {
      for (final entrada in coloresDeTema.entries) {
        expect(
          verdesViejos,
          isNot(contains(entrada.value)),
          reason: '${entrada.key} sigue siendo un verde viejo',
        );
      }
    });
  });

  group('updateThemeColor (PA-01)', () {
    late Color bookColorInicial;

    setUp(() => bookColorInicial = AppColors.bookColor);
    tearDown(() => AppColors.updateThemeColor(bookColorInicial));

    test('guarda el color del libro en bookColor', () {
      const colorLibro = Color(0xFF3B6B7B);

      AppColors.updateThemeColor(colorLibro);

      expect(AppColors.bookColor, colorLibro);
    });

    test('no cambia primary, secondary ni accent', () {
      AppColors.updateThemeColor(const Color(0xFF1F6F5F));

      expect(AppColors.primary, OrtizPalette.accent);
      expect(AppColors.secondary, OrtizPalette.accent);
      expect(AppColors.accent, OrtizPalette.income);
      expect(AppColors.mainTabActiveBg, OrtizPalette.accent);
    });
  });

  group('creationColors (paleta para lo que se crea desde ahora)', () {
    final hexValido = RegExp(r'^#[0-9A-F]{6}$');
    Color desdeHex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));

    test('tiene 8 colores distintos con formato #RRGGBB', () {
      expect(AppColors.creationColors, hasLength(8));
      expect(AppColors.creationColors.toSet(), hasLength(8));
      for (final h in AppColors.creationColors) {
        expect(h, matches(hexValido));
      }
    });

    test('los por defecto son el coral [0] y el dorado de Finanzas [1]', () {
      expect(AppColors.creationColors[0], '#FF8466');
      expect(AppColors.creationColors[1], '#E7C06A');
    });

    test('ya no ofrece los verdes viejos', () {
      for (final h in AppColors.creationColors) {
        expect(verdesViejos, isNot(contains(desdeHex(h))), reason: h);
      }
    });

    test('todos se distinguen del fondo (≥ 3:1 sobre bg)', () {
      final lbg = OrtizPalette.bg.computeLuminance();
      for (final h in AppColors.creationColors) {
        final l = desdeHex(h).computeLuminance();
        expect((l + 0.05) / (lbg + 0.05), greaterThanOrEqualTo(3), reason: h);
      }
    });
  });
}
