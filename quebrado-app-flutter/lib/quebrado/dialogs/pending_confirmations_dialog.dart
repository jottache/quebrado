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
import '../services/biometric_service.dart';
import '../../widgets/responsive_breakpoints.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
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
      // Primero otra cuenta de la misma moneda que alcance (no hace falta cambiar divisa);
      // luego las cuentas en $ con más saldo (vender dólares); al final el resto.
      int rank(Account a) {
        if (a.currency == targetAccount.currency && a.balance >= deficit) return 0;
        if (a.currency == CurrencyType.usd && targetAccount.currency == CurrencyType.bsBCV) return 1;
        return 2;
      }
      sourceAccounts.sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : b.balance.compareTo(a.balance);
      });

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

          // Vender $ → Bs (o comprar $ con Bs): se registra como "Cambio de Divisa"
          final isUsdToBs = source.currency == CurrencyType.usd && targetAccount.currency == CurrencyType.bsBCV;
          final isBsToUsd = source.currency == CurrencyType.bsBCV && targetAccount.currency == CurrencyType.usd;
          if (isUsdToBs || isBsToUsd) {
            await appState.exchangeCurrency(
              usdAccountId: isUsdToBs ? source.id : targetAccount.id,
              vesAccountId: isUsdToBs ? targetAccount.id : source.id,
              amountUSD: isUsdToBs ? sourceAmount : targetAmount,
              exchangeRate: activeRate,
              isVenta: isUsdToBs,
              note: isUsdToBs
                  ? "Venta de \$ para pagos en Bs (${targetAccount.name})"
                  : "Compra de \$ para pagos en ${targetAccount.name}",
            );
            continue;
          }

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

    if (appState.useBiometrics || appState.usePinSecurity) {
      final authenticated = await appState.verifySecurityAuth(
        context,
        reason: "Confirma tu identidad para registrar los cobros seleccionados",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Autenticación de seguridad requerida o cancelada."),
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
    // Lo registrado se devuelve al cerrar (acciones rápidas, «Ver»).
    final recorded = <Transaction>[];
    var confirmedAny = false;

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
          onTransactionRecorded: recorded.add,
          customNote: p.currency == CurrencyType.eur
              ? "Confirmado${existingBalanceStr}: ${p.name} (€${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)"
              : "Confirmado${existingBalanceStr}: ${p.name} (\$${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)",
        );
      } else {
        isLast = await appState.confirmRecurringPayment(
          payment: p,
          actualAmount: actualAmt,
          occurrenceDate: s.occurrence.occurrenceDate,
          onTransactionRecorded: recorded.add,
          customNote: isPartialRest
              ? "Confirmado${existingBalanceStr}: ${p.name} (Restante: ${p.currency.symbol}${remainingVal.toStringAsFixed(2)})"
              : s.useExistingBalance ? "Confirmado${existingBalanceStr}: ${p.name}" : null,
        );
      }
      confirmedAny = true;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Mantener", style: TextStyle(color: AppColors.cardSubtitleText)),
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
        // Movimientos registrados (puede ir vacía si se confirmó con saldo
        // existente); null si solo se omitieron pagos.
        final List<Transaction>? result = confirmedAny ? List.unmodifiable(recorded) : null;
        if (totalUsdIncomeForAutoSave > 0) {
          await _showAutoSaveDialog(context, appState, totalUsdIncomeForAutoSave, result);
        } else {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, result);
          messenger.showSnackBar(
            SnackBar(content: Text("Registros agregados al historial")),
          );
        }
      }
    }
  }

  /// [result] es lo que devuelve la hoja al cerrarse (ver _submitConfirmations).
  Future<void> _showAutoSaveDialog(
    BuildContext context,
    AppState appState,
    double usdIncomeAmount,
    List<Transaction>? result,
  ) async {
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
      Navigator.pop(context, result);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Sugerencias de Auto-Ahorro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Basado en el ingreso cobrado (\$${usdIncomeAmount.toStringAsFixed(2)}), te sugerimos apartar a tus bolsillos:", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText)),
            SizedBox(height: OrtizSpace.lg),
            ...proposedDeposits.entries.map((e) {
              final pocket = appState.pockets.firstWhere((p) => p.id == e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("• ${pocket.name}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm, color: AppColors.cardText))),
                    Text(formatUSD(e.value), style: TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, result);
            },
            child: const Text("Ignorar", style: TextStyle(color: AppColors.cardSubtitleText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
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
                 Navigator.pop(context, result);
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
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Container(
      height: isDesktop ? size.height : null,
      constraints: BoxConstraints(
        maxHeight: isDesktop ? size.height : size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: isDesktop
            ? const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.sheet),
                bottomLeft: Radius.circular(OrtizRadius.sheet),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.sheet),
                topRight: Radius.circular(OrtizRadius.sheet),
              ),
      ),
      padding: EdgeInsets.only(left: OrtizSpace.xl, right: OrtizSpace.xl, top: isDesktop ? OrtizSpace.xxl : OrtizSpace.xl, bottom: OrtizSpace.sm),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDesktop) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorderColor,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),
              const SizedBox(height: OrtizSpace.lg),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(OrtizSpace.sm),
                  decoration: const BoxDecoration(
                    color: OrtizPalette.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: OrtizIconSize.md,
                  ),
                ),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    widget.filterOccurrence != null 
                        ? "Registrar ${widget.filterOccurrence!.payment.type == TransactionType.income ? 'Cobro' : 'Pago'}"
                        : "Cobros y Pagos de Hoy",
                    style: TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.md),
            Text(
              widget.filterOccurrence != null
                  ? "Confirma los detalles para registrar este ${widget.filterOccurrence!.payment.type == TransactionType.income ? 'ingreso' : 'egreso'} en tus cuentas:"
                  : "Tienes registros programados pendientes para hoy. Elige cuáles quieres registrar automáticamente en tus cuentas:",
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            if (showTabs) ...[
              SizedBox(height: OrtizSpace.md),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.nestedTabTrackBg,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: appState.profiles.length > 3,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: OrtizPalette.onAccent,
                  unselectedLabelColor: AppColors.nestedTabInactiveText,
                  labelStyle: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.normal),
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
            SizedBox(height: OrtizSpace.lg),
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
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      size: OrtizIconSize.xxl,
                    ),
                    SizedBox(height: OrtizSpace.md),
                    Text(
                      "¡Todo al día!",
                      style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                    ),
                    SizedBox(height: OrtizSpace.sm),
                    Text(
                      "No tienes ningún pago programado pendiente para hoy en este libro.",
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
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

                    // Fila sin tarjeta: separada de la siguiente por una línea.
                    return Container(
                      margin: const EdgeInsets.only(bottom: OrtizSpace.md),
                      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.cardBorderColor, width: OrtizStroke.hairline),
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
                                padding: EdgeInsets.all(OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  getIconData(p.icon),
                                  color: iconColor,
                                  size: OrtizIconSize.sm,
                                ),
                              ),
                                SizedBox(width: OrtizSpace.xs),
                                Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                    SizedBox(height: OrtizSpace.xxs),
                                    Text(
                                      "${isIncome ? 'Ingreso' : 'Gasto'} • Vence: ${formatDate(state.occurrence.occurrenceDate)}",
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.caption,
                                        color: isIncome ? AppColors.primary : AppColors.expense,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (state.occurrence.partialAmountPaid > 0) ...[
                                      SizedBox(height: OrtizSpace.xxs),
                                      Text(
                                        "Pagado parcial: ${formatCurrency(state.occurrence.partialAmountPaid, p.currency)}",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.caption,
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
                                    fontSize: OrtizFontSize.body,
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? AppColors.primary : AppColors.expense,
                                  ),
                                ),
                            ],
                          ),
                          if ((p.isVariable || state.showCustomAmount) && state.isChecked && !state.willSkip) ...[
                            SizedBox(height: OrtizSpace.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      Text(
                                        "Rango: ${formatCurrency(p.amount, p.currency)} - ${formatCurrency(p.maxAmount ?? p.amount, p.currency)}",
                                        style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      SizedBox(
                                        height: 36,
                                        child: TextField(
                                          controller: state.amountController,
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                            hintText: "0.00 ${p.currency.symbol}",
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                              borderSide: const BorderSide(color: AppColors.cardBorderColor),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
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
                            SizedBox(height: OrtizSpace.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      if (!p.isVariable) ...[
                                        Text(
                                          "Monto Base: ${formatCurrency(p.amount, p.currency)}",
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.bodySm,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.cardText,
                                          ),
                                        ),
                                        SizedBox(height: OrtizSpace.xs),
                                      ],
                                      Text(
                                        "TASA DE CAMBIO",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardSubtitleText,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      Container(
                                        padding: EdgeInsets.all(OrtizSpace.xxs),
                                        decoration: BoxDecoration(
                                          color: AppColors.nestedTabTrackBg,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => state.isCustomRate = false),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                                                  decoration: BoxDecoration(
                                                    color: !state.isCustomRate
                                                        ? AppColors.nestedTabActiveBg
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    "${p.currency == CurrencyType.eur ? 'EUR' : 'BCV'} (${(p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate).toStringAsFixed(2)})",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: OrtizFontSize.caption,
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
                                                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                                                  decoration: BoxDecoration(
                                                    color: state.isCustomRate
                                                        ? AppColors.nestedTabActiveBg
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    "Personalizada",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: OrtizFontSize.caption,
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
                                        SizedBox(height: OrtizSpace.xs),
                                        SizedBox(
                                          height: 36,
                                          child: TextField(
                                            controller: state.rateController,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                              hintText: "Ingrese tasa Bs.",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                borderSide: const BorderSide(color: AppColors.cardBorderColor),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                borderSide: BorderSide(color: AppColors.primary),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: OrtizSpace.sm),
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
                                            padding: EdgeInsets.all(OrtizSpace.sm),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Se registrará en Banco Bs.:",
                                                  style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                                                ),
                                                OrtizAmount(
                                                  value: calculatedBs,
                                                  currencySymbol: 'Bs.',
                                                  format: formatBs,
                                                  color: AppColors.primary,
                                                  style: OrtizType.amount.copyWith(
                                                    fontSize: OrtizFontSize.bodySm,
                                                    fontWeight: FontWeight.w900,
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
                            SizedBox(height: OrtizSpace.md),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
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
                                child: Text(state.showCustomAmount ? "Usar monto completo" : "Modificar monto", style: TextStyle(fontSize: OrtizFontSize.bodySm)),
                              ),
                            ),
                            SizedBox(height: OrtizSpace.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: state.willSkip ? OrtizPalette.onAccent : AppColors.expense,
                                  backgroundColor: state.willSkip ? AppColors.expense : Colors.transparent,
                                  side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
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
                                child: Text(state.willSkip ? "Se omitirá este ${isIncome ? 'ingreso' : 'pago'}" : "Omitir ${isIncome ? 'ingreso' : 'pago'}", style: TextStyle(fontSize: OrtizFontSize.bodySm)),
                              ),
                            ),
                          ],
                          if (isIncome && !state.willSkip && state.isChecked) ...[
                            SizedBox(height: OrtizSpace.sm),
                            CheckboxListTile(
                              value: state.useExistingBalance,
                              dense: true,
                              activeColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              title: Text("Usar saldo existente", style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                              subtitle: Text("No se añadirá saldo extra a la cuenta, previniendo dinero duplicado si ya compraste las divisas manualmente.", style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText)),
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
                                          padding: const EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xs),
                                          child: DropdownButtonFormField<String>(
                                            value: state.selectedExistingBalanceAccountId,
                                            decoration: InputDecoration(
                                              labelText: "Selecciona la cuenta donde ya tienes el dinero",
                                              labelStyle: TextStyle(fontSize: OrtizFontSize.caption),
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                            ),
                                            items: usdAccounts.map((a) {
                                              return DropdownMenuItem(
                                                value: a.id,
                                                child: Text("${a.name} (\$${a.balance.toStringAsFixed(2)})", style: TextStyle(fontSize: OrtizFontSize.bodySm)),
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
                                          padding: const EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xs),
                                          child: Container(
                                            padding: EdgeInsets.all(OrtizSpace.sm),
                                            decoration: BoxDecoration(
                                              color: AppColors.expense.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                              border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: OrtizIconSize.sm),
                                                SizedBox(width: OrtizSpace.sm),
                                                Expanded(
                                                  child: Text(
                                                    existingBalanceError,
                                                    style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.expense, fontWeight: FontWeight.w600, height: 1.3),
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
                    SizedBox(height: OrtizSpace.xs),
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

                        // Bloque destacado sin sombra (antes, tarjeta «glass»).
                        return OrtizSection(
                          surface: true,
                          children: [Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "RESUMEN DE SELECCIÓN",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.micro,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                               SizedBox(height: OrtizSpace.sm),
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
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(height: OrtizSpace.xs),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeUSD.toStringAsFixed(2), "Total Ingresos USD"),
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalIncomeUSD),
                                                  style: TextStyle(
                                                    fontSize: OrtizFontSize.titleSm,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                SizedBox(width: OrtizSpace.xs),
                                                Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: AppColors.income.withValues(alpha: 0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: OrtizSpace.xxs),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeBs.toStringAsFixed(2), "Total Ingresos Bs."),
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalIncomeBs),
                                                  style: TextStyle(
                                                    fontSize: OrtizFontSize.bodySm,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                SizedBox(width: OrtizSpace.xs),
                                                Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: AppColors.income.withValues(alpha: 0.4)),
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
                                    color: AppColors.cardBorderColor,
                                  ),
                                  SizedBox(width: OrtizSpace.lg),
                                  // Egresos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total Egresos",
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(height: OrtizSpace.xs),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseUSD.toStringAsFixed(2), "Total Egresos USD"),
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalExpenseUSD),
                                                  style: TextStyle(
                                                    fontSize: OrtizFontSize.titleSm,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                SizedBox(width: OrtizSpace.xs),
                                                Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: AppColors.expense.withValues(alpha: 0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: OrtizSpace.xxs),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseBs.toStringAsFixed(2), "Total Egresos Bs."),
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalExpenseBs),
                                                  style: TextStyle(
                                                    fontSize: OrtizFontSize.bodySm,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                SizedBox(width: OrtizSpace.xs),
                                                Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: AppColors.expense.withValues(alpha: 0.4)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: OrtizSpace.sm),
                              const Divider(color: AppColors.cardBorderColor, height: OrtizStroke.hairline),
                              SizedBox(height: OrtizSpace.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Neto",
                                    style: TextStyle(
                                        fontSize: OrtizFontSize.caption,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, netUSD.toStringAsFixed(2), "Total Neto USD"),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                displayNetUSD,
                                                style: TextStyle(
                                                  fontSize: OrtizFontSize.body,
                                                  fontWeight: FontWeight.bold,
                                                  color: netColor,
                                                ),
                                              ),
                                              SizedBox(width: OrtizSpace.xs),
                                              Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: netColor.withValues(alpha: 0.5)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xxs),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, netBs.toStringAsFixed(2), "Total Neto Bs."),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                displayNetBs,
                                                style: TextStyle(
                                                  fontSize: OrtizFontSize.bodySm,
                                                  fontWeight: FontWeight.w600,
                                                  color: netColor,
                                                ),
                                              ),
                                              SizedBox(width: OrtizSpace.xs),
                                              Icon(Icons.content_copy_rounded, size: OrtizIconSize.xs,color: netColor.withValues(alpha: 0.4)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (totalDeficitBs > 0) ...[
                                SizedBox(height: OrtizSpace.md),
                                Container(
                                  padding: EdgeInsets.all(OrtizSpace.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                                    border: Border.all(
                                      color: AppColors.secondary.withValues(alpha: 0.2),
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
                                            size: OrtizIconSize.sm,
                                          ),
                                          SizedBox(width: OrtizSpace.xs),
                                          Text(
                                            "OPTIMIZADOR DE VENTA P2P (BINANCE)",
                                            style: TextStyle(
                                              fontSize: OrtizFontSize.micro,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.secondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: OrtizSpace.sm),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, totalDeficitBs.toStringAsFixed(2), "Déficit en Bolívares"),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        child: Padding(
                                          padding: EdgeInsets.only(top: OrtizSpace.xs, bottom: OrtizSpace.xs, right: OrtizSpace.sm, left: 0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Déficit (Falta por Cubrir): ${formatBs(totalDeficitBs)}",
                                                style: TextStyle(
                                                  fontSize: OrtizFontSize.bodySm,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.cardText,
                                                ),
                                              ),
                                              SizedBox(width: OrtizSpace.sm),
                                              Icon(
                                                Icons.content_copy_rounded,
                                                size: OrtizIconSize.xs,
                                                color: AppColors.cardSubtitleText.withValues(alpha: 0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xs),
                                      Text(
                                        "El déficit representa lo que le falta a tus cuentas en Bolívares para cubrir los egresos seleccionados (Egresos - Saldo Disponible).",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          color: AppColors.cardSubtitleText,
                                          height: 1.3,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.md),
                                      Row(
                                        children: [
                                          Text(
                                            "Tasa P2P de Venta: ",
                                            style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                                          ),
                                          SizedBox(width: OrtizSpace.sm),
                                          SizedBox(
                                            width: 80,
                                            height: 28,
                                            child: TextField(
                                              controller: _p2pRateController,
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                ),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          SizedBox(width: OrtizSpace.xs),
                                          Text(
                                            " Bs/\$",
                                            style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: OrtizSpace.md),
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
                                                padding: EdgeInsets.all(OrtizSpace.sm),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                  border: Border.all(
                                                    color: AppColors.primary.withValues(alpha: 0.15),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "OPCIÓN A: VENDER SOLO EL DÉFICIT",
                                                      style: TextStyle(
                                                        fontSize: OrtizFontSize.micro,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(height: OrtizSpace.xs),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededDeficit.toStringAsFixed(2), "Binance P2P (Déficit)"),
                                                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededDeficit)}",
                                                            style: TextStyle(
                                                              fontSize: OrtizFontSize.body,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                          SizedBox(width: OrtizSpace.sm),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: OrtizIconSize.xs,
                                                            color: AppColors.primary.withValues(alpha: 0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdDeficit > 0.01) ...[
                                                      SizedBox(height: OrtizSpace.xxs),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdDeficit)}! (Vs. ${formatUSD(usdNominalDeficit)} a tasa BCV)",
                                                        style: TextStyle(
                                                          fontSize: OrtizFontSize.micro,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.income,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: OrtizSpace.sm),
                                              // Option B Card
                                              Container(
                                                padding: EdgeInsets.all(OrtizSpace.sm),
                                                decoration: BoxDecoration(
                                                  color: OrtizPalette.surfaceHigh,
                                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                  border: Border.all(
                                                    color: AppColors.cardBorderColor,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "OPCIÓN B: VENDER EL EGRESO TOTAL",
                                                      style: TextStyle(
                                                        fontSize: OrtizFontSize.micro,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.cardSubtitleText,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(height: OrtizSpace.xs),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededTotal.toStringAsFixed(2), "Binance P2P (Total)"),
                                                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededTotal)}",
                                                            style: TextStyle(
                                                              fontSize: OrtizFontSize.body,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.cardText,
                                                            ),
                                                          ),
                                                          SizedBox(width: OrtizSpace.sm),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: OrtizIconSize.xs,
                                                            color: AppColors.cardSubtitleText.withValues(alpha: 0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdTotal > 0.01) ...[
                                                      SizedBox(height: OrtizSpace.xxs),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdTotal)}! (Vs. ${formatUSD(usdNominalTotal)} a tasa BCV)",
                                                        style: TextStyle(
                                                          fontSize: OrtizFontSize.micro,
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
                          )],
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
                          SizedBox(height: OrtizSpace.xs),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.unfold_more, size: OrtizIconSize.xs,color: AppColors.cardSubtitleText.withValues(alpha: 0.6)),
                                SizedBox(width: OrtizSpace.xs),
                                Text(
                                  "Desliza para ver más",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
                                    color: AppColors.cardSubtitleText.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: OrtizSpace.lg),
                        Column(
                          children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            foregroundColor: OrtizPalette.onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.block),
                            ),
                            padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          ),
                          child: Text(
                            "Registrar",
                            style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                SizedBox(height: OrtizSpace.md),
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
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          side: const BorderSide(color: AppColors.cardBorderColor),
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        ),
                        child: Text(
                          "Omitir hoy",
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        ),
                        child: Text(
                          "Decidir más tarde",
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
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
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.all(OrtizSpace.xl),
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
                  color: AppColors.cardBorderColor,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: OrtizIconSize.lg),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),
            Text(
              "El saldo en '${targetAccount.name}' (${targetAccount.balance.toStringAsFixed(2)} ${targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados (Déficit consolidado de $deficitFormatted).\n\nNo tienes otras cuentas con fondos disponibles para realizar una transferencia. Por favor, agrega fondos a tus cuentas primero para poder proceder.",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            SizedBox(height: OrtizSpace.xxl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cardSubtitleText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                  side: const BorderSide(color: AppColors.cardBorderColor),
                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                ),
                child: Text("Cerrar", style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold)),
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
    // Vender $ para pagar en Bs: tasa BCV por defecto (la misma que usa la proyección)
    selectedRateType = 'bcv';
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
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.all(OrtizSpace.xl),
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
                  color: AppColors.cardBorderColor,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: OrtizIconSize.lg),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.md),
            Text(
              "El saldo de '${widget.targetAccount.name}' (${widget.targetAccount.balance.toStringAsFixed(2)} ${widget.targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados.\n\nSe necesita cubrir un déficit consolidado de $deficitFormatted.",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            SizedBox(height: OrtizSpace.lg),
            Text(
              "Origen de los fondos:",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            SizedBox(height: OrtizSpace.xs),
            DropdownButtonFormField<Account>(
              initialValue: selectedSource,
              dropdownColor: AppColors.cardBackground,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              ),
              items: widget.sourceAccounts.map((acc) {
                final balFormatted = acc.currency == CurrencyType.usd
                    ? "\$${acc.balance.toStringAsFixed(2)}"
                    : "${acc.balance.toStringAsFixed(2)} Bs.";
                return DropdownMenuItem<Account>(
                  value: acc,
                  child: Text(
                    "${acc.name} ($balFormatted)",
                    style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
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
              SizedBox(height: OrtizSpace.md),
              Text(
                "Tasa de cambio para la transferencia:",
                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: OrtizSpace.xs),
              DropdownButtonFormField<String>(
                initialValue: selectedRateType,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'parallel',
                    child: Text("Paralela / P2P (${widget.appState.parallelRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'bcv',
                    child: Text("BCV Oficial (${widget.appState.bcvRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'euro',
                    child: Text("Euro Oficial (${widget.appState.euroRate.toStringAsFixed(2)} Bs/\$)", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text("Personalizada", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
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
                SizedBox(height: OrtizSpace.sm),
                TextFormField(
                  controller: customRateController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: OrtizFontSize.bodySm),
                  decoration: InputDecoration(
                    labelText: "Tasa de cambio personalizada (Bs/\$)",
                    contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
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
            SizedBox(height: OrtizSpace.md),
            Text(
              "Monto a transferir (origen):",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            SizedBox(height: OrtizSpace.xs),
            TextFormField(
              controller: customAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: OrtizFontSize.body),
              decoration: InputDecoration(
                prefixText: selectedSource.currency == CurrencyType.usd ? "\$ " : "Bs. ",
                contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                errorText: errorText,
              ),
              onChanged: (val) {
                setState(() {
                  _amountEditedByUser = true;
                });
              },
            ),
            SizedBox(height: OrtizSpace.lg),
            Container(
              padding: EdgeInsets.all(OrtizSpace.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(OrtizRadius.field),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: OrtizIconSize.sm),
                  SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      isCrossCurrency
                          ? "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}'. Recibirás $targetAmtFormatted usando la tasa seleccionada (${activeRate.toStringAsFixed(2)} Bs/\$)."
                          : "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}'. Recibirás $targetAmtFormatted.",
                      style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: OrtizSpace.xl),
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
                  foregroundColor: OrtizPalette.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                ),
                child: Text("Transferir y Registrar", style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text("Cancelar", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
