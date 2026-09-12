import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiConfig {
  static String? _inMemoryApiKey;
  static String _selectedModel = 'gemini-1.5-flash';

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

  static String get selectedModel => _selectedModel;

  static void setModel(String model) {
    _selectedModel = model;
  }
}
