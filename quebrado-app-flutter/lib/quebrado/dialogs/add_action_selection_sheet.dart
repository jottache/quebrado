import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import 'add_transaction_dialog.dart';
import 'add_exchange_dialog.dart';
import 'pending_confirmations_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class AddActionSelectionBottomSheet extends StatelessWidget {
  const AddActionSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.xl,
        bottom: OrtizSpace.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: OrtizSpace.xl),
          const Text(
            "Nueva Operación",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: OrtizFontSize.title,
              fontWeight: FontWeight.w900,
              color: OrtizPalette.fg,
            ),
          ),
          SizedBox(height: OrtizSpace.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(
                context,
                title: "Ingreso",
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddTransactionBottomSheet(
                      initialType: TransactionType.income,
                    ),
                  );
                },
              ),
              _buildOption(
                context,
                title: "Cambio",
                icon: Icons.currency_exchange_rounded,
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddExchangeBottomSheet(),
                  );
                },
              ),
              _buildOption(
                context,
                title: "Gasto",
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddTransactionBottomSheet(
                      initialType: TransactionType.expense,
                    ),
                  );
                },
              ),
              if (appState.pendingPaymentsToday.isNotEmpty)
                _buildOption(
                  context,
                  title: "Pendientes",
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.expense,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => PendingConfirmationsBottomSheet(),
                    );
                  },
                  badgeCount: appState.pendingPaymentsToday.length,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
        // Sin tarjeta: la opción va directa sobre la hoja (`surface`).
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xl, horizontal: OrtizSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(OrtizSpace.md),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: OrtizIconSize.lg,
                      ),
                    ),
                    if (badgeCount != null && badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: EdgeInsets.all(OrtizSpace.xs),
                          decoration: BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: OrtizPalette.onAccent,
                                fontSize: OrtizFontSize.micro,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: OrtizSpace.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
