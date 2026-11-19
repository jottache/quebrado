import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/recordatorios/theme/reminders_colors.dart';
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
  group('RemindersColors — primario (CA-03)', () {
    test('el primario y sus variantes salen de SuiteAppColors.recordatorios',
        () {
      expect(RemindersColors.primary, SuiteAppColors.recordatorios);
      expect(RemindersColors.primaryDark, SuiteAppColors.recordatorios);
      expect(RemindersColors.primaryLight, SuiteAppColors.recordatoriosTint);
      expect(RemindersColors.primaryBorder, SuiteAppColors.recordatoriosBorder);
    });
  });

  group('RemindersColors — neutrales', () {
    test('fondos, superficies, bordes y texto leen OrtizPalette', () {
      expect(RemindersColors.background, OrtizPalette.bg);
      expect(RemindersColors.cardSurface, OrtizPalette.surface);
      expect(RemindersColors.cardBorder, OrtizPalette.line);
      expect(RemindersColors.textPrimary, OrtizPalette.fg);
      expect(RemindersColors.textSecondary, OrtizPalette.muted);
      expect(RemindersColors.textMuted, OrtizPalette.muted);
    });
  });

  group('RemindersColors — prioridades y estados', () {
    test('usan el token cuando el significado coincide', () {
      expect(RemindersColors.urgent, OrtizPalette.bad);
      expect(RemindersColors.high, OrtizPalette.warn);
      expect(RemindersColors.medium, SuiteAppColors.recordatorios);
      expect(RemindersColors.low, OrtizPalette.muted);
      expect(RemindersColors.overdue, OrtizPalette.bad);
      expect(RemindersColors.snoozed, OrtizPalette.warn);
      expect(RemindersColors.completed, OrtizPalette.ok);
    });

    test('P1–P4 se distinguen entre sí', () {
      final prioridades = {
        RemindersColors.urgent,
        RemindersColors.high,
        RemindersColors.medium,
        RemindersColors.low,
      };
      expect(prioridades, hasLength(4));
    });

    test('prioridades y estados se leen sobre el fondo (≥ 4,5:1)', () {
      final usadosComoTexto = {
        'urgent': RemindersColors.urgent,
        'high': RemindersColors.high,
        'medium': RemindersColors.medium,
        'low': RemindersColors.low,
        'overdue': RemindersColors.overdue,
        'snoozed': RemindersColors.snoozed,
        'completed': RemindersColors.completed,
      };
      usadosComoTexto.forEach((nombre, color) {
        expect(contraste(color, OrtizPalette.bg), greaterThanOrEqualTo(4.5),
            reason: nombre);
      });
    });
  });

  test('ningún color es uno de los verdes viejos', () {
    final todos = <Color>[
      RemindersColors.primary,
      RemindersColors.primaryLight,
      RemindersColors.primaryDark,
      RemindersColors.primaryBorder,
      RemindersColors.background,
      RemindersColors.cardSurface,
      RemindersColors.cardBorder,
      RemindersColors.textPrimary,
      RemindersColors.textSecondary,
      RemindersColors.textMuted,
      RemindersColors.urgent,
      RemindersColors.high,
      RemindersColors.medium,
      RemindersColors.low,
      RemindersColors.overdue,
      RemindersColors.snoozed,
      RemindersColors.completed,
    ];
    for (final c in todos) {
      expect(verdesViejos, isNot(contains(c.toARGB32())),
          reason: 'color 0x${c.toARGB32().toRadixString(16)}');
    }
  });
}
