// Rutas de la suite con go_router (spec 02, pasos 3a/3b; diseño en
// docs/design/rutas.md §2–§4).
//
// - Un `StatefulShellRoute.indexedStack` con una rama por app: cada rama tiene
//   su propio Navigator dentro de un `IndexedStack`, así que el estado de cada
//   app se conserva al cambiar de una a otra.
// - El shell es `ResponsiveSuiteScaffold` (drawer en `< 840`, sidebar en
//   `≥ 840`).
// - Una URL desconocida lleva a `/` con el aviso «Esa página no existe».
// - Las rutas de detalle (`movimientos/:id`, `entradas/:id`, …) llegan en los
//   pasos 3f/3g como `routes:` hijas de la ruta raíz de cada rama.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../agente/agente.dart';
import '../diario/diario.dart';
import '../habitos/habitos.dart';
import '../notas/notas.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/screens/main_screen.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../recordatorios/recordatorios.dart';
import '../screens/ortiz_home_screen.dart';
import '../services/suite_lock.dart';
import '../services/suite_record_lookup.dart';
import '../theme/ortiz_space.dart';
import '../theme/suite_apps.dart';
import 'ortiz/ortiz_notice.dart';
import 'responsive_suite_scaffold.dart';
import 'suite_actions.dart';
import 'suite_route_pages.dart';
import 'suite_unlock_view.dart';

/// Paths de la suite. La raíz de cada app sale de `SuiteApp.route`; los
/// detalles se construyen aquí para no repetir strings en los formularios.
abstract final class SuiteRoutes {
  static const String home = '/';

  /// Raíz de [app] (p. ej. `/finanzas`).
  static String app(SuiteApp app) => app.route;

  static String movimiento(String id) =>
      '${SuiteApp.finanzas.route}/movimientos/${Uri.encodeComponent(id)}';
  static String get pagos => '${SuiteApp.finanzas.route}/pagos';
  static String entrada(String id) =>
      '${SuiteApp.diario.route}/entradas/${Uri.encodeComponent(id)}';
  static String get animo => '${SuiteApp.diario.route}/animo';
  static String habito(String id) =>
      '${SuiteApp.habitos.route}/${Uri.encodeComponent(id)}';
  static String recordatorio(String id) =>
      '${SuiteApp.recordatorios.route}/${Uri.encodeComponent(id)}';
  static String nota(String id) =>
      '${SuiteApp.notas.route}/${Uri.encodeComponent(id)}';
  static String contacto(String id) =>
      '${SuiteApp.diario.route}/contactos/${Uri.encodeComponent(id)}';

  /// Pantalla del PIN diario de toda la suite (§10, P-04 revisada).
  static const String desbloquearPath = '/desbloquear';

  /// `/desbloquear?siguiente=<next>`.
  static String desbloquear(String next) =>
      Uri(path: desbloquearPath, queryParameters: {'siguiente': next})
          .toString();

  /// Destino seguro tras el PIN: una ruta interna (empieza por una sola `/`,
  /// sin esquema ni dominio) que no sea el propio `desbloquear`; si no, `/`.
  static String safeNext(String? next) {
    if (next == null || !next.startsWith('/') || next.startsWith('//')) {
      return home;
    }
    final parsed = Uri.tryParse(next);
    if (parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        parsed.path == desbloquearPath ||
        parsed.path.startsWith('$desbloquearPath/')) {
      return home;
    }
    return next;
  }
}

/// Ramas del shell, en el orden del `StatefulShellRoute` (su `index` es el
/// índice de la rama). `inicio` es la conversación con Ortiz; el resto, una
/// por app de [SuiteApp].
enum SuiteBranch {
  inicio(null),
  finanzas(SuiteApp.finanzas),
  diario(SuiteApp.diario),
  habitos(SuiteApp.habitos),
  recordatorios(SuiteApp.recordatorios),
  notas(SuiteApp.notas);

  const SuiteBranch(this.app);

  /// App de la rama; `null` en el inicio.
  final SuiteApp? app;

  /// Path raíz de la rama.
  String get path => app?.route ?? SuiteRoutes.home;

  /// Rama de [app].
  static SuiteBranch forApp(SuiteApp app) =>
      values.firstWhere((b) => b.app == app);
}

/// Aviso de una URL que no corresponde a ninguna ruta.
const String suitePaginaNoExiste = 'Esa página no existe';

/// `ScaffoldMessenger` global de la app (`MaterialApp.router`). Los avisos que
/// se lanzan fuera de una pantalla (p. ej. al resolver una URL) salen por él.
final GlobalKey<ScaffoldMessengerState> suiteMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'suiteMessenger');

