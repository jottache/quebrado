// Piezas compartidas del menú ☰ (`SuiteDrawer`) y del riel (`SuiteRail`)
// (spec 02, paso 4; docs/design/ortiz-home.md §3–§4 y §10).
//
// - [SuiteMenuOrtizRow]: la fila «Ortiz» (lleva a `/`).
// - [SuiteMenuAppEntry]: una app en acordeón con «Abrir {App}» y sus acciones.
// - [SuiteMenuRow]: fila simple de 48 (subfilas y pie).
// - [SuiteMenuFooter]: el pie común (Buscar, Conversaciones, Calculadora,
//   Sincronizar, Ajustes).
import 'package:flutter/material.dart';

import '../agente/widgets/ortiz_face.dart';
import '../theme/ortiz_motion.dart';
import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import '../theme/suite_apps.dart';
import 'suite_actions.dart';

/// Descripción corta de cada app en el menú ☰ (§3).
String suiteAppDescription(SuiteApp app) => switch (app) {
      SuiteApp.finanzas => 'Cuentas, bolsillos y pagos',
      SuiteApp.diario => 'Entradas, contactos y ánimo',
      SuiteApp.habitos => 'Rachas de hoy',
      SuiteApp.recordatorios => 'Agenda y matriz Covey',
      SuiteApp.notas => 'Notas y acuerdos',
    };

/// Sangría de las subfilas: alinea su icono con el nombre de la app.
const double _subRowIndent = OrtizSpace.md + OrtizIconSize.xl + OrtizSpace.md;

/// Fila «Ortiz» del menú y del riel: cara pequeña + «Ortiz».
class SuiteMenuOrtizRow extends StatelessWidget {
  const SuiteMenuOrtizRow({
    super.key,
    required this.selected,
    required this.onTap,
  });

  /// Si `/` es la ruta actual (fondo `surfaceHigh`).
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return _Highlight(
      active: selected,
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OrtizSpace.md,
                vertical: OrtizSpace.sm,
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: OrtizIconSize.xl,
                    // Cara quieta: la única animada es la de la barra o el
                    // saludo (ortiz-home.md §2.4).
                    child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: const Center(
                        child: OrtizFace(
                          mood: OrtizMood.idle,
                          size: OrtizIconSize.lg,
                          followPointer: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Text(
                      'Ortiz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OrtizType.titleSm.copyWith(color: t.fg),
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

/// Una app en acordeón: cabecera (cuadro de color, nombre, descripción
/// opcional y chevron) y, abierta, «Abrir {App}» y sus acciones.
class SuiteMenuAppEntry extends StatefulWidget {
  const SuiteMenuAppEntry({
    super.key,
    required this.app,
    required this.expanded,
    required this.onToggle,
    required this.onOpenApp,
    required this.onAction,
    this.selected = false,
    this.showDescription = true,
    this.hoverOpenButton = false,
  });

  final SuiteApp app;

  /// Si está desplegada.
  final bool expanded;

  /// App de la ruta actual (fondo `surfaceHigh`, nombre en `fg`).
  final bool selected;

  /// Muestra la descripción bajo el nombre (menú ☰; el riel no la lleva).
  final bool showDescription;

  /// Riel: el chevron solo se ve activo/con foco/hover y, al pasar el
  /// cursor, aparece un botón «Abrir {App}» a la derecha.
  final bool hoverOpenButton;

  final VoidCallback onToggle;
  final VoidCallback onOpenApp;
  final ValueChanged<SuiteAction> onAction;

  @override
  State<SuiteMenuAppEntry> createState() => _SuiteMenuAppEntryState();
}

class _SuiteMenuAppEntryState extends State<SuiteMenuAppEntry> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final app = widget.app;
    final openLabel = 'Abrir ${app.label}';
    final motion = OrtizMotion.of(context, OrtizMotion.base);
    final showChevron = !widget.hoverOpenButton ||
        widget.selected ||
        widget.expanded ||
        _hovered ||
        _focused;

    final header = Semantics(
      button: true,
      expanded: widget.expanded,
      selected: widget.selected,
      child: InkWell(
        onTap: widget.onToggle,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OrtizSpace.md,
              vertical: OrtizSpace.sm,
            ),
            child: Row(
              children: [
                _AppBadge(app: app),
                const SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        app.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OrtizType.titleSm.copyWith(color: t.fg),
                      ),
                      if (widget.showDescription)
                        Text(
                          suiteAppDescription(app),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OrtizType.caption.copyWith(color: t.muted),
                        ),
                    ],
                  ),
                ),
                if (widget.hoverOpenButton && _hovered)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    iconSize: OrtizIconSize.md,
                    color: t.muted,
                    tooltip: openLabel,
                    onPressed: widget.onOpenApp,
                  ),
                Visibility(
                  visible: showChevron,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: AnimatedRotation(
                    turns: widget.expanded ? 0.25 : 0,
                    duration: motion,
                    curve: OrtizMotion.ease,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: OrtizIconSize.md,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final body = AnimatedSize(
      duration: motion,
      curve: OrtizMotion.ease,
      alignment: Alignment.topCenter,
      child: widget.expanded
          ? Padding(
              padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SuiteMenuRow(
                    icon: Icons.arrow_forward_rounded,
                    label: openLabel,
                    indent: _subRowIndent,
                    onTap: widget.onOpenApp,
                  ),
                  for (final action in suiteActionsFor(app))
                    SuiteMenuRow(
                      key: ValueKey('suite-action-${action.id}'),
                      icon: action.icon,
                      label: action.label,
                      indent: _subRowIndent,
                      onTap: () => widget.onAction(action),
                    ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _Highlight(
        active: widget.expanded || widget.selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        ),
      ),
    );
  }
}

/// Fila simple de 48: icono `muted` + texto `body` `muted` que pasa a `fg`
/// con hover o foco. Se usa en las subfilas del acordeón y en el pie.
class SuiteMenuRow extends StatefulWidget {
  const SuiteMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.indent = OrtizSpace.md,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Margen izquierdo del icono.
  final double indent;

  /// Widget opcional a la derecha (p. ej. el distintivo «Ctrl K»).
  final Widget? trailing;

  @override
  State<SuiteMenuRow> createState() => _SuiteMenuRowState();
}

class _SuiteMenuRowState extends State<SuiteMenuRow> {
  bool _lit = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final color = _lit || _focused ? t.fg : t.muted;
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _lit = v),
      onFocusChange: (v) => setState(() => _focused = v),
      borderRadius: BorderRadius.circular(OrtizRadius.block),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
        child: Padding(
          padding: EdgeInsets.only(left: widget.indent, right: OrtizSpace.md),
          child: Row(
            children: [
              Icon(widget.icon, size: OrtizIconSize.md, color: t.muted),
              const SizedBox(width: OrtizSpace.md),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OrtizType.body.copyWith(color: color),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: OrtizSpace.sm),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pie común del menú y del riel. Cada fila sale solo si tiene callback.
class SuiteMenuFooter extends StatelessWidget {
  const SuiteMenuFooter({
    super.key,
    this.onSearch,
    this.searchShortcutLabel,
    this.onOpenHistory,
    this.onOpenCalculator,
    this.onSync,
    this.onOpenSettings,
  });

  final VoidCallback? onSearch;

  /// Distintivo junto a «Buscar» («Ctrl K» / «⌘ K»).
  final String? searchShortcutLabel;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onSync;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final shortcut = searchShortcutLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSearch != null)
          SuiteMenuRow(
            icon: Icons.search_rounded,
            label: 'Buscar',
            onTap: onSearch!,
            trailing: shortcut == null
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OrtizSpace.xs,
                        vertical: OrtizSpace.xxs,
                      ),
                      child: Text(
                        shortcut,
                        style: OrtizType.caption.copyWith(color: t.muted),
                      ),
                    ),
                  ),
          ),
        if (onOpenHistory != null)
          SuiteMenuRow(
            icon: Icons.history_rounded,
            label: 'Conversaciones anteriores',
            onTap: onOpenHistory!,
          ),
        if (onOpenCalculator != null)
          SuiteMenuRow(
            icon: Icons.calculate_outlined,
            label: 'Calculadora',
            onTap: onOpenCalculator!,
          ),
        if (onSync != null)
          SuiteMenuRow(
            icon: Icons.sync_rounded,
            label: 'Sincronizar',
            onTap: onSync!,
          ),
        if (onOpenSettings != null)
          SuiteMenuRow(
            icon: Icons.settings_outlined,
            label: 'Ajustes',
            onTap: onOpenSettings!,
          ),
      ],
    );
  }
}

