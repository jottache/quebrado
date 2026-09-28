import 'dart:convert';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Tamaños de compresión por tipo de foto.
class MediaImagePreset {
  final String folder;
  final int maxSide;
  final int quality;

  const MediaImagePreset(this.folder, this.maxSide, this.quality);

  /// Avatares: se muestran a 46 px y en pantalla completa al tocarlos.
  static const avatar = MediaImagePreset('avatars', 512, 82);

  /// Fotos adjuntas a entradas del Diario.
  static const entryPhoto = MediaImagePreset('entries', 1600, 80);
}

/// Sube fotos comprimidas (JPEG) al bucket `diario-media` de Supabase Storage
/// (migración 014) para que en las tablas quede solo la URL pública.
class MediaStorageService {
  static final MediaStorageService instance = MediaStorageService._init();
  MediaStorageService._init();

  @visibleForTesting
  MediaStorageService.forTesting();

  static const String bucket = 'diario-media';
  static const String _publicMarker = '/storage/v1/object/public/$bucket/';

  final Uuid _uuid = const Uuid();

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  static bool isInlineImage(String? value) => value != null && value.startsWith('data:image');

  static bool isRemoteUrl(String? value) =>
      value != null && (value.startsWith('http://') || value.startsWith('https://'));

  /// URL de un archivo de este bucket (las demás URLs no se borran nunca).
  static bool isManagedUrl(String? value) => value != null && value.contains(_publicMarker);

  /// ¿Hay que subir este valor? (base64 embebido o ruta de archivo local).
  static bool needsUpload(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (isRemoteUrl(value) || value.startsWith('blob:')) return false;
    return true;
  }

  /// Convierte una foto guardada como base64 o ruta local en una URL de Storage.
  /// - Sin Supabase configurado devuelve el valor original (la app sigue funcionando).
  /// - Si la subida falla devuelve la foto comprimida en base64 para no perderla
  ///   (o el valor original si [fallbackToInline] es false); se reintentará en la
  ///   próxima migración.
  Future<String?> ensureRemote(String? value, MediaImagePreset preset, {bool fallbackToInline = true}) async {
    if (!needsUpload(value) || !isReady) return value;

    final original = await _readBytes(value!);
    if (original == null) return value;

    Uint8List bytes;
    try {
      bytes = await compressToJpeg(original, maxSide: preset.maxSide, quality: preset.quality);
    } catch (e) {
      debugPrint('MediaStorage: no se pudo comprimir la imagen ($e)');
      return value;
    }

    final url = await _upload(bytes, preset.folder);
    if (url != null) return url;
    return fallbackToInline ? 'data:image/jpeg;base64,${base64Encode(bytes)}' : value;
  }

  /// Borra un archivo del bucket si la URL le pertenece (best-effort).
  Future<void> deleteByUrl(String? url) async {
    if (!isReady || !isManagedUrl(url)) return;
    final path = url!.substring(url.indexOf(_publicMarker) + _publicMarker.length).split('?').first;
    try {
      await client!.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('MediaStorage: no se pudo borrar $path ($e)');
    }
  }

  Future<String?> _upload(Uint8List bytes, String folder) async {
    final path = '$folder/${_uuid.v4()}.jpg';
    try {
      final storage = client!.storage.from(bucket);
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000', upsert: false),
      );
      return storage.getPublicUrl(path);
    } catch (e) {
      debugPrint('MediaStorage: error subiendo $path ($e)');
      return null;
    }
  }

  Future<Uint8List?> _readBytes(String value) async {
    try {
      if (isInlineImage(value)) {
        final comma = value.indexOf(',');
        return base64Decode(comma == -1 ? value : value.substring(comma + 1));
      }
      if (kIsWeb) return null;
      final file = File(value);
      if (!await file.exists()) return null; // ruta de otro dispositivo
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('MediaStorage: no se pudo leer la imagen ($e)');
      return null;
    }
  }

  /// Redimensiona (lado mayor ≤ [maxSide]) con el decodificador del motor
  /// —rápido también en web— y codifica a JPEG. La transparencia se aplana sobre blanco.
  static Future<Uint8List> compressToJpeg(Uint8List bytes, {required int maxSide, required int quality}) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = descriptor.width >= descriptor.height
        ? maxSide / descriptor.width
        : maxSide / descriptor.height;
    final targetWidth = scale < 1 ? (descriptor.width * scale).round() : descriptor.width;
    final targetHeight = scale < 1 ? (descriptor.height * scale).round() : descriptor.height;

    // Un JPEG que ya cabe en el tamaño se sube tal cual (sin perder calidad otra vez).
    final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    if (isJpeg && scale >= 1) {
      descriptor.dispose();
      buffer.dispose();
      return bytes;
    }

    final codec = await descriptor.instantiateCodec(targetWidth: targetWidth, targetHeight: targetHeight);
    final frame = await codec.getNextFrame();
    final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (rgba == null) throw StateError('No se pudo leer la imagen decodificada');

    final src = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final flat = img.Image(width: width, height: height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, src);
    return Uint8List.fromList(img.encodeJpg(flat, quality: quality));
  }
}
