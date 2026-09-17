import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lee una imagen del portapapeles en plataformas nativas (Desktop / Mobile).
/// Soporta:
/// 1. Pasteboard.image (plugin nativo)
/// 2. Fallback de sistema nativo en macOS (osascript PNGf) para garantizar que funcione
///    incluso si la app no fue reiniciada tras agregar el plugin.
/// 3. Archivos copiados desde el explorador/Finder (Cmd+C en archivo de imagen).
/// 4. Texto con rutas locales o data URIs.
Future<String?> readImageFromClipboardPlatform() async {
  // 1. Intentar con Pasteboard.image
  try {
    final Uint8List? bytes = await Pasteboard.image;
    if (bytes != null && bytes.isNotEmpty) {
      return await _saveBytesToDisk(bytes);
    }
  } catch (e) {
    debugPrint('Pasteboard.image error: $e');
  }

  // 2. Fallback de alta confiabilidad para macOS
  if (!kIsWeb && Platform.isMacOS) {
    try {
      final script = '''
set targetFile to ((path to temporary items as text) & "diario_clip_" & (do shell script "date +%s") & ".png")
try
    set imgData to the clipboard as «class PNGf»
    set f to open for access file targetFile with write permission
    set eof of f to 0
    write imgData to f
    close access f
    return POSIX path of targetFile
on error
    try
        close access file targetFile
    end try
    return ""
end try
''';
      final result = await Process.run('osascript', ['-e', script]);
      final out = result.stdout.toString().trim();
      final lines = out.split('\n').map((l) => l.trim()).where((l) => l.startsWith('/') && l.endsWith('.png')).toList();
      if (lines.isNotEmpty) {
        final filePath = lines.last;
        final file = File(filePath);
        if (await file.exists() && (await file.length()) > 0) {
          return await _copyToPermanent(filePath);
        }
      }
    } catch (e) {
      debugPrint('macOS osascript clipboard fallback error: $e');
    }
  }

  // 3. Archivos copiados en Finder o File Explorer
  try {
    final List<String> files = await Pasteboard.files();
    if (files.isNotEmpty) {
      const validExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.heic', '.tif', '.tiff', '.ico'};
      for (final filePath in files) {
        final ext = p.extension(filePath).toLowerCase();
        if (validExts.contains(ext) && await File(filePath).exists()) {
          return await _copyToPermanent(filePath);
        }
      }
    }
  } catch (e) {
    debugPrint('Pasteboard.files error: $e');
  }

  // 4. Texto con URI base64 o ruta local
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      if (text.startsWith('data:image/')) {
        return text;
      }
      String clean = text;
      if (clean.startsWith('file://')) {
        clean = Uri.parse(clean).toFilePath();
      }
      const validExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.heic', '.tif', '.tiff', '.ico'};
      final ext = p.extension(clean).toLowerCase();
      if (validExts.contains(ext) && await File(clean).exists()) {
        return await _copyToPermanent(clean);
      }
    }
  } catch (e) {
    debugPrint('Clipboard text fallback error: $e');
  }

  return null;
}

Future<String> _saveBytesToDisk(Uint8List bytes) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'diario_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName = 'diario_clip_${DateTime.now().millisecondsSinceEpoch}.png';
    final permPath = p.join(imagesDir.path, fileName);
    final file = File(permPath);
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}

Future<String> _copyToPermanent(String sourcePath) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'diario_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.png';
    final fileName = 'diario_clip_${DateTime.now().millisecondsSinceEpoch}$ext';
    final permPath = p.join(imagesDir.path, fileName);
    await File(sourcePath).copy(permPath);
    return permPath;
  } catch (e) {
    return sourcePath;
  }
}
