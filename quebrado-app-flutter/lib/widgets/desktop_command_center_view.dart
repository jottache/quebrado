import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../quebrado/theme/colors.dart';
import '../quebrado/models/currency_type.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/dialogs/add_transaction_dialog.dart';
import '../quebrado/screens/main_screen.dart';
import '../diario/viewmodels/diario_state.dart';
import '../diario/theme/diario_colors.dart';
import '../diario/models/diario_contact.dart';
import '../diario/screens/entry_editor_dialog.dart';
import '../diario/screens/diario_home_screen.dart';
import '../diario/screens/contact_detail_screen.dart';
import '../diario/widgets/diario_image_helper.dart';
import '../habitos/viewmodels/habitos_state.dart';
import '../habitos/models/habit_model.dart';
import '../habitos/theme/habitos_terminal_theme.dart';
import '../habitos/screens/habitos_home_screen.dart';
import '../recordatorios/recordatorios.dart';
import 'responsive_breakpoints.dart';
import 'responsive_sheet_helper.dart';

class DesktopCommandCenterView extends StatelessWidget {
  const DesktopCommandCenterView({super.key});

  static String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$formattedWhole.$dec';
  }

  static String _formatReminderDate(DateTime? dt) {
    if (dt == null) return "Sin fecha fija";
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minStr = dt.minute.toString().padLeft(2, '0');
    return "${dt.day} ${months[dt.month - 1]}, $hour12:$minStr $ampm";
  }

  Widget _buildAvatarCircle(DiarioContact contact, {double radius = 16}) {
    if (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: DiarioImageHelper.buildImageWidget(
            contact.avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : "?";
    return CircleAvatar(
      radius: radius,
      backgroundColor: DiarioColors.primaryLight,
      child: Text(
        initial,
        style: TextStyle(
          color: DiarioColors.primaryDark,
          fontWeight: FontWeight.w900,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final diarioState = Provider.of<DiarioState>(context);
    final habitosState = Provider.of<HabitosState>(context);
    final remindersState = Provider.of<RemindersState>(context);

    final isExpanded = ResponsiveBreakpoints.isExpanded(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Pinned Reminders interactivo en la parte superior si existen
          _buildPinnedRemindersHeader(context, remindersState),

          const SizedBox(height: 18),

          // Grid de 2 o 3 columnas según el ancho de pantalla
          if (isExpanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna 1: Finanzas (Quebrado)
                Expanded(
                  flex: 5,
                  child: _buildFinancesCard(context, appState),
                ),
                const SizedBox(width: 20),

                // Columna 2: Productividad (Hábitos & Tareas)
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildHabitsCard(context, habitosState),
                      const SizedBox(height: 20),
                      _buildRemindersCard(context, remindersState),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Columna 3: Diario & Contactos
                Expanded(
                  flex: 4,
                  child: _buildDiarioCard(context, diarioState),
                ),
              ],
            )
          else
            // Modo Tablet / Desktop Compacto (2 Columnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildFinancesCard(context, appState),
                      const SizedBox(height: 20),
                      _buildDiarioCard(context, diarioState),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _buildHabitsCard(context, habitosState),
                      const SizedBox(height: 20),
                      _buildRemindersCard(context, remindersState),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedRemindersHeader(BuildContext context, RemindersState remindersState) {
    final pinned = remindersState.pinnedReminders;
    if (pinned.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RemindersColors.primaryLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RemindersColors.primary.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RemindersColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.push_pin_rounded, color: RemindersColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "RECORDATORIO FIJADO",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: RemindersColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pinned.first.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RemindersColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              pinned.first.timeRemainingFormatted,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: RemindersColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. FINANZAS / QUEBRADO
  // ===========================================================================
  Widget _buildFinancesCard(BuildContext context, AppState appState) {
    final netUSD = appState.totalBalanceUSD;
    final netVES = appState.convert(amountUSD: netUSD, to: CurrencyType.bsBCV);
    final recentTxs = appState.transactions.take(6).toList();

    return _buildSectionCard(
      title: "Finanzas • Quebrado",
      icon: Icons.account_balance_wallet_rounded,
      accentColor: const Color(0xFF1F6F5F),
      onHeaderTap: () {
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MainScreen()));
      },
      actionButton: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        tooltip: "Registrar Gasto/Ingreso",
        onPressed: () {
          showResponsiveSheet(
            context: context,
            builder: (_) => const AddTransactionBottomSheet(),
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Balance Total
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F6F5F), Color(0xFF144D41)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F6F5F).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BALANCE TOTAL CONSOLIDADO",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "\$ ${_formatCurrency(netUSD)}",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "≈ Bs. ${_formatCurrency(netVES)} (BCV)",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Últimos Movimientos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "ÚLTIMOS MOVIMIENTOS",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  appState.setTabIndex(2); // Historial
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MainScreen()));
                },
                child: const Text(
                  "Ver todos",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1F6F5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (recentTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  "No hay transacciones registradas.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: recentTxs.map((tx) {
                final isExpense = tx.type == TransactionType.expense;
                final sign = isExpense ? "-" : "+";
                final color = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
                final curSymbol = tx.currency == CurrencyType.usd ? "\$" : "Bs.";

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: color,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tx.note.isNotEmpty ? tx.note : "Sin concepto",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "$sign $curSymbol ${_formatCurrency(tx.amount)}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. HÁBITOS DEL DÍA
  // ===========================================================================
  Widget _buildHabitsCard(BuildContext context, HabitosState habitosState) {
    final todayHabits = habitosState.habits;
    final todayKey = habitosState.todayKey;
    final completedCount = todayHabits.where((h) => habitosState.isCompleted(h.id, todayKey)).length;

    return _buildSectionCard(
      title: "Hábitos • Hoy",
      icon: Icons.local_fire_department_rounded,
      accentColor: HabitosColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const HabitosHomeScreen()));
      },
      actionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: HabitosColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "$completedCount/${todayHabits.length}",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: HabitosColors.primary,
          ),
        ),
      ),
      child: Column(
        children: todayHabits.take(5).map((habit) {
          final isDone = habitosState.isCompleted(habit.id, todayKey);
          final streak = habitosState.calculateCurrentStreak(habit.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone ? const Color(0xFFBBF7D0) : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    habitosState.toggleHabitCompletion(habit.id);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone ? const Color(0xFF10B981) : Colors.grey[400]!,
                        width: 1.5,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                ),
                Text(
                  "$streak 🔥",
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 3. RECORDATORIOS
  // ===========================================================================
  Widget _buildRemindersCard(BuildContext context, RemindersState remindersState) {
    final topReminders = remindersState.allReminders
        .where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed)
        .take(4)
        .toList();

    return _buildSectionCard(
      title: "Recordatorios",
      icon: Icons.check_circle_outline_rounded,
      accentColor: RemindersColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const RemindersHomeScreen()));
      },
      actionButton: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        tooltip: "Nuevo Recordatorio",
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const ReminderEditorDialog(),
          );
        },
      ),
      child: Column(
        children: topReminders.isEmpty
            ? [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      "No hay recordatorios pendientes.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ]
            : topReminders.map((rem) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => remindersState.toggleCompleted(rem.id),
                        child: const Icon(Icons.circle_outlined, size: 20, color: RemindersColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rem.title,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatReminderDate(rem.dueAt),
                              style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 4. DIARIO JOTTACHE & CONTACTOS
  // ===========================================================================
  Widget _buildDiarioCard(BuildContext context, DiarioState diarioState) {
    final bdays = diarioState.getUpcomingBirthdays(limit: 3);
    final recentEntries = List.of(diarioState.entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final topEntries = recentEntries.take(4).toList();

    return _buildSectionCard(
      title: "Diario • Notas & Vínculos",
      icon: Icons.auto_stories_rounded,
      accentColor: DiarioColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const DiarioHomeScreen()));
      },
      actionButton: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        tooltip: "Nueva Nota",
        onPressed: () {
          final firstContact = diarioState.contacts.firstOrNull;
          if (firstContact != null) {
            showDialog(
              context: context,
              builder: (_) => EntryEditorDialog(
                contactId: firstContact.id,
                categoryId: 'cat_general',
              ),
            );
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cumpleaños Próximos
          if (bdays.isNotEmpty) ...[
            const Text(
              "CUMPLEAÑOS CERCANOS",
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            ResponsiveHorizontalScroll(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: bdays.map((c) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DiarioColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAvatarCircle(c, radius: 12),
                          const SizedBox(width: 6),
                          Text(
                            c.name,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Notas Recientes
          const Text(
            "ÚLTIMAS NOTAS",
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          if (topEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "No hay notas registradas.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: topEntries.map((e) {
                final contact = diarioState.contacts.where((c) => c.id == e.contactId).firstOrNull;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DiarioColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article_outlined, size: 14, color: DiarioColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (contact != null)
                              Text(
                                "@${contact.name}",
                                style: const TextStyle(fontSize: 10, color: DiarioColors.primary, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER CONTAINER
  // ===========================================================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onHeaderTap,
    Widget? actionButton,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onHeaderTap,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18),
                      ],
                    ),
                  ),
                ),
                ?actionButton,
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[150]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
