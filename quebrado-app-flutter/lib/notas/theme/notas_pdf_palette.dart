/// Medidas del PDF de una nota (spec 05).
///
/// El PDF se imprime en papel blanco, así que no sigue el tema oscuro de la
/// app: sus colores son los `PdfColors` con nombre del paquete `pdf` (claros,
/// a propósito) y sus medidas viven aquí, con nombre, para que el servicio no
/// lleve números sueltos. Cambiar estos valores cambia cómo se ve el PDF.
abstract final class NotasPdfPalette {
  /// Margen de la página, en puntos (igual en los cuatro lados).
  static const double pageMargin = 40;
}
