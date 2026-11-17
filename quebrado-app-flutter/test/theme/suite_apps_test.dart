import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;
int alpha(Color c) => c.toARGB32() >> 24;

void main() {
  // Única fuente de color de cada app (base de CA-02).
  const argbPorApp = {
    SuiteApp.finanzas: SuiteAppColors.finanzasArgb,
    SuiteApp.diario: SuiteAppColors.diarioArgb,
    SuiteApp.habitos: SuiteAppColors.habitosArgb,
    SuiteApp.recordatorios: SuiteAppColors.recordatoriosArgb,
    SuiteApp.notas: SuiteAppColors.notasArgb,
  };

  test('hay un ARGB por cada app de la suite', () {
    expect(argbPorApp.keys.toSet(), SuiteApp.values.toSet());
  });

  test('los colores de app son los decididos en PA-03', () {
    expect(SuiteApp.finanzas.color.toARGB32(), 0xFFE7C06A);
    expect(SuiteApp.diario.color.toARGB32(), 0xFFEE8FA6);
    expect(SuiteApp.habitos.color.toARGB32(), 0xFF6FC3DF);
    expect(SuiteApp.recordatorios.color.toARGB32(), 0xFFA99BFF);
    expect(SuiteApp.notas.color.toARGB32(), 0xFFE9D8A6);
  });

  test('los derivados se pueden usar como constantes de compilación', () {
    // Si algún tono deja de ser const, este archivo no compila.
    const tonos = <Color>[
      SuiteAppColors.diario,
      SuiteAppColors.diarioTint,
      SuiteAppColors.diarioBorder,
      SuiteAppColors.finanzasTint,
      SuiteAppColors.habitosBorder,
      SuiteAppColors.recordatoriosTint,
      SuiteAppColors.notasBorder,
    ];
    expect(tonos, hasLength(7));
  });

  for (final app in SuiteApp.values) {
    group('SuiteApp.${app.name}', () {
      test('color sale de su ARGB único y es opaco', () {
        expect(app.color.toARGB32(), argbPorApp[app]);
        expect(alpha(app.color), 0xFF);
      });

      test('tint tiene el RGB de color y alpha de tinte', () {
        expect(rgb(app.tint), rgb(app.color));
        expect(alpha(app.tint), SuiteAppColors.tintAlpha);
      });

      test('border tiene el RGB de color y alpha de borde', () {
        expect(rgb(app.border), rgb(app.color));
        expect(alpha(app.border), SuiteAppColors.borderAlpha);
      });

      test('tiene nombre visible', () {
        expect(app.label.trim(), isNotEmpty);
      });
    });
  }

  test('los alphas derivados son ≈ 16 % y ≈ 45 %', () {
    expect(SuiteAppColors.tintAlpha, 0x29);
    expect(SuiteAppColors.borderAlpha, 0x73);
  });

  test('las rutas son únicas y empiezan por /', () {
    final rutas = SuiteApp.values.map((a) => a.route).toList();
    expect(rutas.toSet(), hasLength(rutas.length));
    expect(rutas.every((r) => r.startsWith('/')), isTrue);
  });

  test('los nombres visibles van en español', () {
    expect(SuiteApp.values.map((a) => a.label).toList(),
        ['Finanzas', 'Diario', 'Hábitos', 'Recordatorios', 'Notas']);
  });
}
