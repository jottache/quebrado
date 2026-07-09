import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../models/account.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../models/mobile_payment_recipient.dart';
import '../screens/mobile_payment_recipient_screen.dart' show venezuelanBanks;
import '../widgets/slide_to_confirm_button.dart';
import '../services/biometric_service.dart';
import '../models/saving_pocket.dart';

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
  String? _destinationPocketId;
  final _noteController = TextEditingController();
  RateSource _selectedRateSource = RateSource.bcv;
  String? _selectedAccountId;
  String _vesMode = "bcv";
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
        } else {
          _vesMode = 'bcv';
        }
      } else {
        _vesMode = 'bcv';
      }
      _customRateController.text = tx.exchangeRate.toString();
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
    return appState.categories.where((cat) => cat.type == targetType).toList();
  }

  Future<void> _handleConfirmAction(AppState appState) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
          const SnackBar(
            content: Text("El nombre o alias del beneficiario es obligatorio."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (idNum.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("La cédula o RIF del beneficiario es obligatoria."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("El número de teléfono es obligatorio."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      if (phone.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("El número de teléfono debe tener al menos 10 dígitos."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
    }

    if (appState.useBiometrics) {
      final authenticated = await BiometricService.authenticate(
        reason: "Confirma tu identidad para registrar esta transacción",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Autenticación biométrica fallida o cancelada."),
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
        txCurrency = CurrencyType.eur;
        rate = appState.euroRate;
      } else if (_vesMode == 'custom') {
        txCurrency = CurrencyType.usd;
        rate = double.tryParse(_customRateController.text) ?? appState.parallelRate;
      } else {
        txCurrency = CurrencyType.usd;
        rate = appState.bcvRate;
      }
    } else {
      txCurrency = CurrencyType.usd;
      rate = appState.bcvRate;
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
      amount: amount,
      currency: txCurrency,
      destinationPocketId: _destinationPocketId,
      categoryId: _selectedCategoryId,
      accountId: _selectedAccountId,
      note: finalNote,
      type: _transactionType,
      exchangeRate: rate,
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
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClaymorphicCard(
          cornerRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.expense,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "¿Eliminar Movimiento?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "¿Estás seguro de que deseas eliminar este movimiento? Esta acción es permanente y recalculará todos los balances y proyecciones correspondientes.",
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.cardSubtitleText,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        appState.deleteTransaction(widget.editingTransaction!);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Eliminar",
                        style: TextStyle(
                          fontSize: 14,
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Transaction Type Selector
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _transactionType == TransactionType.income
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow:
                                      _transactionType == TransactionType.income
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "Ingreso",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _transactionType ==
                                          TransactionType.expense
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow:
                                      _transactionType ==
                                          TransactionType.expense
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "Gasto",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1b. Account Selector
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CUENTA",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.03),
                            ),
                            dropdownColor: AppColors.cardBackground,
                            style: const TextStyle(
                              color: AppColors.cardText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
                                        color: accColor.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        getIconData(acc.icon),
                                        color: accColor,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${acc.name} (${isUsd ? formatUSD(acc.balance) : formatBs(acc.balance)})",
                                      style: const TextStyle(
                                        fontSize: 13,
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
                                    _vesMode = 'bcv';
                                    _destinationPocketId = null;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Amount Input Card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        children: [
                          Text(
                            "CANTIDAD DEL MOVIMIENTO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardText,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: "0.00",
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: AppColors.cardSubtitleText),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          if (!isAccVES) ...[
                            // USD account: non-interactive tab for USD
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.nestedTabActiveBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "USD (\$)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.nestedTabActiveText,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // VES account: interactive tabs for BCV, EUR, Tasa
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _vesMode = 'bcv'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'bcv'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "BCV (\$)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'eur'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "EUR (€)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _vesMode == 'custom'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Tasa",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                                color: Colors.black.withOpacity(0.08),
                              ),
                              Text(
                                "TASA DE CAMBIO PERSONALIZADA (Bs/\$)",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: "Ej: 45.00",
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.03),
                                ),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. General Details Card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DETALLES DE LA TRANSACCIÓN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pocket selection
                          if (!isAccVES || _vesMode != 'eur') ...[
                            Text(
                              _transactionType == TransactionType.income
                                  ? "Destino de los Fondos"
                                  : "Origen de los Fondos",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String?>(
                              value: _destinationPocketId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.03),
                              ),
                              dropdownColor: AppColors.cardBackground,
                              style: const TextStyle(
                                color: AppColors.cardText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    "Balance Libre (Efectivo/Banco)",
                                    style: TextStyle(
                                      fontSize: 13,
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
                                      style: const TextStyle(
                                        fontSize: 13,
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
                            const SizedBox(height: 16),
                          ],

                          // Pago Móvil Toggle & Fields (Conditional: account currency is Bs. & type is Expense)
                          if (isAccVES && _transactionType == TransactionType.expense) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "¿Es Pago Móvil?",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                Switch(
                                  value: _isMobilePayment,
                                  activeColor: AppColors.primary,
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
                              const SizedBox(height: 12),
                              ClaymorphicCard(
                                cornerRadius: 18,
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      "DETALLES DE PAGO MÓVIL",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.cardSubtitleText,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Selector de beneficiario
                                    const Text(
                                      "Beneficiario",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedRecipientId ?? 'manual',
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(color: AppColors.cardText, fontSize: 13),
                                      items: [
                                        const DropdownMenuItem<String>(
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
                                    const SizedBox(height: 12),

                                    // Alias/Nombre
                                    const Text(
                                      "Nombre o Alias",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _mobilePaymentAliasController,
                                      decoration: InputDecoration(
                                        hintText: "Ej. Mamá, Pedro Pérez",
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        contentPadding: const EdgeInsets.all(12),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13, color: AppColors.cardText),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),

                                    // Banco
                                    const Text(
                                      "Banco Receptor",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedMobilePaymentBankCode ?? (venezuelanBanks.isNotEmpty ? venezuelanBanks.first["code"] : null),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(color: AppColors.cardText, fontSize: 13),
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
                                    const SizedBox(height: 12),

                                    // Cédula / RIF
                                    const Text(
                                      "Cédula / RIF",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedMobilePaymentIdPrefix,
                                              dropdownColor: Colors.white,
                                              style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: 13),
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
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _mobilePaymentIdCardController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: "Número de identificación",
                                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                                              contentPadding: const EdgeInsets.all(12),
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            style: const TextStyle(fontSize: 13, color: AppColors.cardText),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Teléfono
                                    const Text(
                                      "Número de Teléfono",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _mobilePaymentPhoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: "Ej. 04121234567",
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        contentPadding: const EdgeInsets.all(12),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13, color: AppColors.cardText),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    
                                    // Quick Save Checkbox
                                    if (!_checkIfContactExists(appState)) ...[
                                      const SizedBox(height: 12),
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
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() => _saveToContacts = !_saveToContacts);
                                              },
                                              child: const Text(
                                                "Guardar en contactos Pago Móvil",
                                                style: TextStyle(
                                                  fontSize: 12,
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
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],

                          // Note Field
                          Text(
                            "Nota / Concepto",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: "Ej. Pago de supermercado",
                              hintStyle: TextStyle(
                                color: AppColors.cardSubtitleText,
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 16),

                          // Date picker row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Fecha",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cardText,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.nestedTabTrackBg,
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
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
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  formatDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Category Grid Selector
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SELECCIONA UNA CATEGORÍA",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (filteredCategories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                              ),
                              child: Center(
                                child: Text(
                                  "No hay categorías de este tipo.",
                                  style: TextStyle(
                                    color: AppColors.cardSubtitleText,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: filteredCategories.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
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
                                            ? catColor.withOpacity(0.18)
                                            : catColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? catColor
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
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
                                                  : catColor.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _transactionType == TransactionType.income
                                                  ? Icons.arrow_upward
                                                  : Icons.arrow_downward,
                                              color: isSelected
                                                  ? Colors.white
                                                  : catColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Ninguna",
                                            style: TextStyle(
                                              fontSize: 11,
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

                                final cat = filteredCategories[index - 1];
                                final catColor = parseHexColor(cat.colorHex);
                                final isSelected =
                                    _selectedCategoryId == cat.id;

                                return GestureDetector(
                                  onTap: () {
                                    setState(
                                      () => _selectedCategoryId = cat.id,
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor.withOpacity(0.18)
                                          : catColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? catColor
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
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
                                                : catColor.withOpacity(0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            getIconData(cat.icon),
                                            color: isSelected
                                                ? Colors.white
                                                : catColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontSize: 11,
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
                    ),
                    if (widget.editingTransaction != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDeleteTransaction(context, appState),
                        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
                        label: const Text(
                          "Eliminar Movimiento",
                          style: TextStyle(
                            color: AppColors.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.expense, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Save / Cancel Buttons Row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: appState.useSlideToConfirm
                      ? SlideToConfirmButton(
                          enabled: (double.tryParse(_amountController.text) ?? 0.0) > 0,
                          label: widget.editingTransaction != null ? "Desliza para actualizar" : "Desliza para registrar",
                          onConfirmed: () => _handleConfirmAction(appState),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: ((double.tryParse(_amountController.text) ?? 0.0) <= 0)
                              ? null
                              : () => _handleConfirmAction(appState),
                          child: Text(
                            widget.editingTransaction != null ? "Guardar" : "Registrar",
                            style: const TextStyle(
                              fontSize: 15,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.cardSubtitleText,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClaymorphicCard(
        cornerRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: themeColor,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                isIncome ? "¡Ingreso Registrado!" : "¡Gasto Registrado!",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                "La transacción ha sido guardada en la app",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.cardSubtitleText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    "Tipo de Operación",
                    isIncome ? "Ingreso" : "Gasto",
                    themeColor,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Monto",
                    "${widget.transaction.currency.symbol} ${widget.transaction.amount.toStringAsFixed(2)}",
                    themeColor,
                    isBold: true,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta",
                    account.name,
                    AppColors.cardText,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Categoría",
                    category.name,
                    AppColors.cardText,
                  ),
                  if (widget.transaction.note.isNotEmpty) ...[
                    const Divider(height: 16),
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
              const SizedBox(height: 16),
              const Text(
                "PLAN DE AHORRO AUTOMÁTICO",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cardSubtitleText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.nestedTabTrackBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cardBorder.withOpacity(0.08),
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
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: parseHexColor(pocket.colorHex).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getIconData(pocket.icon),
                              color: parseHexColor(pocket.colorHex),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pocket.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                Text(
                                  ruleText,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: isProvisioned
                                  ? AppColors.income.withOpacity(0.15)
                                  : AppColors.primary.withOpacity(0.12),
                              foregroundColor: isProvisioned ? AppColors.income : AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isProvisioned) ...[
                                  const Icon(Icons.check_circle_outline_rounded, size: 12),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "Ahorrado",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ] else ...[
                                  const Icon(Icons.auto_awesome_rounded, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Ahorrar \$${suggestUSD.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.appState.setTabIndex(2); // Go to history screen
              },
              child: const Text(
                "Entendido",
                style: TextStyle(
                  fontSize: 13,
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
