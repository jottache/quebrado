import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'quebrado/quebrado.dart';
import 'diario/diario.dart';
import 'habitos/habitos.dart';
import 'recordatorios/recordatorios.dart';
import 'notas/notas.dart';
import 'agente/agente.dart';
import 'services/notification_manager.dart';
import 'screens/app_launcher_screen.dart';
import 'widgets/responsive_suite_scaffold.dart';
import 'theme/ortiz_theme.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'services/supabase_config.dart';
import 'services/web_splash.dart';

void main() async {
  // Ensure Flutter engine is initialized before calling native platforms/services
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database factory for Web and Desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Info: No se cargó archivo .env local: $e");
  }

  // Initialize Supabase if configured
  try {
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    }
  } catch (e) {
    debugPrint("Failed to initialize Supabase: $e");
  }

  // Initialize notifications manager on native platforms
  if (!kIsWeb) {
    try {
      NotificationManager.shared.initialize();
    } catch (e) {
      debugPrint("Failed to initialize NotificationManager: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) removeWebSplash();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
        ChangeNotifierProvider<AnimoState>(create: (_) => AnimoState()..loadAll()),
        ChangeNotifierProvider<HabitosState>(create: (_) => HabitosState()),
        ChangeNotifierProvider<RemindersState>(create: (_) => RemindersState()),
        ChangeNotifierProvider<NotasState>(create: (_) => NotasState()..loadAll()),
        ChangeNotifierProvider<AgenteState>(create: (_) => AgenteState()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'OrtizApp',
            debugShowCheckedModeBanner: false,
            theme: OrtizTheme.dark,
            home: const ResponsiveSuiteScaffold(
              mobileBody: AppLauncherScreen(),
            ),
          );
        }
      ),
    );
  }
}
