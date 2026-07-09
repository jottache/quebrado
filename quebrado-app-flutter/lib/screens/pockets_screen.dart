import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/db_helper.dart';
import '../viewmodels/app_state.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/pocket_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_recurring_payment_dialog.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';
import '../theme/colors.dart';

class PocketsScreen extends StatefulWidget {
  const PocketsScreen({super.key});

  @override
  State<PocketsScreen> createState() => _PocketsScreenState();
}

class _PocketsScreenState extends State<PocketsScreen> {
  int _selectedTab = 0; // 0 = Bolsillos, 1 = Suscripciones
  int _selectedRecurrentFilter = 0; // 0 = Todos, 1 = Ingresos, 2 = Pagos

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _pocketsHeaderKey = GlobalKey();
  final GlobalKey _addPocketKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();
  final GlobalKey _recurrentsHeaderKey = GlobalKey();
  final GlobalKey _recurrentsFilterKey = GlobalKey();
  final GlobalKey _recurrentsListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    
    if (appState.initialPocketsSubTab != _selectedTab) {
      _selectedTab = appState.initialPocketsSubTab;
    }

    if (appState.shouldShowPocketsTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerPocketsTutorialDirectly();
      });
    }

    if (appState.shouldShowRecurrentsTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerRecurrentsTutorialDirectly();
      });
    }
  }

  Future<void> _checkAndShowTutorial() async {
    try {
      if (_selectedTab == 0) {
        final hasSeen = await DatabaseHelper.instance.getSetting('tutorial_pockets_seen');
        if (hasSeen != 'true') {
          if (mounted) {
            ShowCaseWidget.of(context).startShowCase([
              _pocketsHeaderKey,
              _addPocketKey,
              _tabsKey,
            ]);
            await DatabaseHelper.instance.setSetting('tutorial_pockets_seen', 'true');
          }
        }
      } else if (_selectedTab == 1) {
        await _checkAndShowRecurrentsTutorial();
      }
    } catch (e) {
      debugPrint("Error loading pockets tutorial setting: $e");
    }
  }

  void _triggerPocketsTutorialDirectly() {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.shouldShowPocketsTutorial = false; // Reset trigger
      ShowCaseWidget.of(context).startShowCase([
        _pocketsHeaderKey,
        _addPocketKey,
        _tabsKey,
      ]);
      DatabaseHelper.instance.setSetting('tutorial_pockets_seen', 'true');
    } catch (e) {
      debugPrint("Error triggering pockets tutorial directly: $e");
    }
  }

  Future<void> _checkAndShowRecurrentsTutorial() async {
    try {
      final hasSeen = await DatabaseHelper.instance.getSetting('tutorial_recurrents_seen');
      if (hasSeen != 'true') {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([
            _recurrentsHeaderKey,
            _recurrentsFilterKey,
            _recurrentsListKey,
          ]);
          await DatabaseHelper.instance.setSetting('tutorial_recurrents_seen', 'true');
        }
      }
    } catch (e) {
      debugPrint("Error loading recurrents tutorial setting: $e");
    }
  }

  void _triggerRecurrentsTutorialDirectly() {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.shouldShowRecurrentsTutorial = false; // Reset trigger
      ShowCaseWidget.of(context).startShowCase([
        _recurrentsHeaderKey,
        _recurrentsFilterKey,
        _recurrentsListKey,
      ]);
      DatabaseHelper.instance.setSetting('tutorial_recurrents_seen', 'true');
    } catch (e) {
      debugPrint("Error triggering recurrents tutorial directly: $e");
    }
  }

  void _showPocketsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "¿Por qué usar Bolsillos para tus Deudas?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Evita la Ilusión de Liquidez",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Al separar dinero en un bolsillo para una compra a cuotas (ej. Cashea), retiras ese dinero de tu saldo líquido disponible. Esto te impide gastarlo por error y te asegura tener los fondos listos cuando venza la cuota.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Estrategias de Financiamiento",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "• Pre-fondeo: Guarda el monto total de la compra en el bolsillo hoy. Cada cuota se debitará sola sin tocar tu cuenta del día a día.\n• Apartado Progresivo: Usa tu sueldo recurrente para apartar y transferir la cuota al bolsillo automáticamente antes de la fecha de cobro.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ejemplo Práctico (Cashea)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Si compras un teléfono financiado a 6 cuotas de \$20 cada 14 días (total \$120):\n• Si pre-fondeas: Metes los \$120 al bolsillo hoy. Tu cuenta diaria muestra tu balance real y las cuotas se cobran del bolsillo.\n• Si apartas progresivamente: Programas tu sueldo recurrente para depositar \$20 en el bolsillo justo antes de cada cobro de Cashea.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Monitoreo en el Timeline",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Si asocias tus gastos recurrentes a un bolsillo, el simulador vigilará si el bolsillo se queda sin fondos y te dirá cuánto 'Dinero Seguro' tienes realmente para gastar.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Entendido"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 30.5),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                iconSize: 26,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        const PendingConfirmationsBottomSheet(),
                  );
                },
              ),
              if (appState.pendingPaymentsToday.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Center(
                      child: Text(
                        '${appState.pendingPaymentsToday.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            iconSize: 26,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const CalculatorBottomSheet(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Spacing at the top of the CustomScrollView
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),

          // 2. Sticky Tab Bar Selector
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Showcase(
                  key: _tabsKey,
                  title: "Pestañas de Planificación",
                  description: "Navega entre tus Bolsillos de ahorro, tus Pagos Recurrentes (obligaciones periódicas) y la Proyección en el Timeline.",
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.mainTabTrackBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TabSegment(
                          title: "Bolsillos",
                          isSelected: _selectedTab == 0,
                          onTap: () {
                            setState(() => _selectedTab = 0);
                            appState.initialPocketsSubTab = 0;
                          },
                        ),
                        _TabSegment(
                          title: "Recurrentes",
                          isSelected: _selectedTab == 1,
                          onTap: () {
                            setState(() => _selectedTab = 1);
                            appState.initialPocketsSubTab = 1;
                          },
                        ),
                        _TabSegment(
                          title: "Proyección",
                          isSelected: _selectedTab == 2,
                          onTap: () {
                            setState(() => _selectedTab = 2);
                            appState.initialPocketsSubTab = 2;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Tab Content Sliver
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 12.0,
              bottom: 140.0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTab == 0) ...[
                    // Bolsillos de Ahorro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Showcase(
                          key: _pocketsHeaderKey,
                          title: "Bolsillos de Ahorro",
                          description: "Crea 'bolsillos' para apartar fondos de tu dinero disponible líquido y protegerlos de tus gastos diarios. Ideal para pre-fondear cuotas o metas.",
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Bolsillos de Ahorro",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                onPressed: () => _showPocketsInfo(context),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        Showcase(
                          key: _addPocketKey,
                          title: "Añadir Bolsillo",
                          description: "Presiona aquí para crear una nueva meta de ahorro, fijar su monto objetivo, prioridad y fecha límite.",
                          child: IconButton(
                            icon: const Icon(
                              Icons.add_circle_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            onPressed: () => _showAddPocketDialog(context, appState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Pockets list
                    if (appState.pockets.isEmpty)
                      ClaymorphicCard(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        width: double.infinity,
                        child: Column(
                          children: [
                            Icon(
                              Icons.archive_rounded,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No tienes bolsillos aún",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: List.generate(appState.pockets.length, (index) {
                          final pocket = appState.pockets[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == appState.pockets.length - 1 ? 0 : 16,
                            ),
                            child: PocketCard(
                              pocket: pocket,
                              isFeasible: appState.isPocketTargetDateFeasible(pocket),
                              viableTargetDate: appState.getViableTargetDate(pocket),
                              onAdd: () => _showTransactionDialog(
                                context,
                                appState,
                                pocket,
                                isDeposit: true,
                              ),
                              onWithdraw: () => _showTransactionDialog(
                                context,
                                appState,
                                pocket,
                                isDeposit: false,
                              ),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => AddPocketBottomSheet(
                                    appState: appState,
                                    editingPocket: pocket,
                                  ),
                                );
                              },
                              backgroundColor: AppColors.getAlternateCardColor(index),
                            ),
                          );
                        }),
                      ),
                  ] else if (_selectedTab == 1) ...[
                    // Recurrentes
                    Showcase(
                      key: _recurrentsHeaderKey,
                      title: "Obligaciones Recurrentes",
                      description: "Registra tus ingresos periódicos (como tu sueldo) y tus gastos recurrentes o cuotas (como suscripciones o deudas de Cashea). Usa el botón '+' para añadir una nueva obligación.",
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Pagos Recurrentes y Cuotas",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    const AddRecurringPaymentBottomSheet(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Filter Segmented Control
                    Showcase(
                      key: _recurrentsFilterKey,
                      title: "Filtros de Obligaciones",
                      description: "Filtra rápidamente el listado para ver solo tus ingresos planificados, tus pagos recurrentes, o todos al mismo tiempo.",
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.mainTabTrackBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _RecurrentFilterSegment(
                              title: "Todos",
                              isSelected: _selectedRecurrentFilter == 0,
                              onTap: () => setState(() => _selectedRecurrentFilter = 0),
                            ),
                            _RecurrentFilterSegment(
                              title: "Ingresos",
                              isSelected: _selectedRecurrentFilter == 1,
                              onTap: () => setState(() => _selectedRecurrentFilter = 1),
                            ),
                            _RecurrentFilterSegment(
                              title: "Pagos",
                              isSelected: _selectedRecurrentFilter == 2,
                              onTap: () => setState(() => _selectedRecurrentFilter = 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recurring payments list
                    Builder(
                      builder: (context) {
                        final filteredRecurring = appState.recurringPayments.where((
                          pay,
                        ) {
                          if (_selectedRecurrentFilter == 0) return true;
                          if (_selectedRecurrentFilter == 1)
                            return pay.type == TransactionType.income;
                          return pay.type == TransactionType.expense;
                        }).toList();

                        if (filteredRecurring.isEmpty) {
                          return Showcase(
                            key: _recurrentsListKey,
                            title: "Listado de Obligaciones",
                            description: "Aquí verás tus obligaciones y planificaciones una vez las agregues. El simulador las usará para proyectar tu flujo de caja.",
                            child: ClaymorphicCard(
                              padding: const EdgeInsets.symmetric(vertical: 32.0),
                              width: double.infinity,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedRecurrentFilter == 0
                                        ? "Sin registros recurrentes"
                                        : _selectedRecurrentFilter == 1
                                        ? "Sin ingresos recurrentes"
                                        : "Sin pagos recurrentes",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: List.generate(filteredRecurring.length, (index) {
                            final pay = filteredRecurring[index];
                            final row = Padding(
                              padding: EdgeInsets.only(
                                bottom: index == filteredRecurring.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _RecurringPaymentRow(
                                payment: pay,
                                backgroundColor: AppColors.getAlternateCardColor(
                                  index,
                                ),
                              ),
                            );

                            if (index == 0) {
                              return Showcase(
                                key: _recurrentsListKey,
                                title: "Tus Obligaciones",
                                description: "Aquí verás tus programaciones. Presiona cualquier tarjeta para modificar sus detalles, cambiar la cuenta bancaria de origen o vincularla a un bolsillo.",
                                child: row,
                              );
                            }
                            return row;
                          }),
                        );
                      },
                    ),
                  ] else ...[
                    // Timeline Proyección
                    const TimelineScreen(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Dialog Triggers

  void _showAddPocketDialog(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPocketBottomSheet(appState: appState),
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    AppState appState,
    SavingPocket pocket, {
    required bool isDeposit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PocketTransactionBottomSheet(
        appState: appState,
        pocket: pocket,
        isDeposit: isDeposit,
      ),
    );
  }
}

class _RecurringPaymentRow extends StatelessWidget {
  final RecurringPayment payment;
  final Color? backgroundColor;

  const _RecurringPaymentRow({required this.payment, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeColor = backgroundColor ?? parseHexColor(payment.colorHex);
    final isLightCard =
        themeColor == Colors.white ||
        themeColor == AppColors.cardBackground ||
        HSLColor.fromColor(themeColor).lightness >= 0.75;
    final subAccentColor = parseHexColor(payment.colorHex);

    final textColor = isLightCard ? AppColors.cardText : Colors.white;
    final subtitleColor = isLightCard
        ? AppColors.cardSubtitleText
        : Colors.white.withOpacity(0.7);

    final isIncome = payment.type == TransactionType.income;
    final typeLabel = payment.frequency == SubscriptionFrequency.once
        ? "Único"
        : (isIncome
              ? "Ingreso"
              : (payment.totalInstallments != null ? "Cuota" : "Gasto"));

    String? pocketName;
    if (payment.pocketId != null) {
      final pocketIndex = appState.pockets.indexWhere(
        (p) => p.id == payment.pocketId,
      );
      if (pocketIndex != -1) {
        pocketName = appState.pockets[pocketIndex].name;
      }
    }

    String? accountName;
    if (payment.accountId != null) {
      final accIndex = appState.accounts.indexWhere(
        (a) => a.id == payment.accountId,
      );
      if (accIndex != -1) {
        accountName = appState.accounts[accIndex].name;
      }
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              AddRecurringPaymentBottomSheet(editingPayment: payment),
        );
      },
      child: ClaymorphicCard(
        cornerRadius: 18,
        padding: const EdgeInsets.all(14.0),
        backgroundColor: themeColor,
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLightCard
                    ? subAccentColor.withOpacity(0.12)
                    : Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getIconData(payment.icon),
                color: isLightCard ? subAccentColor : Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${payment.frequency.value} • ${payment.notificationOption.value}",
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  if (accountName != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 11,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            accountName,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (pocketName != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.archive_rounded,
                          size: 11,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            pocketName,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Amount / Due date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isIncome ? '+' : '-'}${payment.currency == CurrencyType.usd ? '\$' : 'Bs.'}${payment.amount.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isIncome
                        ? (isLightCard ? Colors.green[700] : Colors.white)
                        : (isLightCard ? Colors.red[700] : Colors.white),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payment.frequency == SubscriptionFrequency.once
                      ? "Fecha: ${formatDate(payment.startDate)}"
                      : "Próximo: ${formatDate(payment.startDate)}",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isLightCard
                        ? (isIncome
                              ? Colors.green.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15))
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isLightCard
                          ? (isIncome ? Colors.green : Colors.red)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddPocketBottomSheet extends StatefulWidget {
  final AppState appState;
  final SavingPocket? editingPocket;

  const AddPocketBottomSheet({
    super.key,
    required this.appState,
    this.editingPocket,
  });

  @override
  State<AddPocketBottomSheet> createState() => _AddPocketBottomSheetState();
}

class _AddPocketBottomSheetState extends State<AddPocketBottomSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fundingRuleValueController = TextEditingController();
  final _fundingRuleThresholdController = TextEditingController();
  String? _selectedImagePath;
  DateTime? _targetDate;
  int _priority = 1;
  String _fundingRuleType = 'none';

  final List<String> _colors = AppColors.creationColors;
  final List<String> _icons = [
    "shield",
    "home",
    "iphone",
    "cart",
    "car",
    "star",
    "airplane",
    "heart",
  ];

  late String _selectedColor;
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    final p = widget.editingPocket;
    if (p != null) {
      _nameController.text = p.name;
      _targetController.text = p.targetAmountUSD.toStringAsFixed(2);
      _descriptionController.text = p.description ?? '';
      _selectedImagePath = p.imageUrl;
      _selectedColor = p.colorHex;
      _selectedIcon = p.icon;
      _targetDate = p.targetDate;
      _priority = p.priority;
      _fundingRuleType = p.fundingRuleType;
      _fundingRuleValueController.text = p.fundingRuleValue != null ? p.fundingRuleValue.toString() : '';
      _fundingRuleThresholdController.text = p.fundingRuleThreshold != null ? p.fundingRuleThreshold.toString() : '';
    } else {
      _selectedImagePath = null;
      _selectedColor = _colors[1]; // default secondary green
      _selectedIcon = _icons[5]; // default star
      _targetDate = null;
      _priority = 1;
      _fundingRuleType = 'none';
      _fundingRuleValueController.text = '';
      _fundingRuleThresholdController.text = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _descriptionController.dispose();
    _fundingRuleValueController.dispose();
    _fundingRuleThresholdController.dispose();
    super.dispose();
  }

  Widget _buildPriorityButton(int val, String label, Color themeColor) {
    final isSelected = _priority == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : themeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? themeColor : themeColor.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : themeColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleTypeButton(String type, String label) {
    final isSelected = _fundingRuleType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _fundingRuleType = type;
        });
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.cardText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _savePocket() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0.0;
    if (name.isNotEmpty && target >= 0) {
      if (_targetDate != null) {
        DateTime? maxTargetOfHigherPriority;
        for (var p in widget.appState.pockets) {
          if (p.id != widget.editingPocket?.id &&
              p.priority < _priority &&
              p.targetDate != null) {
            if (maxTargetOfHigherPriority == null ||
                p.targetDate!.isAfter(maxTargetOfHigherPriority)) {
              maxTargetOfHigherPriority = p.targetDate;
            }
          }
        }
        if (maxTargetOfHigherPriority != null &&
            (_targetDate!.isBefore(maxTargetOfHigherPriority) ||
                _targetDate!.isAtSameMomentAs(maxTargetOfHigherPriority))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La fecha debe ser posterior a la de los bolsillos de mayor prioridad',
              ),
            ),
          );
          return;
        }

        DateTime? minTargetOfLowerPriority;
        for (var p in widget.appState.pockets) {
          if (p.id != widget.editingPocket?.id &&
              p.priority > _priority &&
              p.targetDate != null) {
            if (minTargetOfLowerPriority == null ||
                p.targetDate!.isBefore(minTargetOfLowerPriority)) {
              minTargetOfLowerPriority = p.targetDate;
            }
          }
        }
        if (minTargetOfLowerPriority != null &&
            (_targetDate!.isAfter(minTargetOfLowerPriority) ||
                _targetDate!.isAtSameMomentAs(minTargetOfLowerPriority))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La fecha debe ser anterior a la de los bolsillos de menor prioridad',
              ),
            ),
          );
          return;
        }
      }

      final desc = _descriptionController.text.trim();
      final description = desc.isEmpty ? null : desc;
      final imageUrl = _selectedImagePath;

      double? fundingRuleValue;
      double? fundingRuleThreshold;

      if (_targetDate == null) {
        if (_fundingRuleType == 'percentage') {
          final valText = _fundingRuleValueController.text.trim();
          final val = double.tryParse(valText);
          if (val == null || val <= 0 || val > 100) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor ingrese un porcentaje válido entre 1 y 100%')),
            );
            return;
          }
          fundingRuleValue = val;
        } else if (_fundingRuleType == 'fixedThreshold') {
          final valText = _fundingRuleValueController.text.trim();
          final thresholdText = _fundingRuleThresholdController.text.trim();
          final val = double.tryParse(valText);
          final threshold = double.tryParse(thresholdText);
          if (val == null || val <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor ingrese un monto fijo a ahorrar válido')),
            );
            return;
          }
          if (threshold == null || threshold <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor ingrese un umbral de ingreso válido')),
            );
            return;
          }
          fundingRuleValue = val;
          fundingRuleThreshold = threshold;
        }
      } else {
        _fundingRuleType = 'none';
      }

      if (widget.editingPocket != null) {
        final updated = SavingPocket(
          id: widget.editingPocket!.id,
          name: name,
          currentAmountUSD: widget.editingPocket!.currentAmountUSD,
          targetAmountUSD: target,
          icon: _selectedIcon,
          colorHex: _selectedColor,
          description: description,
          imageUrl: imageUrl,
          targetDate: _targetDate,
          priority: _priority,
          fundingRuleType: _fundingRuleType,
          fundingRuleValue: fundingRuleValue,
          fundingRuleThreshold: fundingRuleThreshold,
        );
        widget.appState.updatePocket(updated);
      } else {
        widget.appState.addPocket(
          name: name,
          targetAmountUSD: target,
          icon: _selectedIcon,
          colorHex: _selectedColor,
          description: description,
          imageUrl: imageUrl,
          targetDate: _targetDate,
          priority: _priority,
          fundingRuleType: _fundingRuleType,
          fundingRuleValue: fundingRuleValue,
          fundingRuleThreshold: fundingRuleThreshold,
        );
      }
      Navigator.pop(context);
    }
  }

  void _deletePocket() {
    if (widget.editingPocket != null) {
      widget.appState.deletePocket(widget.editingPocket!.id);
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showImagePickerSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.dialogBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Seleccionar Origen de Imagen",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Camera option
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Cámara",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Gallery option
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Galería",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = parseHexColor(_selectedColor);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingPocket == null
                      ? "Nuevo Bolsillo"
                      : "Editar Bolsillo",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable fields
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "INFORMACIÓN DEL BOLSILLO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: "Nombre (ej. Regalos de Navidad)",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: "Meta Objetivo (USD) - Opcional",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Fecha Límite Estimada",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cardText,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          AppColors.nestedTabTrackBg,
                                      foregroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _targetDate ??
                                            DateTime.now().add(
                                              const Duration(days: 30),
                                            ),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        setState(() => _targetDate = date);
                                      }
                                    },
                                    child: Text(
                                      _targetDate != null
                                          ? formatDate(_targetDate!)
                                          : "Sin fecha límite",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_targetDate != null) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: AppColors.expense,
                                      ),
                                      onPressed: () {
                                        setState(() => _targetDate = null);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (_targetDate == null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.cardBorder.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Plan de ahorro automático",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'none',
                                          'Ninguno',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'percentage',
                                          '% Recurrente',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'fixedThreshold',
                                          'Monto Fijo',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_fundingRuleType != 'none') ...[
                                    const SizedBox(height: 12),
                                    if (_fundingRuleType == 'percentage') ...[
                                      const Text(
                                        "Porcentaje a ahorrar de cada ingreso recurrente:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _fundingRuleValueController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 10",
                                          suffixText: "%",
                                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ] else if (_fundingRuleType == 'fixedThreshold') ...[
                                      const Text(
                                        "Monto fijo a ahorrar:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _fundingRuleValueController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 20",
                                          suffixText: "\$",
                                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Cuando un ingreso sea igual o supere:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _fundingRuleThresholdController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 100",
                                          suffixText: "\$",
                                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  "Descripción (ej. Qué es lo que quiero comprar, opcional)",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "FOTO DEL BOLSILLO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedImagePath != null &&
                              _selectedImagePath!.isNotEmpty) ...[
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _selectedImagePath!.startsWith('http')
                                      ? Image.network(
                                          _selectedImagePath!,
                                          height: 140,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_selectedImagePath!),
                                          height: 140,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                height: 140,
                                                width: double.infinity,
                                                color: Colors.grey[200],
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image_rounded,
                                                  size: 36,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedImagePath = null,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _showImagePickerSourceSheet,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            GestureDetector(
                              onTap: _showImagePickerSourceSheet,
                              child: Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.08),
                                    style: BorderStyle.solid,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_rounded,
                                      color: themeColor.withOpacity(0.8),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "Agregar foto (Cámara o Galería)",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Priority Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PRIORIDAD DE FINANCIACIÓN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildPriorityButton(1, "Alta (1)", themeColor),
                              const SizedBox(width: 8),
                              _buildPriorityButton(2, "Media (2)", themeColor),
                              const SizedBox(width: 8),
                              _buildPriorityButton(3, "Baja (3)", themeColor),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Los bolsillos con prioridad alta se financiarán primero con tu potencial de ahorro diario. Si hay varios en el mismo nivel, compartirán los fondos proporcionalmente.",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.cardSubtitleText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icon section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ICONO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.2,
                                ),
                            itemCount: _icons.length,
                            itemBuilder: (context, index) {
                              final icon = _icons[index];
                              final isSelected = _selectedIcon == icon;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedIcon = icon),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeColor
                                        : themeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected
                                        ? Colors.white
                                        : themeColor,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COLOR",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _colors.map((colorHex) {
                              final isSelected = _selectedColor == colorHex;
                              final color = parseHexColor(colorHex);
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedColor = colorHex),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Destructive Delete Button
                    if (widget.editingPocket != null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense.withOpacity(0.08),
                          foregroundColor: AppColors.expense,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _deletePocket,
                        child: const Text(
                          "Eliminar Bolsillo",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Save / Cancel Buttons Row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return null;
                      final targetText = _targetController.text.trim();
                      if (targetText.isNotEmpty) {
                        final target = double.tryParse(targetText);
                        if (target == null || target < 0) return null;
                      }
                      return _savePocket;
                    }(),
                    child: const Text(
                      "Guardar",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidBalanceBanner extends StatefulWidget {
  const _LiquidBalanceBanner();

  @override
  State<_LiquidBalanceBanner> createState() => _LiquidBalanceBannerState();
}

class _LiquidBalanceBannerState extends State<_LiquidBalanceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late PageController _pageController;
  int _currentPage = 0;
  bool _obscureBalance = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _pageController = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Sort accounts: USD first, then VES
    final sortedAccounts = List<Account>.from(appState.accounts);
    sortedAccounts.sort((a, b) {
      if (a.currency == CurrencyType.usd && b.currency != CurrencyType.usd)
        return -1;
      if (a.currency != CurrencyType.usd && b.currency == CurrencyType.usd)
        return 1;
      return 0;
    });

    final totalPages = 1 + sortedAccounts.length;

    final displayBalance = _obscureBalance
        ? (appState.selectedCurrency == CurrencyType.usd
              ? "\$ ••••"
              : "Bs. ••••")
        : (appState.selectedCurrency == CurrencyType.usd
              ? formatUSD(appState.liquidBalanceUSD)
              : formatBs(
                  appState.convert(
                    amountUSD: appState.liquidBalanceUSD,
                    to: CurrencyType.bsBCV,
                  ),
                ));

    final String conversionText = _obscureBalance
        ? "≈ ••••"
        : (appState.selectedCurrency == CurrencyType.usd
              ? "≈ ${formatBs(appState.convert(amountUSD: appState.liquidBalanceUSD, to: CurrencyType.bsBCV))} (BCV)"
              : "≈ ${formatUSD(appState.liquidBalanceUSD)}");

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClaymorphicCard(
        cornerRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: totalPages,
                itemBuilder: (context, index) {
                  final isConsolidated = index == sortedAccounts.length;

                  if (isConsolidated) {
                    return GestureDetector(
                      onTapDown: (_) => _controller.forward(),
                      onTapUp: (_) {
                        _controller.reverse();
                        appState.toggleSelectedCurrency();
                      },
                      onTapCancel: () => _controller.reverse(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 16.0,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    appState.selectedCurrency ==
                                            CurrencyType.usd
                                        ? "DISPONIBLE (USD)"
                                        : "DISPONIBLE (VES)",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _obscureBalance = !_obscureBalance;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _obscureBalance
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "1 USD = Bs. ${appState.bcvRate.toStringAsFixed(2)} (BCV)",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayBalance,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              conversionText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final acc = sortedAccounts[index];
                    final isUsd = acc.currency == CurrencyType.usd;
                    final cardColor = parseHexColor(acc.colorHex);

                    final displayAccBalance = _obscureBalance
                        ? (isUsd ? "\$ ••••" : "Bs. ••••")
                        : (isUsd
                              ? formatUSD(acc.balance)
                              : formatBs(acc.balance));

                    final String accConversionText = _obscureBalance
                        ? "≈ ••••"
                        : (isUsd
                              ? "≈ ${formatBs(appState.convert(amountUSD: acc.balance, to: CurrencyType.bsBCV))} (BCV)"
                              : "≈ ${formatUSD(acc.balance / (appState.bcvRate > 0 ? appState.bcvRate : 1.0))}");

                    return GestureDetector(
                      onTapDown: (_) => _controller.forward(),
                      onTapUp: (_) {
                        _controller.reverse();
                      },
                      onTapCancel: () => _controller.reverse(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        getIconData(acc.icon),
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        acc.name.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _obscureBalance = !_obscureBalance;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _obscureBalance
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isUsd
                                  ? "Cuenta en Dólares"
                                  : "Cuenta en Bolívares",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayAccBalance,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              accConversionText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final isSelected = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class PocketTransactionBottomSheet extends StatefulWidget {
  final AppState appState;
  final SavingPocket pocket;
  final bool isDeposit;

  const PocketTransactionBottomSheet({
    super.key,
    required this.appState,
    required this.pocket,
    required this.isDeposit,
  });

  @override
  State<PocketTransactionBottomSheet> createState() =>
      _PocketTransactionBottomSheetState();
}

class _PocketTransactionBottomSheetState
    extends State<PocketTransactionBottomSheet> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _confirmTransaction() {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt > 0) {
      if (widget.isDeposit) {
        widget.appState.depositToPocket(id: widget.pocket.id, amountUSD: amt);
      } else {
        widget.appState.withdrawFromPocket(
          id: widget.pocket.id,
          amountUSD: amt,
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pocket = widget.pocket;
    final isDeposit = widget.isDeposit;
    final themeColor = parseHexColor(pocket.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFD6D6D6),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDeposit ? "Asignar Fondos" : "Retirar Fondos",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card content
          ClaymorphicCard(
            cornerRadius: 24,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Pocket Icon & Name Badge
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getIconData(pocket.icon),
                        color: themeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pocket.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDeposit
                                ? "Disponible: ${formatUSD(widget.appState.liquidBalanceUSD)}"
                                : "Ahorrado: ${formatUSD(pocket.currentAmountUSD)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount Text Field (Modern layout)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "0.00",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      suffixText: "USD",
                      suffixStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),

                // Preset Shortcuts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [10, 50, 100].map((val) {
                    return TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        _amountController.text = val.toString();
                        setState(() {});
                      },
                      child: Text(
                        "+$val USD",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons row
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      (_amountController.text.trim().isEmpty ||
                          (double.tryParse(_amountController.text) ?? 0.0) <= 0)
                      ? null
                      : _confirmTransaction,
                  child: Text(
                    isDeposit ? "Asignar" : "Retirar",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabSegment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurrentFilterSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecurrentFilterSegment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 58.0;
  @override
  double get maxExtent => 58.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

