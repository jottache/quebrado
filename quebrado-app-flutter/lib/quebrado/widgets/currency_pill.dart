import 'package:flutter/material.dart';
import '../models/currency_type.dart';
import '../models/timeline_event.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import 'helpers.dart';

import 'package:quebrado_app_flutter/theme/colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Colores fijos por moneda en la proyección, para reconocerlas de un vistazo.
/// Viven en `AppColors` (calibrados para el tema oscuro, P-39).
const Color usdCurrencyColor = AppColors.currencyUsd; // verde
const Color bsCurrencyColor = AppColors.currencyBs; // ámbar
const Color eurCurrencyColor = AppColors.currencyEur; // azul

Color currencyColor(CurrencyType currency) {
  switch (currency) {
    case CurrencyType.usd:
      return usdCurrencyColor;
    case CurrencyType.bsBCV:
      return bsCurrencyColor;
    case CurrencyType.eur:
      return eurCurrencyColor;
  }
}

String currencyShortLabel(CurrencyType currency) {
  switch (currency) {
    case CurrencyType.usd:
      return "\$";
    case CurrencyType.bsBCV:
      return "Bs";
    case CurrencyType.eur:
      return "€";
  }
}

/// Etiqueta pequeña con la moneda en que se paga o cobra ("Bs", "$", "€").
/// Para los cambios de divisa se pasa [to] y muestra "$ → Bs".
class CurrencyPill extends StatelessWidget {
  final CurrencyType currency;
  final CurrencyType? to;

  const CurrencyPill(this.currency, {super.key, this.to});

  /// Opacidad del borde: la de los `xxxBorder` de la suite.
  static const double _borderOpacity = SuiteAppColors.borderAlpha / 255;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    Widget part(CurrencyType c) => Text(
          currencyShortLabel(c),
          style: OrtizType.caption.copyWith(
            fontWeight: FontWeight.w900,
            color: currencyColor(c),
            height: 1.1,
          ),
        );
    final color = currencyColor(to ?? currency);
    return Container(
      key: ValueKey('currency_pill_${currency.name}${to != null ? '_${to!.name}' : ''}'),
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(
        color: OrtizPill.backgroundFor(color),
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: Border.all(color: color.withValues(alpha: _borderOpacity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          part(currency),
          if (to != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
              child: Icon(Icons.arrow_forward_rounded, size: OrtizIconSize.xs, color: t.muted),
            ),
            part(to!),
          ],
        ],
      ),
    );
  }
}

/// Moneda en la que se mueve el dinero de un evento de la proyección.
CurrencyType paidCurrencyOf(TimelineEvent event) => event.paidInCurrency ?? event.currency;

/// Monto principal (en la moneda que se paga) y la línea secundaria (a qué está anclado).
/// Un pago "USD a tasa BCV" desde una cuenta en Bs se ve como "−Bs. 15000.00" y
/// "anclado a $150.00 · tasa BCV".
({String primary, String? secondary}) projectionAmountTexts(TimelineEvent event, AppState appState) {
  final isIncome = event.type == TransactionType.income;
  final sign = isIncome ? '+' : '-';
  final paidIn = paidCurrencyOf(event);
  final restSuffix = (event.partialAmountPaid > 0 && !event.isCompletedAbono) ? " rest." : "";

  double inPaidCurrency(double amount) {
    if (event.currency == paidIn) return amount;
    return appState.convert(amountUSD: appState.convertToUSD(amount: amount, from: event.currency), to: paidIn);
  }

  final hasRange = event.isVariable && event.maxAmount != null;
  String fmt(double v) => formatCurrency(v, paidIn);
  final primary = hasRange
      ? "$sign${fmt(inPaidCurrency(event.amount))} - ${fmt(inPaidCurrency(event.maxAmount!))}"
      : "$sign${fmt(inPaidCurrency(event.amount))}$restSuffix";

  String? secondary;
  if (paidIn != event.currency) {
    // Monto anclado a otra moneda (lo normal en Venezuela: Bs a tasa BCV)
    final anchor = hasRange
        ? "${formatCurrency(event.amount, event.currency)} - ${formatCurrency(event.maxAmount!, event.currency)}"
        : formatCurrency(event.amount, event.currency);
    secondary = "anclado a $anchor · tasa BCV";
  } else if (paidIn != CurrencyType.usd) {
    secondary = "≈ ${formatUSD(event.amountUSD ?? appState.convertToUSD(amount: event.amount, from: event.currency))}";
  }
  return (primary: primary, secondary: secondary);
}
