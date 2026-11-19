import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

/// Familias de la sección `flutter: fonts:` del pubspec: familia → {peso → asset}.
///
/// Lector mínimo de texto (sin depender de `package:yaml`): solo entiende el
/// formato `- family:` / `- asset:` / `weight:` que usa este pubspec.
Map<String, Map<int, String>> fuentesDelPubspec() {
  final lineas = File('pubspec.yaml').readAsLinesSync();
  final inicio = lineas.indexWhere((l) => l == '  fonts:');
  if (inicio == -1) throw StateError('falta flutter: fonts: en pubspec.yaml');

  // (familia, asset, peso); el peso por defecto de Flutter es 400.
  final entradas = <(String, String, int)>[];
  String? familia;
  for (final linea in lineas.skip(inicio + 1)) {
    final t = linea.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    // Fin de la sección: otra clave con 2 espacios o menos de sangría.
    if (!linea.startsWith('   ')) break;
    if (t.startsWith('- family:')) {
      familia = t.substring('- family:'.length).trim();
    } else if (t.startsWith('- asset:')) {
      entradas.add((familia!, t.substring('- asset:'.length).trim(), 400));
    } else if (t.startsWith('weight:')) {
      final (f, a, _) = entradas.removeLast();
      entradas.add((f, a, int.parse(t.substring('weight:'.length).trim())));
    }
  }
  final familias = <String, Map<int, String>>{};
  for (final (f, a, peso) in entradas) {
    (familias[f] ??= {})[peso] = a;
  }
  return familias;
}

void main() {
  group('OrtizFontSize', () {
    test('coincide con los tamaños de los estilos de OrtizType', () {
      expect(OrtizFontSize.caption, OrtizType.caption.fontSize);
      expect(OrtizFontSize.bodySm, OrtizType.bodySm.fontSize);
      expect(OrtizFontSize.body, OrtizType.body.fontSize);
      expect(OrtizFontSize.titleSm, OrtizType.titleSm.fontSize);
      expect(OrtizFontSize.title, OrtizType.title.fontSize);
      expect(OrtizFontSize.display, OrtizType.display.fontSize);
      expect(OrtizFontSize.displayLg, OrtizType.displayLg.fontSize);
    });

    test('la escala va en orden creciente y sin repetidos', () {
      final s = OrtizFontSize.scale;
      for (var i = 1; i < s.length; i++) {
        expect(s[i], greaterThan(s[i - 1]));
      }
    });
  });

  group('OrtizType — escala (C2)', () {
    final escala = <String, (TextStyle, String, double)>{
      'caption': (OrtizType.caption, OrtizType.fontBody, 11),
      'bodySm': (OrtizType.bodySm, OrtizType.fontBody, 12),
      'body': (OrtizType.body, OrtizType.fontBody, 14),
      'titleSm': (OrtizType.titleSm, OrtizType.fontBody, 16),
      'title': (OrtizType.title, OrtizType.fontDisplay, 18),
      'display': (OrtizType.display, OrtizType.fontDisplay, 24),
      'displayLg': (OrtizType.displayLg, OrtizType.fontDisplay, 32),
      'amount': (OrtizType.amount, OrtizType.fontMono, 14),
      'amountLg': (OrtizType.amountLg, OrtizType.fontMono, 24),
    };

    for (final e in escala.entries) {
      final (estilo, familia, tamano) = e.value;
      test('${e.key} usa $familia a $tamano px y no fija color', () {
        expect(estilo.fontFamily, familia);
        expect(estilo.fontSize, tamano);
        expect(estilo.fontWeight, isNotNull);
        expect(estilo.color, isNull);
      });
    }

    test('los títulos en Bricolage tienen interletrado negativo', () {
      for (final s in [OrtizType.title, OrtizType.display, OrtizType.displayLg]) {
        expect(s.letterSpacing, lessThan(0));
        expect(s.height, inInclusiveRange(1.05, 1.25));
      }
    });

    test('los montos usan cifras tabulares', () {
      for (final s in [OrtizType.amount, OrtizType.amountLg]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });

    test('el TextTheme de Material 3 no tiene slots nulos y usa la escala', () {
      const t = OrtizType.textTheme;
      final slots = [
        t.displayLarge, t.displayMedium, t.displaySmall,
        t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall,
        t.bodyLarge, t.bodyMedium, t.bodySmall,
        t.labelLarge, t.labelMedium, t.labelSmall,
      ];
      for (final s in slots) {
        expect(s, isNotNull);
        expect(s!.fontFamily, isNotNull);
      }
      expect(t.bodyMedium, OrtizType.body);
      expect(t.titleLarge, OrtizType.title);
      expect(t.displayLarge, OrtizType.displayLg);
    });
  });

  group('OrtizType — fuentes empaquetadas (CA-05)', () {
    final fuentes = fuentesDelPubspec();

    test('las familias del pubspec son exactamente las de OrtizType', () {
      expect(fuentes.keys.toSet(), {
        OrtizType.fontDisplay,
        OrtizType.fontBody,
        OrtizType.fontMono,
      });
    });

    test('cada peso usado por la escala está declarado para su familia', () {
      const estilos = [
        OrtizType.caption, OrtizType.bodySm, OrtizType.body,
        OrtizType.titleSm, OrtizType.title, OrtizType.display,
        OrtizType.displayLg, OrtizType.amount, OrtizType.amountLg,
      ];
      final usados = [
        ...estilos,
        ...[
          OrtizType.textTheme.titleSmall,
          OrtizType.textTheme.bodyLarge,
          OrtizType.textTheme.labelLarge,
          OrtizType.textTheme.labelMedium,
        ].nonNulls,
      ];
      for (final s in usados) {
        expect(
          fuentes[s.fontFamily]!.keys,
          contains(s.fontWeight!.value),
          reason: '${s.fontFamily} ${s.fontWeight} no está en pubspec.yaml',
        );
      }
    });

    test('cada archivo listado existe y es un TrueType', () {
      final assets = fuentes.values.expand((m) => m.values).toList();
      expect(assets, hasLength(8));
      for (final ruta in assets) {
        final archivo = File(ruta);
        expect(archivo.existsSync(), isTrue, reason: 'falta $ruta');
        final cabecera = archivo.openSync()..setPositionSync(0);
        final bytes = cabecera.readSync(4);
        cabecera.closeSync();
        expect(bytes, [0x00, 0x01, 0x00, 0x00], reason: '$ruta no es TTF');
      }
    });

    test('cada familia lleva su licencia OFL junto a sus archivos', () {
      for (final m in fuentes.values) {
        final dir = File(m.values.first).parent.path;
        final ofl = File('$dir/OFL.txt');
        expect(ofl.existsSync(), isTrue, reason: 'falta $dir/OFL.txt');
        expect(ofl.readAsStringSync(), contains('SIL Open Font License'));
      }
    });
  });
}
