import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/add_exchange_dialog.dart';
import '../models/currency_type.dart';
import '../models/timeline_event.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import 'currency_pill.dart';
import 'helpers.dart';
import 'timeline_event_row.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Color de los cambios de divisa sugeridos en la proyección (los propone la
/// app, como Ortiz: coral).
const Color exchangeSuggestionColor = OrtizPalette.accent;

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
          TimelineRail(color: exchangeSuggestionColor, isFirst: isFirst, isLast: isLast),
          const SizedBox(width: OrtizSpace.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
              child: GestureDetector(
                key: ValueKey('exchange_suggestion_${event.date.toIso8601String()}'),
                onTap: () => showExchangeSuggestionSheet(context, event),
                child: TimelineRowBody(
                  borderColor: exchangeSuggestionColor.withValues(alpha: 0.5),
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
                                const SizedBox(width: OrtizSpace.xs),
                                Expanded(
                                  child: Text(
                                    "Vender dólares para pagar en Bs",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: OrtizSpace.xs),
                            if (forWhat.isNotEmpty)
                              Text(
                                "Para: $forWhat",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                              ),
                            const SizedBox(height: OrtizSpace.xs),
                            Text(
                              projectedBalanceLabel(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: event.projectedLiquidBalanceUSD < 0 ? AppColors.expense : OrtizPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: OrtizSpace.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OrtizAmount(
                            value: event.amount,
                            currencySymbol: r'$',
                            format: (v) => "−${formatUSD(v)}",
                            color: exchangeSuggestionColor,
                            style: OrtizType.amount.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: OrtizSpace.xxs),
                          OrtizAmount(
                            value: bs,
                            currencySymbol: 'Bs.',
                            format: (v) => "+${formatBs(v)}",
                            color: AppColors.cardSubtitleText,
                            style: OrtizType.amount.copyWith(fontSize: OrtizFontSize.caption),
                          ),
                          const SizedBox(height: OrtizSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: exchangeSuggestionColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: const Text(
                              "Cambio sugerido",
                              style: TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.bold, color: exchangeSuggestionColor),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      padding: const EdgeInsets.all(OrtizSpace.xl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: exchangeSuggestionColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: exchangeSuggestionColor, size: OrtizIconSize.md),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Cambio sugerido · ${formatDate(event.date)}",
                    style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrtizSpace.md),
            Text(
              "Los bolívares que tendrás ese día no alcanzan para tus pagos en Bs. "
              "Vende ${formatUSD(event.amount)} y recibirás ${formatBs(bs)}.",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText, height: 1.4),
            ),
            const SizedBox(height: OrtizSpace.md),
            ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.name, style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText))),
                      Text(r.detail, style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Text(
              "Tasa usada: BCV ${rate.toStringAsFixed(2)} Bs/\$ (la de hoy; puede cambiar).",
              style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
            ),
            Text(
              "Después del cambio: ${projectedBalanceLabel(event)}",
              style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
            ),
            const SizedBox(height: OrtizSpace.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('exchange_suggestion_do'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exchangeSuggestionColor,
                  foregroundColor: OrtizPalette.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                ),
                icon: const Icon(Icons.currency_exchange_rounded, size: OrtizIconSize.sm),
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
