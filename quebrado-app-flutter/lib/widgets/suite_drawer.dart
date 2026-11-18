// Menú ☰ de la suite en ventanas < 840 (spec 02, paso 4;
// docs/design/ortiz-home.md §3). Acordeón: «Ortiz» primero y una entrada por
// app; abrir una pliega la otra; cada app muestra «Abrir {App}» y sus
// acciones rápidas (catálogo `suite_actions.dart`).
import 'package:flutter/material.dart';

import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import '../theme/suite_apps.dart';
import 'suite_actions.dart';
import 'suite_menu_parts.dart';

/// `Drawer` del shell en compact. Pensado para `Scaffold.drawer`: al elegir
/// algo, primero se cierra el menú y luego se navega o se abre el formulario
/// (sobre el contexto del `Scaffold`, que sigue montado).
class SuiteDrawer extends StatefulWidget {
  const SuiteDrawer({
    super.key,
    required this.onOpenOrtiz,
    required this.onOpenApp,
    required this.onViewRecord,
    this.currentApp,
    this.onOpenHistory,
    this.onOpenCalculator,
    this.onSync,
    this.onOpenSettings,
  });

  /// App de la ruta actual (desplegada al abrir); null si se está en `/`.
  final SuiteApp? currentApp;

  /// «Ortiz»: ir a `/`.
  final VoidCallback onOpenOrtiz;

  /// «Abrir {App}»: ir a `app.route`.
  final ValueChanged<SuiteApp> onOpenApp;

  /// «Ver» del aviso tras guardar: ir a la ruta del registro.
  final SuiteNavigate onViewRecord;

  /// Pie. Cada fila sale solo si su callback no es null.
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onSync;
  final VoidCallback? onOpenSettings;

  @override
  State<SuiteDrawer> createState() => _SuiteDrawerState();
}

class _SuiteDrawerState extends State<SuiteDrawer> {
  late SuiteApp? _expanded = widget.currentApp;

  void _toggle(SuiteApp app) =>
      setState(() => _expanded = _expanded == app ? null : app);

  /// Cierra el drawer si está abierto en un `Scaffold`.
  void _close() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  }

  /// Cierra el menú y luego ejecuta [then].
  void _closeThen(VoidCallback? then) {
    _close();
    then?.call();
  }

  void _runAction(SuiteAction action) {
    // El contexto del drawer se desmonta al cerrarse: el formulario y el
    // aviso van sobre el del Scaffold que lo contiene.
    final host = Scaffold.maybeOf(context)?.context ?? context;
    _close();
    runSuiteAction(host, action, onView: widget.onViewRecord);
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return Drawer(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OrtizSpace.lg,
                  OrtizSpace.sm,
                  OrtizSpace.xs,
                  OrtizSpace.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'OrtizApp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OrtizType.title.copyWith(color: t.fg),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar menú',
                      onPressed: _close,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
              sliver: SliverToBoxAdapter(
                child: SuiteMenuEntries(
                  expandedApp: _expanded,
                  selectedApp: widget.currentApp,
                  ortizSelected: widget.currentApp == null,
                  onToggle: _toggle,
                  onOpenOrtiz: () => _closeThen(widget.onOpenOrtiz),
                  onOpenApp: (app) => _closeThen(() => widget.onOpenApp(app)),
                  onAction: _runAction,
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
                      onOpenHistory: _wrap(widget.onOpenHistory),
                      onOpenCalculator: _wrap(widget.onOpenCalculator),
                      onSync: _wrap(widget.onSync),
                      onOpenSettings: _wrap(widget.onOpenSettings),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _wrap(VoidCallback? cb) =>
      cb == null ? null : () => _closeThen(cb);
}
