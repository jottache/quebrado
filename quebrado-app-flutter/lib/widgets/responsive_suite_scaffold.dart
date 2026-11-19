// Shell de la suite (spec 02, pasos 3b y 4; diseño en docs/design/rutas.md §3
// y docs/design/ortiz-home.md §3–§5 y §10).
//
// Envuelve el `StatefulNavigationShell` de go_router:
// - `< 840` (`!isDesktop`): `Scaffold` con el menú ☰ (`SuiteDrawer`); cada
//   app conserva su propia barra.
// - `≥ 840`: riel fijo (`SuiteRail`) a la izquierda y la rama activa a la
//   derecha. Bajo Finanzas, el riel muestra sus pestañas (en escritorio
//   Finanzas no tiene barra inferior).
// Al pie del menú y del riel: Conversaciones anteriores, Calculadora y
// Sincronizar (P-05) y Ajustes (Q5). El riel añade «Buscar» (paleta).
//
// La paleta `Ctrl/⌘+K` (PA-02) y los atajos (`SuiteShortcuts`, CA-10) viven
// aquí. `SuiteShellScope` expone a los descendientes la rama activa,
// `goBranch`, `openMenu`, `openPalette` y el `FocusNode` del campo del chat
// (para el atajo `/`).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../agente/agente.dart';
import '../agente/dialogs/agente_settings_dialog.dart';
import '../diario/diario.dart';
import '../habitos/habitos.dart';
import '../notas/notas.dart';
import '../quebrado/dialogs/calculator_dialog.dart';
import '../quebrado/screens/settings_screen.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../recordatorios/recordatorios.dart';
import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import '../theme/suite_apps.dart';
import 'ortiz/ortiz.dart';
import 'responsive_breakpoints.dart';
import 'responsive_sheet_helper.dart';
import 'suite_actions.dart';
import 'suite_command_palette.dart';
import 'suite_drawer.dart';
import 'suite_menu_parts.dart' show suiteAppDescription;
import 'suite_rail.dart';
import 'suite_router.dart';
import 'suite_shortcuts.dart';

/// Aviso cuando «Sincronizar» falla en alguna app.
const String suiteSyncErrorNotice =
    'No pude sincronizar la suite. Revisa tu conexión e inténtalo de nuevo.';

/// Pestañas de Finanzas que el riel muestra bajo su entrada cuando Finanzas
/// es la app activa (`AppState.currentTabIndex`).
const List<({String label, IconData icon})> _finanzasTabs = [
  (label: 'Dashboard', icon: Icons.grid_view_rounded),
  (label: 'Bolsillos', icon: Icons.inventory_2_rounded),
  (label: 'Historial', icon: Icons.receipt_long_rounded),
  (label: 'Mercado', icon: Icons.shopping_cart_outlined),
];

/// Etiqueta, icono y color de cada rama en el menú y la paleta.
({String label, IconData icon, Color color}) suiteBranchDestination(
  SuiteBranch branch,
) {
  final app = branch.app;
  if (app == null) {
    return (
      label: 'Ortiz',
      icon: Icons.auto_awesome_rounded,
      color: AgenteColors.primary,
    );
  }
  return (label: app.label, icon: app.icon, color: app.color);
}

