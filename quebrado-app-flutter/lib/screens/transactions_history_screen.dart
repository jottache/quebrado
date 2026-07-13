import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../models/account.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/transaction_detail_dialog.dart';
import 'settings_screen.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import '../theme/colors.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  State<TransactionsHistoryScreen> createState() =>
      _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  List<Transaction> _getFilteredTransactions(AppState appState) {
    bool isExchange(Transaction t) {
      if (t.categoryId == null) return false;
      final idx = appState.categories.indexWhere((c) => c.id == t.categoryId);
      if (idx == -1) return false;
      return appState.categories[idx].name == "Cambio de Divisa";
    }

    final now = DateTime.now();

    switch (appState.historyFilterIndex) {
      case 1:
        return appState.transactions
            .where((t) => t.type == TransactionType.income && !isExchange(t) && !t.date.isAfter(now))
            .toList();
      case 2:
        return appState.transactions
            .where((t) => t.type == TransactionType.expense && !isExchange(t) && !t.date.isAfter(now))
            .toList();
      case 3:
        return appState.transactions.where((t) => isExchange(t)).toList();
      case 4:
        return appState.transactions.where((t) => t.date.isAfter(now)).toList();
      default:
        return appState.transactions;
    }
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return "Hoy";
    } else if (txDate == yesterday) {
      return "Ayer";
    } else {
      final daysOfWeek = [
        "Domingo",
        "Lunes",
        "Martes",
        "Miércoles",
        "Jueves",
        "Viernes",
        "Sábado",
      ];
      final dayName = daysOfWeek[date.weekday % 7];
      final dayStr = date.day.toString().padLeft(2, '0');
      final monthStr = date.month.toString().padLeft(2, '0');

      if (date.year == now.year) {
        return "$dayName $dayStr/$monthStr";
      } else {
        return "$dayName $dayStr/$monthStr/${date.year}";
      }
    }
  }

  Widget _buildDateHeader(String title, bool isFirst) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8.0 : 20.0,
        bottom: 8.0,
        left: 4.0,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.cardSubtitleText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final filtered = _getFilteredTransactions(appState);

    final List<dynamic> listItems = [];
    String? currentHeader;
    for (final tx in filtered) {
      final header = _getDateHeader(tx.date);
      if (header != currentHeader) {
        currentHeader = header;
        listItems.add(header);
      }
      listItems.add(tx);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 30.5),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.settings_rounded),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => SettingsScreen()),
            );
          },
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded),
                iconSize: 26,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        PendingConfirmationsBottomSheet(),
                  );
                },
              ),
              if (appState.pendingPaymentsToday.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Center(
                      child: Text(
                        '${appState.pendingPaymentsToday.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.calculate_outlined),
            iconSize: 26,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CalculatorBottomSheet(),
              );
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter segmented selector
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.mainTabTrackBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _FilterSegment(
                    title: "Todos",
                    isSelected: appState.historyFilterIndex == 0,
                    onTap: () => appState.setHistoryFilterIndex(0),
                  ),
                  _FilterSegment(
                    title: "Ingresos",
                    isSelected: appState.historyFilterIndex == 1,
                    onTap: () => appState.setHistoryFilterIndex(1),
                  ),
                  _FilterSegment(
                    title: "Gastos",
                    isSelected: appState.historyFilterIndex == 2,
                    onTap: () => appState.setHistoryFilterIndex(2),
                  ),
                  _FilterSegment(
                    title: "Futuras",
                    isSelected: appState.historyFilterIndex == 4,
                    onTap: () => appState.setHistoryFilterIndex(4),
                  ),
                  _FilterSegment(
                    title: "Cambios",
                    isSelected: appState.historyFilterIndex == 3,
                    onTap: () => appState.setHistoryFilterIndex(3),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),

          // Ledger transactions list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 52,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Historial vacío",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 48.0),
                          child: Text(
                            "Aún no tienes movimientos registrados en esta categoría.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 8.0,
                      bottom: 140.0,
                    ),
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];
                      if (item is String) {
                        return _buildDateHeader(item, index == 0);
                      }

                      final tx = item as Transaction;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: _TransactionRow(
                          transaction: tx,
                          backgroundColor: AppColors.getAlternateCardColor(
                            index,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterSegment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final Color? backgroundColor;

  const _TransactionRow({required this.transaction, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final isIncome = transaction.type == TransactionType.income;

    // Find category details
    final TransactionCategory? category = transaction.categoryId != null
        ? appState.categories.firstWhere(
            (c) => c.id == transaction.categoryId,
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

    final prefix = isIncome ? "+" : "-";

    // Counterpart conversion
    final rate = transaction.exchangeRate > 0 ? transaction.exchangeRate : 1.0;
    final acc = appState.accounts.firstWhere(
      (a) => a.id == transaction.accountId,
      orElse: () => appState.accounts.isNotEmpty
          ? appState.accounts.first
          : Account(id: '', name: '', balance: 0, currency: CurrencyType.usd, colorHex: '#007AFF', icon: 'creditcard'),
    );
    final isAccountVES = acc.currency == CurrencyType.bsBCV;

    final String mainAmountText;
    final String counterpartText;

    if (transaction.currency == CurrencyType.bsBCV) {
      mainAmountText = formatBs(transaction.amount);
      counterpartText = "≈ ${formatUSD(transaction.amount / rate)}";
    } else if (isAccountVES) {
      final vesAmt = transaction.amount * rate;
      mainAmountText = formatBs(vesAmt);
      if (transaction.currency == CurrencyType.eur) {
        counterpartText = "≈ €${transaction.amount.toStringAsFixed(2)}";
      } else {
        counterpartText = "≈ ${formatUSD(transaction.amount)}";
      }
    } else {
      mainAmountText = formatUSD(transaction.amount);
      final vesAmt = transaction.amount * rate;
      counterpartText = "≈ ${formatBs(vesAmt)}";
    }

    final cardBgColor = backgroundColor ?? AppColors.cardBackground;
    final isLightCard =
        cardBgColor == Colors.white ||
        cardBgColor == AppColors.cardBackground ||
        HSLColor.fromColor(cardBgColor).lightness >= 0.75;

    final textColor = isLightCard ? AppColors.cardText : Colors.white;
    final subtitleColor = isLightCard
        ? AppColors.cardSubtitleText
        : Colors.white.withOpacity(0.7);
    final categoryColor = category != null
        ? parseHexColor(category.colorHex)
        : (isIncome ? AppColors.income : AppColors.expense);
    final amountColor = isLightCard
        ? (isIncome ? AppColors.income : AppColors.expense)
        : Colors.white;

    final isExchange = categoryName == "Cambio de Divisa";
    final isExchangeCompra =
        isExchange &&
        ((transaction.currency == CurrencyType.usd &&
                transaction.type == TransactionType.income) ||
            (transaction.currency != CurrencyType.usd &&
                transaction.type == TransactionType.expense));

    final Color exchangeColor = isExchangeCompra
        ? AppColors.income
        : AppColors.expense;
    final IconData exchangeIcon = Icons.attach_money_rounded;

    final displayCategoryColor = isExchange ? exchangeColor : categoryColor;
    final displayIcon = isExchange
        ? exchangeIcon
        : (category != null
              ? getIconData(categoryIcon)
              : (isIncome ? Icons.arrow_upward : Icons.arrow_downward));

    final hour = transaction.date.hour.toString().padLeft(2, '0');
    final minute = transaction.date.minute.toString().padLeft(2, '0');
    final formattedTime = "$hour:$minute";
    final isFuture = transaction.date.isAfter(DateTime.now());
    final displayTimeOrDate = isFuture ? formatDate(transaction.date) : formattedTime;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              TransactionDetailBottomSheet(transaction: transaction),
        );
      },
      child: ClaymorphicCard(
        cornerRadius: 18,
        padding: EdgeInsets.all(14.0),
        backgroundColor: cardBgColor,
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLightCard
                    ? displayCategoryColor.withOpacity(0.12)
                    : Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                displayIcon,
                color: isLightCard ? displayCategoryColor : Colors.white,
                size: isExchange ? 20 : 18,
              ),
            ),
            SizedBox(width: 12),

            // Note / Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note.isEmpty ? categoryName : transaction.note,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        displayTimeOrDate,
                        style: TextStyle(fontSize: 11, color: subtitleColor),
                      ),
                      if (transaction.date.isAfter(DateTime.now())) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
                          ),
                          child: Text(
                            "Programado",
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                      if (appState.partialPayments.any((p) => p.transactionId == transaction.id)) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5),
                          ),
                          child: Text(
                            "Abono Parcial",
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amounts
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prefix,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                    Text(
                      mainAmountText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  counterpartText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