/// Inicio de la suite: [OrtizHomeScreen] con los chips del catálogo
/// ([suiteChipActions]) y el ☰ y el foco del chat del shell
/// ([SuiteShellScope]).
class SuiteOrtizHome extends StatelessWidget {
  const SuiteOrtizHome({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = SuiteShellScope.maybeOf(context);
    void go(String path) => GoRouter.of(context).go(path);
    return OrtizHomeScreen(
      onOpenMenu: shell?.openMenu,
      chatFocusNode: shell?.chatFocusNode,
      quickChips: [
        for (final action in suiteChipActions)
          ActionChip(
            key: ValueKey('suite-chip-${action.id}'),
            avatar: Icon(
              action.icon,
              size: OrtizIconSize.sm,
              color: action.app.color,
            ),
            label: Text(action.label),
            onPressed: () => runSuiteAction(context, action, onView: go),
          ),
      ],
    );
  }
}

/// Pantalla raíz de cada rama.
Widget suiteBranchScreen(SuiteBranch branch) => switch (branch) {
      SuiteBranch.inicio => const SuiteOrtizHome(),
      SuiteBranch.finanzas => const MainScreen(),
      SuiteBranch.diario => const DiarioHomeScreen(),
      SuiteBranch.habitos => const HabitosHomeScreen(),
      SuiteBranch.recordatorios => const RemindersHomeScreen(),
      SuiteBranch.notas => const NotasHomeScreen(),
    };

/// Crea el router de la suite. Se crea UNA vez (en el `State` raíz de la app),
/// nunca dentro de un `builder` que se reconstruya.
///
/// - [initialLocation]: URL de arranque si el navegador no trae otra.
/// - [navigatorKey]: Navigator raíz (diálogos y hojas a pantalla completa).
/// - [screenFor]: pantalla raíz de cada rama; por defecto [suiteBranchScreen]
///   (los tests inyectan pantallas ligeras).
GoRouter buildSuiteRouter({
  String initialLocation = SuiteRoutes.home,
  GlobalKey<NavigatorState>? navigatorKey,
  Widget Function(SuiteBranch branch) screenFor = suiteBranchScreen,
  Widget Function(String reminderId) highlightedReminderScreen =
      suiteHighlightedReminderScreen,
  SuiteLock? lock,
}) {
  final rootKey =
      navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'suiteRoot');

