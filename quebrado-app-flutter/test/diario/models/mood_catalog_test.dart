import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/mood_catalog.dart';

void main() {
  group('MoodCatalog — valencia', () {
    test('hay una entrada por cada valor de -2 a 2, en orden', () {
      expect(MoodCatalog.valences.map((v) => v.value), [-2, -1, 0, 1, 2]);
    });

    test('valenceMeta acota los valores fuera de rango', () {
      expect(MoodCatalog.valenceMeta(-9).value, -2);
      expect(MoodCatalog.valenceMeta(9).value, 2);
      expect(MoodCatalog.valenceMeta(1).label, 'Bien');
    });

    test('lightColor es el mismo color con alpha 0,16', () {
      for (final v in MoodCatalog.valences) {
        expect(v.lightColor.toARGB32() & 0x00FFFFFF, v.color.toARGB32() & 0x00FFFFFF);
        expect(v.lightColor.a, closeTo(0.16, 0.01));
      }
    });

    test('colorForAverage usa el color exacto en enteros e interpola entre ellos', () {
      expect(MoodCatalog.colorForAverage(1), MoodCatalog.valenceMeta(1).color);
      final medio = MoodCatalog.colorForAverage(0.5);
      expect(medio, isNot(MoodCatalog.valenceMeta(0).color));
      expect(medio, isNot(MoodCatalog.valenceMeta(1).color));
      // Fuera de rango se acota.
      expect(MoodCatalog.colorForAverage(7), MoodCatalog.valenceMeta(2).color);
    });

    test('metaForAverage redondea al valor más cercano', () {
      expect(MoodCatalog.metaForAverage(0.6).value, 1);
      expect(MoodCatalog.metaForAverage(-1.4).value, -1);
    });
  });

  group('MoodCatalog — energía', () {
    test('energyLabel acota a 1..5', () {
      expect(MoodCatalog.energyLabel(0), 'Agotado');
      expect(MoodCatalog.energyLabel(3), 'Media');
      expect(MoodCatalog.energyLabel(99), 'A tope');
    });
  });

  group('MoodCatalog — emociones', () {
    test('las claves son únicas y se encuentran por clave', () {
      final keys = MoodCatalog.emotions.map((e) => e.key).toList();
      expect(keys.toSet().length, keys.length);
      expect(MoodCatalog.emotionByKey('alegre')?.label, 'Alegre');
      expect(MoodCatalog.emotionByKey('no_existe'), isNull);
      expect(MoodCatalog.emotionLabel('no_existe'), 'no_existe');
    });

    test('cada cuadrante tiene 8 emociones y la emoción toma el color del cuadrante', () {
      for (final q in MoodQuadrant.values) {
        final es = MoodCatalog.emotionsIn(q);
        expect(es, hasLength(8));
        for (final e in es) {
          expect(e.color, q.color);
        }
      }
    });

    test('con valencia positiva y energía alta, el primer cuadrante es alto y agradable', () {
      final ordered = MoodCatalog.orderedQuadrants(valence: 2, energy: 5);
      expect(ordered.first, MoodQuadrant.highPleasant);
      expect(ordered, hasLength(MoodQuadrant.values.length));
    });

    test('los sugeridos filtran por valencia y energía', () {
      expect(MoodCatalog.suggestedQuadrants(valence: -1, energy: 1), [MoodQuadrant.lowUnpleasant]);
      expect(MoodCatalog.suggestedQuadrants(valence: 1).every((q) => q.isPleasant), isTrue);
      expect(MoodCatalog.suggestedQuadrants(valence: 0), hasLength(4));
    });
  });
}
