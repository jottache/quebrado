import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'responsive_breakpoints.dart';
import 'responsive_sheet_helper.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../quebrado/theme/colors.dart';
import '../diario/diario.dart';
import '../habitos/habitos.dart';
import '../recordatorios/recordatorios.dart';
import '../agente/agente.dart';
import '../notas/notas.dart';
import '../quebrado/screens/main_screen.dart';
import '../quebrado/dialogs/calculator_dialog.dart';
import '../quebrado/dialogs/add_transaction_dialog.dart';
import '../quebrado/models/transaction.dart';
import '../screens/launcher_action_hub_view.dart';
import '../screens/app_launcher_screen.dart';
import 'desktop_command_center_view.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
enum SuiteModule {
  commandCenter,
  quebrado,
  diario,
  habitos,
  recordatorios,
  agente,
  notas,
}

class ResponsiveSuiteScaffold extends StatefulWidget {
  final Widget? mobileBody;

  const ResponsiveSuiteScaffold({
    super.key,
    this.mobileBody,
  });

  @override
  State<ResponsiveSuiteScaffold> createState() => _ResponsiveSuiteScaffoldState();
}

class _ResponsiveSuiteScaffoldState extends State<ResponsiveSuiteScaffold> {
  SuiteModule _currentModule = SuiteModule.commandCenter;

