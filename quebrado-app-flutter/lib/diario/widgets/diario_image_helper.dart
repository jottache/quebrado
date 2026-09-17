import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/diario_colors.dart';
import 'clipboard_image_helper.dart';

class DiarioImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Abre un modal para seleccionar Cámara, Galería, Portapapeles o Quitar Foto para el Avatar del contacto.
  static Future<String?> pickAvatarWithSourceModal(BuildContext context, {bool hasExistingAvatar = false}) async {
    final String? action = await showModalBottomSheet<String>(
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
                'Foto del Contacto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: DiarioColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona o pega una foto para identificar a tu contacto',
                style: TextStyle(fontSize: 13, color: DiarioColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context: ctx,
                      icon: Icons.photo_library_rounded,
                      title: 'Galería',
                      subtitle: 'Elegir de fotos',
                      actionValue: 'gallery',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context: ctx,
                      icon: Icons.camera_alt_rounded,
                      title: 'Cámara',
                      subtitle: 'Tomar foto',
                      actionValue: 'camera',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.of(ctx).pop('paste'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: DiarioColors.primaryLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DiarioColors.primary.withOpacity(0.3), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: DiarioColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pegar del Portapapeles',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: DiarioColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Usa una imagen copiada en tu equipo (Cmd+V)',
                              style: TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DiarioColors.textSecondary),
                    ],
                  ),
                ),
              ),
              if (hasExistingAvatar) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop('remove'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Eliminar Foto de Perfil',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (action == null) return null;
    if (action == 'remove') return ''; // Indicador de eliminación
    if (action == 'paste') {
      return pickImageFromClipboard(context, successMessage: 'Foto de perfil pegada del portapapeles');
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    return pickAvatar(source);
  }

  /// Obtiene una imagen directamente desde el portapapeles (Desktop nativo o Web)
  /// y la almacena de forma persistente.
  static Future<String?> pickImageFromClipboard(
    BuildContext context, {
    String successMessage = 'Imagen pegada del portapapeles',
  }) async {
    try {
      final imageResult = await readImageFromClipboard();
      if (imageResult == null || imageResult.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('No hay ninguna imagen copiada en el portapapeles.'),
                  ),
                ],
              ),
              backgroundColor: Colors.grey[850],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      final savedPath = await saveImagePermanently(imageResult);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: DiarioColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return savedPath;
    } catch (e) {
      debugPrint('Error leyendo portapapeles: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al leer imagen del portapapeles: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Guarda bytes binarios de imagen de forma persistente en documents/diario_images
  static Future<String> saveImageBytesPermanently(Uint8List bytes, {String ext = '.png'}) async {
    if (kIsWeb) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'diario_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = 'diario_clip_${DateTime.now().millisecondsSinceEpoch}$ext';
      final permanentPath = p.join(imagesDir.path, fileName);

      final file = File(permanentPath);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error guardando imagen binaria en disco: $e');
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  static Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionValue,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(actionValue),
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
              decoration: const BoxDecoration(
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

  /// Selector optimizado para fotos de perfil / avatar (512x512, compresión adecuada)
  static Future<String?> pickAvatar(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
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
      debugPrint('Error seleccionando avatar: $e');
      return null;
    }
  }

  /// Abre un modal para seleccionar Cámara, Galería o Portapapeles y retorna la ruta permanente guardada.
  static Future<String?> pickImageWithSourceModal(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
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
                    child: _buildActionCard(
                      context: ctx,
                      icon: Icons.camera_alt_rounded,
                      title: 'Cámara',
                      subtitle: 'Tomar foto ahora',
                      actionValue: 'camera',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context: ctx,
                      icon: Icons.photo_library_rounded,
                      title: 'Galería',
                      subtitle: 'Elegir de fotos',
                      actionValue: 'gallery',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.of(ctx).pop('paste'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: DiarioColors.primaryLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DiarioColors.primary.withOpacity(0.3), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: DiarioColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pegar del Portapapeles',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: DiarioColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Adjunta una imagen que tengas copiada (Cmd+V)',
                              style: TextStyle(fontSize: 11, color: DiarioColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DiarioColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null) return null;
    if (action == 'paste') {
      return pickImageFromClipboard(context, successMessage: 'Foto adjuntada del portapapeles');
    }
    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
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
    if (kIsWeb || tempPath.startsWith('data:image/')) return tempPath;
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
