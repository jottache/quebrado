import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/transaction_category.dart';
import '../models/recurring_payment.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/helpers.dart';
import '../models/mobile_payment_recipient.dart';
import '../services/biometric_service.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class TransferBankBottomSheet extends StatefulWidget {
  final double initialAmount;
  final CurrencyType selectedCurrency;
  final AppState appState;
  final PendingOccurrence? preselectedPendingOccurrence;
  final bool openedFromCalculator;

  const TransferBankBottomSheet({
    super.key,
    required this.initialAmount,
    required this.selectedCurrency,
    required this.appState,
    this.preselectedPendingOccurrence,
    this.openedFromCalculator = false,
  });

  @override
  State<TransferBankBottomSheet> createState() => _TransferBankBottomSheetState();
}

class _TransferBankBottomSheetState extends State<TransferBankBottomSheet> {
  final Map<String, String> _venezuelanBanks = {
    "Banesco (0134)": "0134",
    "Banco de Venezuela (0102)": "0102",
    "Mercantil (0105)": "0105",
    "Provincial (0108)": "0108",
    "BNC (0191)": "0191",
    "Bancamiga (0172)": "0172",
    "Banplus (0174)": "0174",
    "Bicentenario (0175)": "0175",
    "Banco Activo (0171)": "0171",
    "Banco Plaza (0138)": "0138",
    "Otro": "custom",
  };

  final _formKey = GlobalKey<FormState>();
  String _selectedBankName = "Banesco (0134)";
  String _selectedIdLetter = "V";
  
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _customBankCodeController = TextEditingController();

  bool _registerTransaction = true;
  TransactionType _transactionType = TransactionType.expense;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  PendingOccurrence? _selectedPendingOccurrence;

