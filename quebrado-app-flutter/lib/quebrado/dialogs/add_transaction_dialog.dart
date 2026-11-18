import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../models/account.dart';
import '../widgets/helpers.dart';
import '../screens/mobile_payment_recipient_screen.dart' show venezuelanBanks;
import '../services/biometric_service.dart';
import '../models/saving_pocket.dart';
import 'cross_profile_transfer_dialog.dart';
import '../../widgets/responsive_breakpoints.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
enum RateSource { bcv, paralelo, euro }

extension RateSourceExtension on RateSource {
  String get name {
    switch (this) {
      case RateSource.bcv:
        return "Oficial BCV";
      case RateSource.paralelo:
        return "Paralelo";
      case RateSource.euro:
        return "Euro Oficial";
    }
  }

  double getValue(AppState state) {
    switch (this) {
      case RateSource.bcv:
        return state.bcvRate;
      case RateSource.paralelo:
        return state.parallelRate;
      case RateSource.euro:
        return state.euroRate;
    }
  }
}

class AddTransactionBottomSheet extends StatefulWidget {
  final TransactionType initialType;
  final String? initialAccountId;
  final Transaction? editingTransaction;

  const AddTransactionBottomSheet({
    super.key,
    this.initialType = TransactionType.income,
    this.initialAccountId,
    this.editingTransaction,
  });

  @override
  State<AddTransactionBottomSheet> createState() =>
      _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<AddTransactionBottomSheet> {
  late TransactionType _transactionType;
  final _amountController = TextEditingController();
  CurrencyType _selectedCurrency = CurrencyType.usd;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _expandedParentId;
  String? _destinationPocketId;
  final _noteController = TextEditingController();
  final RateSource _selectedRateSource = RateSource.bcv;
  String? _selectedAccountId;
  // Para cuentas VES: puede ser 'bcv', 'eur', 'custom' o 'bs'
  String _vesMode = 'bs'; 
  final _customRateController = TextEditingController();

  // Pago Móvil fields
  bool _isMobilePayment = false;
  String? _selectedRecipientId;
  final _mobilePaymentAliasController = TextEditingController();
  String _selectedMobilePaymentIdPrefix = "V";
  final _mobilePaymentIdCardController = TextEditingController();
  final _mobilePaymentPhoneController = TextEditingController();
  String? _selectedMobilePaymentBankCode;
  bool _saveToContacts = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.editingTransaction;
    if (tx != null) {
      _transactionType = tx.type;
      _amountController.text = tx.amount > 0 ? tx.amount.toString() : "";
      _selectedCurrency = tx.currency;
      _selectedDate = tx.date;
      _selectedCategoryId = tx.categoryId;
      _destinationPocketId = tx.destinationPocketId;
      _selectedAccountId = tx.accountId;

      // Parse Pago Móvil note format
      String noteText = tx.note;
      final matchA = RegExp(r'^(.*?)\s*\(Pago Móvil:\s*(.*?)\s*-\s*(.*?)\s*-\s*(.*?)\s*-\s*(.*?)\)$').firstMatch(noteText);
      final matchB = RegExp(r'^Pago Móvil:\s*(.*?)\s*-\s*(.*?)\s*-\s*(.*?)\s*-\s*(.*?)$').firstMatch(noteText);
      if (matchA != null) {
        _isMobilePayment = true;
        _noteController.text = matchA.group(1)?.trim() ?? "";
        _mobilePaymentAliasController.text = matchA.group(2)?.trim() ?? "";
        final bankStr = matchA.group(3)?.trim() ?? "";
        final bank = venezuelanBanks.firstWhere(
          (b) => b["name"] == bankStr || b["code"] == bankStr,
          orElse: () => {"code": "0102", "name": "Banco de Venezuela"},
        );
        _selectedMobilePaymentBankCode = bank["code"];
        final idStr = matchA.group(4)?.trim() ?? "";
        final idParts = idStr.split('-');
        if (idParts.length >= 2) {
          _selectedMobilePaymentIdPrefix = idParts[0];
          _mobilePaymentIdCardController.text = idParts.sublist(1).join('-');
        } else {
          _mobilePaymentIdCardController.text = idStr;
        }
        _mobilePaymentPhoneController.text = matchA.group(5)?.trim() ?? "";
      } else if (matchB != null) {
        _isMobilePayment = true;
        _noteController.text = "";
        _mobilePaymentAliasController.text = matchB.group(1)?.trim() ?? "";
        final bankStr = matchB.group(2)?.trim() ?? "";
        final bank = venezuelanBanks.firstWhere(
          (b) => b["name"] == bankStr || b["code"] == bankStr,
          orElse: () => {"code": "0102", "name": "Banco de Venezuela"},
        );
        _selectedMobilePaymentBankCode = bank["code"];
        final idStr = matchB.group(3)?.trim() ?? "";
        final idParts = idStr.split('-');
        if (idParts.length >= 2) {
          _selectedMobilePaymentIdPrefix = idParts[0];
          _mobilePaymentIdCardController.text = idParts.sublist(1).join('-');
        } else {
          _mobilePaymentIdCardController.text = idStr;
        }
        _mobilePaymentPhoneController.text = matchB.group(4)?.trim() ?? "";
      } else {
        _noteController.text = tx.note;
      }

      // Determine selected rate source based on rate
      final appState = Provider.of<AppState>(context, listen: false);
      final acc = appState.accounts.firstWhere(
        (a) => a.id == tx.accountId,
        orElse: () => appState.accounts.first,
      );
      if (acc.currency == CurrencyType.bsBCV) {
        if (tx.currency == CurrencyType.eur) {
          _vesMode = 'eur';
        } else if (tx.exchangeRate != appState.bcvRate && tx.exchangeRate != appState.euroRate) {
          _vesMode = 'custom';
          _customRateController.text = tx.exchangeRate.toString();
        } else if (tx.currency == CurrencyType.bsBCV) {
          _vesMode = 'bs';
        } else {
          _vesMode = 'bcv';
        }
      } else {
        _vesMode = 'bcv';
      }
      _customRateController.text = tx.exchangeRate.toString();
      if (_selectedCategoryId != null) {
        try {
          final cat = appState.categories.firstWhere((c) => c.id == _selectedCategoryId);
          if (cat.parentId != null) {
            _expandedParentId = cat.parentId;
          }
        } catch (_) {}
      }
    } else {
      _transactionType = widget.initialType;
      final appState = Provider.of<AppState>(context, listen: false);
      final initAccId = widget.initialAccountId;
      if (initAccId != null && appState.accounts.any((acc) => acc.id == initAccId)) {
        _selectedAccountId = initAccId;
        final acc = appState.accounts.firstWhere((acc) => acc.id == initAccId);
        _selectedCurrency = acc.currency;
      } else if (appState.accounts.isNotEmpty) {
        final defaultAccount = appState.accounts.first;
        _selectedAccountId = defaultAccount.id;
        _selectedCurrency = defaultAccount.currency;
      }
      _vesMode = 'bcv';
      _customRateController.text = appState.parallelRate.toString();
    }
  }

