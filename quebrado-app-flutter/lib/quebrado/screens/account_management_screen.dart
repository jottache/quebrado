import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_account_dialog.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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
        title: Image.asset(
          'assets/images/quebrado/logo_quebrado.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: "Nueva cuenta",
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: OrtizIconSize.lg,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.sm),
              child: Text(
                "Cuentas y Bancos",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
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
      return const OrtizEmptyState(
        icon: Icons.account_balance_wallet_rounded,
        title: "Sin cuentas registradas",
        message: "Crea una nueva cuenta presionando el botón '+' en la esquina superior derecha.",
      );
    }

    // Lista sin tarjetas: filas sobre el fondo separadas por líneas.
    return ListView.separated(
      padding: const EdgeInsets.all(OrtizSpace.lg),
      itemCount: accounts.length,
      separatorBuilder: (context, index) => const Divider(height: OrtizStroke.hairline),
      itemBuilder: (context, index) {
        final account = accounts[index];
        final color = parseHexColor(account.colorHex);
        final isUsd = account.currency == CurrencyType.usd;
        final balanceText = isUsd ? formatUSD(account.balance) : formatBs(account.balance);

        return OrtizListRow(
          leading: Icon(getIconData(account.icon), color: color),
          title: account.name,
          subtitle: isUsd ? "Dólares (\$)" : "Bolívares (Bs.)",
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                balanceText,
                style: OrtizType.amount.copyWith(color: color),
              ),
              const SizedBox(width: OrtizSpace.sm),
              const Icon(Icons.chevron_right_rounded, color: AppColors.cardSubtitleText),
            ],
          ),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddAccountBottomSheet(editingAccount: account),
            );
          },
        );
      },
    );
  }
}
