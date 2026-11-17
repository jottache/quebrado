import 'package:flutter/material.dart';
import '../models/currency_type.dart';
import '../models/timeline_event.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import 'helpers.dart';

/// Colores fijos por moneda en la proyección, para reconocerlas de un vistazo.
const Color usdCurrencyColor = Color(0xFF16A34A); // verde
const Color bsCurrencyColor = Color(0xFFD97706); // ámbar
const Color eurCurrencyColor = Color(0xFF2563EB); // azul

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

  @override
  Widget build(BuildContext context) {
    Widget part(CurrencyType c) => Text(
          currencyShortLabel(c),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: currencyColor(c), height: 1.1),
        );
    final color = currencyColor(to ?? currency);
    return Container(
      key: ValueKey('currency_pill_${currency.name}${to != null ? '_${to!.name}' : ''}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          part(currency),
          if (to != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey[600]),
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
