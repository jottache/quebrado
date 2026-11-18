import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/timeline_event.dart';
import '../models/recurring_payment.dart';
import '../models/currency_type.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
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
            // Handle bar
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
              children: [
                Container(
                  padding: EdgeInsets.all(OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: OrtizIconSize.md,
                  ),
                ),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Acciones del Día: ${widget.headerText}",
                    style: TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Exchange Rate Selector
            Text(
              "TASA DE CAMBIO PARA EL DÍA",
              style: TextStyle(
                fontSize: OrtizFontSize.micro,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Container(
              padding: EdgeInsets.all(OrtizSpace.xxs),
              decoration: BoxDecoration(
                color: AppColors.nestedTabTrackBg,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
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
              SizedBox(height: OrtizSpace.sm),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _customRateController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: OrtizSpace.md,
                      vertical: OrtizSpace.sm,
                    ),
                    hintText: "Ingrese tasa personalizada Bs.",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      borderSide: const BorderSide(color: OrtizPalette.line),
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
            SizedBox(height: OrtizSpace.lg),

            // Events List
            Text(
              "EVENTOS Y PAGOS DEL DÍA",
              style: TextStyle(
                fontSize: OrtizFontSize.micro,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSubtitleText,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Flexible(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (widget.dayEvents.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.xl),
                        child: Text(
                          "No hay eventos programados para este día.",
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
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

                        // Fila sin tarjeta: separada por una línea `line`.
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: OrtizPalette.line),
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
                                padding: EdgeInsets.all(OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: OrtizIconSize.sm,
                                ),
                              ),
                              SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                    SizedBox(height: OrtizSpace.xxs),
                                    Text(
                                      e.pocketName != null
                                          ? "Bolsillo: ${e.pocketName}"
                                          : (e.accountName != null
                                              ? "Cuenta: ${e.accountName}"
                                              : (e.isSuggestion
                                                  ? "Sugerencia del simulador"
                                                  : "")),
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.caption,
                                        color: AppColors.cardSubtitleText,
                                      ),
                                    ),
                                    if (e.isCompletedAbono) ...[
                                      SizedBox(height: OrtizSpace.xxs),
                                      Text(
                                        "Abono Parcial (Confirmado)",
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () => _copyToClipboard(
                                      originalAmt.toStringAsFixed(2),
                                      "Monto Original",
                                    ),
                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          originalFormatted,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.body,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome
                                                ? AppColors.income
                                                : AppColors.expense,
                                          ),
                                        ),
                                        SizedBox(width: OrtizSpace.xs),
                                        const Icon(
                                          Icons.content_copy_rounded,
                                          color: AppColors.primary,
                                          size: OrtizIconSize.sm,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: OrtizSpace.xxs),
                                  InkWell(
                                    onTap: () => _copyToClipboard(
                                      convertedAmt.toStringAsFixed(2),
                                      "Monto Convertido",
                                    ),
                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          convertedFormatted,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.bodySm,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                        SizedBox(width: OrtizSpace.xs),
                                        const Icon(
                                          Icons.content_copy_rounded,
                                          color: AppColors.primary,
                                          size: OrtizIconSize.xs,
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
            SizedBox(height: OrtizSpace.lg),

            // Resumen (sin tarjeta)
            OrtizSection(
              title: "RESUMEN ACUMULADO DEL DÍA",
              children: [
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
                                fontSize: OrtizFontSize.micro,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.xs),
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
                                      fontSize: OrtizFontSize.titleSm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.income,
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.xs),
                                  const Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: OrtizIconSize.sm,
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
                                      fontSize: OrtizFontSize.body,
                                      color: AppColors.income,
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.xs),
                                  const Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: OrtizIconSize.xs,
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
                        color: OrtizPalette.line,
                      ),
                      SizedBox(width: OrtizSpace.md),
                      // Expenses
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Egresos",
                              style: TextStyle(
                                fontSize: OrtizFontSize.micro,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.xs),
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
                                      fontSize: OrtizFontSize.titleSm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.xs),
                                  const Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: OrtizIconSize.sm,
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
                                      fontSize: OrtizFontSize.body,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.xs),
                                  const Icon(
                                    Icons.content_copy_rounded,
                                    color: AppColors.primary,
                                    size: OrtizIconSize.xs,
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
                          fontSize: OrtizFontSize.caption,
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
                                    fontSize: OrtizFontSize.titleSm,
                                    fontWeight: FontWeight.bold,
                                    color: netColor,
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.xs),
                                const Icon(
                                  Icons.content_copy_rounded,
                                  color: AppColors.primary,
                                  size: OrtizIconSize.sm,
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
                                    fontSize: OrtizFontSize.body,
                                    fontWeight: FontWeight.w600,
                                    color: netColor,
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.xs),
                                const Icon(
                                  Icons.content_copy_rounded,
                                  color: AppColors.primary,
                                  size: OrtizIconSize.xs,
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

            // Confirmation / Close buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cardSubtitleText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                      ),
                      side: const BorderSide(color: OrtizPalette.line),
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    ),
                    child: Text(
                      "Cerrar",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (checkableEvents.isNotEmpty) ...[
                  SizedBox(width: OrtizSpace.md),
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

                        List<RecurringPayment> finishedPayments = [];

                        for (var e in selectedEvents) {
                          final paymentList = _appState.recurringPayments.where(
                            (p) => p.id == e.recurringPaymentId,
                          );
                          if (paymentList.isEmpty) continue;
                          final payment = paymentList.first;
                          final accId = payment.accountId ??
                              (payment.currency == CurrencyType.usd
                                  ? 'default_usd'
                                  : 'default_ves');
                          final targetAccount = _appState.accounts.firstWhere(
                            (a) => a.id == accId,
                            orElse: () => _appState.accounts.isNotEmpty
                                ? _appState.accounts.first
                                : Account(
                                    id: accId,
                                    name: 'Cuenta',
                                    currency: payment.currency,
                                    balance: 0.0,
                                    colorHex: '#1F6F5F',
                                    icon: 'wallet',
                                  ),
                          );
                          final needsConversion =
                              payment.currency == CurrencyType.usd &&
                                  targetAccount.currency == CurrencyType.bsBCV;

                          double usdVal = payment.amount;
                          double actualAmt = payment.amount;
                          bool isLast = false;

                          if (needsConversion) {
                            usdVal = payment.amount - e.partialAmountPaid;
                            actualAmt = usdVal * activeRate;

                            isLast = await _appState.confirmRecurringPayment(
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
                            isLast = await _appState.confirmRecurringPayment(
                              payment: payment,
                              actualAmount: actualAmt,
                              occurrenceDate: e.date,
                            );
                          }
                          if (isLast) finishedPayments.add(payment);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          for (var payment in finishedPayments) {
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text("Última Cuota", style: TextStyle(fontWeight: FontWeight.bold)),
                                content: Text("Has registrado la última cuota de '${payment.name}'. ¿Deseas eliminar este registro de la lista de pagos por cuotas?"),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text("Mantener", style: TextStyle(color: OrtizPalette.muted)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _appState.deleteRecurringPayment(payment.id);
                                      Navigator.pop(ctx);
                                    },
                                    child: Text("Eliminar", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }
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
                        foregroundColor: OrtizPalette.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.block),
                        ),
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      ),
                      child: Text(
                        "Registrar",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
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
        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.nestedTabActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: OrtizFontSize.caption,
            color: selected
                ? AppColors.nestedTabActiveText
                : AppColors.nestedTabInactiveText,
          ),
        ),
      ),
    );
  }
}