  void _selectModule(SuiteModule module) {
    if (_currentModule != module) {
      setState(() {
        _currentModule = module;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    // En pantallas compactas/móviles, devolver el launcher tradicional
    if (!isDesktop) {
      return widget.mobileBody ?? const AppLauncherScreen();
    }

    final isExpanded = ResponsiveBreakpoints.isExpanded(context);
    final effectiveSidebarWidth = isExpanded ? 240.0 : 210.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar de navegación Desktop
          SizedBox(
            width: effectiveSidebarWidth,
            child: _buildDesktopSidebar(context, effectiveSidebarWidth),
          ),

          // Divisor vertical
          const VerticalDivider(
            width: OrtizStroke.hairline,
            thickness: OrtizStroke.hairline,
            color: OrtizPalette.line,
          ),

          // Área de contenido principal con estado persistente
          Expanded(
            child: Column(
              children: [
                // TopBar de Utilidades Desktop (Buscador, Sincronización, Calculadora, Tasas)
                _buildDesktopTopBar(context),
                const Divider(height: OrtizStroke.hairline, thickness: OrtizStroke.hairline, color: OrtizPalette.line),

                // Vista activa
                Expanded(
                  child: _buildActiveView(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, double width) {
    final appState = Provider.of<AppState>(context);

    // El menú lateral flota sobre `surface`.
    return Container(
      color: OrtizPalette.surface,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del Sidebar
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.lg),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: OrtizPalette.accent,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: const Center(
                      child: Text(
                        "O",
                        style: TextStyle(
                          color: OrtizPalette.onAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: OrtizFontSize.title,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OrtizApp",
                          style: TextStyle(
                            fontSize: OrtizFontSize.titleSm,
                            fontWeight: FontWeight.w900,
                            color: OrtizPalette.fg,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          "SUITE DESKTOP",
                          style: TextStyle(
                            fontSize: OrtizFontSize.micro,
                            fontWeight: FontWeight.w800,
                            color: OrtizPalette.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: OrtizStroke.hairline, thickness: OrtizStroke.hairline, color: OrtizPalette.line),
            const SizedBox(height: OrtizSpace.md),

            // Items de Navegación
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                children: [
                  _buildNavItem(
                    module: SuiteModule.commandCenter,
                    icon: Icons.dashboard_customize_rounded,
                    label: "Command Center",
                    shortcut: "⌘1",
                    color: OrtizPalette.accent,
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.quebrado,
                    icon: Icons.account_balance_wallet_rounded,
                    label: "Quebrado",
                    shortcut: "⌘2",
                    color: SuiteAppColors.finanzas,
                  ),
                  if (_currentModule == SuiteModule.quebrado) ...[
                    const SizedBox(height: OrtizSpace.xxs),
                    _buildSubNavItem(
                      label: "Dashboard",
                      icon: Icons.grid_view_rounded,
                      tabIndex: 0,
                      currentTabIndex: appState.currentTabIndex,
                      onTap: () {
                        _selectModule(SuiteModule.quebrado);
                        appState.setTabIndex(0);
                      },
                    ),
                    _buildSubNavItem(
                      label: "Bolsillos",
                      icon: Icons.inventory_2_rounded,
                      tabIndex: 1,
                      currentTabIndex: appState.currentTabIndex,
                      onTap: () {
                        _selectModule(SuiteModule.quebrado);
                        appState.setTabIndex(1);
                      },
                    ),
                    _buildSubNavItem(
                      label: "Historial",
                      icon: Icons.receipt_long_rounded,
                      tabIndex: 2,
                      currentTabIndex: appState.currentTabIndex,
                      onTap: () {
                        _selectModule(SuiteModule.quebrado);
                        appState.setTabIndex(2);
                      },
                    ),
                    _buildSubNavItem(
                      label: "Mercado",
                      icon: Icons.shopping_cart_outlined,
                      tabIndex: 3,
                      currentTabIndex: appState.currentTabIndex,
                      onTap: () {
                        _selectModule(SuiteModule.quebrado);
                        appState.setTabIndex(3);
                      },
                    ),
                    const SizedBox(height: OrtizSpace.xs),
                  ],
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.recordatorios,
                    icon: Icons.check_circle_outline_rounded,
                    label: "Recordatorios",
                    shortcut: "⌘3",
                    color: RemindersColors.primary,
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.habitos,
                    icon: Icons.local_fire_department_rounded,
                    label: "Hábitos",
                    shortcut: "⌘4",
                    color: HabitosColors.primary,
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.diario,
                    icon: Icons.auto_stories_rounded,
                    label: "Diario",
                    shortcut: "⌘5",
                    color: DiarioColors.primary,
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.agente,
                    icon: Icons.auto_awesome_rounded,
                    label: "Agente Ortiz",
                    shortcut: "⌘6",
                    color: AgenteColors.primary,
                  ),
                  const SizedBox(height: OrtizSpace.xs),
                  _buildNavItem(
                    module: SuiteModule.notas,
                    icon: Icons.edit_note_rounded,
                    label: "Notas & Acuerdos",
                    shortcut: "⌘7",
                    color: NotasColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrtizSpace.md),
          ],
        ),
      ),
    );
  }

  Widget _buildSubNavItem({
    required String label,
    required IconData icon,
    required int tabIndex,
    required int currentTabIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = tabIndex == currentTabIndex;
    const activeColor = SuiteAppColors.finanzas;

    return Padding(
      padding: const EdgeInsets.only(left: OrtizSpace.md, top: OrtizSpace.xxs, bottom: OrtizSpace.xxs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
            // Lo activo va sobre `surfaceHigh`; el color de la app marca el icono.
            decoration: BoxDecoration(
              color: isSelected ? OrtizPalette.surfaceHigh : Colors.transparent,
              borderRadius: BorderRadius.circular(OrtizRadius.chip),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: OrtizIconSize.sm,
                  color: isSelected ? activeColor : OrtizPalette.muted,
                ),
                const SizedBox(width: OrtizSpace.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? OrtizPalette.fg : OrtizPalette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required SuiteModule module,
    required IconData icon,
    required String label,
    required String shortcut,
    required Color color,
  }) {
    final isSelected = _currentModule == module;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectModule(module),
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
          // Lo activo va sobre `surfaceHigh`; el color de la app marca el icono.
          decoration: BoxDecoration(
            color: isSelected ? OrtizPalette.surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: OrtizIconSize.md,
                color: isSelected ? color : OrtizPalette.muted,
              ),
              const SizedBox(width: OrtizSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: OrtizFontSize.body,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: OrtizPalette.fg,
                  ),
                ),
              ),
              Text(
                shortcut,
                style: const TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.bold,
                  color: OrtizPalette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final habitosState = Provider.of<HabitosState>(context);
    final remindersState = Provider.of<RemindersState>(context);

    final bcv = appState.bcvRate > 0 ? appState.bcvRate.toStringAsFixed(2) : "--";
    final eur = appState.euroRate > 0 ? appState.euroRate.toStringAsFixed(2) : "--";

    return Container(
      height: 64,
      width: double.infinity,
      color: OrtizPalette.bg,
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Módulo actual y ticker de tasas
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getModuleTitle(_currentModule),
                        style: const TextStyle(
                          fontSize: OrtizFontSize.titleSm,
                          fontWeight: FontWeight.w900,
                          color: OrtizPalette.fg,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: OrtizSpace.lg),
                      // Ticker de Tasas BCV / Euro Oficial
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          border: Border.all(color: OrtizPalette.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded, size: OrtizIconSize.sm, color: OrtizPalette.ok),
                            const SizedBox(width: OrtizSpace.sm),
                            Text(
                              "BCV: Bs. $bcv",
                              style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: OrtizPalette.fg),
                            ),
                            const SizedBox(width: OrtizSpace.md),
                            Text(
                              "Euro Oficial: Bs. $eur",
                              style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: OrtizSpace.xl),

                  // Botones de acción directa a la derecha
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentModule == SuiteModule.commandCenter) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: OrtizPalette.accent,
                            foregroundColor: OrtizPalette.onAccent,
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                          ),
                          onPressed: () {
                            showResponsiveSheet(
                              context: context,
                              builder: (_) => const AddTransactionBottomSheet(
                                initialType: TransactionType.expense,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: OrtizIconSize.sm),
                          label: const Text(
                            "Nuevo Gasto",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.sm),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RemindersColors.primary,
                            side: const BorderSide(color: RemindersColors.primary, width: OrtizStroke.hairline),
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const ReminderEditorDialog(),
                            );
                          },
                          icon: const Icon(Icons.alarm_add_rounded, size: OrtizIconSize.sm),
                          label: const Text(
                            "Recordatorio",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.sm),
                      ],

                      IconButton(
                        icon: const Icon(Icons.calculate_outlined),
                        tooltip: "Calculadora de divisas",
                        style: IconButton.styleFrom(
                          backgroundColor: OrtizPalette.surfaceHigh,
                          foregroundColor: OrtizPalette.fg,
                        ),
                        onPressed: () {
                          showResponsiveSheet(
                            context: context,
                            builder: (context) => const CalculatorBottomSheet(),
                          );
                        },
                      ),
                      const SizedBox(width: OrtizSpace.sm),

                      IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        tooltip: "Sincronizar todos los datos",
                        style: IconButton.styleFrom(
                          backgroundColor: OrtizPalette.surfaceHigh,
                          foregroundColor: OrtizPalette.fg,
                        ),
                        onPressed: () async {
                          final notasState = Provider.of<NotasState>(context, listen: false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Sincronizando suite completa..."),
                              duration: Duration(milliseconds: 900),
                            ),
                          );
                          await Future.wait([
                            appState.loadData(forceReload: true),
                            appState.refreshRates(),
                            diarioState.loadAll(),
                            habitosState.loadHabits(),
                            remindersState.reload(),
                            notasState.loadAll(),
                          ]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Suite sincronizada correctamente",
                                  style: TextStyle(color: OrtizPalette.onAccent),
                                ),
                                backgroundColor: OrtizPalette.ok,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getModuleTitle(SuiteModule module) {
    switch (module) {
      case SuiteModule.commandCenter:
        return "Command Center Dashboard";
      case SuiteModule.quebrado:
        return "Quebrado • Finanzas Personales";
      case SuiteModule.diario:
        return "Diario Jottache • Notas & Vínculos";
      case SuiteModule.habitos:
        return "Hábitos • Terminal de Productividad";
      case SuiteModule.recordatorios:
        return "Recordatorios & Agenda";
      case SuiteModule.agente:
        return "Agente Ortiz • Inteligencia & Artefactos";
      case SuiteModule.notas:
        return "Notas & Acuerdos • Documentos & Acuerdos";
    }
  }

  Widget _buildActiveView(BuildContext context) {
    switch (_currentModule) {
      case SuiteModule.commandCenter:
        return const DesktopCommandCenterView();
      case SuiteModule.quebrado:
        return const MainScreen();
      case SuiteModule.diario:
        return const DiarioHomeScreen();
      case SuiteModule.habitos:
        return const HabitosHomeScreen();
      case SuiteModule.recordatorios:
        return const RemindersHomeScreen();
      case SuiteModule.agente:
        return const AgenteHomeScreen();
      case SuiteModule.notas:
        return const NotasHomeScreen();
    }
  }
}