  @override
  void initState() {
    super.initState();
    // Calculate initial Bolivares amount
    final double initialBs = widget.selectedCurrency == CurrencyType.usd
        ? widget.initialAmount * widget.appState.bcvRate
        : widget.initialAmount;

    _amountController.text = initialBs > 0 ? initialBs.toStringAsFixed(2) : "";

    _selectedPendingOccurrence = widget.preselectedPendingOccurrence;

    // Autofill defaults for transaction registry
    if (widget.appState.accounts.isNotEmpty) {
      String? defaultAccountId;
      if (widget.preselectedPendingOccurrence != null) {
        final payAccountId = widget.preselectedPendingOccurrence!.payment.accountId;
        if (payAccountId != null) {
          final matchingAccounts = widget.appState.accounts.where((a) => a.id == payAccountId);
          if (matchingAccounts.isNotEmpty && matchingAccounts.first.currency == CurrencyType.bsBCV) {
            defaultAccountId = payAccountId;
          }
        }
      }
      if (defaultAccountId == null && widget.appState.accounts.isNotEmpty) {
        // Prioritize Bolivares accounts
        final vesAccount = widget.appState.accounts.firstWhere(
          (a) => a.currency == CurrencyType.bsBCV,
          orElse: () => widget.appState.accounts.first,
        );
        defaultAccountId = vesAccount.id;
      }
      _selectedAccountId = defaultAccountId;
    }

    if (widget.appState.categories.isNotEmpty) {
      _selectedCategoryId = widget.appState.categories.first.id;
    }

    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    
    if (_selectedAccountId != null && widget.appState.accounts.isNotEmpty) {
      final selectedAccount = widget.appState.accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
        orElse: () => widget.appState.accounts.first,
      );
      final isVesAccount = selectedAccount.currency == CurrencyType.bsBCV;
      
      if (_selectedPendingOccurrence != null) {
        bool stillValid = false;
        if (isVesAccount && amount > 0) {
          final bcv = widget.appState.bcvRate;
          final p = _selectedPendingOccurrence!.payment;
          if (p.type == TransactionType.expense) {
            final costVES = p.currency == CurrencyType.usd ? p.amount * bcv : p.amount;
            final isMatchingVES = (costVES - amount).abs() < 0.05;
            final isMatchingUSD = p.currency == CurrencyType.usd && bcv > 0 && (p.amount - (amount / bcv)).abs() < 0.02;
            if (isMatchingVES || isMatchingUSD) {
              stillValid = true;
            }
          }
        }
        if (widget.preselectedPendingOccurrence == null && !stillValid) {
          _selectedPendingOccurrence = null;
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _idNumberController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _customBankCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmAction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (widget.appState.useBiometrics || widget.appState.usePinSecurity) {
      final authenticated = await widget.appState.verifySecurityAuth(
        context,
        reason: "Confirma tu identidad para registrar esta transferencia",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Autenticación de seguridad requerida o cancelada."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }
    _copyAndConfirm();
  }

  void _copyAndConfirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bankCode = _selectedBankName == "Otro"
        ? _customBankCodeController.text.trim()
        : _venezuelanBanks[_selectedBankName]!;
    
    final idNumber = _idNumberController.text.trim();
    final phone = _phoneController.text.trim();
    final amountText = _amountController.text.trim();
    final double amount = double.tryParse(amountText) ?? 0.0;

    // Format:
    // BankCode
    // ID Letter + ID Number
    // Phone
    // Amount
    final String formattedText = "$bankCode\n$_selectedIdLetter$idNumber\n$phone\n${amount.toStringAsFixed(2)}";
    await Clipboard.setData(ClipboardData(text: formattedText));

    if (_registerTransaction && _selectedAccountId != null && _selectedCategoryId != null) {
      final account = widget.appState.accounts.firstWhere((a) => a.id == _selectedAccountId);
      
      // If account is USD, convert Bs to USD
      final double finalAmount = account.currency == CurrencyType.usd
          ? (widget.appState.bcvRate > 0 ? amount / widget.appState.bcvRate : 0.0)
          : amount;

      if (_selectedPendingOccurrence != null) {
        final p = _selectedPendingOccurrence!.payment;
        final double remaining = _selectedPendingOccurrence!.remainingAmount;
        if (p.currency == CurrencyType.usd) {
          await widget.appState.confirmRecurringPayment(
            payment: p,
            actualAmount: remaining * widget.appState.bcvRate,
            overrideAccountId: _selectedAccountId,
            occurrenceDate: _selectedPendingOccurrence!.occurrenceDate,
            overrideCurrency: CurrencyType.bsBCV,
            customExchangeRate: widget.appState.bcvRate,
            customNote: "Pago Móvil: ${p.name} | ${_selectedBankName == 'Otro' ? customBankCodeLabel() : _selectedBankName} | $_selectedIdLetter$idNumber",
          );
        } else {
          await widget.appState.confirmRecurringPayment(
            payment: p,
            actualAmount: remaining,
            overrideAccountId: _selectedAccountId,
            occurrenceDate: _selectedPendingOccurrence!.occurrenceDate,
            customNote: "Pago Móvil: ${p.name} | ${_selectedBankName == 'Otro' ? customBankCodeLabel() : _selectedBankName} | $_selectedIdLetter$idNumber",
          );
        }
      } else {
        final newTx = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          amount: finalAmount,
          currency: account.currency,
          categoryId: _selectedCategoryId,
          accountId: _selectedAccountId,
          note: "Pago Móvil: ${_selectedBankName == 'Otro' ? customBankCodeLabel() : _selectedBankName} | $_selectedIdLetter$idNumber",
          type: _transactionType,
          exchangeRate: widget.appState.bcvRate,
        );

        await widget.appState.addTransaction(newTx);
      }
    }

    if (mounted) {
      final category = _selectedCategoryId != null
          ? widget.appState.categories.firstWhere(
              (c) => c.id == _selectedCategoryId,
              orElse: () => widget.appState.categories.isNotEmpty
                  ? widget.appState.categories.first
                  : TransactionCategory(id: 'default', name: 'General', type: TransactionCategoryType.expense, icon: 'tag', colorHex: '#1F6F5F'),
            )
          : null;
      final account = _selectedAccountId != null
          ? widget.appState.accounts.firstWhere(
              (a) => a.id == _selectedAccountId,
              orElse: () => widget.appState.accounts.isNotEmpty
                  ? widget.appState.accounts.first
                  : Account(id: _selectedAccountId ?? 'default', name: 'Cuenta', balance: 0.0, currency: CurrencyType.bsBCV, colorHex: '#1F6F5F', icon: 'wallet'),
            )
          : null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => TransferSuccessDialog(
          bankName: _selectedBankName == "Otro" ? customBankCodeLabel() : _selectedBankName,
          idNumber: "$_selectedIdLetter$idNumber",
          phone: phone,
          amount: amount,
          registered: _registerTransaction,
          isIncome: _transactionType == TransactionType.income,
          accountName: account?.name,
          categoryName: category?.name,
          linkedPaymentName: _selectedPendingOccurrence?.payment.name,
          onClose: () {
            // Dismiss dialog
            Navigator.of(dialogCtx).pop();
            // Pop TransferBankBottomSheet
            Navigator.of(context).pop();
            if (widget.openedFromCalculator) {
              // Pop CalculatorBottomSheet
              Navigator.of(context).pop();
            }
            // Redirect to History
            widget.appState.setTabIndex(2);
          },
        ),
      );
    }
  }

  String customBankCodeLabel() {
    return "Banco (${_customBankCodeController.text.trim()})";
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final selectedAccount = widget.appState.accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => widget.appState.accounts.isNotEmpty
          ? widget.appState.accounts.first
          : Account(id: 'default_ves', name: 'Banco Bs.', balance: 0.0, currency: CurrencyType.bsBCV, colorHex: '#1F6F5F', icon: 'wallet'),
    );
    final isVesAccount = selectedAccount.currency == CurrencyType.bsBCV;
    final bcv = widget.appState.bcvRate;

    final matchingOccurrences = (isVesAccount && amount > 0)
        ? widget.appState.pendingPaymentsToday.where((occ) {
            final p = occ.payment;
            if (p.type != TransactionType.expense) return false;
            final costVES = p.currency == CurrencyType.usd ? p.amount * bcv : p.amount;
            final isMatchingVES = (costVES - amount).abs() < 0.05;
            final isMatchingUSD = p.currency == CurrencyType.usd && bcv > 0 && (p.amount - (amount / bcv)).abs() < 0.02;
            return isMatchingVES || isMatchingUSD;
          }).toList()
        : <PendingOccurrence>[];

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
        bottom: keyboardPadding + MediaQuery.of(context).padding.bottom + OrtizSpace.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top handle
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
            SizedBox(height: OrtizSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Transferir a Banco (Pago Móvil)",
                  style: const TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Campos del formulario, sin tarjeta (grupo sobre el fondo)
            Padding(
              padding: OrtizSection.gap,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DATOS DE LA TRANSFERENCIA",
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (widget.appState.recipients.isNotEmpty)
                          InkWell(
                            onTap: () => _showRecipientSelector(context),
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            child: Container(
                              padding: EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: const Icon(
                                Icons.contact_phone_rounded,
                                size: OrtizIconSize.md,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: OrtizSpace.md),

                    // Bank selector
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded, size: OrtizIconSize.md, color: AppColors.primary),
                        SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedBankName,
                            decoration: InputDecoration(
                              labelText: "Banco Destinatario",
                              border: UnderlineInputBorder(),
                            ),
                            items: _venezuelanBanks.keys.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name, style: TextStyle(fontSize: OrtizFontSize.body)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedBankName = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    if (_selectedBankName == "Otro") ...[
                      SizedBox(height: OrtizSpace.md),
                      Row(
                        children: [
                          SizedBox(width: OrtizSpace.xxxl),
                          Expanded(
                            child: TextFormField(
                              controller: _customBankCodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              decoration: InputDecoration(
                                labelText: "Código del Banco (4 dígitos)",
                                counterText: "",
                                hintText: "Ej. 0102",
                              ),
                              validator: (val) {
                                if (_selectedBankName == "Otro") {
                                  if (val == null || val.trim().isEmpty) {
                                    return "Código de banco requerido";
                                  }
                                  if (val.trim().length != 4) {
                                    return "Debe tener 4 dígitos";
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: OrtizSpace.md),

                    // ID Cédula / RIF Row (aligned center by default to fix the badge icon alignment)
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, size: OrtizIconSize.md, color: AppColors.primary),
                        SizedBox(width: OrtizSpace.md),
                        SizedBox(
                          width: 60,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedIdLetter,
                            decoration: InputDecoration(
                              labelText: "Tipo",
                              border: UnderlineInputBorder(),
                            ),
                            items: ["V", "E", "J", "G"].map((letter) {
                              return DropdownMenuItem<String>(
                                value: letter,
                                child: Text(letter),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedIdLetter = val;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: TextFormField(
                            controller: _idNumberController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Cédula / RIF Destinatario",
                              hintText: "Ej. 30945839",
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Número de identificación requerido";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: OrtizSpace.md),

                    // Phone number
                    Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded, size: OrtizIconSize.md, color: AppColors.primary),
                        SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: "Teléfono",
                              hintText: "Ej. 04128884456",
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Número de teléfono requerido";
                              }
                              if (val.trim().length < 10) {
                                return "Debe tener al menos 10 dígitos";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: OrtizSpace.md),

                                   Row(
                      children: [
                        const Icon(Icons.attach_money_rounded, size: OrtizIconSize.md, color: AppColors.primary),
                        SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            readOnly: widget.preselectedPendingOccurrence != null,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Monto en Bolívares (Bs.)",
                              hintText: "0.00 Bs.",
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Monto requerido";
                              }
                              final amt = double.tryParse(val);
                              if (amt == null || amt <= 0) {
                                return "Monto debe ser mayor a 0";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    if (widget.preselectedPendingOccurrence != null) ...[
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "VINCULADO A PAGO RECURRENTE",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      Builder(
                        builder: (context) {
                          final p = widget.preselectedPendingOccurrence!.payment;
                          final cardColor = parseHexColor(p.colorHex);
                          return Container(
                            padding: EdgeInsets.all(OrtizSpace.md),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(OrtizRadius.field),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(OrtizSpace.sm),
                                  decoration: BoxDecoration(
                                    color: cardColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getIconData(p.icon),
                                    color: cardColor,
                                    size: OrtizIconSize.sm,
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: OrtizSpace.xxs),
                                      Text(
                                        p.currency == CurrencyType.usd
                                            ? "Ref: ${formatUSD(p.amount)} (BCV)"
                                            : "Monto: ${formatBs(p.amount)}",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.caption,
                                          color: AppColors.cardSubtitleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.sm),
                                const Icon(
                                  Icons.link_rounded,
                                  color: AppColors.primary,
                                  size: OrtizIconSize.md,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    if (widget.preselectedPendingOccurrence == null && matchingOccurrences.isNotEmpty) ...[
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "VINCULAR A PAGO RECURRENTE PENDIENTE",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      ...matchingOccurrences.map((occ) {
                        final p = occ.payment;
                        final isSelected = _selectedPendingOccurrence?.payment.id == p.id;
                        final cardColor = parseHexColor(p.colorHex);
                        return Padding(
                          padding: EdgeInsets.only(bottom: OrtizSpace.sm),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPendingOccurrence = null;
                                } else {
                                  _selectedPendingOccurrence = occ;
                                  _registerTransaction = true;
                                  // Update account to match the payment's account if it is in Bolívares
                                  final payAccountId = occ.payment.accountId;
                                  if (payAccountId != null) {
                                    final matchingAccs = widget.appState.accounts.where((a) => a.id == payAccountId);
                                    if (matchingAccs.isNotEmpty && matchingAccs.first.currency == CurrencyType.bsBCV) {
                                      _selectedAccountId = payAccountId;
                                    }
                                  }
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: OrtizMotion.of(context, OrtizMotion.fast),
                              curve: OrtizMotion.ease,
                              padding: EdgeInsets.all(OrtizSpace.md),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? OrtizPalette.surfaceHigh
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : OrtizPalette.line,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(OrtizSpace.sm),
                                    decoration: BoxDecoration(
                                      color: cardColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      getIconData(p.icon),
                                      color: cardColor,
                                      size: OrtizIconSize.sm,
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.bodySm,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                            color: AppColors.cardText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: OrtizSpace.xxs),
                                        Text(
                                          p.currency == CurrencyType.usd
                                              ? "Ref: ${formatUSD(p.amount)} (BCV)"
                                              : "Monto: ${formatBs(p.amount)}",
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            color: AppColors.cardSubtitleText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: OrtizSpace.sm),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected ? AppColors.primary : OrtizPalette.muted,
                                    size: OrtizIconSize.md,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Opciones de registro, sin tarjeta
            Padding(
              padding: OrtizSection.gap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "REGISTRAR TRANSACCIÓN EN LA APP",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Switch(
                        value: _registerTransaction,
                        activeThumbColor: AppColors.primary,
                        onChanged: _selectedPendingOccurrence != null
                            ? null
                            : (val) {
                                setState(() {
                                  _registerTransaction = val;
                                  if (!val) {
                                    _selectedPendingOccurrence = null;
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                  
                  if (_registerTransaction) ...[
                    Divider(height: 20),
                    
                    if (_selectedPendingOccurrence != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.link_rounded, color: AppColors.primary, size: OrtizIconSize.md),
                          SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Text(
                              "Vinculado al pago recurrente: ${_selectedPendingOccurrence!.payment.name}",
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.md),
                    ] else ...[
                      // Transaction Type Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Tipo de Registro",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text("Gasto"),
                                selected: _transactionType == TransactionType.expense,
                                selectedColor: AppColors.expense.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.expense,
                                labelStyle: TextStyle(
                                  color: _transactionType == TransactionType.expense
                                      ? AppColors.expense
                                      : OrtizPalette.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _transactionType = TransactionType.expense;
                                    });
                                  }
                                },
                              ),
                              SizedBox(width: OrtizSpace.sm),
                              ChoiceChip(
                                label: Text("Ingreso"),
                                selected: _transactionType == TransactionType.income,
                                selectedColor: AppColors.income.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.income,
                                labelStyle: TextStyle(
                                  color: _transactionType == TransactionType.income
                                      ? AppColors.income
                                      : OrtizPalette.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _transactionType = TransactionType.income;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.md),
                    ],

                    // Account Selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAccountId,
                      decoration: InputDecoration(
                        labelText: "Cuenta a afectar",
                      ),
                      items: widget.appState.accounts.map((acc) {
                        return DropdownMenuItem<String>(
                          value: acc.id,
                          child: Text(
                            "${acc.name} (${acc.currency.symbol})",
                            style: TextStyle(fontSize: OrtizFontSize.body),
                          ),
                        );
                      }).toList(),
                      onChanged: _selectedPendingOccurrence != null
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedAccountId = val;
                                  // Check if _selectedPendingOccurrence is still valid for this new account
                                  final newAccount = widget.appState.accounts.firstWhere((a) => a.id == val);
                                  final isNewVesAccount = newAccount.currency == CurrencyType.bsBCV;
                                  if (widget.preselectedPendingOccurrence == null && !isNewVesAccount) {
                                    _selectedPendingOccurrence = null;
                                  }
                                });
                              }
                            },
                    ),
                    
                    if (_selectedPendingOccurrence == null) ...[
                      SizedBox(height: OrtizSpace.md),
                      // Category Selector
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: "Categoría",
                        ),
                        items: widget.appState.categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Text(
                              cat.name,
                              style: TextStyle(fontSize: OrtizFontSize.body),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategoryId = val;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Confirm / Copy Button
            ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _handleConfirmAction,
                    icon: const Icon(Icons.copy_all_rounded, size: OrtizIconSize.md),
                    label: Text(
                      _registerTransaction ? "Copiar Datos y Registrar" : "Copiar Datos y Cerrar",
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showRecipientSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final recipients = widget.appState.recipients;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.dialogBg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(OrtizRadius.sheet),
              topRight: Radius.circular(OrtizRadius.sheet),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              SizedBox(height: OrtizSpace.lg),
              Text(
                "Seleccionar Beneficiario",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: OrtizFontSize.titleSm,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
              SizedBox(height: OrtizSpace.lg),
              if (recipients.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.xxl),
                  child: Text(
                    "No tienes contactos guardados en la agenda de Pago Móvil.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: BouncingScrollPhysics(),
                    itemCount: recipients.length,
                    itemBuilder: (context, index) {
                      final MobilePaymentRecipient r = recipients[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: OrtizSpace.xs),
                        child: OrtizListRow(
                          leading: Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: OrtizIconSize.md,
                          ),
                          title: r.alias,
                          subtitle:
                              "${r.bankName} • ${r.identityCard} • ${r.phoneNumber}",
                          onTap: () {
                            setState(() {
                              // Autofill bank
                              String? matchedKey;
                              for (var key in _venezuelanBanks.keys) {
                                if (_venezuelanBanks[key] == r.bankCode) {
                                  matchedKey = key;
                                  break;
                                }
                              }
                              if (matchedKey != null) {
                                _selectedBankName = matchedKey;
                              } else {
                                _selectedBankName = "Otro";
                                _customBankCodeController.text = r.bankCode;
                              }

                              // Autofill id card
                              final parts = r.identityCard.split('-');
                              if (parts.length >= 2) {
                                _selectedIdLetter = parts[0];
                                _idNumberController.text = parts.sublist(1).join('-');
                              } else {
                                _idNumberController.text = r.identityCard;
                              }

                              // Autofill phone
                              _phoneController.text = r.phoneNumber;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TransferSuccessDialog extends StatelessWidget {
  final String bankName;
  final String idNumber;
  final String phone;
  final double amount;
  final bool registered;
  final bool isIncome;
  final String? accountName;
  final String? categoryName;
  final String? linkedPaymentName;
  final VoidCallback onClose;

  const TransferSuccessDialog({
    super.key,
    required this.bankName,
    required this.idNumber,
    required this.phone,
    required this.amount,
    required this.registered,
    required this.isIncome,
    this.accountName,
    this.categoryName,
    this.linkedPaymentName,
    required this.onClose,
  });

  Widget _buildDetailRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: FontWeight.bold,
            color: AppColors.cardSubtitleText,
          ),
        ),
        SizedBox(width: OrtizSpace.sm),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
      child: Padding(
        padding: EdgeInsets.all(OrtizSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(OrtizSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.income,
                  size: OrtizIconSize.xxl,
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),
            Center(
              child: Text(
                "¡Pago Móvil Copiado!",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardText,
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.xs),
            Center(
              child: Text(
                registered
                    ? "Los datos se copiaron y se registró el gasto"
                    : "Los datos se copiaron al portapapeles",
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  color: AppColors.cardSubtitleText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: OrtizSpace.xl),
            Container(
              padding: EdgeInsets.all(OrtizSpace.lg),
              decoration: BoxDecoration(
                color: OrtizPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(OrtizRadius.block),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    "Banco",
                    bankName,
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Cédula / RIF",
                    idNumber,
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Teléfono",
                    phone,
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Monto Copiado",
                    "Bs. ${amount.toStringAsFixed(2)}",
                    AppColors.primary,
                    isBold: true,
                  ),
                  if (registered) ...[
                    Divider(height: 16),
                    _buildDetailRow(
                      "Registro App",
                      linkedPaymentName != null ? "Pago: $linkedPaymentName" : "Cuenta: $accountName",
                      AppColors.cardText,
                    ),
                    if (linkedPaymentName == null) ...[
                      Divider(height: 16),
                      _buildDetailRow(
                        "Categoría",
                        categoryName ?? (isIncome ? "Ingreso" : "Gasto"),
                        AppColors.cardText,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            SizedBox(height: OrtizSpace.xxl),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: OrtizPalette.onAccent,
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
                elevation: 0,
              ),
              onPressed: onClose,
              child: Text(
                "Entendido",
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
