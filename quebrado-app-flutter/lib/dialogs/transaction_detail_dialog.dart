import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'add_transaction_dialog.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../widgets/helpers.dart';
import '../models/account.dart';

class TransactionDetailBottomSheet extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailBottomSheet({super.key, required this.transaction});

  @override
  State<TransactionDetailBottomSheet> createState() => _TransactionDetailBottomSheetState();
}

class _TransactionDetailBottomSheetState extends State<TransactionDetailBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Dynamic resolution of the active transaction state in VM
    final currentTx = appState.transactions.firstWhere(
      (t) => t.id == widget.transaction.id,
      orElse: () => widget.transaction,
    );

    final isIncome = currentTx.type == TransactionType.income;
    final prefix = isIncome ? "+" : "-";
    final amountColor = isIncome ? AppColors.income : AppColors.expense;

    // Category Resolution
    final TransactionCategory? category = currentTx.categoryId != null
        ? appState.categories.firstWhere(
            (c) => c.id == currentTx.categoryId,
            orElse: () => TransactionCategory(
              id: '',
              name: isIncome ? 'Ingreso' : 'Gasto',
              icon: 'ellipsis',
              colorHex: '#8E8E93',
              type: TransactionCategoryType.income,
            ),
          )
        : null;

    final categoryName = category?.name ?? (isIncome ? "Ingreso" : "Gasto");
    final categoryIcon = category?.icon ?? "ellipsis";
    final categoryColor = category != null
        ? parseHexColor(category.colorHex)
        : (isIncome ? AppColors.income : AppColors.expense);

    final isExchange = categoryName == "Cambio de Divisa";
    final isExchangeCompra = isExchange && (
      (currentTx.currency == CurrencyType.usd && currentTx.type == TransactionType.income) ||
      (currentTx.currency != CurrencyType.usd && currentTx.type == TransactionType.expense)
    );

    final Color exchangeColor = isExchangeCompra ? AppColors.income : AppColors.expense;
    final IconData exchangeIcon = Icons.attach_money_rounded;

    final displayCategoryName = isExchange
        ? (isExchangeCompra ? "Compra de Divisa" : "Venta de Divisa")
        : categoryName;
    final displayCategoryColor = isExchange ? exchangeColor : categoryColor;
    final displayIcon = isExchange 
        ? exchangeIcon 
        : (category != null ? getIconData(categoryIcon) : (isIncome ? Icons.arrow_upward : Icons.arrow_downward));

    // Pocket details
    String pocketName = "Balance Libre (Efectivo/Banco)";
    if (currentTx.destinationPocketId != null) {
      final pocketIndex = appState.pockets.indexWhere((p) => p.id == currentTx.destinationPocketId);
      if (pocketIndex != -1) {
        pocketName = appState.pockets[pocketIndex].name;
      }
    }

    // Amounts formatting
    final acc = appState.accounts.firstWhere(
      (a) => a.id == currentTx.accountId,
      orElse: () => appState.accounts.isNotEmpty
          ? appState.accounts.first
          : Account(id: '', name: '', balance: 0, currency: CurrencyType.usd, colorHex: '#007AFF', icon: 'creditcard'),
    );
    final isAccountVES = acc.currency == CurrencyType.bsBCV;
    final rate = currentTx.exchangeRate > 0 ? currentTx.exchangeRate : 1.0;

    final String originalStr;
    final String counterpartStr;

    if (currentTx.currency == CurrencyType.bsBCV) {
      originalStr = formatBs(currentTx.amount);
      counterpartStr = "≈ ${formatUSD(currentTx.amount / rate)}";
    } else if (isAccountVES) {
      final vesAmt = currentTx.amount * rate;
      originalStr = formatBs(vesAmt);
      if (currentTx.currency == CurrencyType.eur) {
        counterpartStr = "≈ €${currentTx.amount.toStringAsFixed(2)}";
      } else {
        counterpartStr = "≈ ${formatUSD(currentTx.amount)}";
      }
    } else {
      originalStr = formatUSD(currentTx.amount);
      final vesAmt = currentTx.amount * rate;
      counterpartStr = "≈ ${formatBs(vesAmt)}";
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row with Category tag & Edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: displayCategoryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: displayCategoryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      displayIcon,
                      color: displayCategoryColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayCategoryName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: displayCategoryColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close details sheet first
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddTransactionBottomSheet(
                      editingTransaction: currentTx,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text(
                  "Editar",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Section
          Column(
            children: [
              Text(
                "$prefix$originalStr",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Equivalente: $counterpartStr",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardSubtitleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Details List Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.cardBorderColor,
                width: AppColors.cardBorderWidth,
              ),
            ),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                _buildDetailRow(
                  title: "Tipo de Movimiento",
                  value: currentTx.type == TransactionType.income ? "Ingreso" : "Gasto",
                ),
                Divider(height: 24, color: AppColors.cardBorderColor.withOpacity(0.6)),
                _buildDetailRow(
                  title: isIncome ? "Destino" : "Origen",
                  value: pocketName,
                ),
                Divider(height: 24, color: AppColors.cardBorderColor.withOpacity(0.6)),
                _buildDetailRow(
                  title: "Fecha",
                  value: formatFullDate(currentTx.date),
                ),
                Divider(height: 24, color: AppColors.cardBorderColor.withOpacity(0.6)),
                _buildDetailRow(
                  title: "Tasa del Registro",
                  value: currentTx.currency == CurrencyType.eur
                      ? "1 EUR = Bs. ${rate.toStringAsFixed(2)}"
                      : "1 USD = Bs. ${rate.toStringAsFixed(2)}",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Concept Note Card (if any)
          if (currentTx.note.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "NOTA / CONCEPTO",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\"${currentTx.note}\"",
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.cardText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Done Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Listo",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.cardSubtitleText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.cardText,
          ),
        ),
      ],
    );
  }
}
