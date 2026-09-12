import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiConfig {
  static String? _inMemoryApiKey;
  static String? _inMemoryModel;

  /// Obtiene la API Key activa de Gemini
  static String get apiKey {
    if (_inMemoryApiKey != null && _inMemoryApiKey!.isNotEmpty) {
      return _inMemoryApiKey!;
    }
    String? envVal;
    try {
      if (dotenv.isInitialized) {
        envVal = dotenv.env['GEMINI_API_KEY'];
      }
    } catch (_) {}
    if (envVal != null && envVal.isNotEmpty && envVal != 'tu-gemini-api-key-aqui') {
      return envVal;
    }
    return const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
  }

  /// Permite establecer o actualizar la API Key en caliente
  static void setApiKey(String key) {
    _inMemoryApiKey = key.trim();
  }

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Obtiene el modelo activo de Gemini (prioridad: memoria > .env > compile-time define > default)
  static String get selectedModel {
    if (_inMemoryModel != null && _inMemoryModel!.isNotEmpty) {
      return _inMemoryModel!;
    }
    String? envModel;
    try {
      if (dotenv.isInitialized) {
        envModel = dotenv.env['GEMINI_MODEL'];
      }
    } catch (_) {}
    if (envModel != null && envModel.trim().isNotEmpty) {
      return envModel.trim();
    }
    const compileDef = String.fromEnvironment('GEMINI_MODEL', defaultValue: '');
    if (compileDef.isNotEmpty) {
      return compileDef;
    }
    return 'gemini-1.5-flash';
  }

  static void setModel(String model) {
    _inMemoryModel = model.trim();
  }
}