/// Lista de entradas del menú (Ortiz + una por app) con acordeón de una sola
/// app abierta. La comparten el drawer y el riel.
class SuiteMenuEntries extends StatelessWidget {
  const SuiteMenuEntries({
    super.key,
    required this.expandedApp,
    required this.onToggle,
    required this.ortizSelected,
    required this.onOpenOrtiz,
    required this.onOpenApp,
    required this.onAction,
    this.selectedApp,
    this.showDescription = true,
    this.hoverOpenButton = false,
    this.selectedAppExtra,
  });

  final SuiteApp? expandedApp;
  final SuiteApp? selectedApp;

  /// Contenido fijo bajo la app activa (p. ej. las pestañas de Finanzas en el
  /// riel, que en escritorio no tiene barra inferior).
  final Widget? selectedAppExtra;
  final bool ortizSelected;
  final ValueChanged<SuiteApp> onToggle;
  final VoidCallback onOpenOrtiz;
  final ValueChanged<SuiteApp> onOpenApp;
  final ValueChanged<SuiteAction> onAction;
  final bool showDescription;
  final bool hoverOpenButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuiteMenuOrtizRow(selected: ortizSelected, onTap: onOpenOrtiz),
        for (final app in SuiteApp.values) ...[
          SuiteMenuAppEntry(
            key: ValueKey('suite-app-${app.name}'),
            app: app,
            expanded: expandedApp == app,
            selected: selectedApp == app,
            showDescription: showDescription,
            hoverOpenButton: hoverOpenButton,
            onToggle: () => onToggle(app),
            onOpenApp: () => onOpenApp(app),
            onAction: onAction,
          ),
          if (selectedApp == app && selectedAppExtra != null) selectedAppExtra!,
        ],
      ],
    );
  }
}

/// Cuadro de 32 con el tint de la app y su icono en su color.
class _AppBadge extends StatelessWidget {
  const _AppBadge({required this.app});

  final SuiteApp app;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: OrtizIconSize.xl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: app.tint,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        child: Icon(app.icon, size: OrtizIconSize.md, color: app.color),
      ),
    );
  }
}

/// Fondo `surfaceHigh` con radio `block` para la fila activa o abierta.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xxs),
      child: Material(
        color: active ? t.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
