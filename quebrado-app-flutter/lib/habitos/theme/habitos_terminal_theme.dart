import 'package:flutter/material.dart';

/// Tema y Tokens de Diseño Minimalista para Hábitos (OrtizApp)
/// Anclado en el único color primario de la suite (#1F6F5F).
class HabitosColors {
  // Color Primario Unificado
  static const Color primary = Color(0xFF1F6F5F);
  static const Color primaryDark = Color(0xFF154C41);
  static const Color primaryLight = Color(0xFFE8F3F0); // Tinte primario suave 8%
  static const Color primaryBorder = Color(0x331F6F5F); // 20% opacidad

  // Fondos y Superficies Limpias (Light Minimalist)
  static const Color background = Color(0xFFF9FAFB); // Neutral Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceHover = Color(0xFFF3F4F6); // Slate 100
  static const Color cardBorder = Color(0xFFE5E7EB); // Slate 200

  // Tipografía y Jerarquía Neutral
  static const Color textPrimary = Color(0xFF111827); // Dark Slate 900
  static const Color textSecondary = Color(0xFF4B5563); // Muted Slate 600
  static const Color textMuted = Color(0xFF9CA3AF); // Light Slate 400

  // Acentos de Soporte Minimalistas
  static const Color amber = Color(0xFFD97706); // Ámbar cálido sobrio (Rachas)
  static const Color amberLight = Color(0xFFFEF3C7); // Fondo ámbar 100
  static const Color rose = Color(0xFFDC2626); // Rojo sobrio (Recaídas / Borrar)
  static const Color roseLight = Color(0xFFFEE2E2); // Fondo rojo 100

  // Aliases ergonómicos / retrocompatibles
  static const Color green = primary;
  static const Color red = rose;
  static const Color cyan = primary;
  static const Color dimGreen = primaryLight;
  static const Color borderMuted = cardBorder;
  static const Color borderSubtle = cardBorder;
  static const Color borderActive = primary;
  static const Color windowBackground = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color textLight = textPrimary;
  static const Color textGreen = primary;
  static const Color textAmber = amber;
}

class HabitosStyles {
  /// Tipografía limpia y moderna estándar
  static TextStyle title({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w800,
    Color color = HabitosColors.textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
      height: 1.2,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle badge({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
    Color color = HabitosColors.primary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  // Compatibilidad
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = HabitosColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle prompt({double fontSize = 13}) => badge(fontSize: fontSize);
  static TextStyle heading({double fontSize = 16}) => title(fontSize: fontSize);
  static TextStyle dim({double fontSize = 11}) => caption(fontSize: fontSize);
}