/// Entradas de la paleta `Ctrl/⌘+K` (ortiz-home.md §5):
/// - **Apps:** «Ortiz» y una por rama (navegan con [goBranch]);
/// - **Acciones rápidas:** todo [suiteActions] (las ejecuta [runAction]);
///   «Tasas del día» sale aquí, como acción de Finanzas (P-05);
/// - **Ortiz:** «Nueva conversación» y, si hay callback, «Conversaciones
///   anteriores» y «Ajustes».
List<PaletteEntry> suitePaletteEntries({
  required ValueChanged<SuiteBranch> goBranch,
  required ValueChanged<SuiteAction> runAction,
  required VoidCallback onNewConversation,
  VoidCallback? onOpenHistory,
  VoidCallback? onOpenSettings,
}) {
  return [
    for (final branch in SuiteBranch.values)
      PaletteEntry(
        title: suiteBranchDestination(branch).label,
        section: PaletteSection.apps,
        icon: suiteBranchDestination(branch).icon,
        color: suiteBranchDestination(branch).color,
        keywords: branch.app == null
            ? 'inicio chat conversación'
            : suiteAppDescription(branch.app!),
        onSelected: () => goBranch(branch),
      ),
    for (final action in suiteActions)
      PaletteEntry(
        title: action.label,
        section: PaletteSection.actions,
        icon: action.icon,
        color: action.app.color,
        appLabel: action.app.label,
        keywords: action.keywords,
        onSelected: () => runAction(action),
      ),
    PaletteEntry(
      title: 'Nueva conversación',
      section: PaletteSection.ortiz,
      icon: Icons.add_comment_outlined,
      keywords: 'chat charla',
      onSelected: onNewConversation,
    ),
    if (onOpenHistory != null)
      PaletteEntry(
        title: 'Conversaciones anteriores',
        section: PaletteSection.ortiz,
        icon: Icons.history_rounded,
        keywords: 'historial charlas',
        onSelected: onOpenHistory,
      ),
    if (onOpenSettings != null)
      PaletteEntry(
        title: 'Ajustes',
        section: PaletteSection.ortiz,
        icon: Icons.settings_outlined,
        keywords: 'configuración clave pin',
        onSelected: onOpenSettings,
      ),
  ];
}

/// Datos del shell para sus descendientes (botón ☰, riel, drawer, inicio).
class SuiteShellScope extends InheritedWidget {
  const SuiteShellScope({
    super.key,
    required this.currentBranch,
    required this.goBranch,
    required this.openMenu,
    required this.openPalette,
    required this.chatFocusNode,
    required super.child,
  });

  /// Rama visible.
  final SuiteBranch currentBranch;

  /// Abre [SuiteBranch]; si ya es la activa, la lleva a su raíz.
  final ValueChanged<SuiteBranch> goBranch;

  /// Abre el drawer (`< 840`). En `≥ 840` no hace nada: el riel es fijo.
  final VoidCallback openMenu;

  /// Abre la paleta `Ctrl/⌘+K`.
  final VoidCallback openPalette;

  /// Foco del campo del chat de Ortiz. La pantalla de inicio lo pasa a su
  /// campo (`OrtizHomeScreen.chatFocusNode`); el atajo `/` lo enfoca. Es del
  /// shell: quien lo usa no lo libera.
  final FocusNode chatFocusNode;

  static SuiteShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuiteShellScope>();

  @override
  bool updateShouldNotify(SuiteShellScope oldWidget) =>
      oldWidget.currentBranch != currentBranch ||
      oldWidget.chatFocusNode != chatFocusNode;
}

class ResponsiveSuiteScaffold extends StatefulWidget {
  const ResponsiveSuiteScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ResponsiveSuiteScaffold> createState() =>
      _ResponsiveSuiteScaffoldState();
}

