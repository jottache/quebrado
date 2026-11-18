// pumpSuiteRouter: monta el router real de la suite (`buildSuiteRouter`) con su
// shell (`ResponsiveSuiteScaffold`), pero con pantallas de prueba ligeras en
// cada rama (`SuiteStubScreen`), para probar rutas y shell sin montar las
// pantallas reales (que leen Supabase, SQLite o plugins).
//
// Uso:
//   final router = await pumpSuiteRouter(tester, initialLocation: '/diario',
//       window: WindowClass.expanded);
//   expect(currentPath(router), '/diario');
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quebrado_app_flutter/services/suite_lock.dart';
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

import 'pump_app.dart';

/// Pantalla de prueba de una rama: su nombre, un contador con estado propio
/// (para comprobar que la rama conserva su estado) y un botón que abre el menú
/// del shell (como el ☰ de los pasos 3c/3d).
class SuiteStubScreen extends StatefulWidget {
  const SuiteStubScreen({super.key, required this.branch});

  final SuiteBranch branch;

  /// Texto que identifica la pantalla de [branch].
  static String labelOf(SuiteBranch branch) => 'pantalla ${branch.name}';

  @override
  State<SuiteStubScreen> createState() => _SuiteStubScreenState();
}

class _SuiteStubScreenState extends State<SuiteStubScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final scope = SuiteShellScope.maybeOf(context);
    return Scaffold(
      body: Column(
        children: [
          Text(SuiteStubScreen.labelOf(widget.branch)),
          Text('contador ${widget.branch.name} $_count'),
          TextButton(
            onPressed: () => setState(() => _count++),
            child: Text('sumar ${widget.branch.name}'),
          ),
          TextButton(
            onPressed: scope?.openMenu,
            child: Text('menú ${widget.branch.name}'),
          ),
        ],
      ),
    );
  }
}

/// Path de la URL actual del router.
String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

/// Monta el router de la suite como `main.dart` (`MaterialApp.router` con el
/// tema y el messenger global) en la clase de ventana [window]. [screenFor]
/// sustituye la pantalla de prueba de alguna rama (devuelve null para usar
/// [SuiteStubScreen]).
Future<GoRouter> pumpSuiteRouter(
  WidgetTester tester, {
  String initialLocation = SuiteRoutes.home,
  WindowClass window = WindowClass.compact,
  List<SingleChildWidget> providers = const [],
  Widget? Function(SuiteBranch branch)? screenFor,
  SuiteLock? lock,
}) async {
  setWindowSize(tester, window.size);
  final router = buildSuiteRouter(
    initialLocation: initialLocation,
    screenFor: (branch) =>
        screenFor?.call(branch) ?? SuiteStubScreen(branch: branch),
    highlightedReminderScreen: (id) => Text('recordatorio resaltado $id'),
    lock: lock,
  );
  addTearDown(router.dispose);

  Widget app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: testAppTheme(),
    scaffoldMessengerKey: suiteMessengerKey,
    routerConfig: router,
  );
  if (providers.isNotEmpty) {
    app = MultiProvider(providers: providers, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  return router;
}

/// Deja pasar el tiempo de un aviso (SnackBar) para que no quede un Timer vivo.
Future<void> letNoticeExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}
