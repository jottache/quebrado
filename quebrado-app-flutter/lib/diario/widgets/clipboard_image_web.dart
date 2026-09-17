import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Lee una imagen del portapapeles en Flutter Web (Chrome / Edge / Firefox / Safari)
/// utilizando la API moderna W3C Clipboard de package:web.
Future<String?> readImageFromClipboardPlatform() async {
  try {
    final clipboard = web.window.navigator.clipboard;
    final itemsPromise = clipboard.read();
    final items = (await itemsPromise.toDart).toDart;

    for (final item in items) {
      final types = item.types.toDart;
      for (final type in types) {
        final typeStr = type.toDart;
        if (typeStr.startsWith('image/')) {
          final blob = await item.getType(typeStr).toDart;
          final reader = web.FileReader();
          final completer = Completer<String?>();
          reader.onloadend = (web.ProgressEvent event) {
            final result = reader.result;
            if (result != null && result.isA<JSString>()) {
              completer.complete((result as JSString).toDart);
            } else {
              completer.complete(null);
            }
          }.toJS;
          reader.onerror = (web.ProgressEvent event) {
            completer.complete(null);
          }.toJS;
          reader.readAsDataURL(blob);
          final dataUrl = await completer.future;
          if (dataUrl != null && dataUrl.isNotEmpty) {
            return dataUrl;
          }
        }
      }
    }
  } catch (_) {
    // Si la lectura directa falla o no hay permisos, continuar a fallback
  }

  // Fallback a texto si es data:image o URL
  try {
    final textData = await Clipboard.getData(Clipboard.kTextPlain);
    final rawText = textData?.text?.trim();
    if (rawText != null && rawText.isNotEmpty) {
      if (rawText.startsWith('data:image/') || rawText.startsWith('http://') || rawText.startsWith('https://')) {
        return rawText;
      }
    }
  } catch (_) {}

  return null;
}
