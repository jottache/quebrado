import 'package:flutter/material.dart';
import '../models/mood_catalog.dart';
import '../theme/diario_colors.dart';

/// Selector de emociones agrupadas por cuadrante (energía × agrado).
/// Muestra primero los cuadrantes que encajan con la valencia/energía y el resto en "Ver todas".
class MoodEmotionPicker extends StatefulWidget {
  final int valence;
  final int? energy;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MoodEmotionPicker({
    super.key,
    required this.valence,
    this.energy,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<MoodEmotionPicker> createState() => _MoodEmotionPickerState();
}

class _MoodEmotionPickerState extends State<MoodEmotionPicker> {
  bool _showAll = false;

  void _toggle(String key) {
    final current = List<String>.from(widget.selected);
    if (current.contains(key)) {
      current.remove(key);
    } else {
      if (current.length >= MoodCatalog.maxEmotionsPerLog) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Puedes elegir hasta 3 emociones.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      current.add(key);
    }
    widget.onChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    final suggested = MoodCatalog.suggestedQuadrants(valence: widget.valence, energy: widget.energy);
    final others = MoodQuadrant.values.where((q) => !suggested.contains(q)).toList();
    // Si alguna emoción elegida está en un cuadrante oculto, mostrarlo.
    final hasHiddenSelection = widget.selected.any((k) {
      final e = MoodCatalog.emotionByKey(k);
      return e != null && others.contains(e.quadrant);
    });
    final visible = [...suggested, if (_showAll || hasHiddenSelection) ...others];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final quadrant in visible) _buildQuadrant(quadrant),
        if (others.isNotEmpty && !hasHiddenSelection)
          TextButton.icon(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: TextButton.styleFrom(foregroundColor: DiarioColors.primary),
            icon: Icon(_showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
            label: Text(
              _showAll ? 'Ver menos' : 'Ver todas las emociones',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildQuadrant(MoodQuadrant quadrant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: quadrant.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                quadrant.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DiarioColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MoodCatalog.emotionsIn(quadrant).map((emotion) {
              final isSelected = widget.selected.contains(emotion.key);
              return FilterChip(
                label: Text(emotion.label),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) => _toggle(emotion.key),
                selectedColor: emotion.color,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : DiarioColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? emotion.color : emotion.color.withOpacity(0.35)),
                ),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
