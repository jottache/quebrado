// Movimiento de la suite OrtizApp (spec 01): duraciones, curva y escalonado.
//
// Toda animación nueva pide su duración con `OrtizMotion.of(context, …)`, que
// devuelve cero cuando el sistema pide reducir el movimiento (CA-06).
import 'package:flutter/widgets.dart';

/// Duraciones y curva comunes. Los valores son `const`; los helpers respetan
/// `MediaQuery.disableAnimations`.
abstract final class OrtizMotion {
  static const Duration fast = Duration(milliseconds: 180); // hover, toggles
  static const Duration base = Duration(milliseconds: 320); // entradas, hojas
  static const Duration slow = Duration(milliseconds: 450); // transiciones grandes
  static const Duration stagger = Duration(milliseconds: 60); // entre elementos
  static const Duration celebrate = Duration(milliseconds: 1800); // Ortiz «happy» tras guardar

  /// Tope de una espera con animación de «revisando» (spec 04: escaneo
  /// «Revisando tus apps» ≤ 1,5 s): al cumplirse se muestra el resultado con
  /// lo que haya cargado. Es un plazo de datos, no una animación: **no** pasa
  /// por [of] y se respeta también con el movimiento reducido.
  static const Duration scanMax = Duration(milliseconds: 1500);

  /// Curva de salida suave (rápida al empezar, se posa al final).
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  /// Desplazamiento vertical de una entrada, en fracción de la altura del
  /// elemento (`slideY(begin: entryOffset)`): un deslizamiento corto.
  static const double entryOffset = 0.08;

  /// Índice máximo que suma retraso en una lista escalonada: a partir de él,
  /// los elementos entran a la vez (una lista larga no hace esperar al final).
  static const int staggerMaxIndex = 8;

  /// True si el sistema pide reducir el movimiento. Sin `MediaQuery` arriba
  /// se asume que no.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], o `Duration.zero` si el movimiento está reducido.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Retraso del elemento [index] de una lista escalonada (`stagger × index`),
  /// o `Duration.zero` si el movimiento está reducido.
  static Duration staggerOf(BuildContext context, int index) =>
      of(context, stagger * index);
}
