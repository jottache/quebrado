// Escala tipográfica de la suite OrtizApp (spec 01, decisión C2).
//
// - Títulos (18 px o más): Bricolage Grotesque 600/700, interletrado negativo.
// - Texto: Manrope 400–700.
// - Montos y cifras: JetBrains Mono con cifras tabulares (columnas alineadas).
//
// Las fuentes vienen empaquetadas en `assets/fonts/` y declaradas en
// `pubspec.yaml` con estos mismos nombres de familia (CA-05: sin descarga en
// tiempo de ejecución). Los estilos no llevan color: lo pone el tema.
import 'package:flutter/material.dart';

/// Tamaños de la escala tipográfica como números `const`, para los
/// `TextStyle(fontSize: …)` que no parten de un estilo de [OrtizType]
/// (spec 05: ningún tamaño de letra suelto en pantallas).
abstract final class OrtizFontSize {
  /// Solo para vistas muy densas (celdas de calendario, badges diminutos).
  /// Por debajo del mínimo legible recomendado: no usarlo en texto corrido.
  static const double micro = 9;
  static const double caption = 11;
  static const double bodySm = 12;
  static const double body = 14;
  static const double titleSm = 16;
  static const double title = 18;
  static const double display = 24;
  static const double displayLg = 32;

  /// La escala completa, de menor a mayor.
  static const List<double> scale = [
    micro, caption, bodySm, body, titleSm, title, display, displayLg, //
  ];
}

/// Familias y estilos con nombre de la escala. Todo valor es `const`.
abstract final class OrtizType {
  // Familias (deben coincidir con `family:` en pubspec.yaml). Llevan prefijo
  // `font` porque `body` y `display` son nombres de la escala.
  static const String fontDisplay = 'Bricolage';
  static const String fontBody = 'Manrope';
  static const String fontMono = 'JetBrainsMono';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Texto (Manrope).
  static const TextStyle caption = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle titleSm = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Títulos (Bricolage).
  static const TextStyle title = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );
  static const TextStyle display = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.4,
  );
  static const TextStyle displayLg = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.6,
  );

  // Montos (JetBrains Mono, cifras tabulares).
  static const TextStyle amount = TextStyle(
    fontFamily: fontMono,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFeatures: _tabular,
  );
  static const TextStyle amountLg = TextStyle(
    fontFamily: fontMono,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  // Variantes de peso solo para los slots de Material (tamaños de la escala).
  static const TextStyle _bodyLg = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _label = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle _labelSm = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Escala aplicada a los 15 slots de Material 3 (para el `ThemeData` del
  /// paso 3). `titleLarge` es el título del AppBar; `bodyMedium`, el texto por
  /// defecto de `Text`; `bodyLarge`, el de los campos; `labelLarge`, el de los
  /// botones.
  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLg,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: display,
    headlineMedium: title,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: titleSm,
    titleSmall: _label,
    bodyLarge: _bodyLg,
    bodyMedium: body,
    bodySmall: bodySm,
    labelLarge: _label,
    labelMedium: _labelSm,
    labelSmall: caption,
  );
}
