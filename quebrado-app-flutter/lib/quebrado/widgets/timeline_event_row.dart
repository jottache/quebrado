import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/timeline_event.dart';
import '../models/currency_type.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import 'currency_pill.dart';
import 'exchange_suggestion_row.dart';
import '../widgets/helpers.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import '../dialogs/transfer_bank_dialog.dart';
import '../dialogs/partial_payment_dialog.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../services/biometric_service.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

/// Sugerencias de ahorro de la proyección (las propone la app, como Ortiz).
const Color _suggestionColor = OrtizPalette.accent;

/// Ahorro estirado, cuotas y ajustes de viabilidad.
const Color _warnColor = OrtizPalette.warn;

/// Cuotas simuladas de Cashea: el amarillo de su marca (relleno claro, así
/// que el texto encima va en `onAccent`).
const Color _casheaColor = AppColors.casheaBrand;

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
      margin: EdgeInsets.only(top: OrtizSpace.lg),
      padding: EdgeInsets.all(OrtizSpace.lg),
      decoration: BoxDecoration(
        color: _warnColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: Border.all(color: _warnColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: _warnColor,
                size: OrtizIconSize.sm,
              ),
              SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  "Ajuste de Viabilidad Automático",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: _warnColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.md),
          Text(
            "Tu flujo de caja mínimo proyectado no permite cumplir la meta original en la fecha planificada. Para protegerte de saldos negativos, la app extendió el plan automáticamente:",
            style: TextStyle(
              fontSize: OrtizFontSize.caption,
              color: AppColors.cardSubtitleText,
              height: 1.4,
            ),
          ),
          SizedBox(height: OrtizSpace.lg),
          Row(
            children: [
              // Original Plan (Faded / Strikethrough)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(OrtizSpace.md),
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    border: Border.all(color: OrtizPalette.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: OrtizIconSize.xs,
                            color: OrtizPalette.muted,
                          ),
                          SizedBox(width: OrtizSpace.xs),
                          Text(
                            "Plan Original",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                              color: OrtizPalette.muted,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      Text(
                        formatDate(originalDate),
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.bold,
                          color: OrtizPalette.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "${formatUSD(originalAmount)} / pago",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: OrtizPalette.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "No es viable",
                        style: TextStyle(
                          fontSize: OrtizFontSize.micro,
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: OrtizSpace.sm),
              // Arrow Indicator
              Icon(
                Icons.arrow_forward_rounded,
                color: _warnColor,
                size: OrtizIconSize.sm,
              ),
              SizedBox(width: OrtizSpace.sm),
              // Viable Plan (Highlighted)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(OrtizSpace.md),
                  decoration: BoxDecoration(
                    color: _warnColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    border: Border.all(color: _warnColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: OrtizIconSize.xs,
                            color: _warnColor,
                          ),
                          SizedBox(width: OrtizSpace.xs),
                          Text(
                            "Ajuste Viable",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                              color: _warnColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      Text(
                        formatDate(viableDate),
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.bold,
                          color: _warnColor,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "${formatUSD(viableAmount)} / pago",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: _warnColor,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "¡Seguro!",
                        style: TextStyle(
                          fontSize: OrtizFontSize.micro,
                          fontWeight: FontWeight.bold,
                          color: _warnColor,
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
        ? _suggestionColor
        : (isIncome ? AppColors.income : AppColors.expense);

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
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.sm),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
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
                              size: OrtizIconSize.md,
                            ),
                          ),
                          SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: OrtizFontSize.titleSm,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.xl),

                      _buildDetailRow(
                        event.isCompletedAbono ? "Fecha del Abono" : "Fecha Proyectada",
                        formatDate(event.date),
                      ),
                      if (event.isCompletedAbono) ...[
                        _buildDetailRow(
                          "Monto Abonado",
                          "${event.currency.symbol}${event.amount.toStringAsFixed(2)}",
                          valueColor: AppColors.income,
                        ),
                      ] else if (event.partialAmountPaid > 0) ...[
                        _buildDetailRow(
                          "Monto Original",
                          "${event.currency.symbol}${(event.amount + event.partialAmountPaid).toStringAsFixed(2)}",
                        ),
                        _buildDetailRow(
                          "Abonado Parcial",
                          "${event.currency.symbol}${event.partialAmountPaid.toStringAsFixed(2)}",
                          valueColor: AppColors.income,
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
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Motivo sugerido",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  color: AppColors.cardSubtitleText,
                                ),
                              ),
                              SizedBox(height: OrtizSpace.sm),
                              ...event.suggestionReasons!.map((reason) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reason.name,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.bodySm,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.cardText,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                      if (reason.detail.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: OrtizSpace.sm),
                                          child: Text(
                                            reason.detail,
                                            style: TextStyle(
                                              fontSize: OrtizFontSize.bodySm,
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

                      if (!event.isSuggestion)
                        Builder(builder: (_) {
                          final paid = paidCurrencyOf(event);
                          final texts = projectionAmountTexts(event, appState);
                          final paidName = paid == CurrencyType.usd ? "Dólares" : (paid == CurrencyType.eur ? "Euros" : "Bolívares");
                          return Padding(
                            padding: EdgeInsets.only(top: OrtizSpace.sm),
                            child: Row(
                              children: [
                                Text("Se paga en", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText)),
                                Spacer(),
                                CurrencyPill(paid),
                                SizedBox(width: OrtizSpace.xs),
                                Flexible(
                                  child: Text(
                                    texts.secondary == null ? paidName : "$paidName (${texts.secondary})",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      Divider(height: 24, color: OrtizPalette.line),

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
                            : AppColors.income,
                        isBold: true,
                      ),
                      if (appState.accounts.any((a) => a.currency == CurrencyType.bsBCV))
                        _buildDetailRow(
                          "Bolívares proyectados",
                          formatBs(event.projectedBsBalance),
                          isBold: true,
                        ),
                      SizedBox(height: OrtizSpace.lg),
                      Container(
                        padding: EdgeInsets.all(OrtizSpace.md),
                        decoration: BoxDecoration(
                          color: OrtizPalette.surfaceHigh,
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                          border: Border.all(color: OrtizPalette.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: OrtizIconSize.xs,
                                  color: OrtizPalette.muted,
                                ),
                                SizedBox(width: OrtizSpace.xs),
                                Text(
                                  "¿Cómo entender estos montos?",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
                                    fontWeight: FontWeight.bold,
                                    color: OrtizPalette.fg,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.sm),
                            Text(
                              "• Total en tus cuentas: Es la suma de todo tu dinero, incluyendo lo que tienes ahorrado o apartado en tus bolsillos.\n"
                              "• ${event.projectedLiquidBalanceUSD >= 0 ? 'Dinero disponible' : 'Dinero que te faltará'}: Es el dinero real que te queda libre para gastar en el día a día (restando lo que ya apartaste en tus bolsillos para metas).",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                color: OrtizPalette.muted,
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
                          SizedBox(height: OrtizSpace.lg),
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.sm),
                            decoration: BoxDecoration(
                              color: event.isLastProvisioning
                                  ? _suggestionColor.withValues(alpha: 0.12)
                                  : _suggestionColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              border: Border.all(
                                color: event.isLastProvisioning
                                    ? _suggestionColor
                                    : _suggestionColor.withValues(alpha: 0.2),
                                width: event.isLastProvisioning ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (event.isLastProvisioning) ...[
                                  Icon(
                                    Icons.flag_rounded,
                                    color: _suggestionColor,
                                    size: OrtizIconSize.sm,
                                  ),
                                  SizedBox(width: OrtizSpace.xs),
                                ],
                                Expanded(
                                  child: Text(
                                    event.isLastProvisioning
                                        ? "¡Último Apartado! Esta es la última sugerencia de ahorro necesaria para completar la meta de tu bolsillo '${event.pocketName}'. Separa este importe en esta fecha para llenarlo por completo."
                                        : "Esta es una sugerencia de ahorro automática para el bolsillo '${event.pocketName}'. Para cumplir la meta de este bolsillo a tiempo, se aconseja separar este importe en esta fecha, aprovechando el ingreso de fondos.",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.caption,
                                      fontWeight: event.isLastProvisioning
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _suggestionColor,
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
                        SizedBox(height: OrtizSpace.lg),
                        Container(
                          padding: EdgeInsets.all(OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            border: Border.all(
                              color: AppColors.expense.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.expense,
                                size: OrtizIconSize.sm,
                              ),
                              SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Text(
                                  "Este ingreso es variable. Tu proyección se calcula asumiendo el peor escenario (monto mínimo de ${event.currency.symbol}${event.amount.toStringAsFixed(2)}) para evitar riesgos de deudas.",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
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
              SizedBox(height: OrtizSpace.lg),
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

                      final authenticated = await appState.verifySecurityAuth(
                        btnCtx,
                        reason: isIncome
                            ? "Confirma tu identidad para marcar este cobro como recibido"
                            : "Confirma tu identidad para marcar esta deuda como pagada",
                      );
                      if (!authenticated) {
                        return;
                      }

                      final accId = payment.accountId ?? (payment.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
                      final targetAccount = appState.accounts.firstWhere(
                        (a) => a.id == accId,
                        orElse: () => appState.accounts.isNotEmpty
                            ? appState.accounts.first
                            : Account(
                                id: accId,
                                name: 'Cuenta',
                                currency: payment.currency,
                                balance: 0.0,
                                colorHex: '#1F6F5F',
                                icon: 'wallet',
                              ),
                      );
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(btnCtx).showSnackBar(
                                        SnackBar(content: Text("Registro agregado al historial.")),
                                      );
                                    },
                                    child: Text("Mantener", style: TextStyle(color: OrtizPalette.muted)),
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
                        SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: OrtizPalette.onAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(OrtizRadius.field),
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
                        SizedBox(height: OrtizSpace.sm),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                            ),
                            icon: Icon(Icons.pie_chart_outline_rounded, size: OrtizIconSize.sm),
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
                        SizedBox(height: OrtizSpace.sm),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                            ),
                            icon: Icon(Icons.edit_rounded, size: OrtizIconSize.sm),
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
                          SizedBox(height: OrtizSpace.sm),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: OrtizPalette.onAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                ),
                              ),
                              icon: Icon(Icons.account_balance_rounded, size: OrtizIconSize.sm),
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
                SizedBox(height: OrtizSpace.sm),
              ],
              if (event.isSuggestion &&
                  event.pocketId != null &&
                  appState.pockets.any((p) => p.id == event.pocketId)) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                    ),
                    onPressed: () async {
                      // 1. Close details sheet
                      Navigator.pop(context);

                      final pocketToDeposit = appState.pockets.firstWhere(
                        (p) => p.id == event.pocketId,
                      );
                      final amt = event.amountUSD ?? event.amount;

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

                      // Abona y marca la sugerencia de ese día como cumplida (no reaparece)
                      final ok = await appState.fulfillPocketSuggestion(
                        date: event.date,
                        pocketId: pocketToDeposit.id,
                        amountUSD: amt,
                        associatedTransactionIds: event.associatedTransactionIds,
                      );
                      if (!ok) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("No se pudo realizar el apartado. Revisa tu saldo líquido e inténtalo de nuevo."),
                              backgroundColor: AppColors.expense,
                            ),
                          );
                        }
                        return;
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
                SizedBox(height: OrtizSpace.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cardSubtitleText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    side: BorderSide(color: OrtizPalette.line),
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
      padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              color: AppColors.cardSubtitleText,
            ),
          ),
          SizedBox(width: OrtizSpace.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
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
    if (event.isExchangeSuggestion) {
      return ExchangeSuggestionRow(event: event, isFirst: isFirst, isLast: isLast);
    }
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

    final Color color = event.isSuggestion
        ? (event.recurringPaymentId != null
              ? _casheaColor
              : (isStretched ? _warnColor : _suggestionColor))
        : (event.isCompletedAbono
            ? AppColors.income
            : (isIncome ? AppColors.income : AppColors.expense));

    // Monto en la moneda con la que se paga (p. ej. "−Bs. 15000.00") y a qué está anclado
    final String amountFormatted;
    String? secondaryAmount;
    if (event.isSuggestion) {
      amountFormatted =
          "➔ ${event.currency.symbol}${event.amount.toStringAsFixed(2)}";
    } else {
      final texts = projectionAmountTexts(event, appState);
      amountFormatted = texts.primary;
      secondaryAmount = texts.secondary;
    }
    final bool showVesConversion = secondaryAmount != null;
    final paidCurrency = paidCurrencyOf(event);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line and dot
          TimelineRail(color: color, isFirst: isFirst, isLast: isLast),
          const SizedBox(width: OrtizSpace.sm),

          // Event Card details
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
              child: GestureDetector(
                onTap: () => _showEventDetailsBottomSheet(context, event),
                child: TimelineRowBody(
                  borderColor: event.isLastProvisioning
                      ? _suggestionColor
                      : (isSimulatedSuggestion
                          ? color
                          : (event.isCompletedAbono
                              ? AppColors.income.withValues(alpha: 0.6)
                              : (event.partialAmountPaid > 0
                                  ? AppColors.income.withValues(alpha: 0.4)
                                  : null))),
                  emphasized: event.isLastProvisioning || isSimulatedSuggestion,
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: OrtizSpace.xxs, right: OrtizSpace.xs),
                                      child: CurrencyPill(paidCurrency),
                                    ),
                                    Expanded(
                                      child: Text(
                                        event.isCompletedAbono
                                            ? event.title
                                            : (event.partialAmountPaid > 0
                                                ? "${event.title} (Abonado)"
                                                : event.title),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: OrtizSpace.xs),
                                Row(
                                  children: [
                                    if (event.accountName != null &&
                                        !event.isSuggestion) ...[
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: OrtizIconSize.xs,
                                        color: OrtizPalette.muted,
                                      ),
                                      SizedBox(width: OrtizSpace.xxs),
                                      Flexible(
                                        child: Text(
                                          event.accountName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            color: OrtizPalette.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (event.pocketName != null) ...[
                                      if (event.accountName != null &&
                                          !event.isSuggestion)
                                        SizedBox(width: OrtizSpace.sm),
                                      Icon(
                                        Icons.archive_rounded,
                                        size: OrtizIconSize.xs,
                                        color: OrtizPalette.muted,
                                      ),
                                      SizedBox(width: OrtizSpace.xxs),
                                      Flexible(
                                        child: Text(
                                          event.pocketName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            color: OrtizPalette.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: OrtizSpace.xs),
                                // Projected balance impact
                                Text(
                                  event.isSuggestion
                                      ? "Reserva para: ${event.accountName ?? 'Gastos programados'}"
                                      : projectedBalanceLabel(event),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        !event.isSuggestion &&
                                            event.projectedLiquidBalanceUSD <= 0
                                        ? AppColors.expense
                                        : OrtizPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: OrtizSpace.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                amountFormatted,
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                              if (showVesConversion) ...[
                                SizedBox(height: OrtizSpace.xxs),
                                Text(
                                  secondaryAmount!,
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
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
                        SizedBox(height: OrtizSpace.xs),
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
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.income.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        border: Border.all(
                                          color: AppColors.income.withValues(alpha: 0.3),
                                          width: OrtizStroke.hairline,
                                        ),
                                      ),
                                      child: Text(
                                        "Abonado el ${formatDate(event.date)}",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    )
                                  else if (event.partialAmountPaid > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.income.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        border: Border.all(
                                          color: AppColors.income.withValues(alpha: 0.3),
                                          width: OrtizStroke.hairline,
                                        ),
                                      ),
                                      child: Text(
                                        "Abonado: ${event.currency.symbol}${event.partialAmountPaid.toStringAsFixed(2)} de ${event.currency.symbol}${(event.amount + event.partialAmountPaid).toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ),
                                  if (event.isLastProvisioning)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _suggestionColor,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      child: Text(
                                        "Último Apartado",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.bold,
                                          color: OrtizPalette.onAccent,
                                        ),
                                      ),
                                    ),
                                  if (event.isSuggestion)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: event.recurringPaymentId != null
                                            ? _casheaColor
                                            : (isStretched
                                                  ? _warnColor.withValues(alpha: 0.15)
                                                  : _suggestionColor.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
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
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.bold,
                                          color: event.recurringPaymentId != null
                                              ? OrtizPalette.onAccent
                                              : (isStretched
                                                    ? _warnColor
                                                    : _suggestionColor),
                                        ),
                                      ),
                                    ),
                                  if (!event.isSuggestion &&
                                      event.installmentNumber != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _warnColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      child: Text(
                                        "Cuota ${event.installmentNumber}/${event.totalInstallments}",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
                                          fontWeight: FontWeight.bold,
                                          color: _warnColor,
                                        ),
                                      ),
                                    ),
                                  if (event.isOverdue)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: OrtizSpace.xs,
                                        vertical: OrtizSpace.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.expense.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      child: Text(
                                        "¡Vencido!",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.micro,
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

/// Riel del timeline: línea vertical (color `line`) con el punto del evento.
class TimelineRail extends StatelessWidget {
  const TimelineRail({
    super.key,
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;

  /// Ancho del riel (alinea las filas del timeline y las sugerencias).
  static const double width = OrtizSpace.xxxl + OrtizSpace.sm;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: OrtizStroke.focus,
              color: isFirst ? Colors.transparent : t.line,
            ),
          ),
          Container(
            width: OrtizIconSize.xs,
            height: OrtizIconSize.xs,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: t.bg, width: OrtizStroke.focus),
            ),
          ),
          Expanded(
            child: Container(
              width: OrtizStroke.focus,
              color: isLast ? Colors.transparent : t.line,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuerpo de una fila del timeline, sin tarjeta: el contenido va sobre el
/// fondo. Solo lleva un borde (sin relleno ni sombra) cuando el evento lo
/// pide; [emphasized] lo engrosa (sugerencia simulada, último apartado).
class TimelineRowBody extends StatelessWidget {
  const TimelineRowBody({
    super.key,
    required this.child,
    this.borderColor,
    this.emphasized = false,
  });

  final Widget child;
  final Color? borderColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: border == null
            ? null
            : Border.all(
                color: border,
                width: emphasized ? OrtizStroke.focus : OrtizStroke.hairline,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrtizSpace.md),
        child: child,
      ),
    );
  }
}
