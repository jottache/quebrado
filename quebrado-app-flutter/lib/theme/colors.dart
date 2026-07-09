import 'package:flutter/material.dart';

class AppColors {
  // --- USER PALETTE CONFIGURATION ---
  // Modify these hex codes to test new color palettes.
  static const Color primary = Color(0xFF1F6F5F);       // Dark teal-green (First bar)
  static const Color secondary = Color(0xFF2FA084);     // Medium teal-green (Second bar)
  static const Color accent = Color(0xFF6FCF97);        // Light green (Third bar)
  static const Color background = Color(0xFFEEEEEE);    // Very light grey (Fourth bar)

  // --- GLOBAL CARD STYLING ---
  static const Color cardBackground = Colors.white;
  static const Color cardText = Colors.black87;
  static const Color cardSubtitleText = Colors.black54;
  static const Color cardBorderColor = Color(0xFFE0E0E0); // Light grey border color
  static const double cardBorderWidth = 1.0; // 1.0 px border width

  // Dynamic helper for alternating card colors
  static Color getAlternateCardColor(int index) {
    // To restore alternating colors, change this to:
    // return index % 3 == 0 ? primary : (index % 3 == 1 ? secondary : accent);
    return cardBackground;
  }

  // --- TABS STYLING ---
  // Main tabs (outside cards)
  static const Color mainTabActiveBg = primary;
  static const Color mainTabActiveText = Colors.white;
  static const Color mainTabInactiveText = Colors.black54;
  static const Color mainTabTrackBg = Color(0x0D000000); // Colors.black.withOpacity(0.05)
  
  // Nested tabs (inside cards)
  static const Color nestedTabTrackBg = Color(0x0D000000); // Colors.black.withOpacity(0.05)
  static const Color nestedTabActiveBg = secondary;
  static const Color nestedTabActiveText = Colors.white;
  static const Color nestedTabInactiveText = Colors.black54;

  // --- DERIVED UI COLORS ---
  static Color get cardBorder => cardBorderColor;
  static Color get dialogBg => background;
  
  // Semantic Colors
  static const Color income = Color(0xFF5F8575);        // Sage green for incomes (positive)
  static const Color expense = Color(0xFFC84E4E);       // Red/coral for expenses (negative)

  // Centralized colors for pockets and subscriptions creation
  static const List<String> creationColors = [
    "#1F6F5F", // primary (Dark teal-green)
    "#2FA084", // secondary (Medium teal-green)
    "#6FCF97", // accent (Light green)
    "#5F8575", // income (Sage green)
    "#3B6B7B", // Slate/Steel blue
    "#7C8B64", // Olive
    "#D4A373", // Sand
    "#C84E4E", // expense (Red/coral)
  ];
}
