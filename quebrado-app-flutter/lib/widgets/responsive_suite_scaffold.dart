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
  bool _isSidebarCollapsed = false;

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
    final effectiveSidebarWidth = _isSidebarCollapsed
        ? 78.0
        : (isExpanded ? 240.0 : 200.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar de navegación Desktop
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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
    final isCollapsed = _isSidebarCollapsed;

    return Container(
      color: Colors.white,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del Sidebar
            Padding(
              padding: EdgeInsets.fromLTRB(isCollapsed ? 12 : 18, 18, 12, 16),
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
                  if (!isCollapsed) ...[
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
                    IconButton(
                      icon: const Icon(Icons.menu_open_rounded, size: 20),
                      tooltip: "Colapsar menú",
                      onPressed: () {
                        setState(() => _isSidebarCollapsed = true);
                      },
                    ),
                  ],
                ],
              ),
            ),

            if (isCollapsed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 22),
                  tooltip: "Expandir menú",
                  onPressed: () {
                    setState(() => _isSidebarCollapsed = false);
                  },
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
                ],
              ),
            ),

            // Acceso Rápido Inferior en Sidebar
            Container(
              padding: EdgeInsets.all(isCollapsed ? 10 : 14),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: isCollapsed
                  ? IconButton(
                      icon: const Icon(Icons.bolt_rounded, color: Color(0xFF1F6F5F)),
                      tooltip: "Acciones Rápidas",
                      onPressed: () => _selectModule(SuiteModule.commandCenter),
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F6F5F).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFF1F6F5F), size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Modo Activo",
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Flujo Rápido",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
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
    final isCollapsed = _isSidebarCollapsed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectModule(module),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 10 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withOpacity(0.35), width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment:
                isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : Colors.grey[700],
              ),
              if (!isCollapsed) ...[
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
    }
  }
}
