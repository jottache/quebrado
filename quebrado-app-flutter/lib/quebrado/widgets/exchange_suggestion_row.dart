import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/add_exchange_dialog.dart';
import '../models/currency_type.dart';
import '../models/timeline_event.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import 'claymorphic_card.dart';
import 'currency_pill.dart';
import 'helpers.dart';

/// Color de los cambios de divisa sugeridos en la proyección.
const Color exchangeSuggestionColor = Color(0xFF7C3AED);

/// Fila de la proyección para un cambio sugerido: vender $ el día de un gasto en Bs
/// que los Bs proyectados no alcanzan a cubrir.
class ExchangeSuggestionRow extends StatelessWidget {
  final TimelineEvent event;
  final bool isFirst;
  final bool isLast;

  const ExchangeSuggestionRow({super.key, required this.event, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final reasons = event.suggestionReasons ?? const [];
    final forWhat = reasons.map((r) => r.name.replaceFirst('• ', '')).join(', ');
    final bs = event.exchangeAmountBs ?? 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : Colors.grey[300])),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: exchangeSuggestionColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: GestureDetector(
                key: ValueKey('exchange_suggestion_${event.date.toIso8601String()}'),
                onTap: () => showExchangeSuggestionSheet(context, event),
                child: ClaymorphicCard(
                  cornerRadius: 16,
                  padding: const EdgeInsets.all(12.0),
                  borderColor: exchangeSuggestionColor.withOpacity(0.5),
                  borderWidth: 1.5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CurrencyPill(CurrencyType.usd, to: CurrencyType.bsBCV),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Vender dólares para pagar en Bs",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (forWhat.isNotEmpty)
                              Text(
                                "Para: $forWhat",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              projectedBalanceLabel(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: event.projectedLiquidBalanceUSD < 0 ? AppColors.expense : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "−${formatUSD(event.amount)}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: exchangeSuggestionColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "+${formatBs(bs)}",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cardSubtitleText),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: exchangeSuggestionColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Cambio sugerido",
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: exchangeSuggestionColor),
                            ),
                          ),
                        ],
                      ),
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

/// "Dinero libre: $X · Bs Y" (o "Faltante") después de un evento de la proyección.
String projectedBalanceLabel(TimelineEvent event) {
  final usd = event.projectedLiquidBalanceUSD;
  final usdPart = usd >= 0 ? "Dinero libre: ${formatUSD(usd)}" : "Faltante: ${formatUSD(-usd)}";
  final bs = event.projectedBsBalance;
  return bs.abs() >= 0.01 ? "$usdPart · ${formatBs(bs)}" : usdPart;
}

/// Detalle del cambio sugerido, con el botón para registrarlo ya prellenado.
void showExchangeSuggestionSheet(BuildContext context, TimelineEvent event) {
  final appState = Provider.of<AppState>(context, listen: false);
  final bs = event.exchangeAmountBs ?? 0.0;
  final rate = event.exchangeRate ?? appState.bcvRate;
  final isToday = DateUtils.isSameDay(event.date, DateTime.now());
  final reasons = event.suggestionReasons ?? const [];
  final forWhat = reasons.map((r) => r.name.replaceFirst('• ', '')).join(', ');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: exchangeSuggestionColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: exchangeSuggestionColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Cambio sugerido · ${formatDate(event.date)}",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Los bolívares que tendrás ese día no alcanzan para tus pagos en Bs. "
              "Vende ${formatUSD(event.amount)} y recibirás ${formatBs(bs)}.",
              style: TextStyle(fontSize: 13, color: AppColors.cardText, height: 1.4),
            ),
            const SizedBox(height: 12),
            ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.name, style: TextStyle(fontSize: 12, color: AppColors.cardText))),
                      Text(r.detail, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Text(
              "Tasa usada: BCV ${rate.toStringAsFixed(2)} Bs/\$ (la de hoy; puede cambiar).",
              style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
            ),
            Text(
              "Después del cambio: ${projectedBalanceLabel(event)}",
              style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('exchange_suggestion_do'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exchangeSuggestionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                label: Text(isToday ? "Hacer cambio ahora" : "Hacer cambio (adelantado)"),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddExchangeBottomSheet(
                      initialUsdAccountId: event.exchangeSourceAccountId,
                      initialVesAccountId: event.exchangeTargetAccountId,
                      initialAmountUSD: event.amount,
                      initialRate: rate,
                      initialNote: forWhat.isEmpty ? "Cambio para pagos en Bs" : "Cambio para: $forWhat",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