  bool _checkIfContactExists(AppState appState) {
    final phone = _mobilePaymentPhoneController.text.trim();
    final idNum = _mobilePaymentIdCardController.text.trim();
    final formattedId = "$_selectedMobilePaymentIdPrefix-$idNum";
    
    if (phone.isEmpty || idNum.isEmpty) return true; // Don't show option if fields are empty
    
    return appState.recipients.any((r) =>
        r.phoneNumber == phone ||
        r.identityCard == formattedId);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _mobilePaymentAliasController.dispose();
    _mobilePaymentIdCardController.dispose();
    _mobilePaymentPhoneController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  List<TransactionCategory> _getFilteredCategories(AppState appState) {
    final targetType = _transactionType == TransactionType.income
        ? TransactionCategoryType.income
        : TransactionCategoryType.expense;
    if (_expandedParentId == null) {
      return appState.getParentCategories(targetType);
    } else {
      try {
        final parent = appState.categories.firstWhere((c) => c.id == _expandedParentId);
        final children = appState.getSubcategories(_expandedParentId!);
        return [parent, ...children];
      } catch (e) {
        return appState.getParentCategories(targetType);
      }
    }
  }

  Future<void> _handleConfirmAction(AppState appState) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("El monto debe ser mayor a cero."),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedCurrency == CurrencyType.bsBCV && _transactionType == TransactionType.expense && _isMobilePayment) {
      final alias = _mobilePaymentAliasController.text.trim();
      final idNum = _mobilePaymentIdCardController.text.trim();
      final phone = _mobilePaymentPhoneController.text.trim();

      if (alias.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("El nombre o alias del beneficiario es obligatorio."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (idNum.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("La cédula o RIF del beneficiario es obligatoria."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("El número de teléfono es obligatorio."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (phone.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("El número de teléfono debe tener al menos 10 dígitos."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
    }

    if (appState.useBiometrics || appState.usePinSecurity) {
      final authenticated = await appState.verifySecurityAuth(
        context,
        reason: "Confirma tu identidad para registrar esta transacción",
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
    _saveTransaction(appState);
  }

  void _saveTransaction(AppState appState) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    final selectedAcc = appState.accounts.firstWhere(
      (acc) => acc.id == _selectedAccountId,
      orElse: () => appState.accounts.first,
    );
    final isAccVES = selectedAcc.currency == CurrencyType.bsBCV;

    final CurrencyType txCurrency;
    final double rate;

    if (isAccVES) {
      if (_vesMode == 'eur') {
        rate = appState.euroRate;
        txCurrency = CurrencyType.eur;
      } else if (_vesMode == 'custom') {
        rate = double.tryParse(_customRateController.text) ?? appState.parallelRate;
        txCurrency = CurrencyType.usd;
      } else if (_vesMode == 'bs') {
        rate = appState.bcvRate;
        txCurrency = CurrencyType.bsBCV;
      } else {
        rate = appState.bcvRate;
        txCurrency = CurrencyType.usd;
      }
    } else {
      rate = appState.bcvRate;
      txCurrency = _selectedCurrency;
    }

    final isEditing = widget.editingTransaction != null;

    String finalNote = _noteController.text.trim();
    if (isAccVES && _transactionType == TransactionType.expense && _isMobilePayment) {
      final alias = _mobilePaymentAliasController.text.trim();
      final bankCode = _selectedMobilePaymentBankCode ?? (venezuelanBanks.isNotEmpty ? venezuelanBanks.first["code"] : "0102");
      final bank = venezuelanBanks.firstWhere(
        (b) => b["code"] == bankCode,
        orElse: () => {"code": bankCode!, "name": "Banco"},
      );
      final bankName = bank["name"]!;
      final idNum = _mobilePaymentIdCardController.text.trim();
      final phone = _mobilePaymentPhoneController.text.trim();
      final formattedId = "$_selectedMobilePaymentIdPrefix-$idNum";

      if (finalNote.isNotEmpty) {
        finalNote = "$finalNote (Pago Móvil: $alias - $bankName - $formattedId - $phone)";
      } else {
        finalNote = "Pago Móvil: $alias - $bankName - $formattedId - $phone";
      }

      // Quick-save recipient if checked and not already saved
      if (_saveToContacts) {
        final alreadyExists = appState.recipients.any((r) =>
            r.phoneNumber == phone ||
            r.identityCard == formattedId);
        if (!alreadyExists && alias.isNotEmpty && idNum.isNotEmpty && phone.isNotEmpty) {
          appState.addRecipient(
            alias: alias,
            bankCode: bankCode!,
            bankName: bankName,
            identityCard: formattedId,
            phoneNumber: phone,
          );
        }
      }
    }

    final newTx = Transaction(
      id: isEditing
          ? widget.editingTransaction!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      categoryId: (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) ? _selectedCategoryId : null,
      amount: amount,
      currency: txCurrency,
      exchangeRate: rate,
      accountId: _selectedAccountId,
      note: finalNote,
      type: _transactionType,
      destinationPocketId: _destinationPocketId,
    );

    final navigator = Navigator.of(context);

    if (isEditing) {
      appState.updateTransaction(widget.editingTransaction!, newTx);
    } else {
      appState.addTransaction(newTx);
    }
    
    navigator.pop();

    showDialog(
      context: navigator.context,
      barrierDismissible: false,
      builder: (context) => TransactionSuccessDialog(
        transaction: newTx,
        appState: appState,
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
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
                    color: AppColors.expense.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.expense,
                    size: OrtizIconSize.xxl,
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.lg),
              Center(
                child: Text(
                  "¿Eliminar Movimiento?",
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.md),
              Text(
                "¿Estás seguro de que deseas eliminar este movimiento? Esta acción es permanente y recalculará todos los balances y proyecciones correspondientes.",
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  color: AppColors.cardSubtitleText,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: OrtizSpace.xxl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(
                          fontSize: OrtizFontSize.body,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardSubtitleText,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        foregroundColor: OrtizPalette.onAccent,
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        appState.deleteTransaction(widget.editingTransaction!);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Eliminar",
                        style: TextStyle(
                          fontSize: OrtizFontSize.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final filteredCategories = _getFilteredCategories(appState);
    final selectedAcc = appState.accounts.firstWhere(
      (acc) => acc.id == _selectedAccountId,
      orElse: () => appState.accounts.isNotEmpty ? appState.accounts.first : Account(id: '', name: '', balance: 0, currency: CurrencyType.usd, colorHex: '#007AFF', icon: 'creditcard'),
    );
    final isAccVES = selectedAcc.currency == CurrencyType.bsBCV;

    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: isDesktop
            ? const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.sheet),
                bottomLeft: Radius.circular(OrtizRadius.sheet),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.pill),
                topRight: Radius.circular(OrtizRadius.pill),
              ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.xl,
        right: OrtizSpace.xl,
        top: isDesktop ? OrtizSpace.xxl : OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
      ),
      child: FractionallySizedBox(
        heightFactor: isDesktop ? 1.0 : 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDesktop) ...[
              // Top drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorderColor,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),
              const SizedBox(height: OrtizSpace.lg),
            ],

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingTransaction != null
                      ? (_transactionType == TransactionType.income
                          ? "Editar Ingreso"
                          : "Editar Gasto")
                      : (_transactionType == TransactionType.income
                          ? "Registrar Ingreso"
                          : "Registrar Gasto"),
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
                Row(
                  children: [
                    if (widget.editingTransaction == null && appState.profiles.length > 1)
                      IconButton(
                        icon: Icon(Icons.sync_alt_rounded, color: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CrossProfileTransferBottomSheet(appState: appState),
                          );
                        },
                        tooltip: "Transferir a otro libro",
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Transaction Type Selector
                    Container(
                      padding: EdgeInsets.all(OrtizSpace.xs),
                      decoration: BoxDecoration(
                        color: AppColors.nestedTabTrackBg,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _transactionType = TransactionType.income;
                                  _selectedCategoryId =
                                      null; // reset to auto-select
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: OrtizSpace.sm,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _transactionType == TransactionType.income
                                      ? OrtizPalette.surfaceHigh
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Ingreso",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: OrtizFontSize.bodySm,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _transactionType = TransactionType.expense;
                                  _selectedCategoryId =
                                      null; // reset to auto-select
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: OrtizSpace.sm,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _transactionType ==
                                          TransactionType.expense
                                      ? OrtizPalette.surfaceHigh
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Gasto",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: OrtizFontSize.bodySm,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.lg),

                    // 1b. Account Selector
                    OrtizSection(
                      title: "CUENTA",
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAccountId,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: OrtizSpace.lg,
                                vertical: OrtizSpace.sm,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: const BorderSide(color: AppColors.cardBorderColor),
                              ),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                            ),
                            dropdownColor: AppColors.cardBackground,
                            style: TextStyle(
                              color: AppColors.cardText,
                              fontWeight: FontWeight.bold,
                              fontSize: OrtizFontSize.bodySm,
                            ),
                            items: appState.accounts.map((acc) {
                              final accColor = parseHexColor(acc.colorHex);
                              final isUsd = acc.currency == CurrencyType.usd;
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: accColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        getIconData(acc.icon),
                                        color: accColor,
                                        size: OrtizIconSize.xs,
                                      ),
                                    ),
                                    SizedBox(width: OrtizSpace.sm),
                                    Text(
                                      "${acc.name} (${isUsd ? formatUSD(acc.balance) : formatBs(acc.balance)})",
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (accId) {
                              if (accId != null) {
                                final selectedAcc = appState.accounts.firstWhere((acc) => acc.id == accId);
                                setState(() {
                                  _selectedAccountId = accId;
                                  _selectedCurrency = selectedAcc.currency;
                                  if (selectedAcc.currency == CurrencyType.bsBCV) {
                                    _vesMode = 'bs';
                                    _destinationPocketId = null;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      ],
                    ),

                    // 2. Amount Input Card
                    OrtizSection(
                      title: "CANTIDAD DEL MOVIMIENTO",
                      children: [
                      Column(
                        children: [
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [CommaTextInputFormatter()],
                            style: TextStyle(
                              fontSize: OrtizFontSize.displayLg,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardText,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: isAccVES 
                                ? (_vesMode == 'eur' ? "0.00 €" : (_vesMode == 'bs' ? "0.00 Bs." : "0.00 \$"))
                                : (_selectedCurrency == CurrencyType.eur ? "0.00 €" : (_selectedCurrency == CurrencyType.usd ? "0.00 \$" : "0.00 Bs.")),
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: AppColors.cardSubtitleText),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          if (!isAccVES) ...[
                            // USD account: non-interactive tab for USD
                            Container(
                              padding: EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.nestedTabActiveBg,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "USD (\$)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: OrtizFontSize.bodySm,
                                    color: AppColors.nestedTabActiveText,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // VES account: interactive tabs for BCV, EUR, Tasa
                            Container(
                              padding: EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _vesMode = 'bs'),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'bs'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Bs.",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _vesMode == 'bs'
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _vesMode = 'bcv'),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'bcv'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "BCV (\$)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _vesMode == 'bcv'
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _vesMode = 'eur'),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'eur'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "EUR (€)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _vesMode == 'eur'
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _vesMode = 'custom'),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'custom'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Tasa",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _vesMode == 'custom'
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_vesMode == 'custom') ...[
                              Divider(
                                height: 24,
                                color: AppColors.cardBorderColor,
                              ),
                              Text(
                                "TASA DE CAMBIO PERSONALIZADA (Bs/\$)",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(height: OrtizSpace.sm),
                              TextField(
                                controller: _customRateController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [CommaTextInputFormatter()],
                                decoration: InputDecoration(
                                  hintText: "Ej: 45.00",
                                  hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
                                  contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                                    borderSide: const BorderSide(color: AppColors.cardBorderColor),
                                  ),
                                  filled: true,
                                  fillColor: OrtizPalette.surfaceHigh,
                                ),
                                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ],
                        ],
                      ),
                      ],
                    ),

                    // 3. General Details Card
                    OrtizSection(
                      title: "DETALLES DE LA TRANSACCIÓN",
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pocket selection
                          if (!isAccVES || _vesMode != 'eur') ...[
                            Text(
                              _transactionType == TransactionType.income
                                  ? "Destino de los Fondos"
                                  : "Origen de los Fondos",
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            DropdownButtonFormField<String?>(
                              initialValue: _destinationPocketId,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: OrtizSpace.lg,
                                  vertical: OrtizSpace.sm,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                  borderSide: const BorderSide(color: AppColors.cardBorderColor),
                                ),
                                filled: true,
                                fillColor: OrtizPalette.surfaceHigh,
                              ),
                              dropdownColor: AppColors.cardBackground,
                              style: TextStyle(
                                color: AppColors.cardText,
                                fontWeight: FontWeight.bold,
                                fontSize: OrtizFontSize.bodySm,
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    "Balance Libre (Efectivo/Banco)",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                ),
                                ...appState.pockets.map((pocket) {
                                  return DropdownMenuItem<String?>(
                                    value: pocket.id,
                                    child: Text(
                                      "Bolsillo: ${pocket.name}",
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cardText,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (pocketId) {
                                setState(() => _destinationPocketId = pocketId);
                              },
                            ),
                            SizedBox(height: OrtizSpace.lg),
                          ],

                          // Pago Móvil Toggle & Fields (Conditional: account currency is Bs. & type is Expense)
                          if (isAccVES && _transactionType == TransactionType.expense) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "¿Es Pago Móvil?",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                Switch(
                                  value: _isMobilePayment,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _isMobilePayment = val;
                                      if (val) {
                                        _selectedRecipientId = null;
                                        if (venezuelanBanks.isNotEmpty) {
                                          _selectedMobilePaymentBankCode = venezuelanBanks.first["code"];
                                        }
                                        _selectedMobilePaymentIdPrefix = "V";
                                        _saveToContacts = false;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_isMobilePayment) ...[
                              SizedBox(height: OrtizSpace.md),
                              OrtizSection(
                                title: "DETALLES DE PAGO MÓVIL",
                                children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Selector de beneficiario
                                    Text(
                                      "Beneficiario",
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedRecipientId ?? 'manual',
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                        filled: true,
                                        fillColor: OrtizPalette.surfaceHigh,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: 'manual',
                                          child: Text("Nuevo beneficiario / Ingresar manual"),
                                        ),
                                        ...appState.recipients.map((r) => DropdownMenuItem<String>(
                                          value: r.id,
                                          child: Text("${r.alias} (${r.bankName})"),
                                        )),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedRecipientId = val == 'manual' ? null : val;
                                          if (_selectedRecipientId != null) {
                                            final r = appState.recipients.firstWhere((x) => x.id == _selectedRecipientId);
                                            _mobilePaymentAliasController.text = r.alias;
                                            _selectedMobilePaymentBankCode = r.bankCode;
                                            _mobilePaymentPhoneController.text = r.phoneNumber;
                                            
                                            final parts = r.identityCard.split('-');
                                            if (parts.length >= 2) {
                                              _selectedMobilePaymentIdPrefix = parts[0];
                                              _mobilePaymentIdCardController.text = parts.sublist(1).join('-');
                                            } else {
                                              _mobilePaymentIdCardController.text = r.identityCard;
                                            }
                                            _saveToContacts = false;
                                          } else {
                                            _mobilePaymentAliasController.clear();
                                            _mobilePaymentIdCardController.clear();
                                            _mobilePaymentPhoneController.clear();
                                            if (venezuelanBanks.isNotEmpty) {
                                              _selectedMobilePaymentBankCode = venezuelanBanks.first["code"];
                                            }
                                            _selectedMobilePaymentIdPrefix = "V";
                                            _saveToContacts = false;
                                          }
                                        });
                                      },
                                    ),
                                    SizedBox(height: OrtizSpace.md),

                                    // Alias/Nombre
                                    Text(
                                      "Nombre o Alias",
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    TextField(
                                      controller: _mobilePaymentAliasController,
                                      decoration: InputDecoration(
                                        hintText: "Ej. Mamá, Pedro Pérez",
                                        hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
                                        contentPadding: EdgeInsets.all(OrtizSpace.md),
                                        filled: true,
                                        fillColor: OrtizPalette.surfaceHigh,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    SizedBox(height: OrtizSpace.md),

                                    // Banco
                                    Text(
                                      "Banco Receptor",
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedMobilePaymentBankCode ?? (venezuelanBanks.isNotEmpty ? venezuelanBanks.first["code"] : null),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                        filled: true,
                                        fillColor: OrtizPalette.surfaceHigh,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
                                      items: venezuelanBanks.map((b) {
                                        return DropdownMenuItem<String>(
                                          value: b["code"],
                                          child: Text("${b["name"]} (${b["code"]})", overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (code) {
                                        setState(() => _selectedMobilePaymentBankCode = code);
                                      },
                                    ),
                                    SizedBox(height: OrtizSpace.md),

                                    // Cédula / RIF
                                    Text(
                                      "Cédula / RIF",
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    Row(
                                      children: [
                                        Container(
                                          width: 70,
                                          decoration: BoxDecoration(
                                            color: OrtizPalette.surfaceHigh,
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          ),
                                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedMobilePaymentIdPrefix,
                                              dropdownColor: AppColors.cardBackground,
                                              style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                              items: ["V", "E", "J", "G"].map((prefix) {
                                                return DropdownMenuItem<String>(
                                                  value: prefix,
                                                  child: Text(prefix),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() => _selectedMobilePaymentIdPrefix = val);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: OrtizSpace.sm),
                                        Expanded(
                                          child: TextField(
                                            controller: _mobilePaymentIdCardController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: "Número de identificación",
                                              hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
                                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                                              filled: true,
                                              fillColor: OrtizPalette.surfaceHigh,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: OrtizSpace.md),

                                    // Teléfono
                                    Text(
                                      "Número de Teléfono",
                                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    SizedBox(height: OrtizSpace.xs),
                                    TextField(
                                      controller: _mobilePaymentPhoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: "Ej. 04121234567",
                                        hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
                                        contentPadding: EdgeInsets.all(OrtizSpace.md),
                                        filled: true,
                                        fillColor: OrtizPalette.surfaceHigh,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    
                                    // Quick Save Checkbox
                                    if (!_checkIfContactExists(appState)) ...[
                                      SizedBox(height: OrtizSpace.md),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: _saveToContacts,
                                              activeColor: AppColors.primary,
                                              onChanged: (val) {
                                                setState(() => _saveToContacts = val ?? false);
                                              },
                                            ),
                                          ),
                                          SizedBox(width: OrtizSpace.sm),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() => _saveToContacts = !_saveToContacts);
                                              },
                                              child: Text(
                                                "Guardar en contactos Pago Móvil",
                                                style: TextStyle(
                                                  fontSize: OrtizFontSize.bodySm,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.cardText,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                ],
                              ),
                            ],
                          ],

                          // Note Field
                          Text(
                            "Nota / Concepto",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: "Ej. Pago de supermercado",
                              hintStyle: TextStyle(
                                color: AppColors.cardSubtitleText,
                                fontSize: OrtizFontSize.bodySm,
                              ),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // Date picker row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Fecha",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cardText,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.nestedTabTrackBg,
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: OrtizSpace.md,
                                    vertical: OrtizSpace.sm,
                                  ),
                                ),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() => _selectedDate = date);
                                  }
                                },
                                icon: Icon(
                                  Icons.calendar_today_rounded,
                                  size: OrtizIconSize.xs,
                                ),
                                label: Text(
                                  formatDate(_selectedDate),
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ],
                    ),

                    // 4. Category Grid Selector
                    OrtizSection(
                      title: "SELECCIONA UNA CATEGORÍA",
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (filteredCategories.isEmpty)
                            const OrtizEmptyState(
                              icon: Icons.category_outlined,
                              title: "No hay categorías de este tipo.",
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: filteredCategories.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  if (_expandedParentId == null) {
                                    final isSelected = _selectedCategoryId == null;
                                    final Color catColor = _transactionType == TransactionType.income
                                        ? AppColors.income
                                        : AppColors.expense;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedCategoryId = null);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? catColor.withValues(alpha: 0.18)
                                              : catColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(OrtizRadius.block),
                                          border: Border.all(
                                            color: isSelected
                                                ? catColor
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: OrtizSpace.sm,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? catColor
                                                    : catColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _transactionType == TransactionType.income
                                                    ? Icons.arrow_upward
                                                    : Icons.arrow_downward,
                                                color: isSelected
                                                    ? OrtizPalette.onAccent
                                                    : catColor,
                                                size: OrtizIconSize.md,
                                              ),
                                            ),
                                            SizedBox(height: OrtizSpace.sm),
                                            Text(
                                              "Ninguna",
                                              style: TextStyle(
                                                fontSize: OrtizFontSize.caption,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.cardText,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _expandedParentId = null);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: OrtizPalette.surfaceHigh,
                                          borderRadius: BorderRadius.circular(OrtizRadius.block),
                                          border: Border.all(
                                            color: Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.cardBorderColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.arrow_back_rounded,
                                                color: AppColors.cardText,
                                                size: OrtizIconSize.md,
                                              ),
                                            ),
                                            SizedBox(height: OrtizSpace.sm),
                                            Text(
                                              "Atrás",
                                              style: TextStyle(
                                                fontSize: OrtizFontSize.caption,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.cardText,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                }

                                final cat = filteredCategories[index - 1];
                                final catColor = parseHexColor(cat.colorHex);
                                
                                bool isSelected = _selectedCategoryId == cat.id;
                                if (_expandedParentId == null && _selectedCategoryId != null) {
                                  try {
                                    final appState = Provider.of<AppState>(context, listen: false);
                                    final selectedCat = appState.categories.firstWhere((c) => c.id == _selectedCategoryId);
                                    if (selectedCat.parentId == cat.id) {
                                      isSelected = true;
                                    }
                                  } catch (_) {}
                                }

                                bool isExpandable = false;
                                if (_expandedParentId == null) {
                                  final appState = Provider.of<AppState>(context, listen: false);
                                  if (appState.getSubcategories(cat.id).isNotEmpty) {
                                    isExpandable = true;
                                  }
                                }

                                return GestureDetector(
                                  onTap: () {
                                    if (isExpandable) {
                                      setState(() => _expandedParentId = cat.id);
                                    } else {
                                      setState(() => _selectedCategoryId = cat.id);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor.withValues(alpha: 0.18)
                                          : catColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                                      border: Border.all(
                                        color: isSelected
                                            ? catColor
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: OrtizSpace.sm,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? catColor
                                                    : catColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                getIconData(cat.icon),
                                                color: isSelected
                                                    ? OrtizPalette.onAccent
                                                    : catColor,
                                                size: OrtizIconSize.md,
                                              ),
                                            ),
                                            if (isExpandable)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: EdgeInsets.all(OrtizSpace.xxs),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.cardBackground,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.more_horiz_rounded,
                                                    size: OrtizIconSize.xs,
                                                    color: catColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: OrtizSpace.sm),
                                        Text(
                                          (cat.parentId != null ? "↳ " : "") + cat.name,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.cardText,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      ],
                    ),
                    if (widget.editingTransaction != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => _confirmDeleteTransaction(context, appState),
                        icon: Icon(Icons.delete_forever_rounded, color: AppColors.expense),
                        label: Text(
                          "Eliminar Movimiento",
                          style: TextStyle(
                            color: AppColors.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: OrtizFontSize.body,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.expense, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: OrtizSpace.xxxl),
                  ],
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Save / Cancel Buttons Row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(
                        fontSize: OrtizFontSize.body,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardSubtitleText,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: OrtizPalette.onAccent,
                            padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.field),
                            ),
                          ),
                          onPressed: ((double.tryParse(_amountController.text) ?? 0.0) <= 0)
                              ? null
                              : () => _handleConfirmAction(appState),
                          child: Text(
                            widget.editingTransaction != null ? "Guardar" : "Registrar",
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

class TransactionSuccessDialog extends StatefulWidget {
  final Transaction transaction;
  final AppState appState;

  const TransactionSuccessDialog({
    super.key,
    required this.transaction,
    required this.appState,
  });

  @override
  State<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends State<TransactionSuccessDialog> {
  final Set<String> _provisionedPocketIds = {};

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
    final isIncome = widget.transaction.type == TransactionType.income;
    final account = widget.appState.accounts.firstWhere(
      (a) => a.id == widget.transaction.accountId,
      orElse: () => Account(id: '', name: 'Desconocido', currency: CurrencyType.usd, balance: 0.0, colorHex: '', icon: ''),
    );
    final category = widget.appState.categories.firstWhere(
      (c) => c.id == widget.transaction.categoryId,
      orElse: () => TransactionCategory(
        id: '',
        name: isIncome ? 'Ingreso' : 'Gasto',
        icon: '',
        colorHex: '',
        type: TransactionCategoryType.expense,
      ),
    );

    final themeColor = isIncome ? AppColors.income : AppColors.expense;

    // Calculate matching automatic savings suggestions
    final matchingPockets = <Map<String, dynamic>>[];
    if (isIncome && widget.transaction.currency == CurrencyType.usd && account.currency == CurrencyType.usd) {
      final rate = widget.transaction.exchangeRate > 0 ? widget.transaction.exchangeRate : widget.appState.bcvRate;
      final amountUSD = widget.transaction.currency == CurrencyType.usd
          ? widget.transaction.amount
          : widget.transaction.amount / rate;

      final isRecurring = widget.transaction.id.contains("_rec") || widget.transaction.id.contains("_partial");

      for (var pocket in widget.appState.pockets) {
        if (pocket.targetDate == null) {
          if (pocket.fundingRuleType == 'percentage') {
            final val = pocket.fundingRuleValue ?? 0.0;
            if (val > 0) {
              final suggestUSD = amountUSD * (val / 100.0);
              final remaining = pocket.targetAmountUSD > 0
                  ? pocket.targetAmountUSD - pocket.currentAmountUSD
                  : double.infinity;
              if (remaining > 0) {
                final finalSuggest = (pocket.targetAmountUSD > 0 && suggestUSD > remaining) ? remaining : suggestUSD;
                matchingPockets.add({
                  'pocket': pocket,
                  'suggestUSD': finalSuggest,
                  'type': 'percentage',
                  'ruleText': isRecurring 
                      ? '${val.toStringAsFixed(0)}% de ingreso recurrente'
                      : '${val.toStringAsFixed(0)}% de ingreso manual',
                });
              }
            }
          } else if (pocket.fundingRuleType == 'fixedThreshold') {
            final threshold = pocket.fundingRuleThreshold ?? 0.0;
            final val = pocket.fundingRuleValue ?? 0.0;
            if (val > 0 && amountUSD >= threshold) {
              final remaining = pocket.targetAmountUSD > 0
                  ? pocket.targetAmountUSD - pocket.currentAmountUSD
                  : double.infinity;
              if (remaining > 0) {
                final finalSuggest = (pocket.targetAmountUSD > 0 && val > remaining) ? remaining : val;
                matchingPockets.add({
                  'pocket': pocket,
                  'suggestUSD': finalSuggest,
                  'type': 'fixedThreshold',
                  'ruleText': isRecurring 
                      ? 'Ingreso ≥ \$${threshold.toStringAsFixed(0)}'
                      : 'Ingreso manual ≥ \$${threshold.toStringAsFixed(0)}',
                });
              }
            }
          }
        }
      }
    }

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
                  color: themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: themeColor,
                  size: OrtizIconSize.xxl,
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),
            Center(
              child: Text(
                isIncome ? "¡Ingreso Registrado!" : "¡Gasto Registrado!",
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
                "La transacción ha sido guardada en la app",
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
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(OrtizRadius.block),
                border: Border.all(color: AppColors.cardBorderColor),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    "Tipo de Operación",
                    isIncome ? "Ingreso" : "Gasto",
                    themeColor,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Monto",
                    "${widget.transaction.currency.symbol} ${widget.transaction.amount.toStringAsFixed(2)}",
                    themeColor,
                    isBold: true,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta",
                    account.name,
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Categoría",
                    category.name,
                    AppColors.cardText,
                  ),
                  if (widget.transaction.note.isNotEmpty) ...[
                    Divider(height: 16),
                    _buildDetailRow(
                      "Nota",
                      widget.transaction.note,
                      AppColors.cardText,
                    ),
                  ],
                ],
              ),
            ),

            if (matchingPockets.isNotEmpty) ...[
              SizedBox(height: OrtizSpace.lg),
              Text(
                "PLAN DE AHORRO AUTOMÁTICO",
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardSubtitleText,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: OrtizSpace.sm),
              Container(
                padding: EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.nestedTabTrackBg,
                  borderRadius: BorderRadius.circular(OrtizRadius.block),
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: matchingPockets.map((match) {
                    final pocket = match['pocket'] as SavingPocket;
                    final suggestUSD = match['suggestUSD'] as double;
                    final ruleText = match['ruleText'] as String;
                    final isProvisioned = _provisionedPocketIds.contains(pocket.id);

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.xs),
                            decoration: BoxDecoration(
                              color: parseHexColor(pocket.colorHex).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getIconData(pocket.icon),
                              color: parseHexColor(pocket.colorHex),
                              size: OrtizIconSize.xs,
                            ),
                          ),
                          SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pocket.name,
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                Text(
                                  ruleText,
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.micro,
                                    color: AppColors.cardSubtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: isProvisioned
                                  ? AppColors.income.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              foregroundColor: isProvisioned ? AppColors.income : AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: isProvisioned
                                ? null
                                : () async {
                                    if (widget.transaction.id.contains("_rec") || widget.transaction.id.contains("_partial")) {
                                      await widget.appState.depositToPocket(
                                        id: pocket.id,
                                        amountUSD: suggestUSD,
                                      );
                                    } else {
                                      await widget.appState.confirmManualSaving(
                                        transactionIds: [widget.transaction.id],
                                        pocketId: pocket.id,
                                        amountUSD: suggestUSD,
                                      );
                                    }
                                    setState(() {
                                      _provisionedPocketIds.add(pocket.id);
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Apartado \$${suggestUSD.toStringAsFixed(2)} a ${pocket.name}"),
                                          backgroundColor: AppColors.income,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isProvisioned) ...[
                                  Icon(Icons.check_circle_outline_rounded, size: OrtizIconSize.xs),
                                  SizedBox(width: OrtizSpace.xs),
                                  Text(
                                    "Ahorrado",
                                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
                                  ),
                                ] else ...[
                                  Icon(Icons.auto_awesome_rounded, size: OrtizIconSize.xs),
                                  SizedBox(width: OrtizSpace.xs),
                                  Text(
                                    "Ahorrar \$${suggestUSD.toStringAsFixed(2)}",
                                    style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

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
              onPressed: () {
                Navigator.pop(context);
                widget.appState.setTabIndex(2); // Go to history screen
              },
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