class _ResponsiveSuiteScaffoldState extends State<ResponsiveSuiteScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'suiteShell');
  final FocusNode _chatFocusNode = FocusNode(debugLabel: 'ortizChat');
  bool _paletteOpen = false;

  SuiteBranch get _current =>
      SuiteBranch.values[widget.navigationShell.currentIndex];

  @override
  void dispose() {
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _goBranch(SuiteBranch branch) {
    final shell = widget.navigationShell;
    shell.goBranch(
      branch.index,
      initialLocation: branch.index == shell.currentIndex,
    );
  }

  void _openApp(SuiteApp app) => _goBranch(SuiteBranch.forApp(app));

  void _goHome() => _goBranch(SuiteBranch.inicio);

  void _go(String path) {
    if (mounted) GoRouter.of(context).go(path);
  }

  void _openMenu() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.hasDrawer) scaffold.openDrawer();
  }

  void _runAction(SuiteAction action) =>
      runSuiteAction(context, action, onView: _go);

  void _openCalculator() {
    showResponsiveSheet(
      context: context,
      builder: (_) => const CalculatorBottomSheet(),
    );
  }

  Future<void> _syncSuite() async {
    final appState = context.read<AppState>();
    final diarioState = context.read<DiarioState>();
    final habitosState = context.read<HabitosState>();
    final remindersState = context.read<RemindersState>();
    final notasState = context.read<NotasState>();
    showOrtizNotice(context, 'Sincronizando la suite…');
    try {
      await Future.wait([
        appState.loadData(forceReload: true),
        appState.refreshRates(),
        diarioState.loadAll(),
        habitosState.loadHabits(),
        remindersState.reload(),
        notasState.loadAll(),
      ]);
    } catch (e) {
      debugPrint('Suite: error al sincronizar ($e)');
      if (mounted) showOrtizNotice(context, suiteSyncErrorNotice);
      return;
    }
    if (mounted) {
      showOrtizNotice(context, 'Suite sincronizada', success: true);
    }
  }

  /// Abre [page] como en las apps: panel lateral en `≥ 840` y pantalla
  /// completa en `< 840`.
  void _openPage(Widget page) {
    if (ResponsiveBreakpoints.isDesktop(context)) {
      showResponsiveSheet(context: context, builder: (_) => page);
    } else {
      Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute<void>(builder: (_) => page));
    }
  }

  /// «Conversaciones anteriores»: la lista de charlas existente del Agente.
  void _openHistory() => _openPage(const AgenteHomeScreen());

  /// «Ajustes» (Q5): elige entre los ajustes existentes de Ortiz y de
  /// Finanzas.
  Future<void> _openSettings() async {
    final choice = await showDialog<_SettingsChoice>(
      context: context,
      builder: (_) => const _SuiteSettingsDialog(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _SettingsChoice.ortiz:
        await showDialog<void>(
          context: context,
          builder: (_) => const AgenteSettingsDialog(),
        );
      case _SettingsChoice.finanzas:
        final app = context.read<AppState>();
        // Con PIN o biometría, los ajustes de Finanzas (PIN, respaldos) se
        // abren desde Finanzas, detrás de su desbloqueo (P-04).
        if (app.usePinSecurity || app.useBiometrics) {
          _openApp(SuiteApp.finanzas);
        } else {
          _openPage(const SettingsScreen());
        }
    }
  }

  /// «Nueva conversación»: va a `/`, empieza una charla si la actual tiene
  /// mensajes y pone el foco en el campo.
  Future<void> _newConversation() async {
    _goHome();
    final agente = context.read<AgenteState>();
    if (agente.messages.isNotEmpty) await agente.startNewSession();
    if (mounted) _focusChatSoon();
  }

  /// «Pregúntale a Ortiz»: va a `/` y envía la búsqueda al chat.
  void _askOrtiz(String question) {
    _goHome();
    context.read<AgenteState>().sendMessage(question);
  }

  /// Pide el foco del chat tras el cambio de rama (el campo puede montarse
  /// en este mismo frame).
  void _focusChatSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chatFocusNode.context != null) {
        _chatFocusNode.requestFocus();
      }
    });
  }

  Future<void> _openPalette() async {
    if (_paletteOpen) return;
    _paletteOpen = true;
    try {
      await showSuiteCommandPalette(
        context,
        entries: suitePaletteEntries(
          goBranch: _goBranch,
          runAction: _runAction,
          onNewConversation: _newConversation,
          onOpenHistory: _openHistory,
          onOpenSettings: _openSettings,
        ),
        onAskOrtiz: GeminiConfig.isConfigured ? _askOrtiz : null,
      );
    } finally {
      _paletteOpen = false;
    }
  }

  /// `/`: solo en el inicio y con el campo del chat montado.
  bool _onSlash() {
    if (_current != SuiteBranch.inicio || _chatFocusNode.context == null) {
      return false;
    }
    _chatFocusNode.requestFocus();
    return true;
  }

  /// `Esc`: cierra el drawer o, si no, quita el foco del chat.
  bool _onEscape() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return true;
    }
    if (_chatFocusNode.hasFocus) {
      _chatFocusNode.unfocus();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final current = _current;
    final currentApp = current.app;

    final Widget body;
    if (isDesktop) {
      body = Row(
        children: [
          SuiteRail(
            selectedApp: currentApp,
            onOpenOrtiz: _goHome,
            onOpenApp: _openApp,
            onViewRecord: _go,
            onSearch: _openPalette,
            onOpenHistory: _openHistory,
            onOpenCalculator: _openCalculator,
            onSync: _syncSuite,
            onOpenSettings: _openSettings,
            selectedAppExtra: currentApp == SuiteApp.finanzas
                ? const _FinanzasTabs()
                : null,
          ),
          Expanded(child: widget.navigationShell),
        ],
      );
    } else {
      body = widget.navigationShell;
    }

    return SuiteShellScope(
      currentBranch: current,
      goBranch: _goBranch,
      openMenu: _openMenu,
      openPalette: _openPalette,
      chatFocusNode: _chatFocusNode,
      child: SuiteShortcuts(
        onTogglePalette: _openPalette,
        onFocusChat: _onSlash,
        onEscape: _onEscape,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: isDesktop
              ? null
              : SuiteDrawer(
                  currentApp: currentApp,
                  onOpenOrtiz: _goHome,
                  onOpenApp: _openApp,
                  onViewRecord: _go,
                  onOpenHistory: _openHistory,
                  onOpenCalculator: _openCalculator,
                  onSync: _syncSuite,
                  onOpenSettings: _openSettings,
                ),
          body: body,
        ),
      ),
    );
  }
}

