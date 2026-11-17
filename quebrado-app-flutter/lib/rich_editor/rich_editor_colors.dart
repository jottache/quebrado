import 'package:flutter/material.dart';

/// Colores del editor enriquecido. [accent] lo fija cada app al abrir el editor
/// (Notas: índigo, Diario: verde). Es estático porque las barras flotantes se
/// dibujan en el Overlay raíz, fuera del árbol del editor.
class RichEditorColors {
  RichEditorColors._();

  static Color accent = const Color(0xFF6366F1);
  static Color get accentLight => Color.alphaBlend(accent.withValues(alpha: 0.10), Colors.white);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color calloutBg = Color(0xFFFFFBEB);
  static const Color calloutBorder = Color(0xFFFDE68A);
  static const Color icon = Color(0xFF37352F);
}
