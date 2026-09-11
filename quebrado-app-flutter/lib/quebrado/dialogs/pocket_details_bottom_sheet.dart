import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';

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
    final themeColor = parseHexColor(widget.pocket.colorHex);
    final isLight = themeColor == Colors.white ||
        themeColor == AppColors.cardBackground ||
        HSLColor.fromColor(themeColor).lightness >= 0.75;
    final pocketAccent = parseHexColor(widget.pocket.colorHex);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12, bottom: 20),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(isLight ? 0.2 : 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getIconData(widget.pocket.icon),
                      color: isLight ? pocketAccent : Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pocket.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        Text(
                          "Detalles del bolsillo",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.cardSubtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.cardSubtitleText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onWithdraw();
                      },
                      icon: Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                      label: Text("Retirar", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAdd();
                      },
                      icon: Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      label: Text("Abonar", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Obligaciones Asociadas",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Obligations List
            if (Provider.of<AppState>(context, listen: false).recurringPayments.where((p) => p.pocketId == widget.pocket.id).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Text(
                  "No hay gastos ni ingresos recurrentes asociados a este bolsillo.",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.cardSubtitleText,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: Provider.of<AppState>(context, listen: false).recurringPayments.where((p) => p.pocketId == widget.pocket.id).length,
                  itemBuilder: (context, index) {
                    final payment = Provider.of<AppState>(context, listen: false).recurringPayments.where((p) => p.pocketId == widget.pocket.id).toList()[index];
                    final isExpense = payment.type == TransactionType.expense;
                    final payColor = isExpense ? AppColors.expense : AppColors.income;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: payColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getIconData(payment.icon),
                              color: payColor,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  payment.frequency.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.cardSubtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${isExpense ? '-' : '+'}${formatCurrency(payment.amount, payment.currency)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: payColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }
}
