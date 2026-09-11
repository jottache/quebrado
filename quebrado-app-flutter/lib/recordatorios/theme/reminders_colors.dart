import 'package:flutter/material.dart';

/// Paleta de diseño minimalista con un solo color primario para Recordatorios.
class RemindersColors {
  // Color primario unificado y sobrio (Slate Indigo)
  static const Color primary = Color(0xFF2E5B88);
  static const Color primaryLight = Color(0xFFEBF2F8);
  static const Color primaryDark = Color(0xFF1E3E5E);

  // Fondos y Superficies
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Textos y Contraste
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Acentos de Estado Sutiles
  static const Color urgent = Color(0xFFDC2626); // P1 urgente
  static const Color high = Color(0xFFEA580C);   // P2 alta
  static const Color medium = Color(0xFF2563EB); // P3 media
  static const Color low = Color(0xFF64748B);    // P4 baja

  static const Color overdue = Color(0xFFE11D48); // Vencido
  static const Color snoozed = Color(0xFFD97706); // Pospuesto
  static const Color completed = Color(0xFF059669); // Completado
}
