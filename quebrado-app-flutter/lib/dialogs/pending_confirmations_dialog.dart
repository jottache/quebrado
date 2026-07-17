import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../models/currency_type.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';
import '../widgets/slide_to_confirm_button.dart';
import '../services/biometric_service.dart';

class PendingConfirmationsBottomSheet extends StatefulWidget {
  final PendingOccurrence? filterOccurrence;
  final bool forceShowCustomAmount;

  const PendingConfirmationsBottomSheet({
    super.key,
    this.filterOccurrence,
    this.forceShowCustomAmount = false,
  });

  @override
  State<PendingConfirmationsBottomSheet> createState() => _PendingConfirmationsBottomSheetState();
}

class _PendingConfirmationsBottomSheetState extends State<PendingConfirmationsBottomSheet> with TickerProviderStateMixin {
  final Map<String, List<_PendingPaymentState>> _profileStates = {};
  String? _currentViewedDb;
  bool _initialized = false;
  late final TextEditingController _p2pRateController;
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;
  bool _tabControllerInitialized = false;
  bool _isLoading = false;
  bool _isSwitchingProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    if (!_initialized) {
      _currentViewedDb = appState.activeDbName;
      _p2pRateController = TextEditingController(text: appState.parallelRate.toStringAsFixed(2));
      _loadAllProfilesData(appState);
      _initialized = true;
    }

