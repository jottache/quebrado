import 'package:flutter/material.dart';

/// Catálogo fijo del módulo Ánimo: escala de valencia, energía y emociones.
/// Las claves (`key`) se guardan en Supabase, así que nunca deben cambiar.

// =============================================================================
// VALENCIA (-2 .. 2)
// =============================================================================
class MoodValenceMeta {
  final int value;
  final String emoji;
  final String label;
  final Color color;

  const MoodValenceMeta(this.value, this.emoji, this.label, this.color);

  Color get lightColor => color.withOpacity(0.16);
}

class MoodCatalog {
  MoodCatalog._();

  static const int minValence = -2;
  static const int maxValence = 2;
  static const int maxEmotionsPerLog = 3;

  static const List<MoodValenceMeta> valences = [
    MoodValenceMeta(-2, '😞', 'Muy mal', Color(0xFF7048E8)),
    MoodValenceMeta(-1, '😕', 'Mal', Color(0xFF4DABF7)),
    MoodValenceMeta(0, '😐', 'Normal', Color(0xFFADB5BD)),
    MoodValenceMeta(1, '🙂', 'Bien', Color(0xFF51CF66)),
    MoodValenceMeta(2, '😄', 'Excelente', Color(0xFFFCC419)),
  ];

  static MoodValenceMeta valenceMeta(int valence) {
    final clamped = valence.clamp(minValence, maxValence);
    return valences.firstWhere((v) => v.value == clamped);
  }

  /// Color interpolado para promedios (ej. 0.6 → entre Normal y Bien).
  static Color colorForAverage(double value) {
    final v = value.clamp(minValence.toDouble(), maxValence.toDouble());
    final lower = v.floor();
    final upper = v.ceil();
    if (lower == upper) return valenceMeta(lower).color;
    return Color.lerp(valenceMeta(lower).color, valenceMeta(upper).color, v - lower)!;
  }

  static MoodValenceMeta metaForAverage(double value) => valenceMeta(value.round());

  // ===========================================================================
  // ENERGÍA (1 .. 5)
  // ===========================================================================
  static const Map<int, String> energyLabels = {
    1: 'Agotado',
    2: 'Baja',
    3: 'Media',
    4: 'Alta',
    5: 'A tope',
  };

  static String energyLabel(int energy) => energyLabels[energy.clamp(1, 5)] ?? 'Media';

  // ===========================================================================
  // EMOCIONES (4 cuadrantes, modelo RULER / How We Feel)
  // ===========================================================================
  static const List<MoodEmotion> emotions = [
    // Alta energía · Agradable
    MoodEmotion('entusiasmado', 'Entusiasmado', MoodQuadrant.highPleasant),
    MoodEmotion('alegre', 'Alegre', MoodQuadrant.highPleasant),
    MoodEmotion('orgulloso', 'Orgulloso', MoodQuadrant.highPleasant),
    MoodEmotion('motivado', 'Motivado', MoodQuadrant.highPleasant),
    MoodEmotion('emocionado', 'Emocionado', MoodQuadrant.highPleasant),
    MoodEmotion('inspirado', 'Inspirado', MoodQuadrant.highPleasant),
    MoodEmotion('optimista', 'Optimista', MoodQuadrant.highPleasant),
    MoodEmotion('divertido', 'Divertido', MoodQuadrant.highPleasant),
    // Baja energía · Agradable
    MoodEmotion('tranquilo', 'Tranquilo', MoodQuadrant.lowPleasant),
    MoodEmotion('relajado', 'Relajado', MoodQuadrant.lowPleasant),
    MoodEmotion('agradecido', 'Agradecido', MoodQuadrant.lowPleasant),
    MoodEmotion('satisfecho', 'Satisfecho', MoodQuadrant.lowPleasant),
    MoodEmotion('en_paz', 'En paz', MoodQuadrant.lowPleasant),
    MoodEmotion('seguro', 'Seguro', MoodQuadrant.lowPleasant),
    MoodEmotion('comodo', 'Cómodo', MoodQuadrant.lowPleasant),
    MoodEmotion('esperanzado', 'Esperanzado', MoodQuadrant.lowPleasant),
    // Alta energía · Desagradable
    MoodEmotion('ansioso', 'Ansioso', MoodQuadrant.highUnpleasant),
    MoodEmotion('estresado', 'Estresado', MoodQuadrant.highUnpleasant),
    MoodEmotion('frustrado', 'Frustrado', MoodQuadrant.highUnpleasant),
    MoodEmotion('enojado', 'Enojado', MoodQuadrant.highUnpleasant),
    MoodEmotion('irritable', 'Irritable', MoodQuadrant.highUnpleasant),
    MoodEmotion('abrumado', 'Abrumado', MoodQuadrant.highUnpleasant),
    MoodEmotion('nervioso', 'Nervioso', MoodQuadrant.highUnpleasant),
    MoodEmotion('celoso', 'Celoso', MoodQuadrant.highUnpleasant),
    // Baja energía · Desagradable
    MoodEmotion('triste', 'Triste', MoodQuadrant.lowUnpleasant),
    MoodEmotion('cansado', 'Cansado', MoodQuadrant.lowUnpleasant),
    MoodEmotion('desanimado', 'Desanimado', MoodQuadrant.lowUnpleasant),
    MoodEmotion('solo', 'Solo', MoodQuadrant.lowUnpleasant),
    MoodEmotion('aburrido', 'Aburrido', MoodQuadrant.lowUnpleasant),
    MoodEmotion('decepcionado', 'Decepcionado', MoodQuadrant.lowUnpleasant),
    MoodEmotion('culpable', 'Culpable', MoodQuadrant.lowUnpleasant),
    MoodEmotion('agotado', 'Agotado', MoodQuadrant.lowUnpleasant),
  ];

