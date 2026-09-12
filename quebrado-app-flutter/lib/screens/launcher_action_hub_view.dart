import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../quebrado/theme/colors.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/dialogs/add_transaction_dialog.dart';
import '../quebrado/screens/account_management_screen.dart';
import '../quebrado/screens/main_screen.dart';
import '../diario/viewmodels/diario_state.dart';
import '../diario/models/diario_contact.dart';
import '../diario/theme/diario_colors.dart';
import '../diario/widgets/diario_image_helper.dart';
import '../diario/screens/entry_editor_dialog.dart';
import '../diario/screens/contact_detail_screen.dart';
import '../diario/screens/diario_home_screen.dart';
import '../habitos/viewmodels/habitos_state.dart';
import '../habitos/models/habit_model.dart';
import '../habitos/theme/habitos_terminal_theme.dart';
import '../habitos/screens/habitos_home_screen.dart';
import '../recordatorios/recordatorios.dart';

class LauncherActionHubView extends StatelessWidget {
  final AppState appState;
  final DiarioState diarioState;
  final HabitosState habitosState;
  final RemindersState remindersState;

  const LauncherActionHubView({
    super.key,
    required this.appState,
    required this.diarioState,
    required this.habitosState,
    required this.remindersState,
  });

  static Color _parseHexColor(String hex, {Color fallback = const Color(0xFF1F6F5F)}) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

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

  static String _formatEntryDate(DateTime dt) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return "${dt.day} ${months[dt.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SECCIÓN QUEBRADO (FINANZAS)
              _buildQuebradoSection(context),
              const SizedBox(height: 22),

              // 2. SECCIÓN DIARIO JOTTACHE
              _buildDiarioSection(context),
              const SizedBox(height: 22),

              // 3. SECCIÓN HÁBITOS
              _buildHabitosSection(context),
              const SizedBox(height: 22),

