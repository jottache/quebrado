// Riel fijo de la suite en ventanas ≥ 840 (spec 02, paso 4;
// docs/design/ortiz-home.md §4). Mismas entradas que el menú ☰, sin
// descripciones; la app activa va resaltada y desplegada; al pasar el cursor
// aparece «Abrir {App}» para ir sin desplegar.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/suite_apps.dart';
import 'responsive_breakpoints.dart';
import 'suite_actions.dart';
import 'suite_menu_parts.dart';

/// Riel de la izquierda: `OrtizSize.railWidth` (`railWidthExpanded` desde
/// 1200), fondo `bg` y línea `line` a la derecha.
class SuiteRail extends StatefulWidget {
  const SuiteRail({
    super.key,
    required this.onOpenOrtiz,
    required this.onOpenApp,
    required this.onViewRecord,
    this.selectedApp,
    this.onSearch,
    this.onOpenHistory,
    this.onOpenCalculator,
    this.onSync,
    this.onOpenSettings,
    this.selectedAppExtra,
  });

  /// App de la ruta actual (resaltada y desplegada); null en `/` (resalta
  /// «Ortiz»).
  final SuiteApp? selectedApp;

  /// Contenido fijo bajo la app activa (las pestañas de Finanzas).
  final Widget? selectedAppExtra;

  /// «Ortiz»: ir a `/`.
  final VoidCallback onOpenOrtiz;

  /// «Abrir {App}» (subfila o botón al pasar el cursor): ir a `app.route`.
  final ValueChanged<SuiteApp> onOpenApp;

  /// «Ver» del aviso tras guardar: ir a la ruta del registro.
  final SuiteNavigate onViewRecord;

  /// Pie. Cada fila sale solo si su callback no es null. «Buscar» abre la
  /// paleta (`Ctrl/⌘+K`).
  final VoidCallback? onSearch;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onSync;
  final VoidCallback? onOpenSettings;

  @override
  State<SuiteRail> createState() => _SuiteRailState();
}

class _SuiteRailState extends State<SuiteRail> {
  late SuiteApp? _expanded = widget.selectedApp;

  @override
  void didUpdateWidget(SuiteRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de app, se despliega la nueva (y se pliega la anterior).
    if (oldWidget.selectedApp != widget.selectedApp) {
      _expanded = widget.selectedApp;
    }
  }

  void _toggle(SuiteApp app) =>
      setState(() => _expanded = _expanded == app ? null : app);

  static String get _searchShortcut =>
      defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? '⌘ K'
          : 'Ctrl K';

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final width = ResponsiveBreakpoints.isExpanded(context)
        ? OrtizSize.railWidthExpanded
        : OrtizSize.railWidth;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.bg,
          border: Border(
            right: BorderSide(color: t.line, width: OrtizStroke.hairline),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            right: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    OrtizSpace.sm,
                    OrtizSpace.md,
                    OrtizSpace.sm,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SuiteMenuEntries(
                      expandedApp: _expanded,
                      selectedApp: widget.selectedApp,
                      ortizSelected: widget.selectedApp == null,
                      showDescription: false,
                      hoverOpenButton: true,
                      selectedAppExtra: widget.selectedAppExtra,
                      onToggle: _toggle,
                      onOpenOrtiz: widget.onOpenOrtiz,
                      onOpenApp: widget.onOpenApp,
                      onAction: (action) => runSuiteAction(
                        context,
                        action,
                        onView: widget.onViewRecord,
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      OrtizSpace.sm,
                      OrtizSpace.lg,
                      OrtizSpace.sm,
                      OrtizSpace.sm,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(),
                        SuiteMenuFooter(
                          onSearch: widget.onSearch,
                          searchShortcutLabel: _searchShortcut,
                          onOpenHistory: widget.onOpenHistory,
                          onOpenCalculator: widget.onOpenCalculator,
                          onSync: widget.onSync,
                          onOpenSettings: widget.onOpenSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
