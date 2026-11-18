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

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xl),
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
                color: OrtizPalette.line,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
            ),
          ),
          SizedBox(height: OrtizSpace.lg),

          // Header Row with Category tag & Edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                decoration: BoxDecoration(
                  color: displayCategoryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                  border: Border.all(
                    color: displayCategoryColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      displayIcon,
                      color: displayCategoryColor,
                      size: OrtizIconSize.sm,
                    ),
                    SizedBox(width: OrtizSpace.xs),
                    Text(
                      displayCategoryName,
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                        color: displayCategoryColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
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
                icon: const Icon(Icons.edit_rounded, size: OrtizIconSize.sm),
                label: Text(
                  "Editar",
                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.xxl),

          // Amount Section
          Column(
            children: [
              Text(
                "$prefix$originalStr",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: OrtizFontSize.displayLg,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                  letterSpacing: -1.0,
                ),
              ),
              SizedBox(height: OrtizSpace.xs),
              Text(
                "Equivalente: $counterpartStr",
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardSubtitleText,
                ),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.xxl),

          // Detalles: grupo sin tarjeta, filas separadas por líneas.
          OrtizSection(
            divided: true,
            children: [
              _buildDetailRow(
                title: "Tipo de Movimiento",
                value: currentTx.type == TransactionType.income ? "Ingreso" : "Gasto",
              ),
              _buildDetailRow(
                title: isIncome ? "Destino" : "Origen",
                value: pocketName,
              ),
              _buildDetailRow(
                title: "Fecha",
                value: formatFullDate(currentTx.date),
              ),
              _buildDetailRow(
                title: "Tasa del Registro",
                value: currentTx.currency == CurrencyType.eur
                    ? "1 EUR = Bs. ${rate.toStringAsFixed(2)}"
                    : "1 USD = Bs. ${rate.toStringAsFixed(2)}",
              ),
            ],
          ),

          // Nota / concepto (si la hay)
          if (currentTx.note.isNotEmpty)
            OrtizSection(
              title: "NOTA / CONCEPTO",
              children: [
                Text(
                  "\"${currentTx.note}\"",
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.cardText,
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

          // Done Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Listo",
              style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
      child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: FontWeight.w600,
            color: AppColors.cardSubtitleText,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: FontWeight.bold,
            color: AppColors.cardText,
          ),
        ),
      ],
      ),
    );
  }
}
