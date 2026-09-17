import 'clipboard_image_io.dart'
    if (dart.library.html) 'clipboard_image_web.dart';

/// Interfaz unificada que detecta la plataforma (Web vs Nativo/Desktop)
/// para extraer la imagen del portapapeles de forma infalible.
Future<String?> readImageFromClipboard() => readImageFromClipboardPlatform();
