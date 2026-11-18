import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/recordatorios/models/covey_quadrant.dart';
import 'package:quebrado_app_flutter/recordatorios/theme/reminders_colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('CoveyQuadrant — colores', () {
    test('cada cuadrante toma su constante con nombre de RemindersColors', () {
      expect(CoveyQuadrant.q1UrgentImportant.color,
          RemindersColors.quadrantUrgentImportant);
      expect(CoveyQuadrant.q2ImportantNotUrgent.color,
          RemindersColors.quadrantImportantNotUrgent);
      expect(CoveyQuadrant.q3UrgentNotImportant.color,
          RemindersColors.quadrantUrgentNotImportant);
      expect(CoveyQuadrant.q4NotUrgentNotImportant.color,
          RemindersColors.quadrantNotUrgentNotImportant);
    });

    test('los cuatro cuadrantes se distinguen entre sí', () {
      final colores = CoveyQuadrant.values.map((q) => q.color).toSet();
      expect(colores, hasLength(CoveyQuadrant.values.length));
    });

    test('el color de cada cuadrante se lee como texto sobre el fondo (≥ 4,5:1)',
        () {
      for (final q in CoveyQuadrant.values) {
        expect(_contraste(q.color, OrtizPalette.bg), greaterThanOrEqualTo(4.5),
            reason: q.code);
      }
    });

    test('el fondo suave y el borde conservan el tono y bajan la opacidad', () {
      for (final q in CoveyQuadrant.values) {
        final base = q.color.toARGB32() & 0x00FFFFFF;
        expect(q.lightBackgroundColor.toARGB32() & 0x00FFFFFF, base,
            reason: q.code);
        expect(q.borderColor.toARGB32() & 0x00FFFFFF, base, reason: q.code);
        expect(q.lightBackgroundColor.a, lessThan(q.borderColor.a),
            reason: q.code);
        expect(q.borderColor.a, lessThan(1.0), reason: q.code);
      }
    });
  });

  group('CoveyQuadrant.fromString', () {
    test('reconoce códigos y palabras clave', () {
      expect(CoveyQuadrant.fromString('q1_urgent_important'),
          CoveyQuadrant.q1UrgentImportant);
      expect(CoveyQuadrant.fromString('C3'), CoveyQuadrant.q3UrgentNotImportant);
      expect(CoveyQuadrant.fromString('escape'),
          CoveyQuadrant.q4NotUrgentNotImportant);
    });

    test('devuelve el cuadrante II si el valor es nulo o desconocido', () {
      expect(CoveyQuadrant.fromString(null), CoveyQuadrant.q2ImportantNotUrgent);
      expect(CoveyQuadrant.fromString('xyz'), CoveyQuadrant.q2ImportantNotUrgent);
    });

    test('el código de cada cuadrante vuelve al mismo cuadrante', () {
      for (final q in CoveyQuadrant.values) {
        expect(CoveyQuadrant.fromCode(q.code), q);
      }
    });
  });
}