              // 4. SECCIÓN RECORDATORIOS & EVENTOS
              _buildRemindersSection(context),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. QUEBRADO (FINANZAS Y TASAS)
  // ===========================================================================
  Widget _buildQuebradoSection(BuildContext context) {
    return _buildHubContainer(
      title: "QUEBRADO • FINANZAS",
      subtitle: "Operaciones rápidas y cotizaciones en tiempo real",
      icon: Icons.account_balance_wallet_outlined,
      accentColor: AppColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const MainScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. Botones Rápidos de Ingreso y Gasto
          Row(
            children: [
              Expanded(
                child: _buildActionPillButton(
                  icon: Icons.arrow_downward_rounded,
                  label: "Registrar Ingreso",
                  color: const Color(0xFF10B981), // Emerald
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AddTransactionBottomSheet(
                        initialType: TransactionType.income,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionPillButton(
                  icon: Icons.arrow_upward_rounded,
                  label: "Registrar Gasto",
                  color: const Color(0xFFEF4444), // Coral / Red
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AddTransactionBottomSheet(
                        initialType: TransactionType.expense,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // B. Cards de Tasas Actualizadas en Vivo
          Row(
            children: [
              Expanded(
                child: _buildLiveRateCard(
                  label: "BCV",
                  sublabel: "USD Oficial",
                  rate: appState.bcvRate,
                  icon: Icons.account_balance_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveRateCard(
                  label: "PARALELO",
                  sublabel: "USD Mercado",
                  rate: appState.parallelRate,
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLiveRateCard(
                  label: "EURO",
                  sublabel: "EUR Oficial",
                  rate: appState.euroRate,
                  icon: Icons.euro_symbol_rounded,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // C. Cuentas y Saldos (Deslizable horizontal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card_outlined, size: 14, color: Color(0xFF6B7280)),
                  SizedBox(width: 5),
                  Text(
                    "CUENTAS & BALANCES",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
                  );
                },
                child: Text(
                  "Gestionar",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (appState.accounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  "No hay cuentas configuradas aún",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: appState.accounts.map((acc) {
                  final currencySymbol = acc.currency.symbol;
                  final formattedBalance = _formatCurrency(acc.balance);
                  final accountColor = _parseHexColor(acc.colorHex);

                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accountColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              acc.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$currencySymbol $formattedBalance",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: acc.balance >= 0 ? const Color(0xFF1F2937) : Colors.redAccent,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. DIARIO JOTTACHE (CUMPLEAÑOS, ÚLTIMOS REGISTROS, REGISTRO RÁPIDO)
  // ===========================================================================
  Widget _buildDiarioSection(BuildContext context) {
    // Contactos con cumpleaños válidos ordenados por cercanía
    final bdayContacts = diarioState.contacts
        .where((c) => c.birthdate != null)
        .toList()
      ..sort((a, b) => (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));

    // Últimos 5 registros en general
    final recentEntries = List.of(diarioState.entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final top5Entries = recentEntries.take(5).toList();

    return _buildHubContainer(
      title: "DIARIO JOTTACHE",
      subtitle: "Relaciones, notas y memorias personales",
      icon: Icons.menu_book_rounded,
      accentColor: DiarioColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const DiarioHomeScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. Próximos Cumpleaños
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cake_outlined, size: 14, color: DiarioColors.primary),
                  SizedBox(width: 5),
                  Text(
                    "PRÓXIMOS CUMPLEAÑOS",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: DiarioColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (bdayContacts.isNotEmpty)
                Text(
                  "${bdayContacts.length} registrados",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (bdayContacts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Text(
                "No hay fechas de cumpleaños registradas en contactos.",
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: bdayContacts.take(8).map((contact) {
                  final days = contact.daysUntilBirthday ?? -1;
                  final isToday = days == 0;
                  final isVeryClose = days > 0 && days <= 7;

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => ContactDetailScreen(contactId: contact.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFFFFBEB)
                            : (isVeryClose ? DiarioColors.primaryLight : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isToday
                              ? const Color(0xFFF59E0B)
                              : (isVeryClose ? DiarioColors.primary : DiarioColors.cardBorder),
                          width: isToday || isVeryClose ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAvatarCircle(contact, radius: 15),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                contact.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: DiarioColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    contact.formattedBirthdate ?? '',
                                    style: const TextStyle(fontSize: 10.5, color: DiarioColors.textSecondary),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isToday ? const Color(0xFFF59E0B) : DiarioColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isToday ? "¡HOY!" : "en ${days}d",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          // B. Botón Registro Rápido con Selector de Contacto
          InkWell(
            onTap: () => _openQuickEntryFlow(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DiarioColors.primary.withOpacity(0.35), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18, color: DiarioColors.primary),
                  SizedBox(width: 8),
                  Text(
                    "Registro Rápido en Contacto",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DiarioColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // C. Últimos 5 Registros en Contactos
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: DiarioColors.textSecondary),
              SizedBox(width: 5),
              Text(
                "ÚLTIMOS 5 REGISTROS EN CONTACTOS",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: DiarioColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (top5Entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  "No hay registros creados en el diario aún",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: top5Entries.map((entry) {
                final contact = diarioState.contacts.where((c) => c.id == entry.contactId).firstOrNull;
                final contactName = contact?.name ?? "Contacto";

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DiarioColors.cardBorder, width: 1),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (contact != null) {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => ContactDetailScreen(contactId: contact.id),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: DiarioColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.article_outlined, size: 16, color: DiarioColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: DiarioColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "@$contactName",
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: DiarioColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatEntryDate(entry.createdAt),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. HÁBITOS (FALTANTES DE HOY: MÍOS Y DE CONTACTOS)
  // ===========================================================================
  Widget _buildHabitosSection(BuildContext context) {
    // Hábitos activos no completados hoy
    final missingHabits = habitosState.allHabits
        .where((h) => !habitosState.isCompleted(h.id))
        .toList();

    return _buildHubContainer(
      title: "HÁBITOS • HOY",
      subtitle: "Progreso diario y hábitos pendientes",
      icon: Icons.track_changes_rounded,
      accentColor: HabitosColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const HabitosHomeScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist_rounded, size: 14, color: HabitosColors.textSecondary),
                  const SizedBox(width: 5),
                  const Text(
                    "FALTANTES POR REGISTRAR HOY",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: HabitosColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: missingHabits.isNotEmpty
                          ? HabitosColors.primary
                          : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${missingHabits.length}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const HabitosHomeScreen()),
                  );
                },
                child: const Text(
                  "Ver todos",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: HabitosColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (missingHabits.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5), // Light emerald
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFF059669), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "¡Todos los hábitos completados por hoy! 🎉",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: missingHabits.map((habit) {
                final isCounter = habit.type == HabitType.counter;
                final currentCount = habitosState.getValue(habit.id).toInt();
                final contact = habit.contactId != null
                    ? diarioState.contacts.where((c) => c.id == habit.contactId).firstOrNull
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Tipo de hábito y avatar o icono
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isCounter
                              ? const Color(0xFFEDE9FE) // Violet tint
                              : HabitosColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCounter ? Icons.pin_invoke_rounded : Icons.check_circle_outline_rounded,
                          color: isCounter ? const Color(0xFF7C3AED) : HabitosColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Título y etiqueta de contacto o personal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: HabitosColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (contact != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: DiarioColors.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_outline_rounded, size: 10, color: DiarioColors.primary),
                                        const SizedBox(width: 2),
                                        Text(
                                          contact.name,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: DiarioColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Personal",
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.grey),
                                    ),
                                  ),
                                ],
                                if (habit.isNegative) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Evitar",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Acción Rápida (Botón de conteo o Check)
                      if (isCounter) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Text(
                                "$currentCount",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF7C3AED), size: 28),
                              tooltip: "Sumar +1",
                              onPressed: () {
                                habitosState.incrementCounter(habit.id);
                              },
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey, size: 26),
                          tooltip: "Marcar completado",
                          onPressed: () {
                            habitosState.toggleHabitCompletion(habit.id);
                          },
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
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
  // 4. RECORDATORIOS & EVENTOS (PRÓXIMOS 5 & REGISTRO RÁPIDO)
  // ===========================================================================
  Widget _buildRemindersSection(BuildContext context) {
    final pendingReminders = remindersState.allReminders
        .where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed)
        .toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt));
    final top5Reminders = pendingReminders.take(5).toList();

    return _buildHubContainer(
      title: "RECORDATORIOS & AGENDA",
      subtitle: "Próximos compromisos y alertas",
      icon: Icons.notifications_active_outlined,
      accentColor: RemindersColors.primary,
      onHeaderTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const RemindersHomeScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: RemindersColors.textSecondary),
                  SizedBox(width: 5),
                  Text(
                    "PRÓXIMOS 5 EVENTOS",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: RemindersColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const ReminderEditorDialog(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: RemindersColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: RemindersColors.primary),
                      SizedBox(width: 3),
                      Text(
                        "Nuevo",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: RemindersColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (top5Reminders.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  "No hay recordatorios pendientes. ¡Estás al día!",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: top5Reminders.map((rem) {
                final dateStr = _formatReminderDate(rem.dueAt);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: rem.isOverdue ? Colors.redAccent.withOpacity(0.4) : RemindersColors.cardBorder,
                      width: rem.isOverdue ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.circle_outlined, size: 20, color: RemindersColors.primary),
                        tooltip: "Marcar completado",
                        onPressed: () => remindersState.toggleCompleted(rem.id),
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: RemindersColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: rem.isOverdue ? FontWeight.bold : FontWeight.normal,
                                    color: rem.isOverdue ? Colors.redAccent : RemindersColors.textSecondary,
                                  ),
                                ),
                                if (rem.tags.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "#${rem.tags.first}",
                                    style: const TextStyle(fontSize: 10, color: RemindersColors.primary),
                                  ),
                                ],
                              ],
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
  // HELPERS VISUALES
  // ===========================================================================
  Widget _buildHubContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onHeaderTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header clickeable para navegar a la app correspondiente
          InkWell(
            onTap: onHeaderTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accentColor, size: 20),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: AppColors.cardBorder),

          // Cuerpo de la sección
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildActionPillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveRateCard({
    required String label,
    required String sublabel,
    required double rate,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "Bs. ${_formatCurrency(rate)}",
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.4,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 9.5, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(DiarioContact contact, {double radius = 18}) {
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

  // Flujo ligero de registro rápido: selecciona contacto y abre EntryEditorDialog
  void _openQuickEntryFlow(BuildContext context) {
    final contacts = diarioState.contacts;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea al menos un contacto en Diario primero')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Selecciona el Contacto",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Text(
                "¿A quién pertenece el nuevo registro que deseas añadir?",
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: DiarioColors.cardBorder),
                  itemBuilder: (_, index) {
                    final contact = contacts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: _buildAvatarCircle(contact, radius: 18),
                      title: Text(
                        contact.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DiarioColors.textPrimary),
                      ),
                      subtitle: contact.relationship != null
                          ? Text(contact.relationship!, style: const TextStyle(fontSize: 12, color: Colors.grey))
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded, color: DiarioColors.primary),
                      onTap: () {
                        Navigator.of(ctx).pop();

                        // Categorías del contacto
                        final categories = diarioState.categories.where((cat) => cat.contactId == contact.id).toList();
                        final catId = categories.isNotEmpty ? categories.first.id : null;

                        if (catId == null) {
                          // Crear categoría predeterminada 'General'
                          diarioState.addCategory(contactId: contact.id, name: 'General').then((_) {
                            final updatedCats = diarioState.categories.where((cat) => cat.contactId == contact.id).toList();
                            final newId = updatedCats.isNotEmpty ? updatedCats.last.id : '';
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => EntryEditorDialog(
                                  contactId: contact.id,
                                  categoryId: newId,
                                ),
                              );
                            }
                          });
                        } else {
                          showDialog(
                            context: context,
                            builder: (_) => EntryEditorDialog(
                              contactId: contact.id,
                              categoryId: catId,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