  static final Map<String, MoodEmotion> _emotionsByKey = {
    for (final e in emotions) e.key: e,
  };

  static MoodEmotion? emotionByKey(String key) => _emotionsByKey[key];

  static String emotionLabel(String key) => _emotionsByKey[key]?.label ?? key;

  /// Cuadrantes ordenados según la valencia y la energía elegidas:
  /// primero los que "encajan", luego el resto.
  static List<MoodQuadrant> orderedQuadrants({required int valence, int? energy}) {
    final pleasantFirst = valence > 0;
    final unpleasantFirst = valence < 0;
    final highFirst = energy != null && energy >= 4;
    final lowFirst = energy != null && energy <= 2;

    int score(MoodQuadrant q) {
      var s = 0;
      if (pleasantFirst && q.isPleasant) s += 2;
      if (unpleasantFirst && !q.isPleasant) s += 2;
      if (highFirst && q.isHighEnergy) s += 1;
      if (lowFirst && !q.isHighEnergy) s += 1;
      return s;
    }

    final list = List<MoodQuadrant>.from(MoodQuadrant.values);
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  /// Cuadrantes sugeridos (los demás van en "Ver todas").
  static List<MoodQuadrant> suggestedQuadrants({required int valence, int? energy}) {
    return orderedQuadrants(valence: valence, energy: energy).where((q) {
      if (valence > 0 && !q.isPleasant) return false;
      if (valence < 0 && q.isPleasant) return false;
      if (energy != null && energy >= 4 && !q.isHighEnergy) return false;
      if (energy != null && energy <= 2 && q.isHighEnergy) return false;
      return true;
    }).toList();
  }

  static List<MoodEmotion> emotionsIn(MoodQuadrant quadrant) =>
      emotions.where((e) => e.quadrant == quadrant).toList();
}

enum MoodQuadrant {
  highPleasant('Energía alta · Agradable', Color(0xFFF59F00), true, true),
  lowPleasant('Energía baja · Agradable', Color(0xFF2F9E44), true, false),
  highUnpleasant('Energía alta · Desagradable', Color(0xFFE03131), false, true),
  lowUnpleasant('Energía baja · Desagradable', Color(0xFF1C7ED6), false, false);

  final String label;
  final Color color;
  final bool isPleasant;
  final bool isHighEnergy;

  const MoodQuadrant(this.label, this.color, this.isPleasant, this.isHighEnergy);
}

class MoodEmotion {
  final String key;
  final String label;
  final MoodQuadrant quadrant;

  const MoodEmotion(this.key, this.label, this.quadrant);

  Color get color => quadrant.color;
}
