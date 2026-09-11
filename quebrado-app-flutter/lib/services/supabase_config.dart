import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Lee la URL de Supabase desde el archivo .env (privado) o variables de compilación
  static String get supabaseUrl {
    String? envVal;
    try {
      if (dotenv.isInitialized) {
        envVal = dotenv.env['SUPABASE_URL'];
      }
    } catch (_) {}
    if (envVal != null && envVal.isNotEmpty && envVal != 'https://tu-proyecto.supabase.co') {
      return envVal;
    }
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://tu-proyecto.supabase.co',
    );
  }

  /// Lee la Anon Key de Supabase desde el archivo .env (privado) o variables de compilación
  static String get supabaseAnonKey {
    String? envVal;
    try {
      if (dotenv.isInitialized) {
        envVal = dotenv.env['SUPABASE_ANON_KEY'];
      }
    } catch (_) {}
    if (envVal != null && envVal.isNotEmpty && envVal != 'tu-anon-key-aqui') {
      return envVal;
    }
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'tu-anon-key-aqui',
    );
  }

  static bool get isConfigured =>
      supabaseUrl != 'https://tu-proyecto.supabase.co' &&
      supabaseAnonKey != 'tu-anon-key-aqui' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
