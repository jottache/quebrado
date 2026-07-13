import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'viewmodels/app_state.dart';
import 'services/notification_manager.dart';
import 'screens/main_screen.dart';
import 'theme/colors.dart';

void main() async {
  // Ensure Flutter engine is initialized before calling native platforms/services
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications manager
  try {
    await NotificationManager.shared.initialize();
  } catch (e) {
    debugPrint("Failed to initialize NotificationManager: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Quebrado',
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
            ),
            home: MainScreen(),
          );
        }
      ),
    );
  }
}
