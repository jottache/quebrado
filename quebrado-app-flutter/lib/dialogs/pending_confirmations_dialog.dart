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

class _PendingConfirmationsBottomSheetState extends State<PendingConfirmationsBottomSheet> {
  final List<_PendingPaymentState> _states = [];
  bool _initialized = false;
  late final TextEditingController _p2pRateController;
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final appState = Provider.of<AppState>(context);
      if (widget.filterOccurrence != null) {
        final occ = widget.filterOccurrence!;
        final rate = occ.payment.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
        final state = _PendingPaymentState(occ, rate);
        if (widget.forceShowCustomAmount) state.showCustomAmount = true;
        _states.add(state);
      } else {
        for (var occ in appState.pendingPaymentsToday) {
          final rate = occ.payment.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
          final state = _PendingPaymentState(occ, rate);
          if (widget.forceShowCustomAmount) state.showCustomAmount = true;
          _states.add(state);
        }
      }
      _p2pRateController = TextEditingController(text: appState.parallelRate.toStringAsFixed(2));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    for (var s in _states) {
      s.amountController.dispose();
      s.rateController.dispose();
    }
    _p2pRateController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _submitConfirmations(AppState appState) async {
    final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
    if (selected.isEmpty) return;

    if (appState.useBiometrics) {
      final authenticated = await BiometricService.authenticate(
        reason: "Confirma tu identidad para registrar los cobros seleccionados",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Autenticación biométrica fallida o cancelada."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }

    // Map of accountId -> net balance change
    final Map<String, double> netChanges = {};

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
      double actualAmt = remainingVal;
      final isPartialRest = remainingVal < p.amount;

      if (needsConversion) {
        final rateController = s.rateController;
        final double defaultRate = p.currency == CurrencyType.eur ? appState.euroRate : appState.bcvRate;
        final double rateVal = double.tryParse(rateController.text.replaceAll(',', '.')) ?? defaultRate;
        actualAmt = remainingVal * rateVal;
        
        await appState.confirmRecurringPayment(
          payment: p,
          actualAmount: actualAmt,
          occurrenceDate: s.occurrence.occurrenceDate,
          overrideCurrency: CurrencyType.bsBCV,
          customExchangeRate: rateVal,
          customNote: p.currency == CurrencyType.eur
              ? "Confirmado: ${p.name} (€${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)"
              : "Confirmado: ${p.name} (\$${remainingVal.toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)",
        );
      } else {
        await appState.confirmRecurringPayment(
          payment: p,
          actualAmount: actualAmt,
          occurrenceDate: s.occurrence.occurrenceDate,
          customNote: isPartialRest 
              ? "Confirmado: ${p.name} (Restante: ${p.currency.symbol}${remainingVal.toStringAsFixed(2)})"
              : null,
        );
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registros agregados al historial")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;

    if (_states.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: const SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¡Todo al día!",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 8),
              Text(
                "No tienes ningún pago programado pendiente para hoy.",
                style: TextStyle(fontSize: 13, color: AppColors.cardSubtitleText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Cobros y Pagos de Hoy",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Tienes registros programados pendientes para hoy. Elige cuáles quieres registrar automáticamente en tus cuentas:",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
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
                                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                    onChanged: (val) {
                                      setState(() {
                                        state.isChecked = val ?? false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
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
                                const SizedBox(width: 6),
                                Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${isIncome ? 'Ingreso' : 'Gasto'} • Vence: ${formatDate(state.occurrence.occurrenceDate)}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isIncome ? AppColors.primary : AppColors.expense,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (state.occurrence.partialAmountPaid > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Pagado parcial: ${formatCurrency(state.occurrence.partialAmountPaid, p.currency)}",
                                        style: const TextStyle(
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
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      Text(
                                        "Rango: ${formatCurrency(p.amount, p.currency)} - ${formatCurrency(p.maxAmount ?? p.amount, p.currency)}",
                                        style: const TextStyle(fontSize: 10, color: AppColors.cardSubtitleText),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 36,
                                        child: TextField(
                                          controller: state.amountController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            prefixText: p.currency.symbol + " ",
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Colors.black12),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppColors.primary),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                              ],
                            ),
                          ],
                          if (needsConversion && state.isChecked && !state.willSkip) ...[
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      if (!p.isVariable) ...[
                                        Text(
                                          "Monto Base: ${formatCurrency(p.amount, p.currency)}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.cardText,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      const Text(
                                        "TASA DE CAMBIO",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardSubtitleText,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(2),
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
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 36,
                                          child: TextField(
                                            controller: state.rateController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              prefixText: "Bs. ",
                                              hintText: "Ingrese tasa",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Colors.black12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: AppColors.primary),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
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
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  "Se registrará en Banco Bs.:",
                                                  style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                                ),
                                                Text(
                                                  formatBs(calculatedBs),
                                                  style: const TextStyle(
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
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                                child: Text(state.showCustomAmount ? "Usar monto completo" : "Modificar monto", style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: state.willSkip ? Colors.white : AppColors.expense,
                                  backgroundColor: state.willSkip ? AppColors.expense : Colors.transparent,
                                  side: BorderSide(color: AppColors.expense.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                                child: Text(state.willSkip ? "Se omitirá este ${isIncome ? 'ingreso' : 'pago'}" : "Omitir ${isIncome ? 'ingreso' : 'pago'}", style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                    if (_states.any((s) => s.isChecked)) ...[
                    const SizedBox(height: 4),
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
                          padding: const EdgeInsets.all(14),
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
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "RESUMEN DE SELECCIÓN",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                               const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Ingresos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Total Ingresos",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeUSD.toStringAsFixed(2), "Total Ingresos USD"),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalIncomeUSD),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 14, color: AppColors.income.withOpacity(0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalIncomeBs.toStringAsFixed(2), "Total Ingresos Bs."),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalIncomeBs),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.income,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
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
                                  const SizedBox(width: 16),
                                  // Egresos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Total Egresos",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseUSD.toStringAsFixed(2), "Total Egresos USD"),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatUSD(totalExpenseUSD),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(Icons.content_copy_rounded, size: 14, color: AppColors.expense.withOpacity(0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, totalExpenseBs.toStringAsFixed(2), "Total Egresos Bs."),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formatBs(totalExpenseBs),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
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
                              const SizedBox(height: 10),
                              Divider(color: Colors.black.withOpacity(0.05), height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                              const SizedBox(width: 6),
                                              Icon(Icons.content_copy_rounded, size: 13, color: netColor.withOpacity(0.5)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, netBs.toStringAsFixed(2), "Total Neto Bs."),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                              const SizedBox(width: 6),
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
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
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
                                          const Icon(
                                            Icons.calculate_outlined,
                                            color: AppColors.secondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
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
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, totalDeficitBs.toStringAsFixed(2), "Déficit en Bolívares"),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8, left: 0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Déficit (Falta por Cubrir): ${formatBs(totalDeficitBs)}",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.cardText,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.content_copy_rounded,
                                                size: 13,
                                                color: AppColors.cardSubtitleText.withOpacity(0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "El déficit representa lo que le falta a tus cuentas en Bolívares para cubrir los egresos seleccionados (Egresos - Saldo Disponible).",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.cardSubtitleText,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            "Tasa P2P de Venta: ",
                                            style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            height: 28,
                                            child: TextField(
                                              controller: _p2pRateController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            " Bs/\$",
                                            style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
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
                                                padding: const EdgeInsets.all(10),
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
                                                    const Text(
                                                      "OPCIÓN A: VENDER SOLO EL DÉFICIT",
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededDeficit.toStringAsFixed(2), "Binance P2P (Déficit)"),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededDeficit)}",
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: 13,
                                                            color: AppColors.primary.withOpacity(0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdDeficit > 0.01) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdDeficit)}! (Vs. ${formatUSD(usdNominalDeficit)} a tasa BCV)",
                                                        style: const TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.income,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              // Option B Card
                                              Container(
                                                padding: const EdgeInsets.all(10),
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
                                                    const Text(
                                                      "OPCIÓN B: VENDER EL EGRESO TOTAL",
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.cardSubtitleText,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _copyToClipboard(context, usdNeededTotal.toStringAsFixed(2), "Binance P2P (Total)"),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Debes vender: ${formatUSD(usdNeededTotal)}",
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.cardText,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Icon(
                                                            Icons.content_copy_rounded,
                                                            size: 13,
                                                            color: AppColors.cardSubtitleText.withOpacity(0.7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (savedUsdTotal > 0.01) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        "¡Ahorras ${formatUSD(savedUsdTotal)}! (Vs. ${formatUSD(usdNominalTotal)} a tasa BCV)",
                                                        style: const TextStyle(
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
                  ],
                ],
              ),
            ),
          ),
        ),
          if (_states.length > 2) ...[
            const SizedBox(height: 6),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.unfold_more, size: 14, color: AppColors.cardSubtitleText.withOpacity(0.6)),
                  const SizedBox(width: 4),
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
          const SizedBox(height: 16),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: appState.useSlideToConfirm
                      ? SlideToConfirmButton(
                          enabled: _states.any((s) => s.isChecked || s.willSkip),
                          label: "Desliza para registrar",
                          onConfirmed: () async {
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
                          onPressed: _states.any((s) => s.isChecked || s.willSkip)
                              ? () async {
                                  // Confirm and register all selected
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Registrar",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // Skip all selected items today (mark as confirmed in database)
                          final selected = _states.where((s) => s.isChecked || s.willSkip).toList();
                          if (selected.isEmpty) return;
                          for (var s in selected) {
                            await appState.dismissRecurringPaymentToday(s.payment, occurrenceDate: s.occurrence.occurrenceDate);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Cobros/pagos omitidos por hoy")),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cardSubtitleText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          "Omitir hoy",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "El saldo en '${targetAccount.name}' (${targetAccount.balance.toStringAsFixed(2)} ${targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados (Déficit consolidado de $deficitFormatted).\n\nNo tienes otras cuentas con fondos disponibles para realizar una transferencia. ¿Deseas registrar los pagos de todas formas?",
              style: const TextStyle(fontSize: 13, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cardSubtitleText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.black.withOpacity(0.08)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Cancelar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Registrar de todas formas", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  @override
  void initState() {
    super.initState();
    selectedSource = widget.sourceAccounts.first;
    selectedRateType = 'parallel'; // default to parallel/P2P
    customRateController = TextEditingController(text: widget.appState.bcvRate.toStringAsFixed(2));
  }

  @override
  void dispose() {
    customRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deficitFormatted = widget.targetAccount.currency == CurrencyType.usd
        ? "\$${widget.deficit.toStringAsFixed(2)}"
        : "${widget.deficit.toStringAsFixed(2)} Bs.";

    // Determine rate to use based on selected type
    double activeRate = widget.appState.bcvRate;
    if (selectedRateType == 'parallel') {
      activeRate = widget.appState.parallelRate;
    } else if (selectedRateType == 'bcv') {
      activeRate = widget.appState.bcvRate;
    } else if (selectedRateType == 'euro') {
      activeRate = widget.appState.euroRate;
    } else if (selectedRateType == 'custom') {
      activeRate = double.tryParse(customRateController.text) ?? widget.appState.bcvRate;
    }

    // Calculate source amount to deduct
    double requiredSourceAmt = widget.deficit;
    bool isCrossCurrency = widget.targetAccount.currency != selectedSource.currency;

    if (isCrossCurrency) {
      if (selectedSource.currency == CurrencyType.usd) {
        // Bs deficit -> USD source
        requiredSourceAmt = activeRate > 0 ? widget.deficit / activeRate : 0.0;
      } else {
        // USD deficit -> Bs source
        requiredSourceAmt = widget.deficit * activeRate;
      }
    }

    final sourceAmtFormatted = selectedSource.currency == CurrencyType.usd
        ? "\$${requiredSourceAmt.toStringAsFixed(2)}"
        : "${requiredSourceAmt.toStringAsFixed(2)} Bs.";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Saldo Insuficiente",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "El saldo de '${widget.targetAccount.name}' (${widget.targetAccount.balance.toStringAsFixed(2)} ${widget.targetAccount.currency.symbol}) es insuficiente para registrar los pagos seleccionados.\n\nSe necesita cubrir un déficit consolidado de $deficitFormatted.",
              style: const TextStyle(fontSize: 12.5, color: AppColors.cardSubtitleText, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              "Origen de los fondos:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<Account>(
              value: selectedSource,
              dropdownColor: AppColors.cardBackground,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: const TextStyle(fontSize: 12, color: AppColors.cardText),
                  ),
                );
              }).toList(),
              onChanged: (acc) {
                if (acc != null) {
                  setState(() {
                    selectedSource = acc;
                  });
                }
              },
            ),
            if (isCrossCurrency) ...[
              const SizedBox(height: 12),
              const Text(
                "Tasa de cambio para la transferencia:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedRateType,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'parallel',
                    child: Text("Paralela / P2P (${widget.appState.parallelRate.toStringAsFixed(2)} Bs/\$)", style: const TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'bcv',
                    child: Text("BCV Oficial (${widget.appState.bcvRate.toStringAsFixed(2)} Bs/\$)", style: const TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  DropdownMenuItem(
                    value: 'euro',
                    child: Text("Euro Oficial (${widget.appState.euroRate.toStringAsFixed(2)} Bs/\$)", style: const TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                  const DropdownMenuItem(
                    value: 'custom',
                    child: Text("Personalizada", style: TextStyle(fontSize: 12, color: AppColors.cardText)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedRateType = val;
                    });
                  }
                },
              ),
              if (selectedRateType == 'custom') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: customRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "Tasa de cambio personalizada (Bs/\$)",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ],
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCrossCurrency
                          ? "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}' para cubrir el déficit usando la tasa seleccionada (${activeRate.toStringAsFixed(2)} Bs/\$)."
                          : "Se registrará una transferencia de $sourceAmtFormatted desde '${selectedSource.name}' hacia '${widget.targetAccount.name}' para cubrir el déficit.",
                      style: const TextStyle(fontSize: 11.5, color: AppColors.cardText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    "action": "transfer",
                    "source": selectedSource,
                    "sourceAmount": requiredSourceAmt,
                    "targetAmount": widget.deficit,
                    "rate": activeRate,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Transferir y Registrar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, {"action": "pay_only"}),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: AppColors.expense, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Registrar sin transferir", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Cancelar", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
