import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../widgets/helpers.dart';
import '../models/account.dart';
import '../dialogs/calculator_dialog.dart';
import '../dialogs/transaction_detail_dialog.dart';
import 'settings_screen.dart';
import '../dialogs/pending_confirmations_dialog.dart';
import '../theme/colors.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../dialogs/book_selector_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return "HOY";
    } else if (txDate == yesterday) {
      return "AYER";
    } else {
      const months = [
        "Enero",
        "Febrero",
        "Marzo",
        "Abril",
        "Mayo",
        "Junio",
        "Julio",
        "Agosto",
        "Septiembre",
        "Octubre",
        "Noviembre",
        "Diciembre"
      ];
      return "${date.day} de ${months[date.month - 1]} de ${date.year}"
          .toUpperCase();
    }
  }

  Widget _buildDateHeader(String title, bool isFirst) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? OrtizSpace.sm : OrtizSpace.xl,
        bottom: OrtizSpace.sm,
        left: OrtizSpace.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: OrtizType.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.cardSubtitleText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    List<Transaction> transactions = _getFilteredTransactions(appState);

    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((tx) {
        final descMatches =
            tx.note.toLowerCase().contains(_searchQuery.toLowerCase());
        final category = appState.categories
            .where((c) => c.id == tx.categoryId)
            .firstOrNull;
        final catMatches = category != null &&
            category.name.toLowerCase().contains(_searchQuery.toLowerCase());
        return descMatches || catMatches;
      }).toList();
    }

    final filtered = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final listItems = [];
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
          padding: const EdgeInsets.only(right: OrtizSpace.xxxl),
          child: Image.asset(
            'assets/images/quebrado/logo_quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        leading: isDesktop
            ? Padding(
                padding: const EdgeInsets.only(left: OrtizSpace.md),
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.auto_stories_rounded, size: OrtizIconSize.sm),
                    label: Text(
                      appState.activeProfileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                    ),
                    onPressed: () {
                      showResponsiveSheet(
                        context: context,
                        builder: (context) => const BookSelectorBottomSheet(),
                      );
                    },
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () {
                  showResponsiveSheet(
                    context: context,
                    builder: (context) => const SettingsScreen(),
                  );
                },
              ),
        leadingWidth: isDesktop ? 180 : null,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                iconSize: 26,
                onPressed: () {
                  showResponsiveSheet(
                    context: context,
                    builder: (context) => const PendingConfirmationsBottomSheet(),
                  );
                },
              ),
              if (appState.pendingPaymentsToday.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Center(
                      child: Text(
                        '${appState.pendingPaymentsToday.length}',
                        style: const TextStyle(
                          color: OrtizPalette.onAccent,
                          fontSize: OrtizFontSize.micro,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: "Ajustes",
              onPressed: () {
                showResponsiveSheet(
                  context: context,
                  builder: (context) => const SettingsScreen(),
                );
              },
            ),
          const SizedBox(width: OrtizSpace.sm),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            iconSize: 26,
            onPressed: () {
              showResponsiveSheet(
                context: context,
                builder: (context) => const CalculatorBottomSheet(),
              );
            },
          ),
          const SizedBox(width: OrtizSpace.lg),
        ],
      ),
      body: Column(
        children: [
          // Filter segmented selector
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: OrtizSpace.lg,
              vertical: OrtizSpace.sm,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.mainTabTrackBg,
                borderRadius: BorderRadius.circular(OrtizRadius.field),
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
          SizedBox(height: OrtizSpace.sm),

          // Ledger transactions list
          Expanded(
            child: filtered.isEmpty
                ? const OrtizEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: "Historial vacío",
                    message: "Aún no tienes movimientos registrados en esta categoría.",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: OrtizSpace.lg,
                      right: OrtizSpace.lg,
                      top: OrtizSpace.sm,
                      // Deja libre el FAB y la barra inferior.
                      bottom: kBottomNavigationBarHeight + OrtizSize.minTouch + OrtizSpace.xxxl,
                    ),
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];
                      if (item is String) {
                        return _buildDateHeader(item, index == 0);
                      }

                      final tx = item as Transaction;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
                        child: _TransactionRow(transaction: tx),
                      ).ortizStaggered(context, index);
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
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: OrtizFontSize.bodySm,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;

  const _TransactionRow({required this.transaction});

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

    final t = OrtizTokens.of(context);
    final textColor = t.fg;
    final subtitleColor = t.muted;
    final categoryColor = category != null
        ? parseHexColor(category.colorHex)
        : (isIncome ? AppColors.income : AppColors.expense);
    final amountColor = isIncome ? t.income : t.expense;

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

    // Fila sin tarjeta: sobre el fondo, con resaltado al tocar.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
      borderRadius: BorderRadius.circular(OrtizRadius.field),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              TransactionDetailBottomSheet(transaction: transaction),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrtizSpace.xs,
          vertical: OrtizSpace.sm,
        ),
        child: Row(
          children: [
            // Category Icon (color de la categoría: dato de la persona)
            Container(
              width: OrtizSpace.xxxl + OrtizSpace.md,
              height: OrtizSpace.xxxl + OrtizSpace.md,
              decoration: BoxDecoration(
                color: displayCategoryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                displayIcon,
                color: displayCategoryColor,
                size: isExchange ? OrtizIconSize.md : OrtizIconSize.sm,
              ),
            ),
            const SizedBox(width: OrtizSpace.md),

            // Note / Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note.isEmpty ? categoryName : transaction.note,
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: OrtizSpace.xxs),
                  Row(
                    children: [
                      Text(
                        displayTimeOrDate,
                        style: TextStyle(fontSize: OrtizFontSize.caption, color: subtitleColor),
                      ),
                      if (transaction.date.isAfter(DateTime.now())) ...[
                        SizedBox(width: OrtizSpace.xs),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: t.warn.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            border: Border.all(color: t.warn.withValues(alpha: 0.3), width: OrtizStroke.hairline),
                          ),
                          child: Text(
                            "Programado",
                            style: TextStyle(
                              fontSize: OrtizFontSize.micro,
                              fontWeight: FontWeight.bold,
                              color: t.warn,
                            ),
                          ),
                        ),
                      ],
                      if (appState.partialPayments.any((p) => p.transactionId == transaction.id)) ...[
                        SizedBox(width: OrtizSpace.xs),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: t.income.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            border: Border.all(color: t.income.withValues(alpha: 0.3), width: OrtizStroke.hairline),
                          ),
                          child: Text(
                            "Abono Parcial",
                            style: TextStyle(
                              fontSize: OrtizFontSize.micro,
                              fontWeight: FontWeight.bold,
                              color: t.income,
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
                OrtizAmount(
                  value: transaction.amount,
                  currencySymbol: transaction.currency.symbol,
                  format: (_) => "$prefix$mainAmountText",
                  color: amountColor,
                  style: OrtizType.amount.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: OrtizSpace.xxs),
                Text(
                  counterpartText,
                  style: OrtizType.amount.copyWith(
                    fontSize: OrtizFontSize.caption,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