enum _SettingsChoice { ortiz, finanzas }

/// «Ajustes» del pie: los ajustes existentes de Ortiz y de Finanzas
/// (ortiz-home.md §11).
class _SuiteSettingsDialog extends StatelessWidget {
  const _SuiteSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Ajustes'),
      contentPadding: const EdgeInsets.all(OrtizSpace.sm),
      children: [
        OrtizListRow(
          leading: const Icon(Icons.auto_awesome_rounded),
          title: 'Ortiz',
          subtitle: 'Clave, modelo y atajos de consulta',
          onTap: () => Navigator.of(context).pop(_SettingsChoice.ortiz),
        ),
        OrtizListRow(
          leading: Icon(SuiteApp.finanzas.icon, color: SuiteApp.finanzas.color),
          title: SuiteApp.finanzas.label,
          subtitle: 'PIN, respaldos y libros',
          onTap: () => Navigator.of(context).pop(_SettingsChoice.finanzas),
        ),
      ],
    );
  }
}

/// Pestañas de Finanzas bajo su entrada del riel.
class _FinanzasTabs extends StatelessWidget {
  const _FinanzasTabs();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.only(left: OrtizSpace.xl, bottom: OrtizSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _finanzasTabs.length; i++)
            _TabRow(
              label: _finanzasTabs[i].label,
              icon: _finanzasTabs[i].icon,
              selected: appState.currentTabIndex == i,
              onTap: () => appState.setTabIndex(i),
            ),
        ],
      ),
    );
  }
}

/// Fila de pestaña: la activa va sobre `surfaceHigh` con el icono en el color
/// de Finanzas.
class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final radius = BorderRadius.circular(OrtizRadius.chip);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? t.surfaceHigh : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: OrtizIconSize.sm,
                    color: selected ? SuiteApp.finanzas.color : t.muted,
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OrtizType.bodySm.copyWith(
                        color: selected ? t.fg : t.muted,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
