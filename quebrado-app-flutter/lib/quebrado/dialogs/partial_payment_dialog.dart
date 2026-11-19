import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/currency_pill.dart';
import '../widgets/helpers.dart';
import '../services/biometric_service.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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

    if (appState.useBiometrics || appState.usePinSecurity) {
      final authenticated = await appState.verifySecurityAuth(
        context,
        reason: "Confirma tu identidad para registrar este pago parcial",
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
              const Icon(Icons.check_circle_outline_rounded, color: OrtizPalette.onAccent),
              const SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  p.type == TransactionType.income
                      ? "Abono de ${p.currency == CurrencyType.usd ? formatUSD(amount) : formatBs(amount)} registrado con éxito para el ingreso '${p.name}'"
                      : "Abono de ${p.currency == CurrencyType.usd ? formatUSD(amount) : formatBs(amount)} registrado con éxito para el gasto '${p.name}'",
                  style: const TextStyle(color: OrtizPalette.onAccent),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.field)),
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

    final targetAccount = appState.accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => appState.accounts.isNotEmpty
          ? appState.accounts.first
          : Account(
              id: _selectedAccountId ?? 'default_usd',
              name: 'Cuenta',
              currency: p.currency,
              balance: 0.0,
              colorHex: '#1F6F5F',
              icon: 'wallet',
            ),
    );
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
        left: OrtizSpace.xl,
        right: OrtizSpace.xl,
        top: OrtizSpace.xl,
        bottom: OrtizSpace.xl + keyboardPadding,
      ),
      decoration: const BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      color: AppColors.cardBorderColor,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                const SizedBox(height: OrtizSpace.lg),
                const Text(
                  "Registrar Pago Parcial",
                  style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.bold, color: AppColors.cardText),
                ),
                const SizedBox(height: OrtizSpace.sm),
                Text(
                  "Restante: ${p.currency == CurrencyType.usd ? formatUSD(widget.occurrence.remainingAmount) : formatBs(widget.occurrence.remainingAmount)}",
                  style: const TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardSubtitleText, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: OrtizSpace.xl),

                OrtizSection(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "MONTO PARCIAL",
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: p.currency == CurrencyType.usd ? "0.00 \$" : (p.currency == CurrencyType.eur ? "0.00 €" : "0.00 Bs."),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.field)),
                              borderSide: BorderSide(color: AppColors.cardBorderColor),
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
                        
                        SizedBox(height: OrtizSpace.lg),
                        Text(
                          "CUENTA ASOCIADA",
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: OrtizSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorderColor),
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            color: OrtizPalette.surfaceHigh,
                          ),
                          child: Row(
                            children: [
                              Icon(getIconData(targetAccount.icon), size: OrtizIconSize.sm, color: parseHexColor(targetAccount.colorHex)),
                              const SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Text(
                                  targetAccount.name,
                                  style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ),
                              // Distintivo de moneda con el color fijo de la moneda
                              // (`currencyColor`), no con un segundo acento.
                              Flexible(
                                child: OrtizPill(
                                  label: targetAccount.currency == CurrencyType.usd ? "USD" : "VES",
                                  color: currencyColor(targetAccount.currency),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (needsConversion) ...[
                          SizedBox(height: OrtizSpace.lg),
                          Text(
                            "TASA DE CAMBIO",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.sm),
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.xs),
                            decoration: BoxDecoration(
                              color: AppColors.nestedTabTrackBg,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isCustomRate = false),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: !_isCustomRate ? AppColors.nestedTabActiveBg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "BCV (${appState.bcvRate.toStringAsFixed(2)})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
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
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: _isCustomRate ? AppColors.nestedTabActiveBg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Personalizada",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
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
                            SizedBox(height: OrtizSpace.md),
                            TextFormField(
                              controller: _rateController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: "Tasa personalizada Bs.",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
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

                        SizedBox(height: OrtizSpace.lg),
                        Text(
                          "NOTA (OPCIONAL)",
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: OrtizSpace.sm),
                        TextFormField(
                          controller: _noteController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: "Ej. Adelanto de la semana",
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.field)),
                              borderSide: BorderSide(color: AppColors.cardBorderColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                _buildSummarySection(p, inputAmount, targetAccount, activeRate, needsConversion, isIncome),

                const SizedBox(height: OrtizSpace.xl),
                SizedBox(
                        width: double.infinity,
                        height: OrtizSize.minTouch,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: OrtizPalette.onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.field),
                            ),
                          ),
                          onPressed: (inputAmount > 0 && inputAmount <= widget.occurrence.remainingAmount)
                              ? () => _submitPartialPayment(appState, p, needsConversion, activeRate)
                              : null,
                          child: const Text(
                            "Registrar Parcial",
                            style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
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
    // Mismo formato que antes: USD con `formatUSD`, cualquier otra moneda con `formatBs`.
    final String Function(double) fmt = p.currency == CurrencyType.usd ? formatUSD : formatBs;

    return OrtizSection(
      surface: true,
      children: [
        const Text(
          "RESUMEN DEL ADELANTO",
          style: TextStyle(
            fontSize: OrtizFontSize.caption,
            fontWeight: FontWeight.w900,
            color: AppColors.cardSubtitleText,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: OrtizSpace.md),
        _buildSummaryRow(
          "Fecha Proyectada:",
          value: formatDate(widget.occurrence.occurrenceDate),
        ),
        _buildSummaryRow(
          "Cuenta destino:",
          value: targetAccount.name,
          icon: getIconData(targetAccount.icon),
          iconColor: parseHexColor(targetAccount.colorHex),
        ),
        _buildSummaryRow(
          "Monto original de la cuota:",
          amount: p.amount,
          format: fmt,
        ),
        if (widget.occurrence.partialAmountPaid > 0)
          _buildSummaryRow(
            "Abonado anteriormente:",
            amount: widget.occurrence.partialAmountPaid,
            format: fmt,
          ),
        _buildSummaryRow(
          "Adelanto (Abono hoy):",
          amount: inputAmount,
          format: fmt,
          valueColor: AppColors.primary,
          isBoldValue: true,
        ),
        if (needsConversion)
          _buildSummaryRow(
            "Conversión en Bs. (Tasa ${activeRate.toStringAsFixed(2)}):",
            amount: inputAmount * activeRate,
            format: formatBs,
            valueColor: AppColors.primary,
          ),
        const Divider(height: OrtizSpace.lg, color: AppColors.cardBorderColor),
        _buildSummaryRow(
          "Restante para el próximo pago:",
          amount: remainingAfter,
          format: fmt,
          valueColor: isIncome ? AppColors.primary : AppColors.expense,
          isBoldValue: true,
          isLargeValue: true,
        ),
      ],
    );
  }

  /// Fila del resumen: [value] para texto, o [amount] + [format] para un monto
  /// (se pinta con `OrtizAmount`, cifras tabulares).
  Widget _buildSummaryRow(
    String label, {
    String? value,
    double? amount,
    String Function(double)? format,
    Color? valueColor,
    bool isBoldValue = false,
    bool isLargeValue = false,
    IconData? icon,
    Color? iconColor,
  }) {
    final valueStyle = TextStyle(
      fontSize: isLargeValue ? OrtizFontSize.body : OrtizFontSize.bodySm,
      fontWeight: (isBoldValue || isLargeValue) ? FontWeight.w900 : FontWeight.bold,
      color: valueColor ?? AppColors.cardText,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
          ),
          const Spacer(),
          if (icon != null) ...[
            Icon(icon, size: OrtizIconSize.xs, color: iconColor ?? AppColors.cardSubtitleText),
            const SizedBox(width: OrtizSpace.xs),
          ],
          if (amount != null)
            OrtizAmount(
              value: amount,
              currencySymbol: '',
              format: format,
              style: OrtizType.amount.merge(valueStyle),
            )
          else
            Text(value ?? '', style: valueStyle),
        ],
      ),
    );
  }
}
