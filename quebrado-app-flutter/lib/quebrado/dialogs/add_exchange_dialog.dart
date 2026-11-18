import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';
import '../models/saving_pocket.dart';
import '../models/transaction.dart';
import 'add_transaction_dialog.dart';
import '../models/recurring_payment.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class AddExchangeBottomSheet extends StatefulWidget {
  final String? initialAccountId;

  /// Prellenado desde un cambio sugerido de la proyección (vender $ para pagar en Bs).
  final String? initialUsdAccountId;
  final String? initialVesAccountId;
  final double? initialAmountUSD;
  final double? initialRate;
  final String? initialNote;

  const AddExchangeBottomSheet({
    super.key,
    this.initialAccountId,
    this.initialUsdAccountId,
    this.initialVesAccountId,
    this.initialAmountUSD,
    this.initialRate,
    this.initialNote,
  });

  @override
  State<AddExchangeBottomSheet> createState() => _AddExchangeBottomSheetState();
}

class _AddExchangeBottomSheetState extends State<AddExchangeBottomSheet> {
  bool _isVenta = true; // true = Venta ($ -> Bs.), false = Compra (Bs. -> $)
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedUsdAccountId;
  String? _selectedVesAccountId;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);

    // Filter accounts by currency
    final usdAccounts = appState.accounts.where((acc) => acc.currency == CurrencyType.usd).toList();
    final vesAccounts = appState.accounts.where((acc) => acc.currency == CurrencyType.bsBCV).toList();

    // Default rate selection from parallel rate reference
    _rateController.text = appState.parallelRate.toStringAsFixed(2);

    // Initial Account Pre-selection logic
    final initAccId = widget.initialAccountId;
    if (initAccId != null) {
      final initialAcc = appState.accounts.firstWhere((acc) => acc.id == initAccId, orElse: () => appState.accounts.first);
      if (initialAcc.currency == CurrencyType.usd) {
        _selectedUsdAccountId = initAccId;
        _isVenta = true;
      } else {
        _selectedVesAccountId = initAccId;
        _isVenta = false;
      }
    }

    // Cambio sugerido por la proyección: venta de $ a Bs con todo prellenado
    if (widget.initialAmountUSD != null) {
      _isVenta = true;
      _amountController.text = widget.initialAmountUSD!.toStringAsFixed(2);
    }
    if (widget.initialRate != null && widget.initialRate! > 0) {
      _rateController.text = widget.initialRate!.toStringAsFixed(2);
    }
    if (widget.initialNote != null) _noteController.text = widget.initialNote!;
    if (widget.initialUsdAccountId != null && usdAccounts.any((a) => a.id == widget.initialUsdAccountId)) {
      _selectedUsdAccountId = widget.initialUsdAccountId;
    }
    if (widget.initialVesAccountId != null && vesAccounts.any((a) => a.id == widget.initialVesAccountId)) {
      _selectedVesAccountId = widget.initialVesAccountId;
    }

    if (_selectedUsdAccountId == null && usdAccounts.isNotEmpty) {
      _selectedUsdAccountId = usdAccounts.first.id;
    }
    if (_selectedVesAccountId == null && vesAccounts.isNotEmpty) {
      _selectedVesAccountId = vesAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _processExchange(AppState appState) {
    final amountUSD = double.tryParse(_amountController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (amountUSD <= 0 || rate <= 0 || _selectedUsdAccountId == null || _selectedVesAccountId == null) return;

    final usdAcc = appState.accounts.firstWhere((acc) => acc.id == _selectedUsdAccountId);
    final vesAcc = appState.accounts.firstWhere((acc) => acc.id == _selectedVesAccountId);

    appState.exchangeCurrency(
      usdAccountId: _selectedUsdAccountId!,
      vesAccountId: _selectedVesAccountId!,
      amountUSD: amountUSD,
      exchangeRate: rate,
      isVenta: _isVenta,
      note: _noteController.text.trim(),
    );

    final isVentaVal = _isVenta;
    final amountVESVal = amountUSD * rate;
    final usdAccName = usdAcc.name;
    final vesAccName = vesAcc.name;
    final navigator = Navigator.of(context);
    final selectedVesAccId = _selectedVesAccountId!;

    navigator.pop();

    if (isVentaVal) {
      showModalBottomSheet(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ExchangePaymentOptionsBottomSheet(
          vesAccountId: selectedVesAccId,
          amountVES: amountVESVal,
          amountUSD: amountUSD,
          rate: rate,
          usdAccountName: usdAccName,
          vesAccountName: vesAccName,
        ),
      );
    } else {
      showDialog(
        context: navigator.context,
        barrierDismissible: false,
        builder: (context) => ExchangeSuccessDialog(
          isVenta: isVentaVal,
          amountUSD: amountUSD,
          rate: rate,
          amountVES: amountVESVal,
          usdAccountName: usdAccName,
          vesAccountName: vesAccName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final usdAccounts = appState.accounts.where((acc) => acc.currency == CurrencyType.usd).toList();
    final vesAccounts = appState.accounts.where((acc) => acc.currency == CurrencyType.bsBCV).toList();

    final amountUSD = double.tryParse(_amountController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final bcv = appState.bcvRate;
    final parallel = appState.parallelRate;

    final amountVES = amountUSD * rate;
    final bcvEquiv = amountUSD * bcv;
    final parallelEquiv = amountUSD * parallel;

    // Metrics Calculations
    double diffBCV = 0.0;
    double pctBCV = 0.0;
    bool isFavorableBCV = false;

    double diffParallel = 0.0;
    double pctParallel = 0.0;
    bool isFavorableParallel = false;

    if (amountUSD > 0 && rate > 0) {
      if (_isVenta) {
        // Vender USD (recibir bolívares): Favorable si tasa > referencia (obtenemos más bolívares)
        diffBCV = amountVES - bcvEquiv;
        pctBCV = bcv > 0 ? ((rate - bcv) / bcv) * 100 : 0.0;
        isFavorableBCV = rate >= bcv;

        diffParallel = amountVES - parallelEquiv;
        pctParallel = parallel > 0 ? ((rate - parallel) / parallel) * 100 : 0.0;
        isFavorableParallel = rate >= parallel;
      } else {
        // Comprar USD (pagar bolívares): Favorable si tasa < referencia (pagamos menos bolívares)
        diffBCV = bcvEquiv - amountVES;
        pctBCV = bcv > 0 ? ((bcv - rate) / bcv) * 100 : 0.0;
        isFavorableBCV = rate <= bcv;

        diffParallel = parallelEquiv - amountVES;
        pctParallel = parallel > 0 ? ((parallel - rate) / parallel) * 100 : 0.0;
        isFavorableParallel = rate <= parallel;
      }
    }

    final isValid = amountUSD > 0 && rate > 0 && _selectedUsdAccountId != null && _selectedVesAccountId != null;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Compra / Venta de Divisas",
                  style: TextStyle(
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
            SizedBox(height: OrtizSpace.md),

            // Tab Selector: Venta vs Compra
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
                      onTap: () => setState(() => _isVenta = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: _isVenta ? OrtizPalette.bg : Colors.transparent,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Venta \$",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVenta = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: !_isVenta ? OrtizPalette.bg : Colors.transparent,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Compra \$",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: OrtizSpace.lg),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Account selection card
                    Padding(
                      padding: OrtizSection.gap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CUENTAS DE LA OPERACIÓN",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // USD Account Selector
                          Text(
                            _isVenta ? "Cuenta USD de Origen (Debitar \$)" : "Cuenta USD de Destino (Acreditar \$)",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedUsdAccountId,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide(color: OrtizPalette.line),
                              ),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                            ),
                            dropdownColor: AppColors.cardBackground,
                            items: usdAccounts.map((acc) {
                              final accColor = parseHexColor(acc.colorHex);
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(color: accColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      child: Icon(getIconData(acc.icon), color: accColor, size: OrtizIconSize.xs),
                                    ),
                                    SizedBox(width: OrtizSpace.sm),
                                    Text(
                                      "${acc.name} (${formatUSD(acc.balance)})",
                                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (accId) => setState(() => _selectedUsdAccountId = accId),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // VES Account Selector
                          Text(
                            _isVenta ? "Cuenta VES de Destino (Acreditar Bs.)" : "Cuenta VES de Origen (Debitar Bs.)",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedVesAccountId,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide(color: OrtizPalette.line),
                              ),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                            ),
                            dropdownColor: AppColors.cardBackground,
                            items: vesAccounts.map((acc) {
                              final accColor = parseHexColor(acc.colorHex);
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(color: accColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      child: Icon(getIconData(acc.icon), color: accColor, size: OrtizIconSize.xs),
                                    ),
                                    SizedBox(width: OrtizSpace.sm),
                                    Text(
                                      "${acc.name} (${formatBs(acc.balance)})",
                                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (accId) => setState(() => _selectedVesAccountId = accId),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.lg),

                    // 2. Data Entry Card
                    Padding(
                      padding: OrtizSection.gap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MONTOS Y TASA PACTADA",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // Amount input
                          Text(
                            "Monto a Cambiar (USD)",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "0.00",
                              prefixIcon: Icon(Icons.attach_money_rounded),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // Rate input
                          Text(
                            "Tasa de Cambio Pactada (Bs. / \$)",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _rateController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "0.00",
                              prefixIcon: Icon(Icons.show_chart_rounded),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.lg),

                    // 3. Live Metrics Card
                    if (amountUSD > 0 && rate > 0) ...[
                      Padding(
                        padding: OrtizSection.gap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "CÁLCULOS Y COMPARATIVAS DEL DÍA",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.lg),

                            // Total converted
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Monto Resultante:",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                                Text(
                                  formatBs(amountVES),
                                  style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.w900, color: AppColors.primary),
                                ),
                              ],
                            ),
                            Divider(height: 24),

                            // BCV Reference Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Tasa Oficial BCV (${formatBs(bcv)}):",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  formatBs(bcvEquiv),
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Diferencia vs BCV:",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  diffBCV == 0
                                      ? "Sin diferencia"
                                      : "${isFavorableBCV ? '+' : '-'}${formatBs(diffBCV.abs())} (${pctBCV.abs().toStringAsFixed(2)}%)",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: diffBCV == 0
                                        ? AppColors.cardSubtitleText
                                        : (isFavorableBCV ? AppColors.income : AppColors.expense),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 24),

                            // Parallel Reference Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Tasa Paralelo (${formatBs(parallel)}):",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  formatBs(parallelEquiv),
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Diferencia vs Paralelo:",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  diffParallel == 0
                                      ? "Sin diferencia"
                                      : "${isFavorableParallel ? '+' : '-'}${formatBs(diffParallel.abs())} (${pctParallel.abs().toStringAsFixed(2)}%)",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: diffParallel == 0
                                        ? AppColors.cardSubtitleText
                                        : (isFavorableParallel ? AppColors.income : AppColors.expense),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                    ],

                    // 4. Note concept card
                    Padding(
                      padding: OrtizSection.gap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DESCRIPCIÓN DE LA OPERACIÓN",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: "Ej. Venta a tasa paralela para pago de servicios",
                              hintStyle: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
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
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xxxl),
                  ],
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Save / Cancel row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: !isValid ? null : () => _processExchange(appState),
                    child: Text(
                      "Procesar Cambio",
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
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

class ExchangeSuccessDialog extends StatelessWidget {
  final bool isVenta;
  final double amountUSD;
  final double rate;
  final double amountVES;
  final String usdAccountName;
  final String vesAccountName;
  final String? confirmedPaymentName;

  const ExchangeSuccessDialog({
    super.key,
    required this.isVenta,
    required this.amountUSD,
    required this.rate,
    required this.amountVES,
    required this.usdAccountName,
    required this.vesAccountName,
    this.confirmedPaymentName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
      child: Padding(
        padding: EdgeInsets.all(OrtizSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            SizedBox(height: OrtizSpace.lg),
            Text(
              confirmedPaymentName != null ? "¡Cambio y Pago Registrados!" : "¡Cambio Registrado!",
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              confirmedPaymentName != null
                  ? "Venta y pago de servicio confirmados"
                  : (isVenta ? "Venta de divisa procesada" : "Compra de divisa procesada"),
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
              ),
            ),
            SizedBox(height: OrtizSpace.xl),
            Container(
              padding: EdgeInsets.all(OrtizSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(OrtizRadius.block),
                border: Border.all(color: OrtizPalette.line),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    "Operación",
                    isVenta ? "Venta \$" : "Compra \$",
                    isVenta ? AppColors.expense : AppColors.income,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Monto USD",
                    formatUSD(amountUSD),
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Tasa de cambio",
                    formatRate(rate),
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Monto VES",
                    formatBs(amountVES),
                    AppColors.primary,
                    isBold: true,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta USD",
                    usdAccountName,
                    AppColors.cardText,
                  ),
                  Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta VES",
                    vesAccountName,
                    AppColors.cardText,
                  ),
                  if (confirmedPaymentName != null) ...[
                    Divider(height: 16),
                    _buildDetailRow(
                      "Gasto Pagado",
                      confirmedPaymentName!,
                      AppColors.expense,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: OrtizSpace.xxl),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<AppState>(context, listen: false).setTabIndex(2);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    ),
                    child: Text(
                      "Cerrar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.muted,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<AppState>(context, listen: false).setTabIndex(2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                    ),
                    child: Text(
                      "Ver transacción",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: OrtizFontSize.bodySm,
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

  Widget _buildDetailRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            color: AppColors.cardSubtitleText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class ExchangePaymentOptionsBottomSheet extends StatefulWidget {
  final String vesAccountId;
  final double amountVES;
  final double amountUSD;
  final double rate;
  final String usdAccountName;
  final String vesAccountName;

  const ExchangePaymentOptionsBottomSheet({
    super.key,
    required this.vesAccountId,
    required this.amountVES,
    required this.amountUSD,
    required this.rate,
    required this.usdAccountName,
    required this.vesAccountName,
  });

  @override
  State<ExchangePaymentOptionsBottomSheet> createState() => _ExchangePaymentOptionsBottomSheetState();
}

class _ExchangePaymentOptionsBottomSheetState extends State<ExchangePaymentOptionsBottomSheet> {
  final Set<PendingOccurrence> _selectedOccurrences = {};

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final bcv = appState.bcvRate;
    final vesPendingOccurrences = appState.pendingPaymentsToday.where((occ) {
      final p = occ.payment;
      if (p.type != TransactionType.expense) return false;
      
      final costVES = p.currency == CurrencyType.usd ? p.amount * bcv : p.amount;
      if (costVES > widget.amountVES) return false;

      if (p.currency == CurrencyType.bsBCV) return true;
      if (p.accountId != null) {
        final matchingAccounts = appState.accounts.where((a) => a.id == p.accountId);
        if (matchingAccounts.isNotEmpty && matchingAccounts.first.currency == CurrencyType.bsBCV) {
          return true;
        }
      }
      return false;
    }).toList();

    // Calculate remaining VES based on selected items
    double remainingVES = widget.amountVES;
    for (var occ in _selectedOccurrences) {
      // Make sure it still exists in the active pending list
      if (vesPendingOccurrences.contains(occ)) {
        final p = occ.payment;
        final costVES = p.currency == CurrencyType.usd ? p.amount * bcv : p.amount;
        remainingVES -= costVES;
      }
    }

    final hasSelection = _selectedOccurrences.isNotEmpty;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xxxl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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
            SizedBox(height: OrtizSpace.xl),
            Text(
              "¿Deseas registrar un pago?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.w900,
                color: OrtizPalette.fg,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              "Se recibieron ${formatBs(widget.amountVES)} en ${widget.vesAccountName}. Puedes usar estos fondos para pagar un gasto pendiente o registrar uno nuevo.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
              ),
            ),
            SizedBox(height: OrtizSpace.xl),
            if (hasSelection) ...[
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                  ),
                  child: Text(
                    "Fondos restantes: ${formatBs(remainingVES)}",
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.lg),
            ],

            // Scrollable area for options
            Flexible(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vesPendingOccurrences.isNotEmpty) ...[
                      Text(
                        "PAGOS RECURRENTES PENDIENTES (VES)",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      ...vesPendingOccurrences.map((occ) {
                        final p = occ.payment;
                        final pocket = appState.pockets.cast<SavingPocket?>().firstWhere(
                          (pkt) => pkt?.id == p.pocketId,
                          orElse: () => null,
                        );
                        final cardColor = parseHexColor(p.colorHex);
                        
                        // Check if selected
                        final isSelected = _selectedOccurrences.contains(occ);
                        final costVES = p.currency == CurrencyType.usd ? p.amount * bcv : p.amount;
                        
                        // Disabled if not selected and cost exceeds remaining VES
                        final isDisabled = !isSelected && costVES > remainingVES;

                        return Padding(
                          padding: EdgeInsets.only(bottom: OrtizSpace.xs),
                          child: Opacity(
                            opacity: isDisabled ? 0.45 : 1.0,
                            child: OrtizListRow(
                              selected: isSelected,
                              onTap: isDisabled
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedOccurrences.remove(occ);
                                        } else {
                                          _selectedOccurrences.add(occ);
                                        }
                                      });
                                    },
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.primary,
                                      onChanged: isDisabled
                                          ? null
                                          : (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedOccurrences.add(occ);
                                                } else {
                                                  _selectedOccurrences.remove(occ);
                                                }
                                              });
                                            },
                                    ),
                                    SizedBox(width: OrtizSpace.xs),
                                    Icon(
                                      getIconData(p.icon),
                                      color: cardColor,
                                      size: OrtizIconSize.md,
                                    ),
                                ],
                              ),
                              title: p.name,
                              subtitle: pocket != null ? "Bolsillo: ${pocket.name}" : null,
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  OrtizAmount(
                                    value: p.amount,
                                    currencySymbol: p.currency.symbol,
                                    format: p.currency == CurrencyType.usd ? formatUSD : formatBs,
                                    color: AppColors.expense,
                                  ),
                                  if (p.currency == CurrencyType.usd) ...[
                                    SizedBox(height: OrtizSpace.xxs),
                                    Text(
                                      "~${formatBs(p.amount * bcv)} (BCV)",
                                      style: OrtizType.caption.copyWith(color: OrtizPalette.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: OrtizSpace.lg),
                    ],

                    Text(
                      "OTRAS OPCIONES",
                      style: TextStyle(
                        fontSize: OrtizFontSize.caption,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cardSubtitleText,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: OrtizSpace.sm),

                    OrtizListRow(
                      onTap: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();

                        showModalBottomSheet(
                          context: navigator.context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddTransactionBottomSheet(
                            initialType: TransactionType.expense,
                            initialAccountId: widget.vesAccountId,
                          ),
                        );

                        ScaffoldMessenger.of(navigator.context).showSnackBar(
                          SnackBar(
                            content: Text("¡Cambio registrado! Crea el nuevo pago."),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      leading: Icon(
                        Icons.add_card_rounded,
                        color: AppColors.primary,
                        size: OrtizIconSize.md,
                      ),
                      title: "Registrar Gasto Nuevo",
                      subtitle: "Registrar un gasto no recurrente personalizado",
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.cardSubtitleText,
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xxl),
                  ],
                ),
              ),
            ),

            // Confirm / Omit button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelection ? AppColors.primary : OrtizPalette.surfaceHigh,
                foregroundColor: hasSelection ? OrtizPalette.onAccent : OrtizPalette.fg,
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                
                if (hasSelection) {
                  // Process all selected payments
                  for (var occ in _selectedOccurrences) {
                    final p = occ.payment;
                    final double remaining = occ.remainingAmount;
                    if (p.currency == CurrencyType.usd) {
                      await appState.confirmRecurringPayment(
                        payment: p,
                        actualAmount: remaining * bcv,
                        overrideAccountId: widget.vesAccountId,
                        occurrenceDate: occ.occurrenceDate,
                        overrideCurrency: CurrencyType.bsBCV,
                        customExchangeRate: bcv,
                        customNote: "Confirmado: ${p.name} (\$${remaining.toStringAsFixed(2)} @ ${bcv.toStringAsFixed(2)} Bs. BCV)",
                      );
                    } else {
                      await appState.confirmRecurringPayment(
                        payment: p,
                        actualAmount: remaining,
                        overrideAccountId: widget.vesAccountId,
                        occurrenceDate: occ.occurrenceDate,
                      );
                    }
                  }

                  navigator.pop();

                  final names = _selectedOccurrences.map((occ) => occ.payment.name).join(", ");
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => ExchangeSuccessDialog(
                      isVenta: true,
                      amountUSD: widget.amountUSD,
                      rate: widget.rate,
                      amountVES: widget.amountVES,
                      usdAccountName: widget.usdAccountName,
                      vesAccountName: widget.vesAccountName,
                      confirmedPaymentName: names,
                    ),
                  );
                } else {
                  // No selection - omit / just register exchange
                  navigator.pop();

                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => ExchangeSuccessDialog(
                      isVenta: true,
                      amountUSD: widget.amountUSD,
                      rate: widget.rate,
                      amountVES: widget.amountVES,
                      usdAccountName: widget.usdAccountName,
                      vesAccountName: widget.vesAccountName,
                    ),
                  );
                }
              },
              child: Text(
                hasSelection ? "Pagar" : "Omitir",
                style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
