import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import '../widgets/helpers.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

class PocketDetailsBottomSheet extends StatefulWidget {
  final SavingPocket pocket;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;

  const PocketDetailsBottomSheet({
    super.key,
    required this.pocket,
    required this.onAdd,
    required this.onWithdraw,
  });

  @override
  State<PocketDetailsBottomSheet> createState() => _PocketDetailsBottomSheetState();
}

class _PocketDetailsBottomSheetState extends State<PocketDetailsBottomSheet> {
  List<PendingOccurrence> _upcomingOccurrences = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateUpcomingOccurrences();
    });
  }

  void _calculateUpcomingOccurrences() {
    final appState = Provider.of<AppState>(context, listen: false);
    final pocketPayments = appState.recurringPayments.where((p) => p.pocketId == widget.pocket.id).toList();

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    List<PendingOccurrence> occurrences = [];

    for (var payment in pocketPayments) {
      DateTime current = payment.startDate.copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      int count = 0;
      int collected = 0;

      while (collected < 5) {
        count++;
        if (payment.totalInstallments != null && count > payment.totalInstallments!) {
          break;
        }

        if (current.isAfter(todayMidnight) || current.isAtSameMomentAs(todayMidnight)) {
          occurrences.add(
            PendingOccurrence(
              payment: payment,
              occurrenceDate: current,
              partialAmountPaid: 0.0,
            ),
          );
          collected++;
        }

        switch (payment.frequency) {
          case SubscriptionFrequency.weekly:
            current = current.add(Duration(days: 7));
            break;
          case SubscriptionFrequency.biweekly:
            current = current.add(Duration(days: 14));
            break;
          case SubscriptionFrequency.fifteenDays:
            if (current.day == 15) {
              current = DateTime(current.year, current.month + 1, 0);
            } else if (current.day > 15) {
              current = DateTime(current.year, current.month + 1, 15);
            } else {
              current = DateTime(current.year, current.month, 15);
            }
            break;
          case SubscriptionFrequency.monthly:
            current = DateTime(current.year, current.month + 1, current.day);
            break;
          case SubscriptionFrequency.threeMonths:
            current = DateTime(current.year, current.month + 3, current.day);
            break;
          case SubscriptionFrequency.yearly:
            current = DateTime(current.year + 1, current.month, current.day);
            break;
          case SubscriptionFrequency.custom:
            final days = payment.customDays ?? 30;
            current = current.add(Duration(days: days > 0 ? days : 30));
            break;
          case SubscriptionFrequency.once:
            collected = 5; // End loop
            break;
        }
      }
    }

    if (mounted) {
      setState(() {
        // No longer calculating upcoming occurrences, just using the list of payments
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    // El color del bolsillo es dato (lo elige la persona): marca el icono, no
    // el fondo de la hoja (spec 05, PA-02).
    final pocketColor = parseHexColor(widget.pocket.colorHex);
    final pocketPayments = Provider.of<AppState>(context, listen: false)
        .recurringPayments
        .where((p) => p.pocketId == widget.pocket.id)
        .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asa de la hoja.
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: OrtizSpace.md, bottom: OrtizSpace.xl),
                  width: OrtizSize.minTouch,
                  height: OrtizSpace.xs,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),

              // Encabezado.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                child: Row(
                  children: [
                    Container(
                      width: OrtizSize.minTouch,
                      height: OrtizSize.minTouch,
                      decoration: BoxDecoration(
                        color: OrtizPill.backgroundFor(pocketColor),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getIconData(widget.pocket.icon),
                        color: OrtizPill.foregroundFor(pocketColor, t),
                        size: OrtizIconSize.lg,
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pocket.name,
                            style: OrtizType.title.copyWith(color: t.fg),
                          ),
                          Text(
                            "Detalles del bolsillo",
                            style: OrtizType.bodySm.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: Icon(Icons.close_rounded, color: t.muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: OrtizSpace.xxl),

              // Acciones: abonar es la principal (accent); retirar, secundaria.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onWithdraw();
                        },
                        icon: const Icon(Icons.remove_rounded, size: OrtizIconSize.md),
                        label: const Text("Retirar", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.lg),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onAdd();
                        },
                        icon: const Icon(Icons.add_rounded, size: OrtizIconSize.md),
                        label: const Text("Abonar", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: OrtizSpace.xxxl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                child: Text(
                  "Obligaciones Asociadas",
                  style: OrtizType.titleSm.copyWith(color: t.fg),
                ),
              ),
              const SizedBox(height: OrtizSpace.sm),

              // Lista de obligaciones, sin tarjetas: filas sobre la hoja.
              if (pocketPayments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl, vertical: OrtizSpace.xl),
                  child: Text(
                    "No hay gastos ni ingresos recurrentes asociados a este bolsillo.",
                    style: OrtizType.body.copyWith(color: t.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    // xxl − el margen propio de la fila: el texto queda
                    // alineado con el título de la sección.
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md),
                    itemCount: pocketPayments.length,
                    itemBuilder: (context, index) {
                      final payment = pocketPayments[index];
                      final isExpense = payment.type == TransactionType.expense;
                      final payColor = isExpense ? t.expense : t.income;

                      return OrtizListRow(
                        leading: Icon(getIconData(payment.icon), color: payColor),
                        title: payment.name,
                        subtitle: payment.frequency.value,
                        trailing: OrtizAmount(
                          value: payment.amount,
                          currencySymbol: '',
                          color: payColor,
                          format: (v) =>
                              "${isExpense ? '-' : '+'}${formatCurrency(v, payment.currency)}",
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: OrtizSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
