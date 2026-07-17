import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../widgets/slide_to_confirm_button.dart';
import '../services/biometric_service.dart';

class PartialPaymentBottomSheet extends StatefulWidget {
  final PendingOccurrence occurrence;

  const PartialPaymentBottomSheet({
    super.key,
    required this.occurrence,
  });

  @override
  State<PartialPaymentBottomSheet> createState() => _PartialPaymentBottomSheetState();
}

class _PartialPaymentBottomSheetState extends State<PartialPaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _rateController = TextEditingController();

  String? _selectedAccountId;
  bool _isCustomRate = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _amountController.text = widget.occurrence.remainingAmount.toStringAsFixed(2);
    _rateController.text = appState.bcvRate.toStringAsFixed(2);
    
    // Set default account based on payment currency
    final p = widget.occurrence.payment;
    final defaultAccId = p.accountId ?? (p.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
    if (appState.accounts.any((a) => a.id == defaultAccId)) {
      _selectedAccountId = defaultAccId;
    } else if (appState.accounts.isNotEmpty) {
      _selectedAccountId = appState.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submitPartialPayment(
    AppState appState,
    RecurringPayment p,
    bool needsConversion,
    double activeRate,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) return;

    if (appState.useBiometrics) {
      final authenticated = await BiometricService.authenticate(
        reason: "Confirma tu identidad para registrar este pago parcial",
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Autenticación biométrica fallida o cancelada."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : "Pago Parcial: ${p.name}";

    await appState.registerPartialPayment(
      payment: p,
      partialAmount: amount,
      occurrenceDate: widget.occurrence.occurrenceDate,
      customNote: note,
      overrideAccountId: _selectedAccountId,
      customExchangeRate: needsConversion && _isCustomRate ? activeRate : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.type == TransactionType.income
                      ? "Abono de ${p.currency == CurrencyType.usd ? formatUSD(amount) : formatBs(amount)} registrado con éxito para el ingreso '${p.name}'"
                      : "Abono de ${p.currency == CurrencyType.usd ? formatUSD(amount) : formatBs(amount)} registrado con éxito para el gasto '${p.name}'",
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final p = widget.occurrence.payment;
    final isIncome = p.type == TransactionType.income;

    final targetAccount = appState.accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => appState.accounts.first);
    final needsConversion = p.currency == CurrencyType.usd && targetAccount.currency == CurrencyType.bsBCV;
    
    double inputAmount = double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (inputAmount > widget.occurrence.remainingAmount) {
      inputAmount = widget.occurrence.remainingAmount;
    }
    
    final activeRate = _isCustomRate 
        ? (double.tryParse(_rateController.text.replaceAll(',', '.')) ?? appState.bcvRate) 
        : appState.bcvRate;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.9),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + keyboardPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                SizedBox(height: 16),
                Text(
                  "Registrar Pago Parcial",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.cardText),
                ),
                SizedBox(height: 8),
                Text(
                  "Restante: ${p.currency == CurrencyType.usd ? formatUSD(widget.occurrence.remainingAmount) : formatBs(widget.occurrence.remainingAmount)}",
                  style: TextStyle(fontSize: 14, color: AppColors.cardSubtitleText, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

                ClaymorphicCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MONTO PARCIAL",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: p.currency == CurrencyType.usd ? "0.00 \$" : (p.currency == CurrencyType.eur ? "0.00 €" : "0.00 Bs."),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.black12),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Requerido";
                            final parsed = double.tryParse(val.replaceAll(',', '.'));
                            if (parsed == null || parsed <= 0) return "Monto inválido";
                            if (parsed > widget.occurrence.remainingAmount) return "Excede el restante";
                            return null;
                          },
                        ),
                        
                        SizedBox(height: 16),
                        Text(
                          "CUENTA ASOCIADA",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(getIconData(targetAccount.icon), size: 18, color: parseHexColor(targetAccount.colorHex)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  targetAccount.name,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: targetAccount.currency == CurrencyType.usd 
                                      ? AppColors.primary.withOpacity(0.1) 
                                      : AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  targetAccount.currency == CurrencyType.usd ? "USD" : "VES",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: targetAccount.currency == CurrencyType.usd 
                                        ? AppColors.primary 
                                        : AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (needsConversion) ...[
                          SizedBox(height: 16),
                          Text(
                            "TASA DE CAMBIO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.nestedTabTrackBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isCustomRate = false),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !_isCustomRate ? AppColors.nestedTabActiveBg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "BCV (${appState.bcvRate.toStringAsFixed(2)})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: !_isCustomRate ? AppColors.nestedTabActiveText : AppColors.nestedTabInactiveText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isCustomRate = true),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _isCustomRate ? AppColors.nestedTabActiveBg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Personalizada",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _isCustomRate ? AppColors.nestedTabActiveText : AppColors.nestedTabInactiveText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isCustomRate) ...[
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _rateController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: "Tasa personalizada Bs.",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (!_isCustomRate) return null;
                                if (val == null || val.isEmpty) return "Requerida";
                                if (double.tryParse(val.replaceAll(',', '.')) == null) return "Inválida";
                                return null;
                              },
                            ),
                          ],
                        ],

                        SizedBox(height: 16),
                        Text(
                          "NOTA (OPCIONAL)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _noteController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: "Ej. Adelanto de la semana",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.black12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                _buildSummarySection(p, inputAmount, targetAccount, activeRate, needsConversion, isIncome),

                SizedBox(height: 20),
                appState.useSlideToConfirm
                    ? SlideToConfirmButton(
                        enabled: inputAmount > 0 && inputAmount <= widget.occurrence.remainingAmount,
                        label: "Desliza para registrar parcial",
                        onConfirmed: () => _submitPartialPayment(appState, p, needsConversion, activeRate),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (inputAmount > 0 && inputAmount <= widget.occurrence.remainingAmount)
                              ? () => _submitPartialPayment(appState, p, needsConversion, activeRate)
                              : null,
                          child: Text(
                            "Registrar Parcial",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    RecurringPayment p,
    double inputAmount,
    Account targetAccount,
    double activeRate,
    bool needsConversion,
    bool isIncome,
  ) {
    final remainingAfter = widget.occurrence.remainingAmount - inputAmount;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RESUMEN DEL ADELANTO",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.cardSubtitleText,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            "Fecha Proyectada:",
            formatDate(widget.occurrence.occurrenceDate),
          ),
          _buildSummaryRow(
            "Cuenta destino:",
            targetAccount.name,
            icon: getIconData(targetAccount.icon),
            iconColor: parseHexColor(targetAccount.colorHex),
          ),
          _buildSummaryRow(
            "Monto original de la cuota:",
            p.currency == CurrencyType.usd ? formatUSD(p.amount) : formatBs(p.amount),
          ),
          if (widget.occurrence.partialAmountPaid > 0)
            _buildSummaryRow(
              "Abonado anteriormente:",
              p.currency == CurrencyType.usd 
                  ? formatUSD(widget.occurrence.partialAmountPaid) 
                  : formatBs(widget.occurrence.partialAmountPaid),
            ),
          _buildSummaryRow(
            "Adelanto (Abono hoy):",
            p.currency == CurrencyType.usd ? formatUSD(inputAmount) : formatBs(inputAmount),
            valueColor: AppColors.primary,
            isBoldValue: true,
          ),
          if (needsConversion)
            _buildSummaryRow(
              "Conversión en Bs. (Tasa ${activeRate.toStringAsFixed(2)}):",
              formatBs(inputAmount * activeRate),
              valueColor: AppColors.primary,
            ),
          Divider(height: 16, color: AppColors.cardBorderColor),
          _buildSummaryRow(
            "Restante para el próximo pago:",
            p.currency == CurrencyType.usd 
                ? formatUSD(remainingAfter) 
                : formatBs(remainingAfter),
            valueColor: isIncome ? AppColors.primary : AppColors.expense,
            isBoldValue: true,
            isLargeValue: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBoldValue = false,
    bool isLargeValue = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
          ),
          Spacer(),
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? AppColors.cardSubtitleText),
            SizedBox(width: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: isLargeValue ? 14 : 12,
              fontWeight: (isBoldValue || isLargeValue) ? FontWeight.w900 : FontWeight.bold,
              color: valueColor ?? AppColors.cardText,
            ),
          ),
        ],
      ),
    );
  }
}