    if (widget.filterOccurrence == null && !_tabControllerInitialized && appState.profiles.isNotEmpty) {
      int activeIndex = appState.profiles.indexWhere((p) => p['id'] == appState.activeDbName);
      if (activeIndex == -1) activeIndex = 0;
      
      _tabController = TabController(
        length: appState.profiles.length,
        vsync: this,
        initialIndex: activeIndex,
      );
      _tabController!.addListener(_handleTabSelection);
      _tabControllerInitialized = true;
    }
  }

  Future<void> _loadAllProfilesData(AppState appState) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    if (widget.filterOccurrence != null) {
      final occ = widget.filterOccurrence!;
      final rate = occ.payment.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
      final state = _PendingPaymentState(occ, rate);
      if (widget.forceShowCustomAmount) state.showCustomAmount = true;
      
      final String profileId = appState.activeDbName;
      _profileStates[profileId] = [state];
    } else {
      for (var profile in appState.profiles) {
        final String profileId = profile['id']!;
        final pending = await appState.fetchPendingPaymentsForProfile(profileId);
        
        final List<_PendingPaymentState> states = [];
        for (var occ in pending) {
          final rate = occ.payment.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
          final state = _PendingPaymentState(occ, rate);
          if (widget.forceShowCustomAmount) state.showCustomAmount = true;
          states.add(state);
        }
        _profileStates[profileId] = states;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var list in _profileStates.values) {
      for (var s in list) {
        s.amountController.dispose();
        s.rateController.dispose();
      }
    }
    _p2pRateController.dispose();
    _scrollController.dispose();
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController == null) return;
    
    final appState = Provider.of<AppState>(context, listen: false);
    if (_tabController!.index < appState.profiles.length) {
      final targetProfile = appState.profiles[_tabController!.index];
      final targetDb = targetProfile['id']!;
      
      if (targetDb != _currentViewedDb) {
        setState(() {
          _currentViewedDb = targetDb;
        });
      }
    }
  }

  Future<bool> _handleConsolidatedDeficits({
    required BuildContext context,
    required AppState appState,
    required List<Map<String, dynamic>> deficits,
  }) async {
    if (deficits.isEmpty) return true;

    for (var item in deficits) {
      final Account targetAccount = item['account'];
      final double deficit = item['deficit'];

      final sourceAccounts = appState.accounts.where((a) => a.id != targetAccount.id && a.balance > 0).toList();

      if (sourceAccounts.isEmpty) {
        // Show warning but let them confirm if they want to allow negative balance
        final proceed = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (sheetContext) => _NoSourceAccountsDeficitBottomSheet(
            targetAccount: targetAccount,
            deficit: deficit,
          ),
        );
        if (proceed != true) return false;
      } else {
        // There are source accounts available!
        final result = await showModalBottomSheet<Map<String, dynamic>?>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (sheetContext) => _DeficitTransferBottomSheet(
            appState: appState,
            targetAccount: targetAccount,
            deficit: deficit,
            sourceAccounts: sourceAccounts,
          ),
        );
        if (result == null) return false; // Cancelled

        if (result["action"] == "pay_only") {
          continue; // Move to next deficit account
        }

        if (result["action"] == "transfer") {
          final Account source = result["source"];
          final double sourceAmount = result["sourceAmount"];
          final double targetAmount = result["targetAmount"];
          final double activeRate = result["rate"];

          // 1. Register expense transaction in source account
          final sourceNote = "Transferencia a ${targetAccount.name} para cubrir déficit de cobros de hoy";
          final sourceTx = Transaction(
            id: "${DateTime.now().millisecondsSinceEpoch}_tx_src",
            date: DateTime.now(),
            amount: sourceAmount,
            currency: source.currency,
            accountId: source.id,
            note: sourceNote,
            type: TransactionType.expense,
            exchangeRate: activeRate,
          );

          // 2. Register income transaction in target account
          final targetNote = "Transferencia desde ${source.name} para cubrir déficit de cobros de hoy";
          final targetTx = Transaction(
            id: "${DateTime.now().millisecondsSinceEpoch}_tx_tgt",
            date: DateTime.now().copyWith(second: DateTime.now().second + 1),
            amount: targetAmount,
            currency: targetAccount.currency,
            accountId: targetAccount.id,
            note: targetNote,
            type: TransactionType.income,
            exchangeRate: activeRate,
          );

          await appState.addTransaction(sourceTx);
          await appState.addTransaction(targetTx);
        }
      }
    }
    return true;
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copiado $label: $text"),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _submitConfirmations(AppState appState) async {
    final _states = _profileStates[_currentViewedDb] ?? [];
    final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
    if (selected.isEmpty) return;

    if (appState.useBiometrics) {
      final authenticated = await BiometricService.authenticate(
        reason: "Confirma tu identidad para registrar los cobros seleccionados",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Autenticación biométrica fallida o cancelada."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }

    // Switch profile if necessary before making DB changes
    if (_currentViewedDb != null && appState.activeDbName != _currentViewedDb) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      await appState.switchProfile(_currentViewedDb!);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // Map of accountId -> net balance change
    final Map<String, double> netChanges = {};
    List<RecurringPayment> finishedPayments = [];
    double totalUsdIncomeForAutoSave = 0.0;

    // First verify useExistingBalance
    for (var s in selected) {
      if (s.willSkip || !s.useExistingBalance) continue;
      
      final usdVal = double.tryParse(s.amountController.text.replaceAll(',', '.')) ?? s.occurrence.remainingAmount;
      final targetCurr = s.payment.currency;
      double usdAmountNeeded = 0.0;
      if (targetCurr == CurrencyType.usd) {
        usdAmountNeeded = usdVal;
      } else if (targetCurr == CurrencyType.bsBCV) {
        usdAmountNeeded = appState.bcvRate > 0 ? usdVal / appState.bcvRate : 0.0;
      }
      
      final usdAccounts = appState.accounts.where((a) => a.currency == CurrencyType.usd).toList();
      if (usdAccounts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No tienes cuentas en USD creadas para usar saldo existente."),
              backgroundColor: AppColors.expense,
            )
          );
        }
        return; // Prevent registration
      } else {
        final targetAccId = s.selectedExistingBalanceAccountId ?? usdAccounts.first.id;
        final targetAcc = appState.accounts.firstWhere((a) => a.id == targetAccId, orElse: () => usdAccounts.first);
        if (targetAcc.balance < usdAmountNeeded) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("La cuenta '${targetAcc.name}' no tiene suficiente saldo (\$${targetAcc.balance.toStringAsFixed(2)}) para cubrir el ingreso '${s.payment.name}' (\$${usdAmountNeeded.toStringAsFixed(2)})."),
                backgroundColor: AppColors.expense,
              )
            );
          }
          return; // Prevent registration
        }
      }
    }

    for (var s in selected) {
      if (s.willSkip) {
        await appState.dismissRecurringPaymentToday(s.payment, occurrenceDate: s.occurrence.occurrenceDate);
        continue;
      }

      final p = s.payment;
      final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
      final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
      final needsConversion = (p.currency == CurrencyType.usd || p.currency == CurrencyType.eur) && targetAccount.currency == CurrencyType.bsBCV;

      double remainingVal = double.tryParse(s.amountController.text.replaceAll(',', '.')) ?? s.occurrence.remainingAmount;
      double actualAmt = s.useExistingBalance ? 0.0 : remainingVal;
      final isPartialRest = remainingVal < p.amount;

      bool isLast = false;
      
      String existingBalanceStr = "";
      if (s.useExistingBalance) {
        String accName = "saldo existente";
        if (s.selectedExistingBalanceAccountId != null) {
          final acc = appState.accounts.firstWhere((a) => a.id == s.selectedExistingBalanceAccountId, orElse: () => appState.accounts.first);
          accName = acc.name;
        }
        existingBalanceStr = " (con saldo de $accName)";
      }

      if (needsConversion) {
        final rateController = s.rateController;
        final double defaultRate = p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
        final double rateVal = double.tryParse(rateController.text.replaceAll(',', '.')) ?? defaultRate;
        actualAmt = s.useExistingBalance ? 0.0 : (remainingVal * rateVal);
        
        isLast = await appState.confirmRecurringPayment(
          payment: p,
          actualAmount: actualAmt,
          occurrenceDate: s.occurrence.occurrenceDate,
          overrideCurrency: CurrencyType.bsBCV,
          customExchangeRate: rateVal,
          customNote: p.currency == CurrencyType.eur
              ? "Confirmado${existingBalanceStr}: ${p.name} (€${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)"
              : "Confirmado${existingBalanceStr}: ${p.name} (\$${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)",
        );
      } else {
        isLast = await appState.confirmRecurringPayment(
          payment: p,
          actualAmount: actualAmt,
          occurrenceDate: s.occurrence.occurrenceDate,
          customNote: isPartialRest 
              ? "Confirmado${existingBalanceStr}: ${p.name} (Restante: ${p.currency.symbol}${remainingVal.toStringAsFixed(2)})"
              : s.useExistingBalance ? "Confirmado${existingBalanceStr}: ${p.name}" : null,
        );
      }

      if (s.useExistingBalance && p.type == TransactionType.income) {
        if (p.currency == CurrencyType.usd) {
           totalUsdIncomeForAutoSave += remainingVal;
        } else if (p.currency == CurrencyType.bsBCV) {
           totalUsdIncomeForAutoSave += appState.bcvRate > 0 ? remainingVal / appState.bcvRate : 0.0;
        }
      }
      
      if (isLast) finishedPayments.add(p);
    }

    if (context.mounted) {
      for (var payment in finishedPayments) {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text("Última Cuota", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text("Has registrado la última cuota de '${payment.name}'. ¿Deseas eliminar este registro de la lista de pagos por cuotas?"),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Mantener", style: TextStyle(color: Colors.grey[700])),
                ),
                TextButton(
                  onPressed: () {
                    appState.deleteRecurringPayment(payment.id);
                    Navigator.pop(ctx);
                  },
                  child: Text("Eliminar", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
      if (context.mounted) {
        if (totalUsdIncomeForAutoSave > 0) {
          await _showAutoSaveDialog(context, appState, totalUsdIncomeForAutoSave);
        } else {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(content: Text("Registros agregados al historial")),
          );
        }
      }
    }
  }

  Future<void> _showAutoSaveDialog(BuildContext context, AppState appState, double usdIncomeAmount) async {
    final Map<String, double> proposedDeposits = {};
    for (var pocket in appState.pockets) {
      if (pocket.targetDate != null) continue;
      if (pocket.fundingRuleType == 'none') continue;
      
      double proposedSaving = 0.0;
      if (pocket.fundingRuleType == 'percentage') {
        final pct = pocket.fundingRuleValue ?? 0.0;
        proposedSaving = usdIncomeAmount * (pct / 100.0);
      } else if (pocket.fundingRuleType == 'fixedThreshold') {
        final threshold = pocket.fundingRuleThreshold ?? 0.0;
        final fixedVal = pocket.fundingRuleValue ?? 0.0;
        if (usdIncomeAmount >= threshold) proposedSaving = fixedVal;
      }
      
      if (pocket.targetAmountUSD > 0) {
        final remaining = pocket.targetAmountUSD - pocket.currentAmountUSD;
        if (proposedSaving > remaining) proposedSaving = remaining;
      }
      
      if (proposedSaving > 0) {
        proposedDeposits[pocket.id] = proposedSaving;
      }
    }

    if (proposedDeposits.isEmpty) {
      Navigator.pop(context);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Sugerencias de Auto-Ahorro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Basado en el ingreso cobrado (\$${usdIncomeAmount.toStringAsFixed(2)}), te sugerimos apartar a tus bolsillos:", style: TextStyle(fontSize: 13, color: AppColors.cardSubtitleText)),
            SizedBox(height: 16),
            ...proposedDeposits.entries.map((e) {
              final pocket = appState.pockets.firstWhere((p) => p.id == e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("• ${pocket.name}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.cardText))),
                    Text(formatUSD(e.value), style: TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text("Ignorar", style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              double totalRequired = proposedDeposits.values.fold(0.0, (a, b) => a + b);
              if (appState.liquidBalanceUSD < totalRequired) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("No tienes suficiente saldo líquido en USD (\$${appState.liquidBalanceUSD.toStringAsFixed(2)}) para este aporte (\$${totalRequired.toStringAsFixed(2)})."), backgroundColor: AppColors.expense));
                return;
              }
              for (var entry in proposedDeposits.entries) {
                await appState.depositToPocket(id: entry.key, amountUSD: entry.value);
              }
              if (ctx.mounted) {
                 Navigator.pop(ctx);
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aportes realizados con éxito"), backgroundColor: AppColors.primary));
              }
            },
            child: Text("Aportar Todo", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;
    final showTabs = widget.filterOccurrence == null && _tabController != null && appState.profiles.isNotEmpty;
    final _states = _profileStates[_currentViewedDb] ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
      child: SafeArea(
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
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.filterOccurrence != null 
                        ? "Registrar ${widget.filterOccurrence!.payment.type == TransactionType.income ? 'Cobro' : 'Pago'}"
                        : "Cobros y Pagos de Hoy",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              widget.filterOccurrence != null
                  ? "Confirma los detalles para registrar este ${widget.filterOccurrence!.payment.type == TransactionType.income ? 'ingreso' : 'egreso'} en tus cuentas:"
                  : "Tienes registros programados pendientes para hoy. Elige cuáles quieres registrar automáticamente en tus cuentas:",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            if (showTabs) ...[
              SizedBox(height: 12),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: appState.profiles.length > 3,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[500],
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                  physics: BouncingScrollPhysics(),
                  tabs: appState.profiles.map((p) {
                    final String name = p['name'] ?? 'Personal';
                    return Tab(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(name),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            SizedBox(height: 16),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            else if (_states.isEmpty)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "¡Todo al día!",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "No tienes ningún pago programado pendiente para hoy en este libro.",
                      style: TextStyle(fontSize: 13, color: AppColors.cardSubtitleText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      ..._states.map((state) {
                        final p = state.payment;
                    final iconColor = parseHexColor(p.colorHex);
                    final isIncome = p.type == TransactionType.income;
                    final isUsd = p.currency == CurrencyType.usd;
                    final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                    final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                    final needsConversion = (p.currency == CurrencyType.usd || p.currency == CurrencyType.eur) && targetAccount.currency == CurrencyType.bsBCV;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: state.isChecked,
                                    activeColor: AppColors.primary,
                                    visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                    onChanged: (val) {
                                      setState(() {
                                        state.isChecked = val ?? false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  getIconData(p.icon),
                                  color: iconColor,
                                  size: 18,
                                ),
                              ),
                                SizedBox(width: 6),
                                Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "${isIncome ? 'Ingreso' : 'Gasto'} • Vence: ${formatDate(state.occurrence.occurrenceDate)}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isIncome ? AppColors.primary : AppColors.expense,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (state.occurrence.partialAmountPaid > 0) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        "Pagado parcial: ${formatCurrency(state.occurrence.partialAmountPaid, p.currency)}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!p.isVariable && !state.showCustomAmount)
                                Text(
                                  formatCurrency(p.amount, p.currency),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? AppColors.primary : AppColors.expense,
                                  ),
                                ),
                            ],
                          ),
                          if ((p.isVariable || state.showCustomAmount) && state.isChecked && !state.willSkip) ...[
                            SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      Text(
                                        "Rango: ${formatCurrency(p.amount, p.currency)} - ${formatCurrency(p.maxAmount ?? p.amount, p.currency)}",
                                        style: TextStyle(fontSize: 10, color: AppColors.cardSubtitleText),
                                      ),
                                      SizedBox(height: 4),
                                      SizedBox(
                                        height: 36,
                                        child: TextField(
                                          controller: state.amountController,
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            hintText: "0.00 ${p.currency.symbol}",
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.black12),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: AppColors.primary),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                              ],
                            ),
                          ],
                          if (needsConversion && state.isChecked && !state.willSkip) ...[
                            SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      if (!p.isVariable) ...[
                                        Text(
                                          "Monto Base: ${formatCurrency(p.amount, p.currency)}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.cardText,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                      ],
                                      Text(
                                        "TASA DE CAMBIO",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardSubtitleText,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppColors.nestedTabTrackBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => state.isCustomRate = false),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: !state.isCustomRate
                                                        ? AppColors.nestedTabActiveBg
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    "${p.currency == CurrencyType.eur ? 'EUR' : 'BCV'} (${(p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate).toStringAsFixed(2)})",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: !state.isCustomRate
                                                          ? AppColors.nestedTabActiveText
                                                          : AppColors.nestedTabInactiveText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => state.isCustomRate = true),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: state.isCustomRate
                                                        ? AppColors.nestedTabActiveBg
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    "Personalizada",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: state.isCustomRate
                                                          ? AppColors.nestedTabActiveText
                                                          : AppColors.nestedTabInactiveText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (state.isCustomRate) ...[
                                        SizedBox(height: 6),
                                        SizedBox(
                                          height: 36,
                                          child: TextField(
                                            controller: state.rateController,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              hintText: "Ingrese tasa Bs.",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: Colors.black12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: AppColors.primary),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: 8),
                                      Builder(
                                        builder: (context) {
                                          final usdVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                                          final defaultRate = p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
                                          final rateVal = state.isCustomRate
                                              ? (double.tryParse(state.rateController.text.replaceAll(',', '.')) ?? defaultRate)
                                              : defaultRate;
                                          final calculatedBs = usdVal * rateVal;
                                          return Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Se registrará en Banco Bs.:",
                                                  style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                                ),
                                                Text(
                                                  formatBs(calculatedBs),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      ),
                              ],
                            ),
                          ],
                          if (!p.isVariable) ...[
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() {
                                    state.showCustomAmount = !state.showCustomAmount;
                                    if (state.showCustomAmount && state.willSkip) {
                                      state.willSkip = false;
                                    }
                                  });
                                },
                                child: Text(state.showCustomAmount ? "Usar monto completo" : "Modificar monto", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: state.willSkip ? Colors.white : AppColors.expense,
                                  backgroundColor: state.willSkip ? AppColors.expense : Colors.transparent,
                                  side: BorderSide(color: AppColors.expense.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() {
                                    state.willSkip = !state.willSkip;
                                    if (state.willSkip) {
                                      state.showCustomAmount = false;
                                      state.isChecked = false;
                                    } else {
                                      state.isChecked = true;
                                    }
                                  });
                                },
                                child: Text(state.willSkip ? "Se omitirá este ${isIncome ? 'ingreso' : 'pago'}" : "Omitir ${isIncome ? 'ingreso' : 'pago'}", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                          if (isIncome && !state.willSkip && state.isChecked) ...[
                            SizedBox(height: 8),
                            CheckboxListTile(
                              value: state.useExistingBalance,
                              dense: true,
                              activeColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              title: Text("Usar saldo existente", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                              subtitle: Text("No se añadirá saldo extra a la cuenta, previniendo dinero duplicado si ya compraste las divisas manualmente.", style: TextStyle(fontSize: 10, color: AppColors.cardSubtitleText)),
                              onChanged: (val) {
                                if (val == true) {
                                  final usdAccounts = appState.accounts.where((a) => a.currency == CurrencyType.usd).toList();
                                  if (usdAccounts.isNotEmpty) {
                                    state.selectedExistingBalanceAccountId = usdAccounts.first.id;
                                  }
                                }
                                setState(() {
                                  state.useExistingBalance = val ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (state.useExistingBalance) ...[
                              Builder(
                                builder: (ctx) {
                                  String? existingBalanceError;
                                  final usdVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                                  final targetCurr = p.currency;
                                  double usdAmountNeeded = 0.0;
                                  if (targetCurr == CurrencyType.usd) {
                                    usdAmountNeeded = usdVal;
                                  } else if (targetCurr == CurrencyType.bsBCV) {
                                    usdAmountNeeded = appState.bcvRate > 0 ? usdVal / appState.bcvRate : 0.0;
                                  }
                                  
                                  final usdAccounts = appState.accounts.where((a) => a.currency == CurrencyType.usd).toList();
                                  if (usdAccounts.isEmpty) {
                                    existingBalanceError = "No tienes cuentas en USD creadas para usar saldo existente.";
                                  } else {
                                    final targetAccId = state.selectedExistingBalanceAccountId ?? usdAccounts.first.id;
                                    final targetAcc = appState.accounts.firstWhere((a) => a.id == targetAccId, orElse: () => usdAccounts.first);
                                    if (targetAcc.balance < usdAmountNeeded) {
                                      existingBalanceError = "La cuenta '${targetAcc.name}' no tiene suficiente saldo (\$${targetAcc.balance.toStringAsFixed(2)}) para cubrir este ingreso (\$${usdAmountNeeded.toStringAsFixed(2)}).";
                                    }
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (usdAccounts.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                          child: DropdownButtonFormField<String>(
                                            value: state.selectedExistingBalanceAccountId,
                                            decoration: InputDecoration(
                                              labelText: "Selecciona la cuenta donde ya tienes el dinero",
                                              labelStyle: TextStyle(fontSize: 11),
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            items: usdAccounts.map((a) {
                                              return DropdownMenuItem(
                                                value: a.id,
                                                child: Text("${a.name} (\$${a.balance.toStringAsFixed(2)})", style: TextStyle(fontSize: 12)),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setState(() {
                                                state.selectedExistingBalanceAccountId = val;
                                              });
                                            },
                                          ),
                                        ),
                                      if (existingBalanceError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.expense.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.expense.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 16),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    existingBalanceError,
                                                    style: TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.w600, height: 1.3),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                }
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  }),
                    if (_states.any((s) => s.isChecked)) ...[
                    SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        double totalIncomeUSD = 0.0;
                        double totalIncomeBs = 0.0;
                        double totalExpenseUSD = 0.0;
                        double totalExpenseBs = 0.0;

                        for (var state in _states) {
                          if (!state.isChecked || state.willSkip) continue;

                          final p = state.payment;
                          final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                          final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                          final needsConversion = (p.currency == CurrencyType.usd || p.currency == CurrencyType.eur) && targetAccount.currency == CurrencyType.bsBCV;
                          final isIncome = p.type == TransactionType.income;

                          double usdVal = 0.0;
                          double bsVal = 0.0;

                          if (p.currency == CurrencyType.usd) {
                            usdVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                            if (needsConversion) {
                              final rateVal = state.isCustomRate
                                  ? (double.tryParse(state.rateController.text.replaceAll(',', '.')) ?? appState.bcvRate)
                                  : appState.bcvRate;
                              bsVal = usdVal * rateVal;
                            } else {
                              bsVal = usdVal * appState.bcvRate;
                            }
                          } else if (p.currency == CurrencyType.eur) {
                            final eurVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                            final rateVal = state.isCustomRate
                                ? (double.tryParse(state.rateController.text.replaceAll(',', '.')) ?? appState.euroRate)
                                : appState.euroRate;
                            bsVal = eurVal * rateVal;
                            usdVal = appState.bcvRate > 0 ? bsVal / appState.bcvRate : 0.0;
                          } else {
                            bsVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                            usdVal = appState.bcvRate > 0 ? bsVal / appState.bcvRate : 0.0;
                          }

                          if (isIncome) {
                            totalIncomeUSD += usdVal;
                            totalIncomeBs += bsVal;
                          } else {
                            totalExpenseUSD += usdVal;
                            totalExpenseBs += bsVal;
                          }
                        }

                        final double netUSD = totalIncomeUSD - totalExpenseUSD;
                        final double netBs = totalIncomeBs - totalExpenseBs;

                        // Calculate total deficit in Bolívares target accounts
                        Map<String, double> requiredBsPerAccount = {};
                        for (var state in _states) {
                          if (!state.isChecked) continue;
                          final p = state.payment;
                          final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                          final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                          
                          if (targetAccount.currency == CurrencyType.bsBCV) {
                            double usdVal = 0.0;
                            double bsVal = 0.0;
                            if (p.currency == CurrencyType.usd) {
                              usdVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                              final rateVal = state.isCustomRate
                                  ? (double.tryParse(state.rateController.text.replaceAll(',', '.')) ?? appState.bcvRate)
                                  : appState.bcvRate;
                              bsVal = usdVal * rateVal;
                            } else if (p.currency == CurrencyType.eur) {
                              final eurVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                              final rateVal = state.isCustomRate
                                  ? (double.tryParse(state.rateController.text.replaceAll(',', '.')) ?? appState.euroRate)
                                  : appState.euroRate;
                              bsVal = eurVal * rateVal;
                            } else {
                              bsVal = double.tryParse(state.amountController.text.replaceAll(',', '.')) ?? state.occurrence.remainingAmount;
                            }
                            requiredBsPerAccount[targetAccount.id] = (requiredBsPerAccount[targetAccount.id] ?? 0.0) + bsVal;
                          }
                        }

                        double totalDeficitBs = 0.0;
                        requiredBsPerAccount.forEach((accountId, requiredBs) {
                          final acc = appState.accounts.firstWhere((a) => a.id == accountId);
                          final deficit = requiredBs - acc.balance;
                          if (deficit > 0) {
                            totalDeficitBs += deficit;
                          }
                        });

                        final String displayNetUSD = (netUSD >= 0 ? "+" : "-") + formatUSD(netUSD.abs());
                        final String displayNetBs = (netBs >= 0 ? "+" : "-") + formatBs(netBs.abs());
                        final Color netColor = netUSD >= 0 ? AppColors.income : AppColors.expense;

                        return Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6), // Premium glassmorphic look
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "RESUMEN DE SELECCIÓN",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                               SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Ingresos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total Ingresos",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeUSD.toStringAsFixed(2), "Total Ingresos USD"),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalIncomeUSD),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 14, color: AppColors.income.withOpacity(0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeBs.toStringAsFixed(2), "Total Ingresos Bs."),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalIncomeBs),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 12, color: AppColors.income.withOpacity(0.4)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Line separator
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.black.withOpacity(0.06),
                                  ),
                                  SizedBox(width: 16),
                                  // Egresos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total Egresos",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseUSD.toStringAsFixed(2), "Total Egresos USD"),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalExpenseUSD),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 14, color: AppColors.expense.withOpacity(0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseBs.toStringAsFixed(2), "Total Egresos Bs."),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalExpenseBs),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 12, color: AppColors.expense.withOpacity(0.4)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Divider(color: Colors.black.withOpacity(0.05), height: 1),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Neto",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, netUSD.toStringAsFixed(2), "Total Neto USD"),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                displayNetUSD,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: netColor,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.content_copy_rounded, size: 13, color: netColor.withOpacity(0.5)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, netBs.toStringAsFixed(2), "Total Neto Bs."),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                displayNetBs,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: netColor,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.content_copy_rounded, size: 11, color: netColor.withOpacity(0.4)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (totalDeficitBs > 0) ...[
                                SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.secondary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calculate_outlined,
                                            color: AppColors.secondary,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "OPTIMIZADOR DE VENTA P2P (BINANCE)",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.secondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, totalDeficitBs.toStringAsFixed(2), "Déficit en Bolívares"),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 4, bottom: 4, right: 8, left: 0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Déficit (Falta por Cubrir): ${formatBs(totalDeficitBs)}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.cardText,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.content_copy_rounded,
                                                size: 13,
                                                color: AppColors.cardSubtitleText.withOpacity(0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "El déficit representa lo que le falta a tus cuentas en Bolívares para cubrir los egresos seleccionados (Egresos - Saldo Disponible).",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.cardSubtitleText,
                                          height: 1.3,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Text(
                                            "Tasa P2P de Venta: ",
                                            style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            height: 28,
                                            child: TextField(
                                              controller: _p2pRateController,
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            " Bs/\$",
                                            style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Builder(
                                        builder: (context) {
                                          final p2pRate = double.tryParse(_p2pRateController.text.replaceAll(',', '.')) ?? appState.parallelRate;
                                          
                                          // Option A: Only deficit
                                          final usdNeededDeficit = p2pRate > 0 ? totalDeficitBs / p2pRate : 0.0;
                                          final usdNominalDeficit = appState.bcvRate > 0 ? totalDeficitBs / appState.bcvRate : 0.0;
                                          final savedUsdDeficit = usdNominalDeficit - usdNeededDeficit;

                                          // Option B: Total expense
                                          final usdNeededTotal = p2pRate > 0 ? totalExpenseBs / p2pRate : 0.0;
                                          final usdNominalTotal = appState.bcvRate > 0 ? totalExpenseBs / appState.bcvRate : 0.0;
                                          final savedUsdTotal = usdNominalTotal - usdNeededTotal;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Option A Card
                                              Container(
                                                padding: EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: AppColors.primary.withOpacity(0.15),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "OPCIÓN A: VENDER SOLO EL DÉFICIT",
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededDeficit.toStringAsFixed(2), "Binance P2P (Déficit)"),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededDeficit)}",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: 13,
                                                            color: AppColors.primary.withOpacity(0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdDeficit > 0.01) ...[
                                                      SizedBox(height: 2),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdDeficit)}! (Vs. ${formatUSD(usdNominalDeficit)} a tasa BCV)",
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.income,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 10),
                                              // Option B Card
                                              Container(
                                                padding: EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.black.withOpacity(0.05),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "OPCIÓN B: VENDER EL EGRESO TOTAL",
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.cardSubtitleText,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededTotal.toStringAsFixed(2), "Binance P2P (Total)"),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededTotal)}",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.cardText,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: 13,
                                                            color: AppColors.cardSubtitleText.withOpacity(0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdTotal > 0.01) ...[
                                                      SizedBox(height: 2),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdTotal)}! (Vs. ${formatUSD(usdNominalTotal)} a tasa BCV)",
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.income,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                    ),
                  ], // closes if (_states.any...)
                ], // closes children: [
              ), // closes Column
              ),
            ),
          ),
        ],
                Builder(
                  builder: (context) {
                    final _states = _profileStates[_currentViewedDb] ?? [];
                    
                    bool hasExistingBalanceError = false;
                    for (var s in _states) {
                      if (!s.isChecked || !s.useExistingBalance || s.willSkip) continue;
                      final usdVal = double.tryParse(s.amountController.text.replaceAll(',', '.')) ?? s.occurrence.remainingAmount;
                      final targetCurr = s.payment.currency;
                      double usdAmountNeeded = 0.0;
                      if (targetCurr == CurrencyType.usd) {
                        usdAmountNeeded = usdVal;
                      } else if (targetCurr == CurrencyType.bsBCV) {
                        usdAmountNeeded = appState.bcvRate > 0 ? usdVal / appState.bcvRate : 0.0;
                      }
                      
                      final usdAccounts = appState.accounts.where((a) => a.currency == CurrencyType.usd).toList();
                      if (usdAccounts.isEmpty) {
                        hasExistingBalanceError = true;
                        break;
                      } else {
                        final targetAccId = s.selectedExistingBalanceAccountId ?? usdAccounts.first.id;
                        final targetAcc = appState.accounts.firstWhere((a) => a.id == targetAccId, orElse: () => usdAccounts.first);
                        if (targetAcc.balance < usdAmountNeeded) {
                          hasExistingBalanceError = true;
                          break;
                        }
                      }
                    }

                    final bool isEnabled = _states.any((s) => s.isChecked || s.willSkip) && !hasExistingBalanceError;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_states.length > 2) ...[
                          SizedBox(height: 6),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.unfold_more, size: 14, color: AppColors.cardSubtitleText.withOpacity(0.6)),
                                SizedBox(width: 4),
                                Text(
                                  "Desliza para ver más",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.cardSubtitleText.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 16),
                        Column(
                          children: [
                        SizedBox(
                          width: double.infinity,
                          child: appState.useSlideToConfirm
                              ? SlideToConfirmButton(
                                  enabled: isEnabled,
                          label: "Desliza para registrar",
                          onConfirmed: () async {
                            final _states = _profileStates[_currentViewedDb] ?? [];
                            final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
                            if (selected.isEmpty) return;

                            // Map of accountId -> net balance change
                            final Map<String, double> netChanges = {};

                            for (var s in selected) {
                              if (s.willSkip) continue; // skipped ones don't affect balance change
                              final p = s.payment;
                              final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                              final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                              final needsConversion = (p.currency == CurrencyType.usd || p.currency == CurrencyType.eur) && targetAccount.currency == CurrencyType.bsBCV;

                              double actualAmt = p.amount;
                              if (needsConversion) {
                                final rateController = s.rateController;
                                final defaultRate = p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
                                final double rateVal = double.tryParse(rateController.text.replaceAll(',', '.')) ?? defaultRate;
                                actualAmt = p.amount * rateVal;
                              }

                              // Determine net effect
                              double change = actualAmt;
                              if (p.type == TransactionType.expense) {
                                change = -change;
                              }

                              netChanges[targetAccount.id] = (netChanges[targetAccount.id] ?? 0.0) + change;
                            }

                            // Check deficits
                            final List<Map<String, dynamic>> deficitAccounts = [];
                            netChanges.forEach((accountId, netChange) {
                              final acc = appState.accounts.firstWhere((a) => a.id == accountId);
                              if (acc.balance + netChange < 0) {
                                final deficit = -(acc.balance + netChange);
                                deficitAccounts.add({
                                  'account': acc,
                                  'deficit': deficit,
                                });
                              }
                            });

                            final proceed = await _handleConsolidatedDeficits(
                              context: context,
                              appState: appState,
                              deficits: deficitAccounts,
                            );
                            if (!proceed) return;

                            await _submitConfirmations(appState);
                          },
                        )
                      : ElevatedButton(
                          onPressed: isEnabled && !_isLoading
                              ? () async {
                                  // Confirm and register all selected
                                  final _states = _profileStates[_currentViewedDb] ?? [];
                                  final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
                                  if (selected.isEmpty) return;

                                  // Map of accountId -> net balance change
                                  final Map<String, double> netChanges = {};

                                  for (var s in selected) {
                                    if (s.willSkip) continue; // skipped ones don't affect balance change
                                    final p = s.payment;
                                    final accId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                                    final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                                    final needsConversion = (p.currency == CurrencyType.usd || p.currency == CurrencyType.eur) && targetAccount.currency == CurrencyType.bsBCV;

                                    double actualAmt = p.amount;
                                    if (needsConversion) {
                                      final rateController = s.rateController;
                                      final defaultRate = p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
                                      final double rateVal = double.tryParse(rateController.text.replaceAll(',', '.')) ?? defaultRate;
                                      actualAmt = p.amount * rateVal;
                                    }

                                    // Determine net effect
                                    double change = actualAmt;
                                    if (p.type == TransactionType.expense) {
                                      change = -change;
                                    }

                                    netChanges[targetAccount.id] = (netChanges[targetAccount.id] ?? 0.0) + change;
                                  }

                                  // Check deficits
                                  final List<Map<String, dynamic>> deficitAccounts = [];
                                  netChanges.forEach((accountId, netChange) {
                                    final acc = appState.accounts.firstWhere((a) => a.id == accountId);
                                    if (acc.balance + netChange < 0) {
                                      final deficit = -(acc.balance + netChange);
                                      deficitAccounts.add({
                                        'account': acc,
                                        'deficit': deficit,
                                      });
                                    }
                                  });

                                  final proceed = await _handleConsolidatedDeficits(
                                    context: context,
                                    appState: appState,
                                    deficits: deficitAccounts,
                                  );
                                  if (!proceed) return;

                                  await _submitConfirmations(appState);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "Registrar",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // Skip all selected items today (mark as confirmed in database)
                          final _states = _profileStates[_currentViewedDb] ?? [];
                          final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
                          if (selected.isEmpty) return;
                          
                          // Switch profile if necessary
                          if (_currentViewedDb != null && appState.activeDbName != _currentViewedDb) {
                            if (context.mounted) {
                              setState(() => _isLoading = true);
                            }
                            await appState.switchProfile(_currentViewedDb!);
                            if (context.mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                          
                          for (var s in selected) {
                            await appState.dismissRecurringPaymentToday(s.payment, occurrenceDate: s.occurrence.occurrenceDate);
                          }
                          if (context.mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            messenger.showSnackBar(
                              SnackBar(content: Text("Cobros/pagos omitidos por hoy")),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cardSubtitleText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          "Omitir hoy",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          "Decidir más tarde",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
        ),
      ),
    );
  }
}

class _PendingPaymentState {
  final PendingOccurrence occurrence;
  bool isChecked = true;
  late final TextEditingController amountController;
  bool isCustomRate = false;
  late final TextEditingController rateController;
  bool showCustomAmount = false;
  bool willSkip = false;
  bool useExistingBalance = false;
  String? selectedExistingBalanceAccountId;

  RecurringPayment get payment => occurrence.payment;

  _PendingPaymentState(this.occurrence, double initialRate) {
    amountController = TextEditingController(text: occurrence.remainingAmount.toStringAsFixed(2));
    rateController = TextEditingController(text: initialRate.toStringAsFixed(2));
  }
}

class _NoSourceAccountsDeficitBottomSheet extends StatelessWidget {
  final Account targetAccount;
  final double deficit;

  const _NoSourceAccountsDeficitBottomSheet({
    required this.targetAccount,
    required this.deficit,
  });

  @override
  Widget build(BuildContext context) {
    final deficitFormatted = targetAccount.currency == CurrencyType.usd
        ? "\$${deficit.toStringAsFixed(2)}"
        : "${deficit.toStringAsFixed(2)} Bs.";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.all(20),
      child: SafeArea(
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
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              "El saldo en '${targetAccount.name}' (${targetAccount.balance.toStringAsFixed(2)} ${targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados (Déficit consolidado de $deficitFormatted).\n\nNo tienes otras cuentas con fondos disponibles para realizar una transferencia. Por favor, agrega fondos a tus cuentas primero para poder proceder.",
              style: TextStyle(fontSize: 13, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cardSubtitleText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.black.withOpacity(0.08)),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("Cerrar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeficitTransferBottomSheet extends StatefulWidget {
  final AppState appState;
  final Account targetAccount;
  final double deficit;
  final List<Account> sourceAccounts;

  const _DeficitTransferBottomSheet({
    required this.appState,
    required this.targetAccount,
    required this.deficit,
    required this.sourceAccounts,
  });

  @override
  State<_DeficitTransferBottomSheet> createState() => _DeficitTransferBottomSheetState();
}

class _DeficitTransferBottomSheetState extends State<_DeficitTransferBottomSheet> {
  late Account selectedSource;
  late String selectedRateType;
  late final TextEditingController customRateController;
  late final TextEditingController customAmountController;
  bool _amountEditedByUser = false;

  @override
  void initState() {
    super.initState();
    selectedSource = widget.sourceAccounts.first;
    selectedRateType = 'parallel'; // default to parallel/P2P
    customRateController = TextEditingController(text: widget.appState.bcvRate.toStringAsFixed(2));
    customAmountController = TextEditingController();
    _updateDefaultAmount();
  }

  @override
  void dispose() {
    customRateController.dispose();
    customAmountController.dispose();
    super.dispose();
  }

  double _getActiveRate() {
    if (selectedRateType == 'parallel') return widget.appState.parallelRate;
    if (selectedRateType == 'bcv') return widget.appState.bcvRate;
    if (selectedRateType == 'euro') return widget.appState.euroRate;
    if (selectedRateType == 'custom') return double.tryParse(customRateController.text) ?? widget.appState.bcvRate;
    return widget.appState.bcvRate;
  }

  void _updateDefaultAmount() {
    if (_amountEditedByUser) return;
    double activeRate = _getActiveRate();
    double requiredSourceAmt = widget.deficit;
    bool isCrossCurrency = widget.targetAccount.currency != selectedSource.currency;

    if (isCrossCurrency) {
      if (selectedSource.currency == CurrencyType.usd) {
        requiredSourceAmt = activeRate > 0 ? widget.deficit / activeRate : 0.0;
      } else {
        requiredSourceAmt = widget.deficit * activeRate;
      }
    }
    customAmountController.text = requiredSourceAmt.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final deficitFormatted = widget.targetAccount.currency == CurrencyType.usd
        ? "\$${widget.deficit.toStringAsFixed(2)}"
        : "${widget.deficit.toStringAsFixed(2)} Bs.";

    // Determine rate to use based on selected type
    double activeRate = _getActiveRate();
    bool isCrossCurrency = widget.targetAccount.currency != selectedSource.currency;

    // Source amount comes from the controller
    double inputSourceAmt = double.tryParse(customAmountController.text) ?? 0.0;
    
    // Calculate how much the target account will actually receive
    double targetAmt = inputSourceAmt;
    if (isCrossCurrency) {
      if (selectedSource.currency == CurrencyType.usd) {
        // Source is USD, target is Bs
        targetAmt = inputSourceAmt * activeRate;
      } else {
        // Source is Bs, target is USD
        targetAmt = activeRate > 0 ? inputSourceAmt / activeRate : 0.0;
      }
    }

    final sourceAmtFormatted = selectedSource.currency == CurrencyType.usd
        ? "\$${inputSourceAmt.toStringAsFixed(2)}"
        : "${inputSourceAmt.toStringAsFixed(2)} Bs.";

    final targetAmtFormatted = widget.targetAccount.currency == CurrencyType.usd
        ? "\$${targetAmt.toStringAsFixed(2)}"
        : "${targetAmt.toStringAsFixed(2)} Bs.";

    bool hasInsufficientFunds = inputSourceAmt > selectedSource.balance;
    bool isAmountTooSmall = targetAmt < (widget.deficit - 0.01);

    String? errorText;
    if (hasInsufficientFunds) {
      errorText = "Saldo insuficiente en cuenta origen";
    } else if (isAmountTooSmall) {
      errorText = "El monto no cubre el déficit";
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.all(20),
      child: SafeArea(
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
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              "El saldo de '${widget.targetAccount.name}' (${widget.targetAccount.balance.toStringAsFixed(2)} ${widget.targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados.\n\nSe necesita cubrir un déficit consolidado de $deficitFormatted.",
              style: TextStyle(fontSize: 12.5, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              "Origen de los fondos:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            SizedBox(height: 6),
            DropdownButtonFormField<Account>(
              initialValue: selectedSource,
              dropdownColor: AppColors.cardBackground,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: widget.sourceAccounts.map((acc) {
                final balFormatted = acc.currency == CurrencyType.usd
                    ? "\$${acc.balance.toStringAsFixed(2)}"
                    : "${acc.balance.toStringAsFixed(2)} Bs.";
                return DropdownMenuItem<Account>(
                  value: acc,
                  child: Text(
                    "${acc.name} ($balFormatted)",
                    style: TextStyle(fontSize: 12, color: AppColors.cardText),
                  ),
                );
              }).toList(),
              onChanged: (acc) {
                if (acc != null) {
                  setState(() {
                    selectedSource = acc;
                    _updateDefaultAmount();
                  });
                }
              },
            ),
            if (isCrossCurrency) ...[
              SizedBox(height: 12),
              Text(
                "Tasa de cambio para la transferencia:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedRateType,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'parallel',
                    child: Text("Paralela / P2P (${widget.appState.parallelRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'bcv',
                    child: Text("BCV Oficial (${widget.appState.bcvRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'euro',
                    child: Text("Euro Oficial (${widget.appState.euroRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text("Personalizada", style: TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedRateType = val;
                      _updateDefaultAmount();
                    });
                  }
                },
              ),
              if (selectedRateType == 'custom') ...[
                SizedBox(height: 8),
                TextFormField(
                  controller: customRateController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: "Tasa de cambio personalizada (Bs/\$)",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _updateDefaultAmount();
                    });
                  },
                ),
              ],
            ],
            SizedBox(height: 12),
            Text(
              "Monto a transferir (origen):",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            SizedBox(height: 6),
            TextFormField(
              controller: customAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixText: selectedSource.currency == CurrencyType.usd ? "\$ " : "Bs. ",
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: errorText,
              ),
              onChanged: (val) {
                setState(() {
                  _amountEditedByUser = true;
                });
              },
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCrossCurrency
                          ? "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}'. Recibirás $targetAmtFormatted usando la tasa seleccionada (${activeRate.toStringAsFixed(2)} Bs/\$)."
                          : "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}'. Recibirás $targetAmtFormatted.",
                      style: TextStyle(fontSize: 11.5, color: AppColors.cardText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: errorText != null ? null : () {
                  Navigator.pop(context, {
                    "action": "transfer",
                    "source": selectedSource,
                    "sourceAmount": inputSourceAmt,
                    "targetAmount": targetAmt,
                    "rate": activeRate,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("Transferir y Registrar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text("Cancelar", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
