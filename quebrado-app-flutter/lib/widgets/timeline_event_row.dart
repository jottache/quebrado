import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/timeline_event.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import '../dialogs/transfer_bank_dialog.dart';
import '../dialogs/partial_payment_dialog.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../widgets/slide_to_confirm_button.dart';
import '../services/biometric_service.dart';

class TimelineEventRow extends StatelessWidget {
  final TimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final List<SavingPocket> virtualPockets;
  final List<RecurringPayment> virtualPayments;

  const TimelineEventRow({
    super.key,
    required this.event,
    required this.isFirst,
    required this.isLast,
    this.virtualPockets = const [],
    this.virtualPayments = const [],
  });

  Widget _buildAhorroEstiradoVisualComparison({
    required BuildContext context,
    required DateTime originalDate,
    required DateTime viableDate,
    required double originalAmount,
    required double viableAmount,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Colors.orange,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Ajuste de Viabilidad Automático",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "Tu flujo de caja mínimo proyectado no permite cumplir la meta original en la fecha planificada. Para protegerte de saldos negativos, la app extendió el plan automáticamente:",
            style: TextStyle(
              fontSize: 11,
              color: AppColors.cardSubtitleText,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Original Plan (Faded / Strikethrough)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Plan Original",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        formatDate(originalDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${formatUSD(originalAmount)} / pago",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "No es viable",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Arrow Indicator
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.orange,
                size: 16,
              ),
              SizedBox(width: 8),
              // Viable Plan (Highlighted)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Ajuste Viable",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        formatDate(viableDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${formatUSD(viableAmount)} / pago",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "¡Seguro!",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEventDetailsBottomSheet(BuildContext context, TimelineEvent event) {
    final isIncome = event.type == TransactionType.income;
    final color = event.isSuggestion
        ? Colors.blue
        : (isIncome ? AppColors.primary : AppColors.expense);

    final appState = Provider.of<AppState>(context, listen: false);

    // Combining real and virtual pockets to find the right one
    final allPockets = [...appState.pockets, ...virtualPockets];
    final pocketIndex = event.pocketName != null
        ? allPockets.indexWhere((p) => p.name == event.pocketName)
        : -1;
    final pocket = pocketIndex != -1 ? allPockets[pocketIndex] : null;

    final targetFeasible = pocket != null
        ? appState.isPocketTargetDateFeasible(
            pocket,
            virtualPockets: virtualPockets,
          )
        : true;
    final viableDate = pocket != null
        ? appState.getViableTargetDate(pocket, virtualPockets: virtualPockets)
        : null;
    final isStretched = !targetFeasible && viableDate != null;

    // Calculate original payday amount if stretched
    double? originalPaydayAmount;
    if (isStretched && pocket.targetDate != null) {
      final today = DateTime.now().copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      final targetD = pocket.targetDate!;
      final remaining = pocket.targetAmountUSD - pocket.currentAmountUSD;

      List<DateTime> originalPaydays = [];
      for (var payment in appState.recurringPayments) {
        if (payment.type == TransactionType.income) {
          DateTime current = payment.startDate;
          int count = 0;
          while (current.isBefore(targetD) ||
              current.isAtSameMomentAs(targetD)) {
            count++;
            if (payment.totalInstallments != null &&
                count > payment.totalInstallments!) {
              break;
            }
            if (current.isAfter(today) || current.isAtSameMomentAs(today)) {
              if (!originalPaydays.contains(current)) {
                originalPaydays.add(current);
              }
            }
            // Advance frequency
            switch (payment.frequency) {
              case SubscriptionFrequency.weekly:
                current = current.add(Duration(days: 7));
                break;
              case SubscriptionFrequency.biweekly:
                current = current.add(Duration(days: 14));
                break;
              case SubscriptionFrequency.fifteenDays:
                if (current.day == 15) {
                  current = DateTime(
                    current.year,
                    current.month + 1,
                    0,
                    current.hour,
                    current.minute,
                    current.second,
                  );
                } else if (current.day > 15) {
                  current = DateTime(
                    current.year,
                    current.month + 1,
                    15,
                    current.hour,
                    current.minute,
                    current.second,
                  );
                } else {
                  current = DateTime(
                    current.year,
                    current.month,
                    15,
                    current.hour,
                    current.minute,
                    current.second,
                  );
                }
                break;
              case SubscriptionFrequency.monthly:
                current = DateTime(
                  current.year,
                  current.month + 1,
                  current.day,
                );
                break;
              case SubscriptionFrequency.threeMonths:
                current = DateTime(
                  current.year,
                  current.month + 3,
                  current.day,
                );
                break;
              case SubscriptionFrequency.yearly:
                current = DateTime(
                  current.year + 1,
                  current.month,
                  current.day,
                );
                break;
              case SubscriptionFrequency.custom:
                final days = payment.customDays ?? 30;
                current = current.add(Duration(days: days > 0 ? days : 30));
                break;
              case SubscriptionFrequency.once:
                current = targetD.add(Duration(days: 1)); // stop loop
                break;
            }
          }
        }
      }
      if (originalPaydays.isNotEmpty) {
        originalPaydayAmount = remaining / originalPaydays.length;
      } else {
        originalPaydayAmount = remaining;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              event.isSuggestion
                                  ? (event.recurringPaymentId != null
                                        ? Icons.shopping_bag_rounded
                                        : Icons.savings_rounded)
                                  : (isIncome
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded),
                              color: color,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      _buildDetailRow(
                        event.isCompletedAbono ? "Fecha del Abono" : "Fecha Proyectada",
                        formatDate(event.date),
                      ),
                      if (event.isCompletedAbono) ...[
                        _buildDetailRow(
                          "Monto Abonado",
                          "${event.currency.symbol}${event.amount.toStringAsFixed(2)}",
                          valueColor: AppColors.primary,
                        ),
                      ] else if (event.partialAmountPaid > 0) ...[
                        _buildDetailRow(
                          "Monto Original",
                          "${event.currency.symbol}${(event.amount + event.partialAmountPaid).toStringAsFixed(2)}",
                        ),
                        _buildDetailRow(
                          "Abonado Parcial",
                          "${event.currency.symbol}${event.partialAmountPaid.toStringAsFixed(2)}",
                          valueColor: AppColors.primary,
                        ),
                        _buildDetailRow(
                          "Monto Restante",
                          "${event.currency.symbol}${event.amount.toStringAsFixed(2)}",
                          valueColor: color,
                        ),
                      ] else
                        _buildDetailRow(
                          "Monto",
                          event.isVariable && event.maxAmount != null
                              ? "${event.currency.symbol}${event.amount.toStringAsFixed(2)} - ${event.currency.symbol}${event.maxAmount!.toStringAsFixed(2)} (Rango Variable)"
                              : "${event.currency.symbol}${event.amount.toStringAsFixed(2)}",
                          valueColor: color,
                        ),
                      _buildDetailRow(
                        "Tipo",
                        event.isCompletedAbono
                            ? "Abono Parcial (Confirmado)"
                            : (event.isSuggestion
                                ? (event.recurringPaymentId != null
                                      ? "Cuota Cashea (Simulada)"
                                      : "Sugerencia de Ahorro")
                                : (isIncome
                                      ? "Ingreso Programado"
                                      : "Gasto/Deuda Programada")),
                      ),
                      if (event.isSuggestion && event.recurringPaymentId == null && event.suggestionReasons != null && event.suggestionReasons!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Motivo sugerido",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.cardSubtitleText,
                                ),
                              ),
                              SizedBox(height: 8),
                              ...event.suggestionReasons!.map((reason) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reason.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.cardText,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                      if (reason.detail.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: Text(
                                            reason.detail,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.cardText,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        )
                      else if (event.accountName != null)
                        _buildDetailRow(
                          event.isSuggestion
                              ? (event.recurringPaymentId != null
                                    ? "Cuenta/Motivo"
                                    : "Motivo sugerido")
                              : "Cuenta/Motivo",
                          event.accountName!,
                        ),
                      if (event.pocketName != null)
                        _buildDetailRow("Bolsillo Asociado", event.pocketName!),
                      if (event.installmentNumber != null)
                        _buildDetailRow(
                          "Cuotas",
                          "Cuota ${event.installmentNumber} de ${event.totalInstallments}",
                        ),

                      Divider(height: 24, color: Colors.black.withOpacity(0.08)),

                      _buildDetailRow(
                        "Total en tus cuentas",
                        formatUSD(event.projectedBalanceUSD),
                        isBold: true,
                      ),
                      _buildDetailRow(
                        event.projectedLiquidBalanceUSD >= 0
                            ? "Dinero disponible proyectado"
                            : "Dinero que te faltará",
                        event.projectedLiquidBalanceUSD >= 0
                            ? formatUSD(event.projectedLiquidBalanceUSD)
                            : formatUSD(-event.projectedLiquidBalanceUSD),
                        valueColor: event.projectedLiquidBalanceUSD <= 0
                            ? AppColors.expense
                            : AppColors.primary,
                        isBold: true,
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "¿Cómo entender estos montos?",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "• Total en tus cuentas: Es la suma de todo tu dinero, incluyendo lo que tienes ahorrado o apartado en tus bolsillos.\n"
                              "• ${event.projectedLiquidBalanceUSD >= 0 ? 'Dinero disponible' : 'Dinero que te faltará'}: Es el dinero real que te queda libre para gastar en el día a día (restando lo que ya apartaste en tus bolsillos para metas).",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (event.isSuggestion) ...[
                        if (isStretched)
                          _buildAhorroEstiradoVisualComparison(
                            context: context,
                            originalDate: pocket.targetDate!,
                            viableDate: viableDate,
                            originalAmount: originalPaydayAmount ?? 0.0,
                            viableAmount: event.amount,
                          )
                        else ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: event.isLastProvisioning
                                  ? Colors.blue.withOpacity(0.12)
                                  : Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: event.isLastProvisioning
                                    ? Colors.blue
                                    : Colors.blue.withOpacity(0.2),
                                width: event.isLastProvisioning ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (event.isLastProvisioning) ...[
                                  Icon(
                                    Icons.flag_rounded,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    event.isLastProvisioning
                                        ? "¡Último Apartado! Esta es la última sugerencia de ahorro necesaria para completar la meta de tu bolsillo '${event.pocketName}'. Separa este importe en esta fecha para llenarlo por completo."
                                        : "Esta es una sugerencia de ahorro automática para el bolsillo '${event.pocketName}'. Para cumplir la meta de este bolsillo a tiempo, se aconseja separar este importe en esta fecha, aprovechando el ingreso de fondos.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: event.isLastProvisioning
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: Colors.blue[800],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (event.isVariable) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.expense.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.expense,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Este ingreso es variable. Tu proyección se calcula asumiendo el peor escenario (monto mínimo de ${event.currency.symbol}${event.amount.toStringAsFixed(2)}) para evitar riesgos de deudas.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.expense,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (event.recurringPaymentId != null &&
                  !event.isSuggestion &&
                  !event.isCompletedAbono) ...[
                Builder(
                  builder: (btnCtx) {
                    final payment = appState.recurringPayments.firstWhere(
                      (p) => p.id == event.recurringPaymentId,
                    );
                    final isVesPayment = payment.currency == CurrencyType.bsBCV ||
                        (payment.accountId != null &&
                            appState.accounts.any((a) => a.id == payment.accountId && a.currency == CurrencyType.bsBCV));

                    void onTrigger() async {
                      // Calculate partial paid
                      double partialPaid = 0.0;
                      final dateStr = "${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}";
                      for (var p in appState.partialPayments) {
                        if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
                          partialPaid += p.amount;
                        }
                      }

                      if (appState.useBiometrics) {
                        final authenticated = await BiometricService.authenticate(
                          reason: isIncome
                              ? "Confirma tu identidad para marcar este cobro como recibido"
                              : "Confirma tu identidad para marcar esta deuda como pagada",
                        );
                        if (!authenticated) {
                          if (btnCtx.mounted) {
                            ScaffoldMessenger.of(btnCtx).showSnackBar(
                              SnackBar(
                                content: Text("Autenticación biométrica fallida o cancelada."),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                          return;
                        }
                      }

                      final accId = payment.accountId ?? (payment.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                      final targetAccount = appState.accounts.firstWhere((a) => a.id == accId, orElse: () => appState.accounts.first);
                      final needsConversion = payment.currency == CurrencyType.usd && targetAccount.currency == CurrencyType.bsBCV;

                      double actualAmt = payment.amount - partialPaid;
                      double change = actualAmt;
                      if (needsConversion) {
                        change = actualAmt * appState.bcvRate;
                      }
                      if (payment.type == TransactionType.expense) {
                        change = -change;
                      }

                      if (targetAccount.balance + change < 0 || isIncome) {
                        // Fallback to PendingConfirmationsBottomSheet
                        if (btnCtx.mounted) {
                          Navigator.pop(btnCtx);
                          showModalBottomSheet(
                            context: btnCtx,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetCtx) => PendingConfirmationsBottomSheet(
                              filterOccurrence: PendingOccurrence(
                                payment: payment,
                                occurrenceDate: event.date,
                                partialAmountPaid: partialPaid,
                              ),
                            ),
                          );
                        }
                      } else {
                        // Register directly!
                        bool isLast = false;
                        if (needsConversion) {
                          final double rateVal = appState.bcvRate;
                          final convertedAmt = (payment.amount - partialPaid) * rateVal;
                          isLast = await appState.confirmRecurringPayment(
                            payment: payment,
                            actualAmount: convertedAmt,
                            occurrenceDate: event.date,
                            overrideCurrency: CurrencyType.bsBCV,
                            customExchangeRate: rateVal,
                            customNote: "Confirmado: ${payment.name} (\$${(payment.amount - partialPaid).toStringAsFixed(2)} @ ${rateVal.toStringAsFixed(2)} Bs.)",
                          );
                        } else {
                          isLast = await appState.confirmRecurringPayment(
                            payment: payment,
                            actualAmount: actualAmt,
                            occurrenceDate: event.date,
                          );
                        }
                        if (btnCtx.mounted) {
                          Navigator.pop(btnCtx);
                          if (isLast) {
                            showDialog(
                              context: btnCtx,
                              builder: (ctx) => AlertDialog(
                                title: Text("Última Cuota", style: TextStyle(fontWeight: FontWeight.bold)),
                                content: Text("Has registrado la última cuota de este pago/ingreso recurrente. ¿Deseas eliminar este registro de la lista de pagos por cuotas?"),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(btnCtx).showSnackBar(
                                        SnackBar(content: Text("Registro agregado al historial.")),
                                      );
                                    },
                                    child: Text("Mantener", style: TextStyle(color: Colors.grey[700])),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      appState.deleteRecurringPayment(payment.id);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(btnCtx).showSnackBar(
                                        SnackBar(content: Text("Pago recurrente eliminado y registro agregado.")),
                                      );
                                    },
                                    child: Text("Eliminar", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(btnCtx).showSnackBar(
                              SnackBar(content: Text("Registro agregado al historial")),
                            );
                          }
                        }
                      }
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        appState.useSlideToConfirm
                            ? SlideToConfirmButton(
                                label: isIncome ? "Desliza para marcar recibido" : "Desliza para marcar pagado",
                                onConfirmed: onTrigger,
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: onTrigger,
                                  child: Text(
                                    isIncome
                                        ? "Marcar como Recibido"
                                        : "Marcar como Pagado",
                                  ),
                                ),
                              ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                              ),
                            ),
                            icon: Icon(Icons.pie_chart_outline_rounded, size: 18),
                            label: Text(isIncome ? "Registrar Cobro Parcial" : "Registrar Pago Parcial"),
                            onPressed: () {
                              // Calculate partial paid
                              double partialPaid = 0.0;
                              final dateStr = "${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}";
                              for (var p in appState.partialPayments) {
                                if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
                                  partialPaid += p.amount;
                                }
                              }

                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => PartialPaymentBottomSheet(
                                  occurrence: PendingOccurrence(
                                    payment: payment,
                                    occurrenceDate: event.date,
                                    partialAmountPaid: partialPaid,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                              ),
                            ),
                            icon: Icon(Icons.edit_rounded, size: 18),
                            label: Text("Modificar monto y saldar"),
                            onPressed: () {
                              double partialPaid = 0.0;
                              final dateStr = "${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}";
                              for (var p in appState.partialPayments) {
                                if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
                                  partialPaid += p.amount;
                                }
                              }

                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => PendingConfirmationsBottomSheet(
                                  filterOccurrence: PendingOccurrence(
                                    payment: payment,
                                    occurrenceDate: event.date,
                                    partialAmountPaid: partialPaid,
                                  ),
                                  forceShowCustomAmount: true,
                                ),
                              );
                            },
                          ),
                        ),
                        if (!isIncome && isVesPayment) ...[
                          SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(Icons.account_balance_rounded, size: 18),
                              label: Text("Transferir a Banco"),
                              onPressed: () {
                                // 1. Close details sheet
                                Navigator.pop(context);

                                // 2. Determine initial amount in VES
                                final double initialBs = payment.currency == CurrencyType.usd
                                    ? payment.amount * appState.bcvRate
                                    : payment.amount;

                                // 3. Open TransferBankBottomSheet with preselected occurrence
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => TransferBankBottomSheet(
                                    initialAmount: initialBs,
                                    selectedCurrency: CurrencyType.bsBCV,
                                    appState: appState,
                                    preselectedPendingOccurrence: PendingOccurrence(
                                      payment: payment,
                                      occurrenceDate: event.date,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                SizedBox(height: 10),
              ],
              if (event.isSuggestion &&
                  event.pocketId != null &&
                  appState.pockets.any((p) => p.id == event.pocketId)) ...[
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
                    onPressed: () async {
                      // 1. Close details sheet
                      Navigator.pop(context);

                      final pocketToDeposit = appState.pockets.firstWhere(
                        (p) => p.id == event.pocketId,
                      );
                      final amt = event.amount;

                      // 2. Perform deposit check
                      if (appState.liquidBalanceUSD < amt) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "No tienes suficiente saldo disponible líquido en USD (\$${appState.liquidBalanceUSD.toStringAsFixed(2)} de \$${amt.toStringAsFixed(2)}) para realizar este apartado.",
                              ),
                              backgroundColor: AppColors.expense,
                            ),
                          );
                        }
                        return;
                      }

                      if (event.associatedTransactionIds != null && event.associatedTransactionIds!.isNotEmpty) {
                        await appState.confirmManualSaving(
                          transactionIds: event.associatedTransactionIds!,
                          pocketId: pocketToDeposit.id,
                          amountUSD: amt,
                        );
                      } else {
                        await appState.depositToPocket(
                          id: pocketToDeposit.id,
                          amountUSD: amt,
                        );
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "¡Éxito! Reservados \$${amt.toStringAsFixed(2)} en el bolsillo '${pocketToDeposit.name}'",
                            ),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: Text("Apartar para Bolsillo Ahora"),
                  ),
                ),
                SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cardSubtitleText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.black.withOpacity(0.08)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cerrar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.cardSubtitleText,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.cardText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final allPockets = [...appState.pockets, ...virtualPockets];
    final pocketIndex = event.pocketName != null
        ? allPockets.indexWhere((p) => p.name == event.pocketName)
        : -1;
    final pocket = pocketIndex != -1 ? allPockets[pocketIndex] : null;
    final targetFeasible = pocket != null
        ? appState.isPocketTargetDateFeasible(
            pocket,
            virtualPockets: virtualPockets,
          )
        : true;
    final viableDate = pocket != null
        ? appState.getViableTargetDate(pocket, virtualPockets: virtualPockets)
        : null;
    final isStretched = !targetFeasible && viableDate != null;
    final isSimulatedSuggestion =
        (event.isSuggestion &&
            event.pocketName != null &&
            virtualPockets.any((p) => p.name == event.pocketName)) ||
        (event.isSuggestion &&
            event.recurringPaymentId != null &&
            virtualPayments.any((p) => p.id == event.recurringPaymentId));

    final isIncome = event.type == TransactionType.income;

    final now = DateTime.now();
    final isToday =
        event.date.year == now.year &&
        event.date.month == now.month &&
        event.date.day == now.day;

    bool isVesAccount = false;
    if (!event.isSuggestion) {
      if (event.accountName != null) {
        for (var acc in appState.accounts) {
          if (acc.name == event.accountName &&
              acc.currency == CurrencyType.bsBCV) {
            isVesAccount = true;
            break;
          }
        }
      }
    } else {
      isVesAccount = appState.accounts.any(
        (a) => a.currency == CurrencyType.bsBCV,
      );
    }

    final bool showVesConversion =
        isToday && event.currency == CurrencyType.usd && isVesAccount;

    final Color color = event.isSuggestion
        ? (event.recurringPaymentId != null
              ? Color.fromARGB(255, 255, 230, 7)
              : (isStretched ? Colors.orange : Colors.blue))
        : (event.isCompletedAbono
            ? AppColors.primary
            : (isIncome ? AppColors.primary : AppColors.expense));
    final String amountFormatted;
    if (event.isSuggestion) {
      amountFormatted =
          "➔ ${event.currency.symbol}${event.amount.toStringAsFixed(2)}";
    } else if (event.isVariable && event.maxAmount != null) {
      final symbol = event.currency.symbol;
      amountFormatted =
          "${isIncome ? '+' : '-'}$symbol${event.amount.toStringAsFixed(2)} - $symbol${event.maxAmount!.toStringAsFixed(2)}";
    } else {
      final symbol = event.currency.symbol;
      final baseAmt = "${isIncome ? '+' : '-'}$symbol${event.amount.toStringAsFixed(2)}";
      amountFormatted = (event.partialAmountPaid > 0 && !event.isCompletedAbono) ? "$baseAmt rest." : baseAmt;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line and dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.grey[300],
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),

          // Event Card details
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: GestureDetector(
                onTap: () => _showEventDetailsBottomSheet(context, event),
                child: ClaymorphicCard(
                  cornerRadius: 16,
                  padding: EdgeInsets.all(12.0),
                  borderColor: event.isLastProvisioning
                      ? Colors.blue
                      : (isSimulatedSuggestion
                          ? color
                          : (event.isCompletedAbono
                              ? AppColors.primary.withOpacity(0.6)
                              : (event.partialAmountPaid > 0
                                  ? AppColors.primary.withOpacity(0.4)
                                  : null))),
                  borderWidth: event.isLastProvisioning
                      ? 2.5
                      : (isSimulatedSuggestion
                          ? 2.5
                          : ((event.partialAmountPaid > 0 || event.isCompletedAbono) ? 1.5 : null)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.isCompletedAbono
                                      ? event.title
                                      : (event.partialAmountPaid > 0
                                          ? "${event.title} (Abonado)"
                                          : event.title),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (event.accountName != null &&
                                        !event.isSuggestion) ...[
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 10,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          event.accountName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (event.pocketName != null) ...[
                                      if (event.accountName != null &&
                                          !event.isSuggestion)
                                        SizedBox(width: 8),
                                      Icon(
                                        Icons.archive_rounded,
                                        size: 10,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          event.pocketName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 4),
                                // Projected balance impact
                                Text(
                                  event.isSuggestion
                                      ? "Reserva para: ${event.accountName ?? 'Gastos programados'}"
                                      : (event.projectedLiquidBalanceUSD >= 0
                                            ? "Dinero libre: ${formatUSD(event.projectedLiquidBalanceUSD)}"
                                            : "Faltante: ${formatUSD(-event.projectedLiquidBalanceUSD)}"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        !event.isSuggestion &&
                                            event.projectedLiquidBalanceUSD <= 0
                                        ? AppColors.expense
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                amountFormatted,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                              if (showVesConversion) ...[
                                SizedBox(height: 2),
                                Text(
                                  event.isVariable && event.maxAmount != null
                                      ? "≈ ${formatBs(event.amount * appState.bcvRate)} - ${formatBs(event.maxAmount! * appState.bcvRate)}"
                                      : "≈ ${formatBs(event.amount * appState.bcvRate)}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardSubtitleText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (event.isSuggestion ||
                          event.installmentNumber != null ||
                          event.isOverdue ||
                          event.partialAmountPaid > 0 ||
                          event.isCompletedAbono) ...[
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                children: [
                                  if (event.isCompletedAbono)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "Abonado el ${formatDate(event.date)}",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else if (event.partialAmountPaid > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "Abonado: ${event.currency.symbol}${event.partialAmountPaid.toStringAsFixed(2)} de ${event.currency.symbol}${(event.amount + event.partialAmountPaid).toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  if (event.isLastProvisioning)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Último Apartado",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (event.isSuggestion)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: event.recurringPaymentId != null
                                            ? Color.fromARGB(255, 255, 230, 7)
                                            : (isStretched
                                                  ? Colors.orange.withOpacity(0.15)
                                                  : Colors.blue.withOpacity(0.15)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        event.recurringPaymentId != null
                                            ? (event.totalInstallments == 1
                                                  ? "Inicial Cashea"
                                                  : "Cuota ${event.installmentNumber}/${event.totalInstallments} (Simulada)")
                                            : (isStretched
                                                  ? "Ahorro Estirado"
                                                  : "Sugerencia de Ahorro"),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: event.recurringPaymentId != null
                                              ? Colors.black87
                                              : (isStretched
                                                    ? Colors.orange[800]
                                                    : Colors.blue),
                                        ),
                                      ),
                                    ),
                                  if (!event.isSuggestion &&
                                      event.installmentNumber != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Cuota ${event.installmentNumber}/${event.totalInstallments}",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  if (event.isOverdue)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.expense.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "¡Vencido!",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.expense,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