  // Avisos que se lanzan al resolver una URL: salen cuando la pantalla de
  // destino ya está montada, por el messenger global.
  void noticeAfterFrame(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootKey.currentContext;
      if (ctx != null && ctx.mounted) showOrtizNotice(ctx, message);
    });
  }

  // Busca el registro de una ruta de detalle (P-01/P-03): si no existe o
  // está en otro libro, avisa y lleva a la raíz de su app.
  Future<String?> lookupOrRoot<T>(
    Future<SuiteLookupResult<T>> lookup,
    SuiteApp app, {
    void Function(T record)? onFound,
  }) async {
    final result = await lookup;
    if (result is SuiteRecordFound<T>) {
      onFound?.call(result.record);
      return null;
    }
    noticeAfterFrame(result is SuiteRecordInOtherBook<T>
        ? result.notice
        : SuiteRecordMissing.notice);
    return app.route;
  }

  // Si el registro desapareció entre el redirect y el build.
  Page<void> missingPage(GoRouterState state, SuiteApp app) =>
      NoTransitionPage<void>(
        key: state.pageKey,
        child: _SuiteGoTo(path: app.route, notice: SuiteRecordMissing.notice),
      );

  // PIN diario de toda la suite (§10, P-04 revisada el 2026-11-18): hace falta
  // si la seguridad está activada y hoy aún no se desbloqueó. La primera vez
  // en un navegador (sin valor recordado) espera a `loadData()` para no abrir
  // la app antes de leer los ajustes (A1).
  FutureOr<bool> suiteLocked(BuildContext context) {
    final guard = lock;
    if (guard == null) return false;
    if (guard.requiresUnlock) return true;
    if (guard.securityKnown || guard.isUnlocked) return false;
    final app = context.read<AppState>();
    if (app.isDataLoaded) return guard.requiresUnlock;
    return app.loadData().then((_) => guard.requiresUnlock);
  }

  GoRoute detail(
    String path, {
    GoRouterRedirect? redirect,
    required GoRouterPageBuilder pageBuilder,
  }) =>
      GoRoute(path: path, redirect: redirect, pageBuilder: pageBuilder);

  List<RouteBase> detailsOf(SuiteBranch branch) => switch (branch) {
        SuiteBranch.inicio => const [],
        SuiteBranch.finanzas => [
            detail(
              'movimientos/:id',
              redirect: (context, state) => lookupOrRoot<Transaction>(
                SuiteRecordLookup.transaction(
                  context.read<AppState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.finanzas,
                // Debajo, la pestaña Historial.
                onFound: (_) => context.read<AppState>().setTabIndex(2),
              ),
              pageBuilder: (context, state) {
                final app = context.read<AppState>();
                final found = SuiteRecordLookup.find<Transaction>(
                    app.transactions, state.pathParameters['id']!, (t) => t.id);
                return found is SuiteRecordFound<Transaction>
                    ? SuiteRoutePages.movimiento(found.record, key: state.pageKey)
                    : missingPage(state, SuiteApp.finanzas);
              },
            ),
            detail(
              'pagos',
              pageBuilder: (context, state) =>
                  SuiteRoutePages.pagos(key: state.pageKey),
            ),
          ],
        SuiteBranch.diario => [
            detail(
              'entradas/:id',
              redirect: (context, state) => lookupOrRoot<DiarioEntry>(
                SuiteRecordLookup.diarioEntry(
                  context.read<DiarioState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.diario,
              ),
              pageBuilder: (context, state) {
                final found = SuiteRecordLookup.find<DiarioEntry>(
                    context.read<DiarioState>().entries,
                    state.pathParameters['id']!,
                    (e) => e.id);
                return found is SuiteRecordFound<DiarioEntry>
                    ? SuiteRoutePages.entrada(found.record, key: state.pageKey)
                    : missingPage(state, SuiteApp.diario);
              },
            ),
            detail(
              'animo',
              pageBuilder: (context, state) =>
                  SuiteRoutePages.animo(key: state.pageKey),
            ),
            detail(
              'contactos/:id',
              redirect: (context, state) => lookupOrRoot<DiarioContact>(
                SuiteRecordLookup.diarioContact(
                  context.read<DiarioState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.diario,
              ),
              pageBuilder: (context, state) => MaterialPage<void>(
                key: state.pageKey,
                child: ContactDetailScreen(
                    contactId: state.pathParameters['id']!),
              ),
            ),
          ],
        SuiteBranch.habitos => [
            detail(
              ':id',
              redirect: (context, state) => lookupOrRoot<HabitModel>(
                SuiteRecordLookup.habit(
                  context.read<HabitosState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.habitos,
              ),
              pageBuilder: (context, state) {
                final found = SuiteRecordLookup.find<HabitModel>(
                    context.read<HabitosState>().habits,
                    state.pathParameters['id']!,
                    (h) => h.id);
                return found is SuiteRecordFound<HabitModel>
                    ? SuiteRoutePages.habito(found.record, key: state.pageKey)
                    : missingPage(state, SuiteApp.habitos);
              },
            ),
          ],
        SuiteBranch.recordatorios => [
            // P-02: la lista con ese recordatorio resaltado y visible.
            detail(
              ':id',
              redirect: (context, state) => lookupOrRoot<ReminderModel>(
                SuiteRecordLookup.reminder(
                  context.read<RemindersState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.recordatorios,
              ),
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: highlightedReminderScreen(state.pathParameters['id']!),
              ),
            ),
          ],
        SuiteBranch.notas => [
            detail(
              ':id',
              redirect: (context, state) => lookupOrRoot(
                SuiteRecordLookup.note(
                  context.read<NotasState>(),
                  state.pathParameters['id']!,
                ),
                SuiteApp.notas,
              ),
              pageBuilder: (context, state) => SuiteRoutePages.nota(
                state.pathParameters['id']!,
                key: state.pageKey,
              ),
            ),
          ],
      };

  // `/desbloquear`: fuera del shell, para que ni el chat ni ninguna app se
  // construyan antes del PIN. Si cancela, la vista se queda con un botón
  // para reintentar (no hay adónde ir con la app bloqueada).
  final unlockRoute = GoRoute(
    path: SuiteRoutes.desbloquearPath,
    redirect: (context, state) {
      final next = SuiteRoutes.safeNext(state.uri.queryParameters['siguiente']);
      final locked = suiteLocked(context);
      String? decide(bool isLocked) => isLocked ? null : next;
      return locked is bool ? decide(locked) : locked.then(decide);
    },
    pageBuilder: (context, state) {
      final next = SuiteRoutes.safeNext(state.uri.queryParameters['siguiente']);
      return NoTransitionPage<void>(
        key: state.pageKey,
        child: SuiteUnlockView(
          onUnlocked: () {
            lock?.unlock();
            GoRouter.of(context).go(next);
          },
        ),
      );
    },
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: lock,
    redirect: (context, state) {
      if (state.uri.path == SuiteRoutes.desbloquearPath) return null;
      final locked = suiteLocked(context);
      String? decide(bool isLocked) =>
          isLocked ? SuiteRoutes.desbloquear(state.uri.toString()) : null;
      return locked is bool ? decide(locked) : locked.then(decide);
    },
    onException: (context, state, router) {
      router.go(SuiteRoutes.home);
      noticeAfterFrame(suitePaginaNoExiste);
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ResponsiveSuiteScaffold(navigationShell: navigationShell),
        branches: [
          for (final branch in SuiteBranch.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: branch.path,
                  name: branch.name,
                  builder: (context, state) => screenFor(branch),
                  routes: detailsOf(branch),
                ),
              ],
            ),
        ],
      ),
      unlockRoute,
    ],
  );
}

/// Pantalla de `/recordatorios/:id`: la lista con ese recordatorio resaltado.
Widget suiteHighlightedReminderScreen(String reminderId) =>
    RemindersHomeScreen(highlightReminderId: reminderId);

/// Lleva a [path] con un aviso al montarse (registro que ya no está).
class _SuiteGoTo extends StatefulWidget {
  const _SuiteGoTo({required this.path, required this.notice});

  final String path;
  final String notice;

  @override
  State<_SuiteGoTo> createState() => _SuiteGoToState();
}

class _SuiteGoToState extends State<_SuiteGoTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showOrtizNotice(context, widget.notice);
      GoRouter.of(context).go(widget.path);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
