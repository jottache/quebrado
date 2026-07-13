import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../services/db_helper.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/slide_to_confirm_button.dart';
import '../services/biometric_service.dart';
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
    
    if (widget.appState.useBiometrics) {
      final authenticated = await BiometricService.authenticate();
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
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: keyboardPadding > 0 ? keyboardPadding + 24 : 32,
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
                      fontSize: 20,
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
              SizedBox(height: 8),
              Text(
                "Mueve dinero desde tu contabilidad actual hacia otra contabilidad.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24),

              if (_availableTargetProfiles.isEmpty)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "No tienes otros libros contables creados. Crea uno primero en la configuración.",
                    style: TextStyle(color: AppColors.expense),
                  ),
                )
              else ...[
                // Amount Input
                ClaymorphicCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Monto a transferir",
                      border: InputBorder.none,
                      suffixText: _getSourceAccount()?.currency == CurrencyType.usd ? "USD" : "Bs",
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
                ),
                SizedBox(height: 16),

                // Source Account
                ClaymorphicCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSourceAccountId,
                    decoration: InputDecoration(
                      labelText: "Cuenta Origen (Actual)",
                      border: InputBorder.none,
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
                ),
                if (_getSourceAccount() != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 16.0),
                    child: Text(
                      "Saldo disponible: ${_getSourceAccount()!.currency == CurrencyType.usd ? '\$' : 'Bs'}${_getSourceAccount()!.balance.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                SizedBox(height: 16),

                Divider(),
                SizedBox(height: 16),

                // Target Profile
                ClaymorphicCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTargetProfileId,
                    decoration: InputDecoration(
                      labelText: "Libro Destino",
                      border: InputBorder.none,
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
                ),
                SizedBox(height: 16),

                // Target Account
                if (_isLoadingAccounts)
                  Center(child: CircularProgressIndicator())
                else if (_targetProfileAccounts.isEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Este libro no tiene cuentas disponibles.",
                      style: TextStyle(color: AppColors.expense),
                    ),
                  )
                else
                  ClaymorphicCard(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTargetAccountId,
                      decoration: InputDecoration(
                        labelText: "Cuenta Destino",
                        border: InputBorder.none,
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
                  ),

                SizedBox(height: 32),

                // Confirm Button
                widget.appState.useSlideToConfirm
                    ? SlideToConfirmButton(
                        enabled: _targetProfileAccounts.isNotEmpty && 
                                 (double.tryParse(_amountController.text) ?? 0.0) > 0,
                        label: "Desliza para transferir",
                        onConfirmed: _handleTransfer,
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        onPressed: (_targetProfileAccounts.isEmpty || (double.tryParse(_amountController.text) ?? 0.0) <= 0)
                            ? null
                            : _handleTransfer,
                        child: Text(
                          "Transferir",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
