import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/timeline_event.dart';
import '../models/recurring_payment.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';

class DayActionsBottomSheet extends StatefulWidget {
  final String headerText;
  final List<TimelineEvent> dayEvents;

  const DayActionsBottomSheet({
    super.key,
    required this.headerText,
    required this.dayEvents,
  });

  @override
  State<DayActionsBottomSheet> createState() => _DayActionsBottomSheetState();
}

class _DayActionsBottomSheetState extends State<DayActionsBottomSheet> {
  late final AppState _appState;
  final Map<String, bool> _checkedEvents = {}; // Key: recurringPaymentId
  String _rateType = 'bcv'; // 'bcv', 'euro', 'custom'
  late final TextEditingController _customRateController;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _appState = Provider.of<AppState>(context);
      _customRateController = TextEditingController(
        text: _appState.bcvRate.toStringAsFixed(2),
      );

      // Initialize checkbox states for checkable events
      for (var e in widget.dayEvents) {
        if (e.recurringPaymentId != null &&
            !e.isSuggestion &&
            !e.isCompletedAbono) {
          _checkedEvents[e.recurringPaymentId!] = true;
        }
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _customRateController.dispose();
    super.dispose();
  }

  double get _activeRate {
    if (_rateType == 'bcv') {
      return _appState.bcvRate;
    } else if (_rateType == 'euro') {
      return _appState.euroRate;
    } else {
      return double.tryParse(_customRateController.text) ?? _appState.bcvRate;
    }
  }

