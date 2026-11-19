import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
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
import 'rates_history_screen.dart';
import '../dialogs/super_app_hub_sheet.dart';
import '../dialogs/book_selector_dialog.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/suite_menu_button.dart';

import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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
    final tomorrow = today.add(Duration(days: 1));
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
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isDesktop
            ? Padding(
                padding: const EdgeInsets.only(left: OrtizSpace.md),
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.menu_book_rounded,
                        size: OrtizIconSize.sm),
                    label: Text(
                      appState.activeProfileName,
                      style: const TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      showResponsiveSheet(
                        context: context,
                        builder: (context) => const BookSelectorBottomSheet(),
                      );
                    },
                  ),
                ),
              )
            : SuiteMenuButton.leading(context),
        leadingWidth: isDesktop ? 190 : null,
        title: Image.asset(
          'assets/images/quebrado/logo_quebrado.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                iconSize: 26,
                onPressed: () {
                  showResponsiveSheet(
                    context: context,
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
                    padding: const EdgeInsets.all(OrtizSpace.xxs),
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
                          color: OrtizPalette.onAccent,
                          fontSize: OrtizFontSize.micro,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: OrtizSpace.sm),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            iconSize: 26,
            tooltip: "Sincronizar datos",
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sincronizando datos..."),
                  duration: Duration(milliseconds: 1000),
                ),
              );
              await Future.wait([
                appState.loadData(forceReload: true),
                appState.refreshRates(),
              ]);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Datos sincronizados correctamente"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: OrtizSpace.xs),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            iconSize: 26,
            tooltip: "Calculadora de divisas",
            onPressed: () {
              showResponsiveSheet(
                context: context,
                builder: (context) => const CalculatorBottomSheet(),
              );
            },
          ),
          const SizedBox(width: OrtizSpace.sm),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            iconSize: 24,
            tooltip: "Ajustes",
            onPressed: () {
              if (isDesktop) {
                showResponsiveSheet(
                  context: context,
                  builder: (context) => const SettingsScreen(),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              }
            },
          ),
          const SizedBox(width: OrtizSpace.lg),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.refreshRates();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1300 : 1100),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: isDesktop ? OrtizSpace.xxl : OrtizSpace.lg,
                right: isDesktop ? OrtizSpace.xxl : OrtizSpace.lg,
                top: OrtizSpace.lg,
                // Móvil: deja libre la barra inferior y el FAB.
                bottom: isDesktop
                    ? OrtizSpace.xxxl + OrtizSpace.sm
                    : kBottomNavigationBarHeight +
                        OrtizSize.minTouch +
                        OrtizSpace.xxxl,
              ),
              child: isDesktop
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFutureTransactionsCard(appState),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Columna Izquierda: Balance, Tasas, Cuentas
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                // Cada sección deja OrtizSpace.xxl debajo.
                                children: [
                                  _buildBalanceSection(appState),
                                  _buildRatesSection(appState),
                                  _buildAccountsSection(appState),
                                ],
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.xxl),
                            // Columna Derecha: Gráfica, Timeline / Proyecciones
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildChartsSection(appState),
                                  _buildTimelineSection(appState, context),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (appState.rateFetchError != null) ...[
                          const SizedBox(height: OrtizSpace.lg),
                          Center(
                            child: Text(
                              "Error de Conexión: ${appState.rateFetchError}",
                              style: const TextStyle(
                                fontSize: OrtizFontSize.caption,
                                color: AppColors.expense,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFutureTransactionsCard(appState),
                        // Cada sección deja OrtizSpace.xxl debajo.
                        _buildBalanceSection(appState),
                        _buildRatesSection(appState),
                        _buildAccountsSection(appState),
                        _buildChartsSection(appState),
                        _buildTimelineSection(appState, context),
                        if (appState.rateFetchError != null) ...[
                          const SizedBox(height: OrtizSpace.lg),
                          Center(
                            child: Text(
                              "Error de Conexión: ${appState.rateFetchError}",
                              style: const TextStyle(
                                fontSize: OrtizFontSize.caption,
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
        ),
      ),
    );
  }

  Widget _buildFutureTransactionsCard(AppState appState) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final futureTxs =
        appState.transactions.where((t) => t.date.isAfter(todayEnd)).toList();
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
      padding: const EdgeInsets.only(bottom: OrtizSpace.lg),
      child: GestureDetector(
        onTap: () {
          appState.setHistoryFilterIndex(4); // "Futuras" filter
          appState.setTabIndex(2); // "Historial" tab
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
          // Aviso (no tarjeta): mismo tono `warn` que «Programado» en Historial.
          decoration: BoxDecoration(
            color: OrtizPalette.warnTint,
            borderRadius: BorderRadius.circular(OrtizRadius.block),
            border: Border.all(
                color: OrtizPalette.warnBorder, width: OrtizStroke.hairline),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: OrtizPalette.warn,
                size: OrtizIconSize.sm,
              ),
              const SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Transacciones Programadas",
                      style: OrtizType.bodySm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.warn,
                      ),
                    ),
                    const SizedBox(height: OrtizSpace.xxs),
                    Text(
                      "Tienes $count ${count == 1 ? 'pago programado' : 'pagos programados'} por un total de ${formatUSD(expensesUSD)}. Ya se descontaron de tu saldo actual.",
                      style: OrtizType.caption.copyWith(
                        color: OrtizPalette.fg,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: OrtizPalette.warn,
                size: OrtizIconSize.md,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection(AppState appState) {
    return Showcase(
      key: _patrimonioKey,
      title: "Balance general",
      description:
          "Muestra el balance total unificado o el saldo de una cuenta específica. Puedes pulsar sobre la tarjeta para alternar entre Dólares y Bolívares oficiales, y deslizar hacia la izquierda o derecha para ver el detalle de cada una de tus cuentas.",
      child: _BouncyBalanceCard(balanceActionsKey: _balanceActionsKey),
    );
  }

  Widget _buildRatesSection(AppState appState) {
    return Showcase(
      key: _tasaKey,
      title: "Tasas Oficiales",
      description:
          "Consulta el precio del dólar oficial BCV, paralelo y euro. Se actualizan automáticamente si hay conexión a internet.",
      child: OrtizSection(
        title: "Tasas Oficiales",
        headerPadding:
            const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.show_chart_rounded),
              tooltip: 'Historial de tasas',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RatesHistoryScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: appState.isFetchingRates
                  ? const SizedBox(
                      width: OrtizIconSize.sm,
                      height: OrtizIconSize.sm,
                      child: CircularProgressIndicator(
                        strokeWidth: OrtizStroke.focus,
                      ),
                    )
                  : Icon(
                      appState.hasInternet
                          ? Icons.refresh_rounded
                          : Icons.wifi_off_rounded,
                      color: appState.hasInternet
                          ? null
                          : OrtizTokens.of(context).muted,
                      size: OrtizIconSize.md,
                    ),
              tooltip: appState.hasInternet
                  ? 'Actualizar tasas'
                  : 'Reintentar conexión',
              onPressed: appState.isFetchingRates
                  ? null
                  : () => appState.refreshRates(),
            ),
          ],
        ),
        children: [
          _buildExchangeCard(
            title: "Oficial BCV",
            rate: appState.bcvRate,
            date: appState.rateHistory.isNotEmpty ? appState.rateHistory.first.date : null,
            currencySymbol: "\$",
            isPositiveChange: true,
          ),
          _buildExchangeCard(
            title: "Euro Oficial",
            rate: appState.euroRate,
            date: appState.euroRateHistory.isNotEmpty ? appState.euroRateHistory.first.date : null,
            currencySymbol: "€",
            isPositiveChange: true,
          ),
          _buildExchangeCard(
            title: "Paralelo",
            rate: appState.parallelRate,
            date: null,
            currencySymbol: "\$",
            isPositiveChange: false,
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard({
    required String title,
    required double rate,
    DateTime? date,
    required String currencySymbol,
    required bool isPositiveChange,
  }) {
    return _RateCard(
      title: title,
      rate: rate,
      date: date,
      badge: Text(
        currencySymbol,
        style: OrtizType.titleSm.copyWith(
          color: currencySymbol == "€"
              ? AppColors.currencyEur
              : AppColors.currencyUsd,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildAccountsSection(AppState appState) {
    return Showcase(
      key: _cuentasKey,
      title: "Cuentas y bancos",
      description:
          "Lista de cuentas bancarias y billeteras digitales. Puedes pulsar sobre una cuenta para editar su saldo, icono o color.",
      child: OrtizSection(
        title: "Mis Cuentas",
        headerPadding:
            const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          tooltip: "Agregar cuenta",
          onPressed: () {
            showResponsiveSheet(
              context: context,
              builder: (context) => const AddAccountBottomSheet(),
            );
          },
        ),
        children: appState.accounts.map((acc) {
          // Color de la cuenta: dato de la persona.
          final color = parseHexColor(acc.colorHex);
          final isUsd = acc.currency == CurrencyType.usd;
          return OrtizListRow(
            leading: Icon(getIconData(acc.icon), color: color),
            title: acc.name,
            subtitle: isUsd ? "Cuenta en Dólares" : "Cuenta en Bolívares",
            trailing: OrtizAmount(
              value: acc.balance,
              currencySymbol: isUsd ? "\$" : "Bs.",
              format: isUsd ? formatUSD : formatBs,
            ),
            onTap: () {
              showResponsiveSheet(
                context: context,
                builder: (context) =>
                    AddAccountBottomSheet(editingAccount: acc),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartsSection(AppState appState) {
    return const DashboardChartsCard();
  }

  Widget _buildTimelineSection(AppState appState, BuildContext context) {
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
      final nextDay = sortedDays.firstWhere(
        (d) => d.isAfter(today),
        orElse: () => today,
      );
      if (nextDay != today) {
        daysToShow.add(nextDay);
      }
    } else {
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

    final t = OrtizTokens.of(context);
    return OrtizSection(
      title: "Proyecciones Recientes",
      trailing: TextButton(
        onPressed: () {
          appState.setTabIndex(1);
          appState.initialPocketsSubTab = 2;
        },
        child: const Text("Ver más"),
      ),
      children: [
        Column(
          children: List.generate(dashboardItems.length, (index) {
            final item = dashboardItems[index];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: OrtizSpace.lg,
                  bottom: OrtizSpace.sm,
                  left: OrtizSpace.xs,
                  right: OrtizSpace.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: OrtizSize.dot,
                          height: OrtizSize.dot,
                          decoration: BoxDecoration(
                            color: t.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.sm),
                        Text(
                          item,
                          style: OrtizType.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: t.fg,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: "Acciones del día",
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: t.muted,
                        size: OrtizIconSize.md,
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
      ],
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
      duration: Duration(milliseconds: 100),
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
      if (a.currency == CurrencyType.usd && b.currency != CurrencyType.usd) {
        return -1;
      }
      if (a.currency != CurrencyType.usd && b.currency == CurrencyType.usd) {
        return 1;
      }
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

    final t = OrtizTokens.of(context);
    _controller.duration = OrtizMotion.of(context, OrtizMotion.fast);
    final double consolidatedValue =
        appState.selectedCurrency == CurrencyType.usd
            ? appState.totalBalanceUSD
            : appState.convert(
                amountUSD: appState.totalBalanceUSD,
                to: CurrencyType.bsBCV,
              );
    final bigAmountStyle = OrtizType.amountLg.copyWith(
      fontSize: OrtizFontSize.displayLg,
      fontWeight: FontWeight.w700,
    );
    final labelStyle = OrtizType.caption.copyWith(
      color: t.muted,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    final conversionStyle = OrtizType.bodySm.copyWith(
      color: t.muted,
      fontWeight: FontWeight.w600,
    );

    // Cifras principales: el único bloque destacado (sobre `surfaceHigh`).
    return ScaleTransition(
      scale: _scaleAnimation,
      child: OrtizSection(
        surface: true,
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
                      child: SizedBox(
                        width: double.infinity,
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
                                    style: labelStyle,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _obscureToggle(t),
                                ),
                              ],
                            ),
                            const SizedBox(height: OrtizSpace.sm),
                            OrtizAmount(
                              value: consolidatedValue,
                              currencySymbol:
                                  appState.selectedCurrency == CurrencyType.usd
                                      ? "\$"
                                      : "Bs.",
                              format: (_) => displayBalance,
                              style: bigAmountStyle,
                            ),
                            const SizedBox(height: OrtizSpace.xxs),
                            Text(conversionText, style: conversionStyle),
                            const SizedBox(height: OrtizSpace.xs),
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
                      child: SizedBox(
                        width: double.infinity,
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
                                      // Color de la cuenta: dato de la persona.
                                      Icon(
                                        getIconData(acc.icon),
                                        color: cardColor,
                                        size: OrtizIconSize.sm,
                                      ),
                                      const SizedBox(width: OrtizSpace.xs),
                                      Text(
                                        acc.name.toUpperCase(),
                                        style: labelStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _obscureToggle(t),
                                ),
                              ],
                            ),
                            const SizedBox(height: OrtizSpace.xs),
                            Text(
                              isUsd
                                  ? "Cuenta en Dólares"
                                  : "Cuenta en Bolívares",
                              style: OrtizType.caption.copyWith(color: t.muted),
                            ),
                            const SizedBox(height: OrtizSpace.lg),
                            OrtizAmount(
                              value: acc.balance,
                              currencySymbol: isUsd ? "\$" : "Bs.",
                              format: (_) => displayAccBalance,
                              style: bigAmountStyle,
                            ),
                            const SizedBox(height: OrtizSpace.xs),
                            Text(accConversionText, style: conversionStyle),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: OrtizSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final isSelected = _currentPage == i;
                return AnimatedContainer(
                  duration: OrtizMotion.of(context, OrtizMotion.fast),
                  curve: OrtizMotion.ease,
                  width: isSelected ? OrtizSpace.lg : OrtizSize.dot,
                  height: OrtizSize.dot,
                  margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: isSelected ? t.fg : t.line,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                );
              }),
            ),
            const SizedBox(height: OrtizSpace.sm),
            const Divider(height: OrtizStroke.hairline),
            const SizedBox(height: OrtizSpace.md),
            Showcase(
              key: widget.balanceActionsKey,
              title: "Acciones de Balance",
              description: "Registra rápidamente un ingreso, gasto o realiza una compra-venta de divisas (dólares o bolívares) asociada a la cuenta activa.",
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
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
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_circle_down_rounded,
                                color: t.income,
                                size: OrtizIconSize.lg,
                              ),
                              SizedBox(height: OrtizSpace.xs),
                              Text(
                                "Ingreso",
                                style: OrtizType.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: t.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: OrtizSpace.xxl,
                      width: OrtizStroke.hairline,
                      color: t.line,
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
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.currency_exchange_rounded,
                                color: t.fg,
                                size: OrtizIconSize.lg,
                              ),
                              SizedBox(height: OrtizSpace.xs),
                              Text(
                                "Compra-Venta",
                                style: OrtizType.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: t.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: OrtizSpace.xxl,
                      width: OrtizStroke.hairline,
                      color: t.line,
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
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_circle_up_rounded,
                                color: t.expense,
                                size: OrtizIconSize.lg,
                              ),
                              SizedBox(height: OrtizSpace.xs),
                              Text(
                                "Gasto",
                                style: OrtizType.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: t.fg,
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
    );
  }

  /// Botón de ojo para ocultar o mostrar los saldos.
  Widget _obscureToggle(OrtizTokens t) {
    return IconButton(
      tooltip: _obscureBalance ? "Mostrar saldos" : "Ocultar saldos",
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _obscureBalance
            ? Icons.visibility_rounded
            : Icons.visibility_off_rounded,
        size: OrtizIconSize.sm,
        color: t.muted,
      ),
      onPressed: () {
        setState(() {
          _obscureBalance = !_obscureBalance;
        });
      },
    );
  }
}

/// Fila de una tasa: al tocarla, copia el valor al portapapeles.
class _RateCard extends StatelessWidget {
  final String title;
  final double rate;
  final Widget badge;
  final DateTime? date;

  const _RateCard({
    required this.title,
    required this.rate,
    required this.badge,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return OrtizListRow(
      leading: SizedBox(
        width: OrtizIconSize.lg,
        child: Center(child: badge),
      ),
      title: title,
      subtitle: date != null ? formatDate(date!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrtizAmount(
            value: rate,
            currencySymbol: "Bs.",
            format: formatRate,
            style: OrtizType.amount.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: OrtizSpace.sm),
          Icon(
            Icons.content_copy_rounded,
            size: OrtizIconSize.xs,
            color: t.muted,
          ),
        ],
      ),
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
    final t = OrtizTokens.of(context);

    return Container(
      height: 60,
      margin: EdgeInsets.only(top: OrtizSpace.sm),
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
              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
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

                final isLast = index == widget.accounts.length - 1;
                return Container(
                  margin: EdgeInsets.only(right: isLast ? 0.0 : OrtizSpace.sm),
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                  // Pastilla sobre el bloque `surfaceHigh`: borde fino, sin sombra.
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    border: Border.all(
                      color: t.line,
                      width: OrtizStroke.hairline,
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
                            color: t.muted,
                            size: OrtizIconSize.xs,
                          ),
                          const SizedBox(width: OrtizSpace.xs),
                          Text(
                            acc.name.toUpperCase(),
                            style: OrtizType.caption.copyWith(
                              fontSize: OrtizFontSize.micro,
                              fontWeight: FontWeight.bold,
                              color: t.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: OrtizSpace.xxs),
                      Text(
                        displayAccBalance,
                        style: OrtizType.amount.copyWith(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.w700,
                          color: t.fg,
                        ),
                      ),
                      Text(
                        convertedText,
                        style: OrtizType.amount.copyWith(
                          fontSize: OrtizFontSize.micro,
                          color: t.muted,
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
                        t.surfaceHigh,
                        t.surfaceHigh.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: OrtizSpace.xs),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: t.muted,
                      size: OrtizIconSize.xs,
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
                        t.surfaceHigh,
                        t.surfaceHigh.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: OrtizSpace.xs),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: t.muted,
                      size: OrtizIconSize.xs,
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
