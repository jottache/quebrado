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
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.grey[200],
          ),

          // Área de contenido principal con estado persistente
          Expanded(
            child: Column(
              children: [
                // TopBar de Utilidades Desktop (Buscador, Sincronización, Calculadora, Tasas)
                _buildDesktopTopBar(context),
                Divider(height: 1, thickness: 1, color: Colors.grey[200]),

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

    return Container(
      color: Colors.white,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del Sidebar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F6F5F), Color(0xFF114B40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F6F5F).withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "O",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OrtizApp",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          "SUITE DESKTOP",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F6F5F),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: Colors.grey[150]),
            const SizedBox(height: 12),

            // Items de Navegación
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _buildNavItem(
                    module: SuiteModule.commandCenter,
                    icon: Icons.dashboard_customize_rounded,
                    label: "Command Center",
                    shortcut: "⌘1",
                    color: const Color(0xFF1F6F5F),
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    module: SuiteModule.quebrado,
                    icon: Icons.account_balance_wallet_rounded,
                    label: "Quebrado",
                    shortcut: "⌘2",
                    color: const Color(0xFF1F6F5F),
                  ),
                  if (_currentModule == SuiteModule.quebrado) ...[
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 4),
                  _buildNavItem(
                    module: SuiteModule.recordatorios,
                    icon: Icons.check_circle_outline_rounded,
                    label: "Recordatorios",
                    shortcut: "⌘3",
                    color: RemindersColors.primary,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    module: SuiteModule.habitos,
                    icon: Icons.local_fire_department_rounded,
                    label: "Hábitos",
                    shortcut: "⌘4",
                    color: HabitosColors.primary,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    module: SuiteModule.diario,
                    icon: Icons.auto_stories_rounded,
                    label: "Diario",
                    shortcut: "⌘5",
                    color: DiarioColors.primary,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    module: SuiteModule.agente,
                    icon: Icons.auto_awesome_rounded,
                    label: "Agente Ortiz",
                    shortcut: "⌘6",
                    color: AgenteColors.primary,
                  ),
                  const SizedBox(height: 4),
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
            const SizedBox(height: 12),
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
    const activeColor = Color(0xFF1F6F5F);

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: activeColor.withOpacity(0.35), width: 1.0)
                  : Border.all(color: Colors.transparent, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? activeColor : Colors.grey[600],
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? activeColor : Colors.black87,
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withOpacity(0.35), width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : Colors.black87,
                  ),
                ),
              ),
              Text(
                shortcut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color.withOpacity(0.8) : Colors.grey[400],
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Ticker de Tasas BCV / Euro Oficial
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Text(
                              "BCV: Bs. $bcv",
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Euro Oficial: Bs. $eur",
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey[750]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Botones de acción directa a la derecha
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentModule == SuiteModule.commandCenter) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1F6F5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            showResponsiveSheet(
                              context: context,
                              builder: (_) => const AddTransactionBottomSheet(
                                initialType: TransactionType.expense,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text(
                            "Nuevo Gasto",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RemindersColors.primary,
                            side: const BorderSide(color: RemindersColors.primary, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const ReminderEditorDialog(),
                            );
                          },
                          icon: const Icon(Icons.alarm_add_rounded, size: 17),
                          label: const Text(
                            "Recordatorio",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      IconButton(
                        icon: const Icon(Icons.calculate_outlined),
                        tooltip: "Calculadora de divisas",
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: () {
                          showResponsiveSheet(
                            context: context,
                            builder: (context) => const CalculatorBottomSheet(),
                          );
                        },
                      ),
                      const SizedBox(width: 10),

                      IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        tooltip: "Sincronizar todos los datos",
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          foregroundColor: const Color(0xFF1F6F5F),
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
                                content: Text("Suite sincronizada correctamente"),
                                backgroundColor: Color(0xFF10B981),
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
