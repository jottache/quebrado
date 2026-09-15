import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../diario/diario.dart';
import '../habitos/habitos.dart';
import '../recordatorios/recordatorios.dart';
import '../agente/agente.dart';
import '../theme/colors.dart';
import '../quebrado/screens/main_screen.dart';
import '../quebrado/dialogs/calculator_dialog.dart';
import '../quebrado/services/db_helper.dart';
import 'launcher_action_hub_view.dart';

class AppLauncherScreen extends StatefulWidget {
  const AppLauncherScreen({super.key});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  bool _isActionHubView = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    try {
      final saved = await DatabaseHelper.instance.getSetting('launcher_is_action_hub_view');
      if (saved != null && mounted) {
        setState(() {
          _isActionHubView = saved == 'true';
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleView(bool actionHub) async {
    setState(() {
      _isActionHubView = actionHub;
    });
    try {
      await DatabaseHelper.instance.setSetting('launcher_is_action_hub_view', actionHub ? 'true' : 'false');
    } catch (_) {}
  }

  Future<void> _syncAllData({
    required AppState appState,
    required DiarioState diarioState,
    required HabitosState habitosState,
    required RemindersState remindersState,
  }) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      await Future.wait([
        appState.loadData(forceReload: true),
        appState.refreshRates(),
        diarioState.loadAll(),
        habitosState.loadHabits(),
        remindersState.reload(),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Todos los datos han sido sincronizados', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildSyncButton(
    BuildContext context,
    AppState appState,
    DiarioState diarioState,
    HabitosState habitosState,
    RemindersState remindersState,
  ) {
    return IconButton(
      icon: _isSyncing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.sync_rounded),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.all(10),
      ),
      tooltip: "Sincronizar datos",
      onPressed: _isSyncing
          ? null
          : () => _syncAllData(
                appState: appState,
                diarioState: diarioState,
                habitosState: habitosState,
                remindersState: remindersState,
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final habitosState = Provider.of<HabitosState>(context);
    final remindersState = Provider.of<RemindersState>(context);
    final agenteState = Provider.of<AgenteState>(context);

    // Conectar dependencias vivas al motor RAG del Agente
    agenteState.updateDependencies(
      appState: appState,
      diarioState: diarioState,
      habitosState: habitosState,
      remindersState: remindersState,
    );

    final now = DateTime.now();

    // Days & Months in Spanish
    final weekDays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final dateString =
        "${weekDays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Vista con scroll del dashboard
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top Header Sliver
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar: Date & Calculator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateString.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[500],
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        "OrtizApp",
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Sync & Calculator Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSyncButton(
                                        context,
                                        appState,
                                        diarioState,
                                        habitosState,
                                        remindersState,
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.calculate_outlined),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.all(10),
                                        ),
                                        tooltip: "Calculadora de divisas",
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) =>
                                                const CalculatorBottomSheet(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Section Title & View Switcher Toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: _isActionHubView
                                              ? const Color(0xFF6366F1)
                                              : AppColors.primary,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isActionHubView ? "Accesos Rápidos" : "Suite de Apps",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildViewSwitcherPill(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Contenido Principal según el modo seleccionado
                  if (!_isActionHubView)
                    // Modo 1: Suite Applications Grid (2 columns layout)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            child: Column(
                              children: [
                                // Row 1: Quebrado & Diario Jottache
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _buildQuebradoHubCard(context, appState),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDiarioHubCard(context, diarioState),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Row 2: Hábitos & Recordatorios
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _buildHabitosHubCard(context, habitosState),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildRemindersHubCard(context, remindersState),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Row 3: Agente Ortiz (Chats & Artefactos)
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _buildAgenteHubCard(context, agenteState),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    // Modo 2: Hub Operacional con Funciones y Accesos Rápidos
                    SliverToBoxAdapter(
                      child: LauncherActionHubView(
                        appState: appState,
                        diarioState: diarioState,
                        habitosState: habitosState,
                        remindersState: remindersState,
                      ),
                    ),
                ],
              ),
            ),

            // Dock inferior para lanzar el modal de chat (presente en ambas vistas)
            const DockedLauncherChat(),
          ],
        ),
      ),
    );
  }

  /// Segmented Switcher Pill: [ ▦ Suite | ⚡ Acciones ]
  Widget _buildViewSwitcherPill() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitcherOption(
            label: "Suite",
            icon: Icons.grid_view_rounded,
            isSelected: !_isActionHubView,
            activeColor: AppColors.primary,
            onTap: () => _toggleView(false),
          ),
          _buildSwitcherOption(
            label: "Acciones",
            icon: Icons.bolt_rounded,
            isSelected: _isActionHubView,
            activeColor: const Color(0xFF6366F1),
            onTap: () => _toggleView(true),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The redesigned Quebrado Card
  Widget _buildQuebradoHubCard(BuildContext context, AppState appState) {
    final pendingCount = appState.pendingPaymentsToday.length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.primary.withOpacity(0.08),
      highlightColor: AppColors.primary.withOpacity(0.04),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              offset: const Offset(0, 8),
              blurRadius: 20.0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 6.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Quebrado Calligraphic Logo & Notification Icon aligned
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 38,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 2.0),
                    child: Image.asset(
                      'assets/images/quebrado/logo_quebrado.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  _buildPendingNotificationBadge(pendingCount),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Official Rates: Stacked vertically with centered icons
              _buildOfficialRatesSection(appState),
            ],
          ),
        ),
      ),
    );
  }

  /// Notification badge with simple bell icon without circular container or borders
  Widget _buildPendingNotificationBadge(int pendingCount) {
    final hasPending = pendingCount > 0;

    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            hasPending
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            size: 22,
            color: hasPending ? AppColors.expense : Colors.grey[400],
          ),
          if (hasPending)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Official Rates banner stacked vertically with centered icons
  Widget _buildOfficialRatesSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dólar BCV
          _buildRateRow(
            label: "DÓLAR BCV",
            value: "Bs. ${appState.bcvRate.toStringAsFixed(2)}",
            icon: Icons.attach_money_rounded,
            accentColor: AppColors.primary,
          ),

          Divider(height: 12, thickness: 1, color: Colors.grey[200]),

          // Euro Oficial
          _buildRateRow(
            label: "EURO OFICIAL",
            value: "Bs. ${appState.euroRate.toStringAsFixed(2)}",
            icon: Icons.euro_rounded,
            accentColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        // Symmetrically centered vector icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey[600],
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  /// The redesigned Diario Jottache Card (Matches Quebrado card styling)
  Widget _buildDiarioHubCard(BuildContext context, DiarioState diarioState) {
    final contactsCount = diarioState.contacts.length;
    final upcomingBirthdays = diarioState.getUpcomingBirthdays(limit: 1);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const DiarioHomeScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: DiarioColors.primary.withOpacity(0.08),
      highlightColor: DiarioColors.primary.withOpacity(0.04),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: DiarioColors.primary.withOpacity(0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: DiarioColors.primary.withOpacity(0.06),
              offset: const Offset(0, 8),
              blurRadius: 20.0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 6.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Diario Jottache Minimalist Branding Header (Exact same 40px height)
              Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: DiarioColors.primary.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: DiarioColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Diario",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            "JOTTACHE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: DiarioColors.primary,
                              letterSpacing: 0.6,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Diario Summary Box (Clean Single Primary Color, matching rates box)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRateRow(
                      label: "PERSONAS",
                      value: "$contactsCount",
                      icon: Icons.people_outline_rounded,
                      accentColor: DiarioColors.primary,
                    ),
                    Divider(height: 12, thickness: 1, color: Colors.grey[200]),
                    _buildRateRow(
                      label: "CUMPLE",
                      value: upcomingBirthdays.isNotEmpty
                          ? "${upcomingBirthdays.first.name.split(' ').first} (${upcomingBirthdays.first.daysUntilBirthday}d)"
                          : "Al día",
                      icon: Icons.cake_outlined,
                      accentColor: DiarioColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Minimalist Hábitos Card (Matches Quebrado and Diario styling)
  Widget _buildHabitosHubCard(BuildContext context, HabitosState habitosState) {
    final progressPct = (habitosState.todayCompletionRate * 100).round();
    final maxStreak = habitosState.bestCurrentStreak;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const HabitosHomeScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: HabitosColors.primary.withOpacity(0.08),
      highlightColor: HabitosColors.primary.withOpacity(0.04),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: HabitosColors.primary.withOpacity(0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: HabitosColors.primary.withOpacity(0.06),
              offset: const Offset(0, 8),
              blurRadius: 20.0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 6.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Hábitos Minimalist Header (40px height)
              Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: HabitosColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HabitosColors.primary.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: HabitosColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Hábitos",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            "METAS & RUTINAS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: HabitosColors.primary,
                              letterSpacing: 0.6,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Summary Box (Matching rates & diario box)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRateRow(
                      label: "HOY",
                      value: "$progressPct%",
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: HabitosColors.primary,
                    ),
                    Divider(height: 12, thickness: 1, color: Colors.grey[200]),
                    _buildRateRow(
                      label: "RACHA",
                      value: "${maxStreak}d",
                      icon: Icons.local_fire_department_outlined,
                      accentColor: HabitosColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Minimalist Recordatorios Card (Matches OrtizApp suite styling)
  Widget _buildRemindersHubCard(BuildContext context, RemindersState remindersState) {
    final todayCount = remindersState.todayCount;
    final overdueCount = remindersState.overdueCount;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const RemindersHomeScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: RemindersColors.primary.withOpacity(0.08),
      highlightColor: RemindersColors.primary.withOpacity(0.04),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: overdueCount > 0
                ? RemindersColors.overdue.withOpacity(0.35)
                : RemindersColors.primary.withOpacity(0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: overdueCount > 0
                  ? RemindersColors.overdue.withOpacity(0.06)
                  : RemindersColors.primary.withOpacity(0.06),
              offset: const Offset(0, 8),
              blurRadius: 20.0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 6.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Recordatorios Minimalist Header (40px height)
              Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: overdueCount > 0 ? RemindersColors.overdue.withOpacity(0.12) : RemindersColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: overdueCount > 0
                              ? RemindersColors.overdue.withOpacity(0.30)
                              : RemindersColors.primary.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        overdueCount > 0 ? Icons.notifications_active_rounded : Icons.alarm_on_rounded,
                        color: overdueCount > 0 ? RemindersColors.overdue : RemindersColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Recordatorios",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            "NLP & SMART SNOOZE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: overdueCount > 0 ? RemindersColors.overdue : RemindersColors.primary,
                              letterSpacing: 0.6,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Summary Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRateRow(
                      label: "HOY",
                      value: "$todayCount",
                      icon: Icons.today_rounded,
                      accentColor: RemindersColors.primary,
                    ),
                    Divider(height: 12, thickness: 1, color: Colors.grey[200]),
                    _buildRateRow(
                      label: "VENCIDOS",
                      value: "$overdueCount",
                      icon: Icons.warning_amber_rounded,
                      accentColor: overdueCount > 0 ? RemindersColors.overdue : Colors.grey[500]!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Minimalist Agente Ortiz Card (Matches OrtizApp suite styling)
  Widget _buildAgenteHubCard(BuildContext context, AgenteState agenteState) {
    final sessionsCount = agenteState.sessions.length;
    final artifactsCount = agenteState.allArtifacts.length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const AgenteHomeScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: AgenteColors.primary.withOpacity(0.08),
      highlightColor: AgenteColors.primary.withOpacity(0.04),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AgenteColors.primary.withOpacity(0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AgenteColors.primary.withOpacity(0.06),
              offset: const Offset(0, 8),
              blurRadius: 20.0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 2),
              blurRadius: 6.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Header (40px height)
              Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AgenteColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AgenteColors.primary.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AgenteColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Agente Ortiz",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            "CHATS & ARTEFACTOS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AgenteColors.primary,
                              letterSpacing: 0.6,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Summary Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRateRow(
                      label: "CHARLAS",
                      value: "$sessionsCount",
                      icon: Icons.chat_bubble_outline_rounded,
                      accentColor: AgenteColors.primary,
                    ),
                    Divider(height: 12, thickness: 1, color: Colors.grey[200]),
                    _buildRateRow(
                      label: "ARTEFACTOS",
                      value: "$artifactsCount",
                      icon: Icons.inventory_2_outlined,
                      accentColor: AgenteColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
