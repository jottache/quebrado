import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'quebrado/quebrado.dart';
import 'diario/diario.dart';
import 'habitos/habitos.dart';
import 'recordatorios/recordatorios.dart';
import 'agente/agente.dart';
import 'services/notification_manager.dart';
import 'screens/app_launcher_screen.dart';
import 'widgets/responsive_suite_scaffold.dart';
import 'theme/colors.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_config.dart';

void main() async {
  // Ensure Flutter engine is initialized before calling native platforms/services
  WidgetsFlutterBinding.ensureInitialized();

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
        ChangeNotifierProvider<HabitosState>(create: (_) => HabitosState()),
        ChangeNotifierProvider<RemindersState>(create: (_) => RemindersState()),
        ChangeNotifierProvider<AgenteState>(create: (_) => AgenteState()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'OrtizApp',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              textTheme: GoogleFonts.josefinSansTextTheme(ThemeData.light().textTheme),
              scaffoldBackgroundColor: AppColors.background,
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                ),
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                surface: AppColors.background,
              ),
              appBarTheme: AppBarTheme(
                centerTitle: true,
                iconTheme: IconThemeData(color: AppColors.primary),
                actionsIconTheme: IconThemeData(color: AppColors.primary),
                titleTextStyle: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            home: const ResponsiveSuiteScaffold(
              mobileBody: AppLauncherScreen(),
            ),
          );
        }
      ),
    );
  }
}
