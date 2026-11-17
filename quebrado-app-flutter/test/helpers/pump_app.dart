// pumpApp: monta un widget como lo vería el usuario.
//
// - MultiProvider con los ChangeNotifier que el test le pase (normalmente
//   `ChangeNotifierProvider<XState>.value(value: state)` con un state ya preparado
//   o un servicio fake inyectado).
// - MaterialApp con el tema de la app (copia de main.dart SIN GoogleFonts: en
//   tests no hay red y google_fonts dejaría timers/peticiones pendientes).
// - Locale: la app no define locale ni depende de flutter_localizations, así que
//   aquí tampoco; Material queda en inglés igual que en producción.
// - Tamaño de ventana opcional por clase (compact/medium/expanded, ver
//   lib/widgets/responsive_breakpoints.dart); se restaura solo con addTearDown.
//
// Uso:
//   await pumpApp(tester, const MiPantalla(),
//       providers: [ChangeNotifierProvider<NotasState>.value(value: state)],
//       window: WindowClass.expanded);
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quebrado_app_flutter/theme/colors.dart';

/// Clases de ventana del proyecto (breakpoints 600 / 840 / 1200).
enum WindowClass {
  /// < 600: móvil.
  compact(Size(390, 844)),

  /// 600–839: tablet vertical (isMedium = true, isDesktop = false).
  medium(Size(720, 1024)),

  /// 840–1199: ventana de escritorio estrecha (isMedium e isDesktop = true).
  desktop(Size(1000, 800)),

  /// ≥ 1200: escritorio / web ancho.
  expanded(Size(1280, 800));

  const WindowClass(this.size);
  final Size size;
}

/// Tema de main.dart sin GoogleFonts. Si cambias el tema de la app, actualiza esto.
ThemeData testAppTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.background,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primary.withOpacity(0.12),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primary),
        actionsIconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

/// Fija el tamaño lógico de la ventana (devicePixelRatio 1) y lo restaura al final.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<SingleChildWidget> providers = const [],
  WindowClass? window,
  Size? size,
  bool wrapInScaffold = true,
  ThemeData? theme,
  bool settle = true,
}) async {
  final windowSize = size ?? window?.size;
  if (windowSize != null) setWindowSize(tester, windowSize);

  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? testAppTheme(),
    home: wrapInScaffold ? Scaffold(body: child) : child,
  );
  if (providers.isNotEmpty) {
    app = MultiProvider(providers: providers, child: app);
  }

  await tester.pumpWidget(app);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
