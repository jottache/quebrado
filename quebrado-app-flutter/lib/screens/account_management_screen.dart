import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_account_dialog.dart';
import '../theme/colors.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final accounts = appState.accounts;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 0),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddAccountBottomSheet(),
              );
            },
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                "Cuentas y Bancos",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ),
            Expanded(
              child: _buildAccountList(context, appState, accounts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(
    BuildContext context,
    AppState appState,
    List<Account> accounts,
  ) {
    if (accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "Sin cuentas registradas",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Crea una nueva cuenta presionando el botón '+' en la esquina superior derecha.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final color = parseHexColor(account.colorHex);
        final isUsd = account.currency == CurrencyType.usd;
        final balanceText = isUsd ? formatUSD(account.balance) : formatBs(account.balance);

        return Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddAccountBottomSheet(editingAccount: account),
              );
            },
            child: ClaymorphicCard(
              cornerRadius: 18,
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              backgroundColor: AppColors.getAlternateCardColor(index),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getIconData(account.icon),
                      color: color,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          isUsd ? "Dólares (\$)" : "Bolívares (Bs.)",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    balanceText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
