import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'quebrado/quebrado.dart';
import 'diario/diario.dart';
import 'habitos/habitos.dart';
import 'recordatorios/recordatorios.dart';
import 'notas/notas.dart';
import 'agente/agente.dart';
import 'services/notification_manager.dart';
import 'services/suite_lock.dart';
import 'widgets/suite_router.dart';
import 'theme/ortiz_theme.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
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

  // URLs sin `#` en web (`/diario`, no `/#/diario`); no hace nada fuera de web.
  usePathUrlStrategy();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // El router se crea una sola vez: nunca dentro del builder del Consumer,
  // que se reconstruye con cada cambio de AppState.
  // Bloqueo de la suite con PIN una vez al día (P-04 revisada): el router lo
  // escucha, `AppState` le pasa los ajustes de seguridad y, tras desbloquear,
  // deja de pedir el PIN en cada operación.
  final SuiteLock _lock = SuiteLock();
  late final GoRouter _router = buildSuiteRouter(lock: _lock);

  AppState _createAppState() {
    final app = AppState()
      ..onSecurityVerified = _lock.unlock
      ..isSessionUnlocked = (() => _lock.isUnlocked);
    void syncSecurity() => _lock.updateSecurity(
          enabled: app.usePinSecurity || app.useBiometrics,
          confirmed: app.securitySettingsConfirmed,
        );
    app.addListener(syncSecurity);
    syncSecurity();
    return app;
  }

  @override
  void dispose() {
    _router.dispose();
    _lock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) removeWebSplash();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SuiteLock>.value(value: _lock),
        ChangeNotifierProvider<AppState>(create: (_) => _createAppState()),
        ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
        ChangeNotifierProvider<AnimoState>(create: (_) => AnimoState()..loadAll()),
        ChangeNotifierProvider<HabitosState>(create: (_) => HabitosState()),
        ChangeNotifierProvider<RemindersState>(create: (_) => RemindersState()),
        ChangeNotifierProvider<NotasState>(create: (_) => NotasState()..loadAll()),
        // Ortiz necesita los estados vivos de la suite para leer y registrar
        // (spec 03). `updateDependencies` no rehace nada si no cambiaron.
        ChangeNotifierProxyProvider6<AppState, DiarioState, AnimoState,
            HabitosState, RemindersState, NotasState, AgenteState>(
          create: (_) => AgenteState(),
          update: (_, app, diario, animo, habitos, reminders, notas, agente) =>
              (agente ?? AgenteState())
                ..updateDependencies(
                  appState: app,
                  diarioState: diario,
                  habitosState: habitos,
                  remindersState: reminders,
                  animoState: animo,
                  notasState: notas,
                ),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp.router(
            title: 'OrtizApp',
            debugShowCheckedModeBanner: false,
            theme: OrtizTheme.dark,
            scaffoldMessengerKey: suiteMessengerKey,
            routerConfig: _router,
          );
        }
      ),
    );
  }
}
