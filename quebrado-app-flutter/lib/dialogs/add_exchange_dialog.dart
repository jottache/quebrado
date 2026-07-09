import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../theme/colors.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../models/saving_pocket.dart';
import '../models/transaction.dart';
import 'add_transaction_dialog.dart';
import '../models/recurring_payment.dart';

class AddExchangeBottomSheet extends StatefulWidget {
  final String? initialAccountId;

  const AddExchangeBottomSheet({super.key, this.initialAccountId});

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
        borderRadius: const BorderRadius.only(
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
            // Drag handle
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
                const Text(
                  "Compra / Venta de Divisas",
                  style: TextStyle(
                    fontSize: 18,
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
            const SizedBox(height: 12),

            // Tab Selector: Venta vs Compra
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
                      onTap: () => setState(() => _isVenta = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isVenta ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isVenta
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Venta \$",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVenta = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isVenta ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isVenta
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Compra \$",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Account selection card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CUENTAS DE LA OPERACIÓN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // USD Account Selector
                          Text(
                            _isVenta ? "Cuenta USD de Origen (Debitar \$)" : "Cuenta USD de Destino (Acreditar \$)",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedUsdAccountId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.03),
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
                                      decoration: BoxDecoration(color: accColor.withOpacity(0.15), shape: BoxShape.circle),
                                      child: Icon(getIconData(acc.icon), color: accColor, size: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${acc.name} (${formatUSD(acc.balance)})",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (accId) => setState(() => _selectedUsdAccountId = accId),
                          ),
                          const SizedBox(height: 16),

                          // VES Account Selector
                          Text(
                            _isVenta ? "Cuenta VES de Destino (Acreditar Bs.)" : "Cuenta VES de Origen (Debitar Bs.)",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedVesAccountId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.03),
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
                                      decoration: BoxDecoration(color: accColor.withOpacity(0.15), shape: BoxShape.circle),
                                      child: Icon(getIconData(acc.icon), color: accColor, size: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${acc.name} (${formatBs(acc.balance)})",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
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
                    const SizedBox(height: 16),

                    // 2. Data Entry Card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MONTOS Y TASA PACTADA",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Amount input
                          const Text(
                            "Monto a Cambiar (USD)",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "0.00",
                              prefixIcon: const Icon(Icons.attach_money_rounded),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // Rate input
                          const Text(
                            "Tasa de Cambio Pactada (Bs. / \$)",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "0.00",
                              prefixIcon: const Icon(Icons.show_chart_rounded),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Live Metrics Card
                    if (amountUSD > 0 && rate > 0) ...[
                      ClaymorphicCard(
                        cornerRadius: 24,
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "CÁLCULOS Y COMPARATIVAS DEL DÍA",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Total converted
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Monto Resultante:",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                                Text(
                                  formatBs(amountVES),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // BCV Reference Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Tasa Oficial BCV (${formatBs(bcv)}):",
                                  style: const TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  formatBs(bcvEquiv),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Diferencia vs BCV:",
                                  style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  diffBCV == 0
                                      ? "Sin diferencia"
                                      : "${isFavorableBCV ? '+' : '-'}${formatBs(diffBCV.abs())} (${pctBCV.abs().toStringAsFixed(2)}%)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: diffBCV == 0
                                        ? AppColors.cardSubtitleText
                                        : (isFavorableBCV ? AppColors.income : AppColors.expense),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Parallel Reference Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Tasa Paralelo (${formatBs(parallel)}):",
                                  style: const TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  formatBs(parallelEquiv),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Diferencia vs Paralelo:",
                                  style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                                ),
                                Text(
                                  diffParallel == 0
                                      ? "Sin diferencia"
                                      : "${isFavorableParallel ? '+' : '-'}${formatBs(diffParallel.abs())} (${pctParallel.abs().toStringAsFixed(2)}%)",
                                  style: TextStyle(
                                    fontSize: 12,
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
                      const SizedBox(height: 16),
                    ],

                    // 4. Note concept card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DESCRIPCIÓN DE LA OPERACIÓN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: "Ej. Venta a tasa paralela para pago de servicios",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Save / Cancel row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: !isValid ? null : () => _processExchange(appState),
                    child: const Text(
                      "Procesar Cambio",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClaymorphicCard(
        cornerRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.income.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.income,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              confirmedPaymentName != null ? "¡Cambio y Pago Registrados!" : "¡Cambio Registrado!",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              confirmedPaymentName != null
                  ? "Venta y pago de servicio confirmados"
                  : (isVenta ? "Venta de divisa procesada" : "Compra de divisa procesada"),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.cardSubtitleText,
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
                    "Operación",
                    isVenta ? "Venta \$" : "Compra \$",
                    isVenta ? AppColors.expense : AppColors.income,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Monto USD",
                    formatUSD(amountUSD),
                    AppColors.cardText,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Tasa de cambio",
                    formatRate(rate),
                    AppColors.cardText,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Monto VES",
                    formatBs(amountVES),
                    AppColors.primary,
                    isBold: true,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta USD",
                    usdAccountName,
                    AppColors.cardText,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    "Cuenta VES",
                    vesAccountName,
                    AppColors.cardText,
                  ),
                  if (confirmedPaymentName != null) ...[
                    const Divider(height: 16),
                    _buildDetailRow(
                      "Gasto Pagado",
                      confirmedPaymentName!,
                      AppColors.expense,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<AppState>(context, listen: false).setTabIndex(2);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Cerrar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<AppState>(context, listen: false).setTabIndex(2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Ver transacción",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.cardSubtitleText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "¿Deseas registrar un pago?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Se recibieron ${formatBs(widget.amountVES)} en ${widget.vesAccountName}. Puedes usar estos fondos para pagar un gasto pendiente o registrar uno nuevo.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.cardSubtitleText,
              ),
            ),
            const SizedBox(height: 20),
            if (hasSelection) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Fondos restantes: ${formatBs(remainingVES)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Scrollable area for options
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vesPendingOccurrences.isNotEmpty) ...[
                      Text(
                        "PAGOS RECURRENTES PENDIENTES (VES)",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GestureDetector(
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
                            child: Opacity(
                              opacity: isDisabled ? 0.45 : 1.0,
                              child: ClaymorphicCard(
                                cornerRadius: 16,
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
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
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: cardColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        getIconData(p.icon),
                                        color: cardColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.cardText,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (pocket != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "Bolsillo: ${pocket.name}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.cardSubtitleText,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          p.currency == CurrencyType.usd 
                                              ? formatUSD(p.amount)
                                              : formatBs(p.amount),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.expense,
                                          ),
                                        ),
                                        if (p.currency == CurrencyType.usd) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "~${formatBs(p.amount * bcv)} (BCV)",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.cardSubtitleText,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      "OTRAS OPCIONES",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cardSubtitleText,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
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
                          const SnackBar(
                            content: Text("¡Cambio registrado! Crea el nuevo pago."),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      child: ClaymorphicCard(
                        cornerRadius: 16,
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.add_card_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Registrar Gasto Nuevo",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Registrar un gasto no recurrente personalizado",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cardSubtitleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.cardSubtitleText,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Confirm / Omit button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelection ? AppColors.primary : Colors.grey[200],
                foregroundColor: hasSelection ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
