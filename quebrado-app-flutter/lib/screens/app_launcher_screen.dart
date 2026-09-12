import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../diario/diario.dart';
import '../habitos/habitos.dart';
import '../recordatorios/recordatorios.dart';
import '../theme/colors.dart';
import '../quebrado/screens/main_screen.dart';
import '../quebrado/screens/settings_screen.dart';

class AppLauncherScreen extends StatelessWidget {
  const AppLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final habitosState = Provider.of<HabitosState>(context);
    final remindersState = Provider.of<RemindersState>(context);
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
                        // Top Bar: Date & Settings
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
                            // Global Settings Button
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.all(10),
                              ),
                              tooltip: "Ajustes",
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Section Title
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Suite de Aplicaciones",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Suite Applications Grid (2 columns layout)
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }  /// The redesigned Quebrado Card
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Quebrado Calligraphic Logo
                  Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 28.0, left: 2.0),
                    child: Image.asset(
                      'assets/images/quebrado/logo_quebrado.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. Official Rates: Stacked vertically with centered icons
                  _buildOfficialRatesSection(appState),
                ],
              ),
            ),

            // Notification Bell pegada al borde superior derecho de la card
            Positioned(
              top: 6,
              right: 6,
              child: _buildPendingNotificationBadge(pendingCount),
            ),
          ],
        ),
      ),
    );
  }

  /// Notification badge with simple bell icon (with or without notification indicator)
  Widget _buildPendingNotificationBadge(int pendingCount) {
    final hasPending = pendingCount > 0;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: hasPending
            ? AppColors.expense.withOpacity(0.10)
            : Colors.grey.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: hasPending
              ? AppColors.expense.withOpacity(0.35)
              : Colors.grey.withOpacity(0.20),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasPending
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            size: 15,
            color: hasPending ? AppColors.expense : Colors.grey[500],
          ),
          if (hasPending)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 6,
                height: 6,
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
}