  void _copyToClipboard(String text, String label) {
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

  @override
  Widget build(BuildContext context) {
    final activeRate = _activeRate;
    final size = MediaQuery.of(context).size;

    // Filter actual checkable occurrences in dayEvents
    final checkableEvents = widget.dayEvents.where((e) {
      return e.recurringPaymentId != null &&
          !e.isSuggestion &&
          !e.isCompletedAbono;
    }).toList();

    // Financial calculations (exclude suggestions)
    double totalIncomeUSD = 0.0;
    double totalIncomeBs = 0.0;
    double totalExpenseUSD = 0.0;
    double totalExpenseBs = 0.0;

    for (var e in widget.dayEvents) {
      if (e.isSuggestion) continue;

      double usdVal = 0.0;
      double bsVal = 0.0;

      if (e.currency == CurrencyType.usd) {
        usdVal = e.amount - e.partialAmountPaid;
        bsVal = usdVal * activeRate;
      } else {
        bsVal = e.amount - e.partialAmountPaid;
        usdVal = activeRate > 0 ? bsVal / activeRate : 0.0;
      }

      if (e.type == TransactionType.income) {
        totalIncomeUSD += usdVal;
        totalIncomeBs += bsVal;
      } else {
        totalExpenseUSD += usdVal;
        totalExpenseBs += bsVal;
      }
    }

    final double netUSD = totalIncomeUSD - totalExpenseUSD;
    final double netBs = totalIncomeBs - totalExpenseBs;
    final Color netColor = netUSD >= 0 ? AppColors.income : AppColors.expense;

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
      padding: EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Acciones del Día: ${widget.headerText}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Exchange Rate Selector
            Text(
              "TASA DE CAMBIO PARA EL DÍA",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.nestedTabTrackBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRateTab(
                      label: "BCV (${_appState.bcvRate.toStringAsFixed(2)})",
                      selected: _rateType == 'bcv',
                      onTap: () => setState(() => _rateType = 'bcv'),
                    ),
                  ),
                  Expanded(
                    child: _buildRateTab(
                      label: "Euro (${_appState.euroRate.toStringAsFixed(2)})",
                      selected: _rateType == 'euro',
                      onTap: () => setState(() => _rateType = 'euro'),
                    ),
                  ),
                  Expanded(
                    child: _buildRateTab(
                      label: "Personalizada",
                      selected: _rateType == 'custom',
                      onTap: () => setState(() => _rateType = 'custom'),
                    ),
                  ),
                ],
              ),
            ),
            if (_rateType == 'custom') ...[
              SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _customRateController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixText: "Bs. ",
                    hintText: "Ingrese tasa personalizada",
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
            SizedBox(height: 16),

            // Events List
            Text(
              "EVENTOS Y PAGOS DEL DÍA",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (widget.dayEvents.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(
                          "No hay eventos programados para este día.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.cardSubtitleText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...widget.dayEvents.map((e) {
                        final isCheckable = e.recurringPaymentId != null &&
                            !e.isSuggestion &&
                            !e.isCompletedAbono;
                        final isIncome = e.type == TransactionType.income;
                        final isUSD = e.currency == CurrencyType.usd;

                        // Find payment properties
                        RecurringPayment? payment;
                        if (e.recurringPaymentId != null) {
                          payment = _appState.recurringPayments.firstWhere(
                            (p) => p.id == e.recurringPaymentId,
                            orElse: () => RecurringPayment(
                              id: e.recurringPaymentId!,
                              name: e.title,
                              amount: e.amount,
                              currency: e.currency,
                              frequency: SubscriptionFrequency.once,
                              startDate: e.date,
                              notificationOption: NotificationOption.none,
                              type: e.type,
                              icon: 'calendar',
                              colorHex: '#1F6F5F',
                            ),
                          );
                        }

                        final iconColor = payment != null
                            ? parseHexColor(payment.colorHex)
                            : AppColors.primary;
                        final iconData = payment != null
                            ? getIconData(payment.icon)
                            : Icons.calendar_today;

                        // Calculate converted amount for display
                        double originalAmt = e.amount - e.partialAmountPaid;
                        double convertedAmt = 0.0;
                        if (isUSD) {
                          convertedAmt = originalAmt * activeRate;
                        } else {
                          convertedAmt = activeRate > 0
                              ? originalAmt / activeRate
                              : 0.0;
                        }

                        final originalFormatted = isUSD
                            ? formatUSD(originalAmt)
                            : formatBs(originalAmt);
                        final convertedFormatted = isUSD
                            ? formatBs(convertedAmt)
                            : formatUSD(convertedAmt);

                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.04),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isCheckable)
                                Checkbox(
                                  value: _checkedEvents[e.recurringPaymentId!] ??
                                      false,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _checkedEvents[e.recurringPaymentId!] =
                                          val ?? false;
                                    });
                                  },
                                ),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      e.pocketName != null
                                          ? "Bolsillo: ${e.pocketName}"
                                          : (e.accountName != null
                                              ? "Cuenta: ${e.accountName}"
                                              : (e.isSuggestion
                                                  ? "Sugerencia del simulador"
                                                  : "")),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.cardSubtitleText,
                                      ),
                                    ),
                                    if (e.isCompletedAbono) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        "Abono Parcial (Confirmado)",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () => _copyToClipboard(
                                      originalAmt.toStringAsFixed(2),
                                      "Monto Original",
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          originalFormatted,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome
                                                ? AppColors.income
                                                : AppColors.expense,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.content_copy_rounded,
                                          color: AppColors.primary,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  InkWell(
                                    onTap: () => _copyToClipboard(
                                      convertedAmt.toStringAsFixed(2),
                                      "Monto Convertido",
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          convertedFormatted,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.content_copy_rounded,
                                          color: AppColors.primary,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Summary card
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.05),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "RESUMEN ACUMULADO DEL DÍA",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Incomes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Ingresos",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                            SizedBox(height: 4),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                totalIncomeUSD.toStringAsFixed(2),
                                "Total Ingresos USD",
                              ),
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
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                totalIncomeBs.toStringAsFixed(2),
                                "Total Ingresos VES",
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatBs(totalIncomeBs),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.income,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.black.withOpacity(0.06),
                      ),
                      SizedBox(width: 12),
                      // Expenses
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Egresos",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                            SizedBox(height: 4),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                totalExpenseUSD.toStringAsFixed(2),
                                "Total Egresos USD",
                              ),
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
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                totalExpenseBs.toStringAsFixed(2),
                                "Total Egresos VES",
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatBs(totalExpenseBs),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Saldo Neto Proyectado",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: () => _copyToClipboard(
                              netUSD.toStringAsFixed(2),
                              "Neto USD",
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (netUSD >= 0 ? "+" : "") + formatUSD(netUSD),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: netColor,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.content_copy_rounded,
                                  color: AppColors.primary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _copyToClipboard(
                              netBs.toStringAsFixed(2),
                              "Neto VES",
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (netBs >= 0 ? "+" : "") + formatBs(netBs),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: netColor,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.content_copy_rounded,
                                  color: AppColors.primary,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Confirmation / Close buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cardSubtitleText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.black.withOpacity(0.08)),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Cerrar",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (checkableEvents.isNotEmpty) ...[
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Confirm and register all selected
                        final selectedEvents = checkableEvents.where((e) {
                          return _checkedEvents[e.recurringPaymentId!] ?? false;
                        }).toList();

                        if (selectedEvents.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Ningún registro seleccionado"),
                            ),
                          );
                          return;
                        }

                        // Verify destination account and if conversion rate is required
                        for (var e in selectedEvents) {
                          final payment = _appState.recurringPayments.firstWhere(
                            (p) => p.id == e.recurringPaymentId,
                          );
                          final accId = payment.accountId ??
                              (payment.currency == CurrencyType.usd
                                  ? 'default_usd'
                                  : 'default_ves');
                          final targetAccount = _appState.accounts.firstWhere(
                            (a) => a.id == accId,
                            orElse: () => _appState.accounts.first,
                          );
                          final needsConversion =
                              payment.currency == CurrencyType.usd &&
                                  targetAccount.currency == CurrencyType.bsBCV;

                          double usdVal = payment.amount;
                          double actualAmt = payment.amount;

                          if (needsConversion) {
                            usdVal = payment.amount - e.partialAmountPaid;
                            actualAmt = usdVal * activeRate;

                            await _appState.confirmRecurringPayment(
                              payment: payment,
                              actualAmount: actualAmt,
                              occurrenceDate: e.date,
                              overrideCurrency: CurrencyType.bsBCV,
                              customExchangeRate: activeRate,
                              customNote:
                                  "Confirmado: ${payment.name} (\$${usdVal.toStringAsFixed(2)} @ ${activeRate.toStringAsFixed(2)} Bs.)",
                            );
                          } else {
                            actualAmt = payment.amount - e.partialAmountPaid;
                            await _appState.confirmRecurringPayment(
                              payment: payment,
                              actualAmount: actualAmt,
                              occurrenceDate: e.date,
                            );
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${selectedEvents.length} registros agregados al historial",
                              ),
                              backgroundColor: AppColors.income,
                            ),
                          );
                        }
                      },
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.nestedTabActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: selected
                ? AppColors.nestedTabActiveText
                : AppColors.nestedTabInactiveText,
          ),
        ),
      ),
    );
  }
}
