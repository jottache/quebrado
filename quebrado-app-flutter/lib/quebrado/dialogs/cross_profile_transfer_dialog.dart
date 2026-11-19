import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../services/db_helper.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import '../services/biometric_service.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class CrossProfileTransferBottomSheet extends StatefulWidget {
  final AppState appState;

  const CrossProfileTransferBottomSheet({
    super.key,
    required this.appState,
  });

  @override
  State<CrossProfileTransferBottomSheet> createState() => _CrossProfileTransferBottomSheetState();
}

class _CrossProfileTransferBottomSheetState extends State<CrossProfileTransferBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedSourceAccountId;
  String? _selectedTargetProfileId;
  String? _selectedTargetAccountId;

  List<Map<String, String>> _availableTargetProfiles = [];
  List<Account> _targetProfileAccounts = [];
  bool _isLoadingAccounts = false;

  @override
  void initState() {
    super.initState();
    if (widget.appState.accounts.isNotEmpty) {
      _selectedSourceAccountId = widget.appState.accounts.first.id;
    }
    
    // Filtrar perfil actual
    _availableTargetProfiles = widget.appState.profiles
        .where((p) => p['id'] != widget.appState.activeDbName)
        .toList();

    if (_availableTargetProfiles.isNotEmpty) {
      _selectedTargetProfileId = _availableTargetProfiles.first['id'];
      _loadTargetAccounts(_selectedTargetProfileId!);
    }
  }

  Future<void> _loadTargetAccounts(String profileId) async {
    setState(() {
      _isLoadingAccounts = true;
      _targetProfileAccounts = [];
      _selectedTargetAccountId = null;
    });

    try {
      final accounts = await DatabaseHelper.instance.getAccountsForProfile(profileId);
      final sourceAcc = _getSourceAccount();
      
      setState(() {
        if (sourceAcc != null) {
          _targetProfileAccounts = accounts.where((a) => a.currency == sourceAcc.currency).toList();
        } else {
          _targetProfileAccounts = accounts;
        }
        
        if (_targetProfileAccounts.isNotEmpty) {
          _selectedTargetAccountId = _targetProfileAccounts.first.id;
        } else {
          _selectedTargetAccountId = null;
        }
      });
    } catch (e) {
      debugPrint("Error loading target accounts: $e");
    } finally {
      setState(() {
        _isLoadingAccounts = false;
      });
    }
  }

  Account? _getSourceAccount() {
    if (_selectedSourceAccountId == null) return null;
    return widget.appState.accounts.firstWhere(
      (a) => a.id == _selectedSourceAccountId,
      orElse: () => widget.appState.accounts.first,
    );
  }

  Account? _getTargetAccount() {
    if (_selectedTargetAccountId == null) return null;
    return _targetProfileAccounts.firstWhere(
      (a) => a.id == _selectedTargetAccountId,
      orElse: () => _targetProfileAccounts.first,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.appState.useBiometrics || widget.appState.usePinSecurity) {
      final authenticated = await widget.appState.verifySecurityAuth(
        context,
        reason: "Confirma tu identidad para transferir entre contabilidades",
      );
      if (!authenticated) return;
    }
    
    if (_selectedSourceAccountId == null || _selectedTargetProfileId == null || _selectedTargetAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Por favor selecciona todos los campos"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("El monto debe ser mayor a cero"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final sourceAcc = _getSourceAccount()!;
    final targetAcc = _getTargetAccount()!;
    final targetProfile = _availableTargetProfiles.firstWhere((p) => p['id'] == _selectedTargetProfileId);
    
    // Check if source account has enough balance (optional, but good practice)
    if (sourceAcc.balance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saldo insuficiente en la cuenta de origen"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    // Execute transfer
    await widget.appState.performCrossProfileTransfer(
      targetProfileId: targetProfile['id']!,
      targetProfileName: targetProfile['name'] ?? 'Otro libro',
      sourceAccountId: sourceAcc.id,
      targetAccount: targetAcc,
      amount: amount,
      currency: sourceAcc.currency,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Transferencia enviada a ${targetProfile['name']}"),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.xxl,
        right: OrtizSpace.xxl,
        top: OrtizSpace.xxl,
        bottom: keyboardPadding > 0 ? keyboardPadding + OrtizSpace.xxl : OrtizSpace.xxxl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Transferir a otro libro",
                    style: TextStyle(
                      fontSize: OrtizFontSize.title,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: OrtizSpace.sm),
              Text(
                "Mueve dinero desde tu contabilidad actual hacia otra contabilidad.",
                style: TextStyle(
                  fontSize: OrtizFontSize.body,
                  color: OrtizPalette.muted,
                ),
              ),
              SizedBox(height: OrtizSpace.xxl),

              if (_availableTargetProfiles.isEmpty)
                Container(
                  padding: EdgeInsets.all(OrtizSpace.lg),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                  ),
                  child: Text(
                    "No tienes otros libros contables creados. Crea uno primero en la configuración.",
                    style: TextStyle(color: AppColors.expense),
                  ),
                )
              else ...[
                // Amount Input
                // Campos sin tarjeta: el tema les da fondo y borde.
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Monto a transferir",
                    hintText: _getSourceAccount()?.currency == CurrencyType.usd ? "0.00 \$" : (_getSourceAccount()?.currency == CurrencyType.eur ? "0.00 €" : "0.00 Bs."),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Ingresa un monto";
                    final parsed = double.tryParse(val);
                    if (parsed == null) return "Monto inválido";
                    final sourceAcc = _getSourceAccount();
                    if (sourceAcc != null && parsed > sourceAcc.balance) {
                      return "Saldo insuficiente";
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: OrtizSpace.lg),

                // Source Account
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceAccountId,
                  decoration: const InputDecoration(
                    labelText: "Cuenta Origen (Actual)",
                  ),
                  items: widget.appState.accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text("${acc.name} (${acc.currency == CurrencyType.usd ? '\$' : 'Bs'})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSourceAccountId = val;
                    });
                    if (_selectedTargetProfileId != null) {
                      _loadTargetAccounts(_selectedTargetProfileId!);
                    }
                  },
                ),
                if (_getSourceAccount() != null)
                  Padding(
                    padding: EdgeInsets.only(top: OrtizSpace.sm, left: OrtizSpace.lg),
                    child: Text(
                      "Saldo disponible: ${_getSourceAccount()!.currency == CurrencyType.usd ? '\$' : 'Bs'}${_getSourceAccount()!.balance.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        color: OrtizPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                SizedBox(height: OrtizSpace.lg),

                Divider(),
                SizedBox(height: OrtizSpace.lg),

                // Target Profile
                DropdownButtonFormField<String>(
                  initialValue: _selectedTargetProfileId,
                  decoration: const InputDecoration(
                    labelText: "Libro Destino",
                  ),
                  items: _availableTargetProfiles.map((p) {
                    return DropdownMenuItem(
                      value: p['id'],
                      child: Text(p['name'] ?? 'Desconocido'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedTargetProfileId) {
                      setState(() {
                        _selectedTargetProfileId = val;
                      });
                      _loadTargetAccounts(val);
                    }
                  },
                ),
                SizedBox(height: OrtizSpace.lg),

                // Target Account
                if (_isLoadingAccounts)
                  Center(child: CircularProgressIndicator())
                else if (_targetProfileAccounts.isEmpty)
                  Container(
                    padding: EdgeInsets.all(OrtizSpace.lg),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: Text(
                      "Este libro no tiene cuentas disponibles.",
                      style: TextStyle(color: AppColors.expense),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTargetAccountId,
                    decoration: const InputDecoration(
                      labelText: "Cuenta Destino",
                    ),
                    items: _targetProfileAccounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Text("${acc.name} (${acc.currency == CurrencyType.usd ? '\$' : 'Bs'})"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedTargetAccountId = val;
                      });
                    },
                  ),

                SizedBox(height: OrtizSpace.xxxl),

                // Confirm Button
                ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: OrtizPalette.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.block),
                          ),
                          elevation: 0,
                        ),
                        onPressed: (_targetProfileAccounts.isEmpty || (double.tryParse(_amountController.text) ?? 0.0) <= 0)
                            ? null
                            : _handleTransfer,
                        child: Text(
                          "Transferir",
                          style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
