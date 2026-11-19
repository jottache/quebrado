import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/pocket_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_recurring_payment_dialog.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';
import '../theme/colors.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../dialogs/book_selector_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

class PocketsScreen extends StatefulWidget {
  const PocketsScreen({super.key});

  @override
  State<PocketsScreen> createState() => _PocketsScreenState();
}

class _PocketsScreenState extends State<PocketsScreen> {
  /// Espacio libre al final de la lista para que el último elemento no quede
  /// tapado por la barra de navegación y el botón flotante.
  static const double _listBottomInset = 140;

  int _selectedTab = 0; // 0 = Bolsillos, 1 = Suscripciones
  int _selectedRecurrentFilter = 0; // 0 = Todos, 1 = Ingresos, 2 = Pagos

  bool _isFastScrolling = false;
  double _fastScrollY = 0.0;
  DateTime? _fastScrollDate;
  int _lastHapticMonth = -1;

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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: OrtizSize.minTouch,
                    height: OrtizSpace.xs,
                    decoration: BoxDecoration(
                      color: OrtizTokens.of(context).line,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "¿Por qué usar Bolsillos para tus Deudas?",
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Evita la Ilusión de Liquidez",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "Al separar dinero en un bolsillo para una compra a cuotas (ej. Cashea), retiras ese dinero de tu saldo líquido disponible. Esto te impide gastarlo por error y te asegura tener los fondos listos cuando venza la cuota.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Estrategias de Financiamiento",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "• Pre-fondeo: Guarda el monto total de la compra en el bolsillo hoy. Cada cuota se debitará sola sin tocar tu cuenta del día a día.\n• Apartado Progresivo: Usa tu sueldo recurrente para apartar y transferir la cuota al bolsillo automáticamente antes de la fecha de cobro.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Ejemplo Práctico (Cashea)",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "Si compras un teléfono financiado a 6 cuotas de \$20 cada 14 días (total \$120):\n• Si pre-fondeas: Metes los \$120 al bolsillo hoy. Tu cuenta diaria muestra tu balance real y las cuotas se cobran del bolsillo.\n• Si apartas progresivamente: Programas tu sueldo recurrente para depositar \$20 en el bolsillo justo antes de cada cobro de Cashea.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Monitoreo en el Timeline",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "Si asocias tus gastos recurrentes a un bolsillo, el simulador vigilará si el bolsillo se queda sin fondos y te dirá cuánto 'Dinero Seguro' tienes realmente para gastar.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.xxl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
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
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final t = OrtizTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: OrtizSpace.xxxl),
          child: Image.asset(
            'assets/images/quebrado/logo_quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        leading: isDesktop
            ? Padding(
                padding: const EdgeInsets.only(left: OrtizSpace.md),
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.auto_stories_rounded, size: OrtizIconSize.sm),
                    label: Text(
                      appState.activeProfileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
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
            : IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () {
                  showResponsiveSheet(
                    context: context,
                    builder: (context) => const SettingsScreen(),
                  );
                },
              ),
        leadingWidth: isDesktop ? 180 : null,
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
                    builder: (context) => const PendingConfirmationsBottomSheet(),
                  );
                },
              ),
              if (appState.pendingPaymentsToday.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(OrtizSpace.xxs),
                    decoration: BoxDecoration(
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
            icon: const Icon(Icons.calculate_outlined),
            iconSize: 26,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CalculatorBottomSheet(),
              );
            },
          ),
          const SizedBox(width: OrtizSpace.lg),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
          // Spacing at the top of the CustomScrollView
          SliverToBoxAdapter(
            child: SizedBox(height: OrtizSpace.md),
          ),

          // 2. Sticky Tab Bar Selector
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: Container(
                color: AppColors.background,
                padding: EdgeInsets.symmetric(
                  horizontal: OrtizSpace.lg,
                  vertical: OrtizSpace.sm,
                ),
                child: Showcase(
                  key: _tabsKey,
                  title: "Pestañas de Planificación",
                  description: "Navega entre tus Bolsillos de ahorro, tus Pagos Recurrentes (obligaciones periódicas) y la Proyección en el Timeline.",
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.mainTabTrackBg,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
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
          if (_selectedTab == 0 || _selectedTab == 1)
            SliverPadding(
              padding: EdgeInsets.only(
                left: OrtizSpace.lg,
                right: OrtizSpace.lg,
                top: OrtizSpace.md,
                bottom: _listBottomInset,
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
                                Text(
                                  "Bolsillos de Ahorro",
                                  style: OrtizType.titleSm.copyWith(color: t.muted),
                                ),
                                const SizedBox(width: OrtizSpace.xs),
                                IconButton(
                                  tooltip: 'Qué son los bolsillos',
                                  icon: Icon(
                                    Icons.info_outline_rounded,
                                    color: t.muted,
                                    size: OrtizIconSize.md,
                                  ),
                                  onPressed: () => _showPocketsInfo(context),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Nuevo bolsillo',
                            icon: Icon(
                              Icons.add_circle_rounded,
                              color: t.accent,
                              size: OrtizIconSize.lg,
                            ),
                            onPressed: () =>
                                _showAddPocketDialog(context, appState),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: OrtizSpace.sm),

                      if (appState.pockets.isEmpty)
                        const OrtizEmptyState(
                          icon: Icons.archive_rounded,
                          title: "No tienes bolsillos aún",
                        )
                      else
                        _buildPocketList(context, appState),
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
                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.sm),
                                Text(
                                  "Pagos Recurrentes y Cuotas",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.body,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.cardText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_rounded,
                                color: AppColors.primary,
                                size: OrtizIconSize.lg,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      AddRecurringPaymentBottomSheet(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: OrtizSpace.sm),

                      // Filter Segmented Control
                      Showcase(
                        key: _recurrentsFilterKey,
                        title: "Filtros de Obligaciones",
                        description: "Filtra rápidamente el listado para ver solo tus ingresos planificados, tus pagos recurrentes, o todos al mismo tiempo.",
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(OrtizSpace.xs),
                          decoration: BoxDecoration(
                            color: AppColors.mainTabTrackBg,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
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
                      SizedBox(height: OrtizSpace.lg),

                      // Recurring payments list
                      Builder(
                        builder: (context) {
                          final filteredRecurring = appState.recurringPayments.where((
                            pay,
                          ) {
                            if (_selectedRecurrentFilter == 0) return true;
                            if (_selectedRecurrentFilter == 1) {
                              return pay.type == TransactionType.income;
                            }
                            return pay.type == TransactionType.expense;
                          }).toList();

                          if (filteredRecurring.isEmpty) {
                            return Showcase(
                              key: _recurrentsListKey,
                              title: "Listado de Obligaciones",
                              description: "Aquí verás tus obligaciones y planificaciones una vez las agregues. El simulador las usará para proyectar tu flujo de caja.",
                              child: SizedBox(
                                width: double.infinity,
                                child: OrtizEmptyState(
                                  icon: Icons.credit_card_rounded,
                                  title: _selectedRecurrentFilter == 0
                                      ? "Sin registros recurrentes"
                                      : _selectedRecurrentFilter == 1
                                      ? "Sin ingresos recurrentes"
                                      : "Sin pagos recurrentes",
                                ),
                              ),
                            );
                          }

                          return OrtizSection(
                            divided: true,
                            children: List.generate(filteredRecurring.length, (index) {
                              final pay = filteredRecurring[index];
                              final row = _RecurringPaymentRow(
                                payment: pay,
                                backgroundColor: AppColors.getAlternateCardColor(
                                  index,
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
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                left: OrtizSpace.lg,
                right: OrtizSpace.lg,
                top: OrtizSpace.md,
                bottom: _listBottomInset,
              ),
              sliver: TimelineScreen(),
            ),
        ],
          ),
          
          // FAST SCROLLER (Only active on Timeline tab)
          if (_selectedTab == 2) ...[
            // Hit Area
            Positioned(
              left: 0,
              top: 140, // Below headers
              bottom: 0,
              width: 50,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (details) => _updateFastScroll(details.localPosition.dy, constraints.maxHeight, appState),
                    onVerticalDragUpdate: (details) => _updateFastScroll(details.localPosition.dy, constraints.maxHeight, appState),
                    onVerticalDragEnd: (_) {
                      setState(() {
                        _isFastScrolling = false;
                        _lastHapticMonth = -1;
                      });
                    },
                    onVerticalDragCancel: () {
                      setState(() {
                        _isFastScrolling = false;
                        _lastHapticMonth = -1;
                      });
                    },
                    child: Container(
                      color: Colors.transparent, // Hit area
                    ),
                  );
                },
              ),
            ),
            
            // Popover Date Bubble
            if (_isFastScrolling && _fastScrollDate != null)
              Positioned(
                left: 60,
                top: 140 + _fastScrollY - 25, // Align center of bubble with finger
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                  color: AppColors.primary,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: OrtizIconSize.sm, color: OrtizPalette.onAccent),
                        SizedBox(width: OrtizSpace.sm),
                        Text(
                          _getFormattedMonthYear(_fastScrollDate!),
                          style: TextStyle(
                            color: OrtizPalette.onAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: OrtizFontSize.body,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Lista de bolsillos sin tarjetas: una fila por bolsillo, separadas por una
  /// línea fina, con entrada escalonada.
  Widget _buildPocketList(BuildContext context, AppState appState) {
    final pockets = appState.pockets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < pockets.length; index++) ...[
          if (index > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
              child: Divider(height: OrtizStroke.hairline),
            ),
          KeyedSubtree(
            key: ValueKey('pocket_row_${pockets[index].id}'),
            child: ortizStaggered(
              context,
              index,
              _buildPocketRow(context, appState, pockets[index]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPocketRow(
    BuildContext context,
    AppState appState,
    SavingPocket pocket,
  ) {
    return PocketCard(
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

  void _updateFastScroll(double localY, double maxHeight, AppState appState) {
    final events = appState.getTimelineEvents(365);
    if (events.isEmpty) return;

    double percentage = (localY / maxHeight).clamp(0.0, 1.0);
    int targetIndex = (percentage * (events.length - 1)).round();
    
    DateTime targetDate = events[targetIndex].date;

    // Estimate the scroll offset. 
    // Header slivers take roughly 72px (12 + 60 for tab bar).
    double headerHeight = 72.0;
    double estimatedItemHeight = 110.0;
    double targetOffset = headerHeight + (targetIndex * estimatedItemHeight);

    if (_scrollController.hasClients) {
       _scrollController.jumpTo(targetOffset);
    }

    if (_lastHapticMonth != targetDate.month) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _isFastScrolling = true;
      _fastScrollY = localY;
      _fastScrollDate = targetDate;
      _lastHapticMonth = targetDate.month;
    });
  }

  String _getFormattedMonthYear(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${months[date.month - 1]} ${date.year}';
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
        themeColor == OrtizPalette.fg ||
        themeColor == AppColors.cardBackground ||
        HSLColor.fromColor(themeColor).lightness >= 0.75;
    final subAccentColor = parseHexColor(payment.colorHex);

    final textColor = isLightCard ? AppColors.cardText : OrtizPalette.fg;
    final subtitleColor = isLightCard
        ? AppColors.cardSubtitleText
        : OrtizPalette.fg.withValues(alpha: 0.7);

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

    // Fila sin tarjeta (spec 05): va dentro de una `OrtizSection` dividida.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              AddRecurringPaymentBottomSheet(editingPayment: payment),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(OrtizSpace.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLightCard
                    ? subAccentColor.withValues(alpha: 0.12)
                    : OrtizPalette.fg.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getIconData(payment.icon),
                color: isLightCard ? subAccentColor : OrtizPalette.fg,
                size: OrtizIconSize.md,
              ),
            ),
            SizedBox(width: OrtizSpace.md),

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
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.xxs),
                  Text(
                    "${payment.frequency.value} • ${payment.notificationOption.value}",
                    style: TextStyle(fontSize: OrtizFontSize.caption, color: subtitleColor),
                  ),
                  if (accountName != null) ...[
                    SizedBox(height: OrtizSpace.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: OrtizIconSize.xs,
                          color: subtitleColor,
                        ),
                        SizedBox(width: OrtizSpace.xs),
                        Flexible(
                          child: Text(
                            accountName,
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
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
                    SizedBox(height: OrtizSpace.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.archive_rounded,
                          size: OrtizIconSize.xs,
                          color: subtitleColor,
                        ),
                        SizedBox(width: OrtizSpace.xs),
                        Flexible(
                          child: Text(
                            pocketName,
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
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
                OrtizAmount(
                  value: payment.amount,
                  currencySymbol:
                      payment.currency == CurrencyType.usd ? '\$' : 'Bs.',
                  format: (v) =>
                      "${isIncome ? '+' : '-'}${payment.currency == CurrencyType.usd ? '\$' : 'Bs.'}${v.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.body,
                    fontWeight: FontWeight.w900,
                    color: isIncome
                        ? (isLightCard ? OrtizPalette.income : OrtizPalette.fg)
                        : (isLightCard ? OrtizPalette.expense : OrtizPalette.fg),
                  ),
                ),
                SizedBox(height: OrtizSpace.xxs),
                Text(
                  payment.frequency == SubscriptionFrequency.once
                      ? "Fecha: ${formatDate(payment.startDate)}"
                      : "Próximo: ${formatDate(payment.startDate)}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                OrtizPill(
                  label: typeLabel,
                  color: isLightCard
                      ? (isIncome ? OrtizPalette.income : OrtizPalette.expense)
                      : null,
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
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(
              color: isSelected ? themeColor : themeColor.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: FontWeight.bold,
              color: isSelected ? OrtizPalette.onAccent : themeColor,
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
        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : OrtizPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
          border: Border.all(
            color: isSelected ? AppColors.primary : OrtizPalette.line,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? OrtizPalette.onAccent : AppColors.cardText,
            fontSize: OrtizFontSize.caption,
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
            SnackBar(
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
            SnackBar(
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
              SnackBar(content: Text('Por favor ingrese un porcentaje válido entre 1 y 100%')),
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
              SnackBar(content: Text('Por favor ingrese un monto fijo a ahorrar válido')),
            );
            return;
          }
          if (threshold == null || threshold <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor ingrese un umbral de ingreso válido')),
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
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(OrtizRadius.sheet),
              topRight: Radius.circular(OrtizRadius.sheet),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.xl, horizontal: OrtizSpace.lg),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Seleccionar Origen de Imagen",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.xl),
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
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                              size: OrtizIconSize.lg,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.sm),
                          Text(
                            "Cámara",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_library_rounded,
                              color: AppColors.primary,
                              size: OrtizIconSize.lg,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.sm),
                          Text(
                            "Galería",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: OrtizSpace.md),
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
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
                  color: OrtizPalette.line,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingPocket == null
                      ? "Nuevo Bolsillo"
                      : "Editar Bolsillo",
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Scrollable fields
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Section
                    OrtizSection(
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "INFORMACIÓN DEL BOLSILLO",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.lg),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: "Nombre (ej. Regalos de Navidad)",
                              hintStyle: TextStyle(
                                color: OrtizPalette.muted,
                                fontSize: OrtizFontSize.bodySm,
                              ),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          TextField(
                            controller: _targetController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: "Meta Objetivo (USD) - Opcional",
                              hintStyle: TextStyle(
                                color: OrtizPalette.muted,
                                fontSize: OrtizFontSize.bodySm,
                              ),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Fecha Límite Estimada",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
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
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.md,
                                        vertical: OrtizSpace.sm,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _targetDate ??
                                            DateTime.now().add(
                                              Duration(days: 30),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: OrtizFontSize.bodySm,
                                      ),
                                    ),
                                  ),
                                  if (_targetDate != null) ...[
                                    SizedBox(width: OrtizSpace.xs),
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: OrtizIconSize.md,
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
                            SizedBox(height: OrtizSpace.md),
                            Container(
                              padding: EdgeInsets.all(OrtizSpace.md),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(OrtizRadius.block),
                                border: Border.all(
                                  color: AppColors.cardBorder.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: OrtizIconSize.sm,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: OrtizSpace.xs),
                                      Text(
                                        "Plan de ahorro automático",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: OrtizSpace.sm),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'none',
                                          'Ninguno',
                                        ),
                                      ),
                                      SizedBox(width: OrtizSpace.sm),
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'percentage',
                                          '% Recurrente',
                                        ),
                                      ),
                                      SizedBox(width: OrtizSpace.sm),
                                      Expanded(
                                        child: _buildRuleTypeButton(
                                          'fixedThreshold',
                                          'Monto Fijo',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_fundingRuleType != 'none') ...[
                                    SizedBox(height: OrtizSpace.md),
                                    if (_fundingRuleType == 'percentage') ...[
                                      Text(
                                        "Porcentaje a ahorrar de cada ingreso recurrente:",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      TextField(
                                        controller: _fundingRuleValueController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 10",
                                          suffixText: "%",
                                          suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                          filled: true,
                                          fillColor: OrtizPalette.surfaceHigh,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                        ),
                                        style: TextStyle(fontSize: OrtizFontSize.body),
                                      ),
                                    ] else if (_fundingRuleType == 'fixedThreshold') ...[
                                      Text(
                                        "Monto fijo a ahorrar:",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      TextField(
                                        controller: _fundingRuleValueController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 20",
                                          suffixText: "\$",
                                          suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                          filled: true,
                                          fillColor: OrtizPalette.surfaceHigh,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                        ),
                                        style: TextStyle(fontSize: OrtizFontSize.body),
                                      ),
                                      SizedBox(height: OrtizSpace.sm),
                                      Text(
                                        "Cuando un ingreso sea igual o supere:",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      TextField(
                                        controller: _fundingRuleThresholdController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ej: 100",
                                          suffixText: "\$",
                                          suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                                          contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                          filled: true,
                                          fillColor: OrtizPalette.surfaceHigh,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            borderSide: BorderSide(color: OrtizPalette.line),
                                          ),
                                        ),
                                        style: TextStyle(fontSize: OrtizFontSize.body),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: OrtizSpace.md),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  "Descripción (ej. Qué es lo que quiero comprar, opcional)",
                              hintStyle: TextStyle(
                                color: OrtizPalette.muted,
                                fontSize: OrtizFontSize.bodySm,
                              ),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              color: AppColors.cardText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.lg),
                          Text(
                            "FOTO DEL BOLSILLO",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.sm),
                          if (_selectedImagePath != null &&
                              _selectedImagePath!.isNotEmpty) ...[
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(OrtizRadius.block),
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
                                                color: OrtizPalette.surfaceHigh,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.broken_image_rounded,
                                                  size: OrtizIconSize.xl,
                                                  color: OrtizPalette.muted,
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
                                          padding: EdgeInsets.all(OrtizSpace.xs),
                                          decoration: BoxDecoration(
                                            color: OrtizPalette.muted,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: OrtizPalette.fg,
                                            size: OrtizIconSize.md,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: OrtizSpace.sm),
                                      GestureDetector(
                                        onTap: _showImagePickerSourceSheet,
                                        child: Container(
                                          padding: EdgeInsets.all(OrtizSpace.xs),
                                          decoration: BoxDecoration(
                                            color: OrtizPalette.muted,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.edit_rounded,
                                            color: OrtizPalette.fg,
                                            size: OrtizIconSize.md,
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
                                  color: OrtizPalette.surfaceHigh,
                                  borderRadius: BorderRadius.circular(OrtizRadius.block),
                                  border: Border.all(
                                    color: Colors.transparent,
                                    style: BorderStyle.solid,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_rounded,
                                      color: themeColor.withValues(alpha: 0.8),
                                      size: OrtizIconSize.xl,
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    Text(
                                      "Agregar foto (Cámara o Galería)",
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.bold,
                                        color: OrtizPalette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    ),

                    // Priority Section
                    OrtizSection(
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PRIORIDAD DE FINANCIACIÓN",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          Row(
                            children: [
                              _buildPriorityButton(1, "Alta (1)", themeColor),
                              SizedBox(width: OrtizSpace.sm),
                              _buildPriorityButton(2, "Media (2)", themeColor),
                              SizedBox(width: OrtizSpace.sm),
                              _buildPriorityButton(3, "Baja (3)", themeColor),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.md),
                          Text(
                            "Los bolsillos con prioridad alta se financiarán primero con tu potencial de ahorro diario. Si hay varios en el mismo nivel, compartirán los fondos proporcionalmente.",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              color: AppColors.cardSubtitleText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                    ),

                    // Icon section
                    OrtizSection(
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ICONO",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
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
                                        : themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected
                                        ? OrtizPalette.fg
                                        : themeColor,
                                    size: OrtizIconSize.md,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    ),

                    // Color Section
                    OrtizSection(
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COLOR",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
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
                                          ? OrtizPalette.fg
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
                    ],
                    ),

                    // Destructive Delete Button
                    if (widget.editingPocket != null) ...[
                      SizedBox(height: OrtizSpace.xl),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense.withValues(alpha: 0.08),
                          foregroundColor: AppColors.expense,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                        ),
                        onPressed: _deletePocket,
                        child: Text(
                          "Eliminar Bolsillo",
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: OrtizSpace.xxxl),
                  ],
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Save / Cancel Buttons Row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(
                        fontSize: OrtizFontSize.body,
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.muted,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
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
                    child: Text(
                      "Guardar",
                      style: TextStyle(
                        fontSize: OrtizFontSize.body,
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
      child: OrtizSection(
        children: [
        Column(
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
                        padding: EdgeInsets.symmetric(
                          vertical: OrtizSpace.lg,
                          horizontal: OrtizSpace.lg,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.block)),
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
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.w900,
                                      color: OrtizPalette.fg,
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
                                      padding: EdgeInsets.all(OrtizSpace.xs),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.fg.withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _obscureBalance
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: OrtizIconSize.sm,
                                        color: OrtizPalette.fg,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Text(
                              "1 USD = Bs. ${appState.bcvRate.toStringAsFixed(2)} (BCV)",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: OrtizPalette.fg,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.lg),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayBalance,
                                style: TextStyle(
                                  fontSize: OrtizFontSize.displayLg,
                                  fontWeight: FontWeight.w900,
                                  color: OrtizPalette.fg,
                                ),
                              ),
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Text(
                              conversionText,
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: OrtizPalette.fg,
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
                        padding: EdgeInsets.symmetric(
                          vertical: OrtizSpace.lg,
                          horizontal: OrtizSpace.lg,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.all(
                            Radius.circular(OrtizRadius.block),
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
                                        color: OrtizPalette.fg,
                                        size: OrtizIconSize.sm,
                                      ),
                                      SizedBox(width: OrtizSpace.xs),
                                      Text(
                                        acc.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.w900,
                                          color: OrtizPalette.fg,
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
                                      padding: EdgeInsets.all(OrtizSpace.xs),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.fg.withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _obscureBalance
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: OrtizIconSize.sm,
                                        color: OrtizPalette.fg,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Text(
                              isUsd
                                  ? "Cuenta en Dólares"
                                  : "Cuenta en Bolívares",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: OrtizPalette.fg,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.lg),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayAccBalance,
                                style: TextStyle(
                                  fontSize: OrtizFontSize.displayLg,
                                  fontWeight: FontWeight.w900,
                                  color: OrtizPalette.fg,
                                ),
                              ),
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Text(
                              accConversionText,
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: OrtizPalette.fg,
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
            SizedBox(height: OrtizSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final isSelected = _currentPage == i;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : OrtizPalette.line,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                );
              }),
            ),
          ],
        ),
        ],
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
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
              decoration: BoxDecoration(
                color: OrtizPalette.line,
                borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.chip)),
              ),
            ),
          ),
          SizedBox(height: OrtizSpace.lg),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDeposit ? "Asignar Fondos" : "Retirar Fondos",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.w900,
                  color: OrtizPalette.fg,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.lg),

          // Card content
          OrtizSection(
            children: [
            Column(
              children: [
                // Pocket Icon & Name Badge
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getIconData(pocket.icon),
                        color: themeColor,
                        size: OrtizIconSize.md,
                      ),
                    ),
                    SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pocket.name,
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xxs),
                          Text(
                            isDeposit
                                ? "Disponible: ${formatUSD(widget.appState.liquidBalanceUSD)}"
                                : "Ahorrado: ${formatUSD(pocket.currentAmountUSD)}",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: OrtizSpace.xxl),

                // Amount Text Field (Modern layout)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: OrtizSpace.lg,
                    vertical: OrtizSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.block),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: OrtizFontSize.displayLg,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "0.00",
                      hintStyle: TextStyle(color: OrtizPalette.muted),
                      suffixText: "USD",
                      suffixStyle: TextStyle(
                        fontSize: OrtizFontSize.titleSm,
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.muted,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),

                // Preset Shortcuts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [10, 50, 100].map((val) {
                    return TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: OrtizSpace.lg,
                          vertical: OrtizSpace.sm,
                        ),
                      ),
                      onPressed: () {
                        _amountController.text = val.toString();
                        setState(() {});
                      },
                      child: Text(
                        "+$val USD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: OrtizFontSize.bodySm,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            ],
          ),

          // Action buttons row
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.bold,
                      color: OrtizPalette.muted,
                    ),
                  ),
                ),
              ),
              SizedBox(width: OrtizSpace.md),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                  ),
                  onPressed:
                      (_amountController.text.trim().isEmpty ||
                          (double.tryParse(_amountController.text) ?? 0.0) <= 0)
                      ? null
                      : _confirmTransaction,
                  child: Text(
                    isDeposit ? "Asignar" : "Retirar",
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
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
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.transparent,
                      blurRadius: 4,
                      offset: Offset(0, 2),
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
              fontSize: OrtizFontSize.bodySm,
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
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.transparent,
                      blurRadius: 2,
                      offset: Offset(0, 1),
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
              fontSize: OrtizFontSize.bodySm,
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

