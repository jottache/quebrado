import 'package:flutter/material.dart';

/// Minimalist, unified color palette for Diario Jottache
/// Anchored on the super app's single primary color (0xFF1F6F5F).
/// Uses compile-time const colors so they can be safely evaluated in const widgets.
class DiarioColors {
  // Single Unified Primary Color (Matching AppColors.primary)
  static const Color primary = Color(0xFF1F6F5F);
  static const Color primaryDark = Color(0xFF154C41);
  static const Color primaryLight = Color(0xFFE8F3F0); // Subtle 8% primary wash
  static Color get primaryGlow => primary.withOpacity(0.18);

  // Secondary & Accents map cleanly to the single primary shade
  static const Color accent = primary;
  static const Color secondary = Color(0xFF2FA084);
  static const Color secondaryLight = Color(0xFFE8F3F0);

  // Neutral Backgrounds & Surfaces (Minimalist & Clean)
  static const Color background = Color(0xFFF9FAFB); // Neutral Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceHover = Color(0xFFF3F4F6); // Slate 100
  static const Color cardBorder = Color(0xFFE5E7EB); // Slate 200

  // Semantic Colors (Neutralized to preserve single-color minimalism)
  static const Color amber = primary;
  static const Color amberLight = Color(0xFFF3F4F6);

  static const Color emerald = primary;
  static const Color emeraldLight = Color(0xFFE8F3F0);

  // Only red for destructive actions (e.g. Delete)
  static const Color rose = Color(0xFFDC2626);
  static const Color roseLight = Color(0xFFFEE2E2);

  static const Color purple = primary;
  static const Color purpleLight = Color(0xFFE8F3F0);

  static const Color blue = primary;
  static const Color blueLight = Color(0xFFE8F3F0);

  static const Color cyan = primary;
  static const Color cyanLight = Color(0xFFE8F3F0);

  // Typography
  static const Color textPrimary = Color(0xFF111827); // Dark Slate
  static const Color textSecondary = Color(0xFF4B5563); // Muted Slate
  static const Color textMuted = Color(0xFF9CA3AF); // Light Slate

  // Minimalist Unified Avatar Palette
  static const Color avatarBackground = Color(0xFFE8F3F0);
  static const Color avatarText = primary;

  static Color getAvatarColor(String seed) {
    return primary;
  }
}
