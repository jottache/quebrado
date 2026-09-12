import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/diario_colors.dart';

class DiarioImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Abre un modal para seleccionar Cámara o Galería y retorna la ruta permanente guardada.
  static Future<String?> pickImageWithSourceModal(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agregar Foto al Registro',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: DiarioColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige cómo deseas adjuntar la fotografía',
                style: TextStyle(fontSize: 13, color: DiarioColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOptionCard(
                      context: ctx,
                      icon: Icons.camera_alt_rounded,
                      title: 'Cámara',
                      subtitle: 'Tomar foto ahora',
                      source: ImageSource.camera,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSourceOptionCard(
                      context: ctx,
                      icon: Icons.photo_library_rounded,
                      title: 'Galería',
                      subtitle: 'Elegir de fotos',
                      source: ImageSource.gallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    return pickImage(source);
  }

  static Widget _buildSourceOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: DiarioColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DiarioColors.cardBorder, width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: DiarioColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: DiarioColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Toma o selecciona la imagen y la almacena de forma persistente en la carpeta del diario.
  static Future<String?> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file == null) return null;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final ext = p.extension(file.name).replaceAll('.', '').toLowerCase();
        final mime = (ext == 'png' || ext == 'webp' || ext == 'gif') ? ext : 'jpeg';
        return 'data:image/$mime;base64,${base64Encode(bytes)}';
      }

      return await saveImagePermanently(file.path);
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Guarda una copia permanente de la imagen en documents/diario_images
  static Future<String> saveImagePermanently(String tempPath) async {
    if (kIsWeb) return tempPath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'diario_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final ext = p.extension(tempPath).isNotEmpty ? p.extension(tempPath) : '.jpg';
      final fileName = 'diario_${DateTime.now().millisecondsSinceEpoch}$ext';
      final permanentPath = p.join(imagesDir.path, fileName);

      final savedFile = await File(tempPath).copy(permanentPath);
      return savedFile.path;
    } catch (e) {
      debugPrint('Error copiando imagen permanente: $e');
      return tempPath;
    }
  }

  /// Renderiza la imagen desde archivo local o URL remota de forma segura
  static Widget buildImageWidget(
    String pathOrUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget;

    if (pathOrUrl.startsWith('data:image')) {
      try {
        final commaIdx = pathOrUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? pathOrUrl.substring(commaIdx + 1) : pathOrUrl;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholderWidget(width, height),
        );
      } catch (_) {
        imageWidget = _placeholderWidget(width, height);
      }
    } else if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://') || pathOrUrl.startsWith('blob:')) {
      imageWidget = Image.network(
        pathOrUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholderWidget(width, height),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[100],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: DiarioColors.primary),
              ),
            ),
          );
        },
      );
    } else if (!kIsWeb) {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholderWidget(width, height),
        );
      } else {
        imageWidget = _placeholderWidget(width, height);
      }
    } else {
      imageWidget = _placeholderWidget(width, height);
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  static Widget _placeholderWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey[400]),
    );
  }

  /// Abre visor a pantalla completa con zoom interactivo
  static void openFullScreenImage(BuildContext context, String pathOrUrl, {String? title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.7),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              title ?? 'Fotografía del Registro',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: buildImageWidget(pathOrUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
