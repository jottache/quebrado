import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/add_transaction_dialog.dart';
import '../dialogs/add_account_dialog.dart';
import '../dialogs/add_exchange_dialog.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import 'settings_screen.dart';
import '../theme/colors.dart';

import 'package:showcaseview/showcaseview.dart';
import '../services/db_helper.dart';
import '../models/timeline_event.dart';
import '../widgets/timeline_event_row.dart';
import '../dialogs/day_actions_dialog.dart';
import '../widgets/dashboard_charts_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _patrimonioKey = GlobalKey();
  final GlobalKey _balanceActionsKey = GlobalKey();
  final GlobalKey _cuentasKey = GlobalKey();
  final GlobalKey _tasaKey = GlobalKey();

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
    if (appState.shouldShowDashboardTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorialDirectly();
      });
    }
  }

  Future<void> _checkAndShowTutorial() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final hasSeen = await DatabaseHelper.instance.getSetting('tutorial_dashboard_seen');
      if (hasSeen != 'true') {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([
            _patrimonioKey,
            _balanceActionsKey,
            _tasaKey,
            _cuentasKey,
            appState.fabKey,
          ]);
          await DatabaseHelper.instance.setSetting('tutorial_dashboard_seen', 'true');
        }
      }
    } catch (e) {
      debugPrint("Error loading dashboard tutorial setting: $e");
    }
  }

  void _triggerTutorialDirectly() {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.shouldShowDashboardTutorial = false; // Reset trigger
      ShowCaseWidget.of(context).startShowCase([
        _patrimonioKey,
        _balanceActionsKey,
        _tasaKey,
        _cuentasKey,
        appState.fabKey,
      ]);
      DatabaseHelper.instance.setSetting('tutorial_dashboard_seen', 'true');
    } catch (e) {
      debugPrint("Error triggering dashboard tutorial directly: $e");
    }
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return "Hoy";
    } else if (eventDate == tomorrow) {
      return "Mañana";
    } else {
      final daysOfWeek = [
        "Domingo",
        "Lunes",
        "Martes",
        "Miércoles",
        "Jueves",
        "Viernes",
        "Sábado",
      ];
      final dayName = daysOfWeek[date.weekday % 7];
      final dayStr = date.day.toString().padLeft(2, '0');
      final monthStr = date.month.toString().padLeft(2, '0');

      if (date.year == now.year) {
        return "$dayName $dayStr/$monthStr";
      } else {
        return "$dayName $dayStr/$monthStr/${date.year}";
      }
    }
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
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.refreshRates();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 140.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Future transactions warning card
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  final futureTxs = appState.transactions.where((t) => t.date.isAfter(todayEnd)).toList();
                  if (futureTxs.isEmpty) return const SizedBox.shrink();

                  final count = futureTxs.length;
                  double expensesUSD = 0.0;
                  for (var t in futureTxs) {
                    if (t.type == TransactionType.expense) {
                      expensesUSD += t.currency == CurrencyType.usd
                          ? t.amount
                          : t.amount / (t.exchangeRate > 0 ? t.exchangeRate : 1.0);
                    }
                  }

                  if (expensesUSD <= 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        appState.setHistoryFilterIndex(4); // "Futuras" filter
                        appState.setTabIndex(2);           // "Historial" tab
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Pagos a futuro detectados",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Tienes $count ${count == 1 ? 'pago programado' : 'pagos programados'} por un total de ${formatUSD(expensesUSD)}. Ya se descontaron de tu saldo actual.",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.primary.withOpacity(0.85),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // 1. MAIN BALANCE CARD
              Showcase(
                key: _patrimonioKey,
                title: "Balance general",
                description: "Muestra el balance total unificado o el saldo de una cuenta específica. Puedes pulsar sobre la tarjeta para alternar entre Dólares y Bolívares oficiales, y deslizar (slide) hacia la izquierda o derecha para ver el detalle de cada una de tus cuentas.",
                child: _BouncyBalanceCard(balanceActionsKey: _balanceActionsKey),
              ),
              const SizedBox(height: 24),

              // 2. MOTOR DE TASAS
              Showcase(
                key: _tasaKey,
                title: "Tasas Oficiales",
                description: "Consulta el precio del dólar oficial BCV, paralelo y euro. Se actualizan automáticamente si hay conexión a internet.",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              "Tasas Oficiales",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        appState.hasInternet
                            ? IconButton(
                                icon: appState.isFetchingRates
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primary,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                onPressed: appState.isFetchingRates
                                    ? null
                                    : () => appState.refreshRates(),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _RateCard(
                            title: "Oficial BCV",
                            rate: appState.bcvRate,
                            date: appState.rateHistory.isNotEmpty
                                ? appState.rateHistory.first.date
                                : null,
                            badge: const Text(
                              "\$",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _RateCard(
                            title: "Euro Oficial",
                            rate: appState.euroRate,
                            date: appState.euroRateHistory.isNotEmpty
                                ? appState.euroRateHistory.first.date
                                : null,
                            badge: const Text(
                              "€",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _RateCard(
                            title: "Paralelo",
                            rate: appState.parallelRate,
                            date: appState.rateHistory.isNotEmpty
                                ? appState.rateHistory.first.date
                                : null,
                            badge: const Text(
                              "\$",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1.5. MIS CUENTAS
              Showcase(
                key: _cuentasKey,
                title: "Mis Cuentas",
                description: "Tus cuentas físicas de dinero (efectivo, bancos). Pulsa '+' para agregar una nueva cuenta, o presiona alguna tarjeta para editarla.",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              "Mis Cuentas",
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
                            Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const AddAccountBottomSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: appState.accounts.map((acc) {
                          final color = parseHexColor(acc.colorHex);
                          final isUsd = acc.currency == CurrencyType.usd;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      AddAccountBottomSheet(editingAccount: acc),
                                );
                              },
                              child: ClaymorphicCard(
                                cornerRadius: 18,
                                padding: const EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 140,
                                  height: 110,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              getIconData(acc.icon),
                                              color: color,
                                              size: 16,
                                            ),
                                          ),
                                          Text(
                                            isUsd ? "\$" : "Bs.",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        acc.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isUsd
                                            ? formatUSD(acc.balance)
                                            : formatBs(acc.balance),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ANALYTICS CHARTS SECTION
              const DashboardChartsCard(),
              const SizedBox(height: 24),

              // PROJECTION SECTION
              Builder(
                builder: (context) {
                  final events = appState.getTimelineEvents(365);
                  if (events.isEmpty) return const SizedBox.shrink();

                  final Map<DateTime, List<TimelineEvent>> grouped = {};
                  for (var ev in events) {
                    final day = DateTime(ev.date.year, ev.date.month, ev.date.day);
                    grouped.putIfAbsent(day, () => []).add(ev);
                  }

                  final sortedDays = grouped.keys.toList()..sort();

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  List<DateTime> daysToShow = [];

                  if (grouped.containsKey(today)) {
                    daysToShow.add(today);
                    // Find the next day with events
                    final nextDay = sortedDays.firstWhere(
                      (d) => d.isAfter(today),
                      orElse: () => today,
                    );
                    if (nextDay != today) {
                      daysToShow.add(nextDay);
                    }
                  } else {
                    // Find the first day after today
                    final nextDay = sortedDays.firstWhere(
                      (d) => d.isAfter(today),
                      orElse: () => today,
                    );
                    if (nextDay != today) {
                      daysToShow.add(nextDay);
                    }
                  }

                  if (daysToShow.isEmpty) return const SizedBox.shrink();

                  final List<dynamic> dashboardItems = [];
                  for (var day in daysToShow) {
                    dashboardItems.add(_getDateHeader(day));
                    dashboardItems.addAll(grouped[day]!);
                  }

                  int firstEventIndex = -1;
                  int lastEventIndex = -1;
                  for (int i = 0; i < dashboardItems.length; i++) {
                    if (dashboardItems[i] is TimelineEvent) {
                      if (firstEventIndex == -1) firstEventIndex = i;
                      lastEventIndex = i;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                "Proyecciones Recientes",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              appState.setTabIndex(1);
                              appState.initialPocketsSubTab = 2;
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Ver más",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: List.generate(dashboardItems.length, (index) {
                          final item = dashboardItems[index];
                          if (item is String) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 16.0,
                                bottom: 8.0,
                                left: 4.0,
                                right: 4.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      final dayEvents = events
                                          .where((e) => _getDateHeader(e.date) == item)
                                          .toList();
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => DayActionsBottomSheet(
                                          headerText: item,
                                          dayEvents: dayEvents,
                                        ),
                                      );
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            );
                          } else {
                            final event = item as TimelineEvent;
                            return TimelineEventRow(
                              event: event,
                              isFirst: index == firstEventIndex,
                              isLast: index == lastEventIndex,
                            );
                          }
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (appState.rateFetchError != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "Error de Conexión: ${appState.rateFetchError}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.expense,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncyBalanceCard extends StatefulWidget {
  final GlobalKey balanceActionsKey;
  const _BouncyBalanceCard({required this.balanceActionsKey});

  @override
  State<_BouncyBalanceCard> createState() => _BouncyBalanceCardState();
}

class _BouncyBalanceCardState extends State<_BouncyBalanceCard>
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
              ? formatUSD(appState.totalBalanceUSD)
              : formatBs(
                  appState.convert(
                    amountUSD: appState.totalBalanceUSD,
                    to: CurrencyType.bsBCV,
                  ),
                ));

    final String conversionText = _obscureBalance
        ? "≈ ••••"
        : (appState.selectedCurrency == CurrencyType.usd
              ? "≈ ${formatBs(appState.convert(amountUSD: appState.totalBalanceUSD, to: CurrencyType.bsBCV))} (BCV)"
              : "≈ ${formatUSD(appState.totalBalanceUSD)}");

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClaymorphicCard(
        cornerRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
        child: Column(
          children: [
            SizedBox(
              height: 235,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: totalPages,
                itemBuilder: (context, index) {
                  final isConsolidated = index == 0;

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
                          vertical: 14.0,
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
                                        ? "CONSOLIDADO (USD)"
                                        : "CONSOLIDADO (VES)",
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
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayBalance,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              conversionText,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _HorizontalAccountsList(
                              accounts: sortedAccounts,
                              appState: appState,
                              obscureBalance: _obscureBalance,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final acc = sortedAccounts[index - 1];
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
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(height: 1, color: Colors.black12),
            ),
            const SizedBox(height: 12),
            Showcase(
              key: widget.balanceActionsKey,
              title: "Acciones de Balance",
              description: "Registra rápidamente un ingreso, gasto o realiza una compra-venta de divisas (dólares o bolívares) asociada a la cuenta activa.",
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final String? accountId =
                              _currentPage == sortedAccounts.length
                              ? null
                              : sortedAccounts[_currentPage].id;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddTransactionBottomSheet(
                              initialType: TransactionType.income,
                              initialAccountId: accountId,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_circle_down_rounded,
                                color: Colors.grey[700],
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Ingreso",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final String? accountId =
                              _currentPage == sortedAccounts.length
                              ? null
                              : sortedAccounts[_currentPage].id;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddExchangeBottomSheet(
                              initialAccountId: accountId,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.currency_exchange_rounded,
                                color: Colors.grey[700],
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Compra-Venta",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final String? accountId =
                              _currentPage == sortedAccounts.length
                              ? null
                              : sortedAccounts[_currentPage].id;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddTransactionBottomSheet(
                              initialType: TransactionType.expense,
                              initialAccountId: accountId,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_circle_up_rounded,
                                color: Colors.grey[700],
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Gasto",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
}

class _RateCard extends StatelessWidget {
  final String title;
  final double rate;
  final Color backgroundColor;
  final Widget badge;
  final DateTime? date;

  const _RateCard({
    required this.title,
    required this.rate,
    required this.badge,
    this.backgroundColor = AppColors.cardBackground,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return ClaymorphicCard(
      cornerRadius: 18,
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.all(12.0),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: rate.toStringAsFixed(2)));
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tasa "$title" copiada al portapapeles: ${rate.toStringAsFixed(2)}',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 100,
          height: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge,
              const Spacer(),
              Icon(
                Icons.content_copy_rounded,
                size: 12,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardSubtitleText,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  formatDate(date!),
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                formatRate(rate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalAccountsList extends StatefulWidget {
  final List<Account> accounts;
  final AppState appState;
  final bool obscureBalance;

  const _HorizontalAccountsList({
    required this.accounts,
    required this.appState,
    required this.obscureBalance,
  });

  @override
  State<_HorizontalAccountsList> createState() => _HorizontalAccountsListState();
}

class _HorizontalAccountsListState extends State<_HorizontalAccountsList> {
  late ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateIndicators);
    // Trigger check after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  @override
  void didUpdateWidget(covariant _HorizontalAccountsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateIndicators() {
    if (!_scrollController.hasClients) return;
    final metrics = _scrollController.position;
    final canLeft = metrics.pixels > 5;
    final canRight = metrics.pixels < metrics.maxScrollExtent - 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 8.0),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateIndicators();
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: widget.accounts.length,
              itemBuilder: (context, index) {
                final acc = widget.accounts[index];
                final isUsd = acc.currency == CurrencyType.usd;
                final displayAccBalance = widget.obscureBalance
                    ? (isUsd ? "\$ ••••" : "Bs. ••••")
                    : (isUsd ? formatUSD(acc.balance) : formatBs(acc.balance));

                final convertedText = isUsd
                    ? formatBs(acc.balance * widget.appState.bcvRate)
                    : formatUSD(acc.balance / (widget.appState.bcvRate > 0 ? widget.appState.bcvRate : 1.0));

                return Container(
                  margin: EdgeInsets.only(
                    right: index == widget.accounts.length - 1 ? 0.0 : 8.0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getIconData(acc.icon),
                            color: Colors.white.withOpacity(0.7),
                            size: 9,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            acc.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayAccBalance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        convertedText,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Left fade & scroll reference
          if (_canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0),
                      ],
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          // Right fade & scroll reference
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0),
                      ],
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
