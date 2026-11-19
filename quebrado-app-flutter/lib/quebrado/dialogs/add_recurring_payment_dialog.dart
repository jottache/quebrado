import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../models/recurring_payment.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../widgets/helpers.dart';
import '../models/account.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
class AddRecurringPaymentBottomSheet extends StatefulWidget {
  final RecurringPayment? editingPayment;

  const AddRecurringPaymentBottomSheet({super.key, this.editingPayment});

  @override
  State<AddRecurringPaymentBottomSheet> createState() => _AddRecurringPaymentBottomSheetState();
}

class _AddRecurringPaymentBottomSheetState extends State<AddRecurringPaymentBottomSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _customDaysController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  CurrencyType _selectedCurrency = CurrencyType.usd;

  /// Recurrente viejo guardado en Bs que se convirtió a $ al abrirlo.
  bool _convertedFromBs = false;
  double? _legacyMaxAmountUsd;
  SubscriptionFrequency _selectedFrequency = SubscriptionFrequency.monthly;
  DateTime _startDate = DateTime.now();
  NotificationOption _selectedNotification = NotificationOption.none;
  String? _selectedAccountId;
  String? _selectedPocketId;
  bool _isVariable = false;
  bool _isOnce = false;
  String _expenseType = 'recurrent';
  late String _selectedIcon;
  late String _selectedColorHex;

  final List<String> _colors = AppColors.creationColors;
  final List<String> _icons = [
    "creditcard", "wallet", "bank", "briefcase", "computer", "gift",
    "trendingup", "restaurant", "localcafe", "cart", "bag", "car",
    "home", "bolt", "gamecontroller", "heart", "airplane", "tv",
    "book", "musicnote", "medical", "pills", "tag", "shield",
    "iphone", "star", "wifi", "person", "clock", "gear",
    "calculator", "ellipsis"
  ];

  @override
  void initState() {
    super.initState();
    final pay = widget.editingPayment;
    if (pay != null) {
      _nameController.text = pay.name;
      _amountController.text = pay.amount.toStringAsFixed(2);
      _selectedType = pay.type;
      _selectedCurrency = pay.currency;
      if (pay.currency == CurrencyType.bsBCV) {
        // En Venezuela los pagos en Bs siempre están anclados al dólar: los recurrentes
        // viejos guardados en Bs se pasan a $ con la tasa BCV de hoy (no con el mismo número).
        final rate = Provider.of<AppState>(context, listen: false).bcvRate;
        _selectedCurrency = CurrencyType.usd;
        _convertedFromBs = rate > 0;
        if (rate > 0) {
          _amountController.text = (pay.amount / rate).toStringAsFixed(2);
          if (pay.maxAmount != null) _legacyMaxAmountUsd = pay.maxAmount! / rate;
        }
      }
      _selectedFrequency = pay.frequency;
      _isOnce = pay.frequency == SubscriptionFrequency.once;
      if (_isOnce) {
        _expenseType = 'once';
      } else if (pay.totalInstallments != null) {
        _expenseType = 'installments';
      } else {
        _expenseType = 'recurrent';
      }
      _startDate = pay.startDate;
      _selectedNotification = pay.notificationOption;
      _selectedAccountId = pay.accountId;
      _selectedPocketId = pay.pocketId;
      _selectedIcon = pay.icon;
      _selectedColorHex = pay.colorHex;
      _isVariable = pay.isVariable;
      if (pay.maxAmount != null) {
        _maxAmountController.text = (_legacyMaxAmountUsd ?? pay.maxAmount!).toStringAsFixed(2);
      }
      if (pay.totalInstallments != null) {
        _installmentsController.text = pay.totalInstallments.toString();
      }
      _customDaysController.text = pay.customDays?.toString() ?? '30';
    } else {
      _expenseType = 'recurrent';
      _isOnce = false;
      _selectedIcon = _icons[0];
      _selectedColorHex = _colors[1]; // default green
      _customDaysController.text = '30';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _maxAmountController.dispose();
    _installmentsController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  void _savePayment(AppState appState) {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (name.isEmpty || amount <= 0) return;
    if (_expenseType == 'installments' && (int.tryParse(_installmentsController.text) ?? 0) <= 0) return;

    final isVariable = _selectedType == TransactionType.income && _isVariable && !_isOnce;
    final maxAmount = isVariable ? (double.tryParse(_maxAmountController.text) ?? 0.0) : null;
    final accountId = _selectedAccountId ?? (appState.accounts.isNotEmpty ? appState.accounts.first.id : null);
    // En cuentas en $ el recurrente siempre es en $ (Bs y EUR solo tienen sentido en cuentas en Bs)
    final account = appState.accounts.where((a) => a.id == accountId).firstOrNull;
    if (account != null && account.currency == CurrencyType.usd) _selectedCurrency = CurrencyType.usd;
    final isFiniteExpense = _expenseType == 'installments';
    final totalInstallments = _isOnce 
        ? 1 
        : (isFiniteExpense ? int.tryParse(_installmentsController.text) : null);
    final customDays = (!_isOnce && _selectedFrequency == SubscriptionFrequency.custom)
        ? (int.tryParse(_customDaysController.text) ?? 30)
        : null;
    final frequency = _isOnce ? SubscriptionFrequency.once : _selectedFrequency;

    if (widget.editingPayment != null) {
      final updated = RecurringPayment(
        id: widget.editingPayment!.id,
        name: name,
        amount: amount,
        currency: _selectedCurrency,
        frequency: frequency,
        startDate: _startDate,
        notificationOption: _selectedNotification,
        icon: _selectedIcon,
        colorHex: _selectedColorHex,
        type: _selectedType,
        accountId: accountId,
        pocketId: _selectedPocketId,
        totalInstallments: totalInstallments,
        customDays: customDays,
        isVariable: isVariable,
        maxAmount: maxAmount,
      );
      appState.updateRecurringPayment(updated);
    } else {
      appState.addRecurringPayment(
        name: name,
        amount: amount,
        currency: _selectedCurrency,
        frequency: frequency,
        startDate: _startDate,
        notificationOption: _selectedNotification,
        icon: _selectedIcon,
        colorHex: _selectedColorHex,
        type: _selectedType,
        accountId: accountId,
        pocketId: _selectedPocketId,
        totalInstallments: totalInstallments,
        customDays: customDays,
        isVariable: isVariable,
        maxAmount: maxAmount,
      );
    }
    Navigator.pop(context);
  }

  void _deletePayment(AppState appState) async {
    if (widget.editingPayment != null) {
      try {
        await appState.deleteRecurringPayment(widget.editingPayment!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar: $e"), backgroundColor: AppColors.expense),
          );
        }
      }
    }
  }

  void _showAssociationsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
        child: SafeArea(
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
              SizedBox(height: OrtizSpace.lg),
              Flexible(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "¿Cómo funcionan las Asociaciones?",
                        style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Bolsillo Asociado (Opcional)",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "• Si es un Ingreso: El simulador sumará este monto periódicamente al balance del bolsillo de ahorro seleccionado para ver cómo crece.\n• Si es un Gasto/Deuda (ej. Cashea): El simulador restará este cobro directamente del fondo del bolsillo, en lugar de consumirte el efectivo libre de tu cuenta.",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Entendido"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBasicInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
        child: SafeArea(
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
              SizedBox(height: OrtizSpace.lg),
              Flexible(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "¿Cómo funciona la Información Básica?",
                        style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Planificación Recurrente vs Única",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "Te permite programar ingresos o egresos a futuro. Pueden ocurrir una sola vez (Pago Único) o repetirse periódicamente (Frecuencia recurrente como mensual, quincenal, etc.).",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Cuenta Asociada",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "Define de qué cuenta física (efectivo o banco) ingresará o se debitará el dinero real cuando se ejecute la transacción programada.",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Tipo de Gasto / Cuotas",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "• Pago Único: Se ejecuta una sola vez en la fecha indicada.\n• Cuotas: Permite definir una cantidad limitada de pagos (ej. 6 cuotas de Cashea). Deja el campo vacío si el cobro es ilimitado (ej. suscripciones como Netflix).",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Entendido"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectionsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
        child: SafeArea(
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
              SizedBox(height: OrtizSpace.lg),
              Flexible(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Proyecciones y Cuotas",
                        style: TextStyle(fontSize: OrtizFontSize.titleSm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Frecuencia e Inicio",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "Indica cada cuánto tiempo se repite el movimiento y la fecha en la que se cobrará o recibirá el primer pago.",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Text(
                        "Deuda Finita / Cuotas Limitadas",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "Ideal para compras a cuotas (ej. Cashea a 6 cuotas). Si activas esta opción, el simulador dejará de proyectar gastos una vez que se alcance el número de cuotas establecido, mostrando cada cuota numerada (ej. Cuota 2/6) en el Timeline.",
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Entendido"),
                ),
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
    final themeColor = parseHexColor(_selectedColorHex);
    // Filter accounts by current currency to ensure correct association
    final filteredAccounts = appState.accounts;
    if (_selectedAccountId == null && filteredAccounts.isNotEmpty) {
      // Pick first account matching currency if possible, or just first account
      final match = filteredAccounts.firstWhere(
        (acc) => acc.currency == _selectedCurrency,
        orElse: () => filteredAccounts.first,
      );
      _selectedAccountId = match.id;
    }

    final selectedAcc = appState.accounts.firstWhere(
      (acc) => acc.id == _selectedAccountId,
      orElse: () => appState.accounts.isNotEmpty ? appState.accounts.first : Account(id: '', name: '', balance: 0, currency: CurrencyType.usd, colorHex: '#007AFF', icon: 'creditcard'),
    );
    final isAccVES = selectedAcc.currency == CurrencyType.bsBCV;

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
            SizedBox(height: OrtizSpace.lg),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingPayment == null ? "Nuevo Pago / Ingreso" : "Editar Registro",
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Scrollable fields
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type selector tab (Ingreso / Gasto)
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
                              onTap: () => setState(() => _selectedType = TransactionType.income),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: _selectedType == TransactionType.income
                                      ? AppColors.primary.withValues(alpha: 0.85)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _isOnce ? "Ingreso Programado" : "Ingreso Recurrente",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: OrtizFontSize.bodySm,
                                    color: _selectedType == TransactionType.income
                                        ? OrtizPalette.onAccent
                                        : AppColors.nestedTabInactiveText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = TransactionType.expense),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                decoration: BoxDecoration(
                                  color: _selectedType == TransactionType.expense
                                      ? AppColors.expense.withValues(alpha: 0.85)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Gasto / Deuda",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: OrtizFontSize.bodySm,
                                    color: _selectedType == TransactionType.expense
                                        ? OrtizPalette.onAccent
                                        : AppColors.nestedTabInactiveText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.md),

                    // Information Section
                    OrtizSection(
                      children: [Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "INFORMACIÓN BÁSICA",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: OrtizIconSize.sm, color: AppColors.primary),
                                onPressed: () => _showBasicInfo(context),
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Cuenta Asociada",
                                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              DropdownButton<String>(
                                value: _selectedAccountId,
                                underline: SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                items: filteredAccounts.map((acc) {
                                  final symbol = acc.currency == CurrencyType.usd ? "\$" : "Bs.";
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Text("${acc.name} ($symbol)", style: TextStyle(color: AppColors.cardText)),
                                  );
                                }).toList(),
                                 onChanged: (val) {
                                   if (val != null) {
                                     setState(() {
                                       _selectedAccountId = val;
                                       final selectedAcc = appState.accounts.firstWhere((acc) => acc.id == val);
                                       if (selectedAcc.currency == CurrencyType.usd) {
                                         _selectedCurrency = CurrencyType.usd;
                                       }
                                     });
                                   }
                                 },
                              ),
                            ],
                          ),
                          const Divider(height: OrtizSpace.xl, color: AppColors.cardBorderColor),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: _isOnce
                                  ? (_selectedType == TransactionType.income
                                      ? "Nombre (ej. Venta Única, Reembolso)"
                                      : "Nombre (ej. Compra de Laptop, Pago de Seguro)")
                                  : (_selectedType == TransactionType.income
                                      ? "Nombre (ej. Sueldo Quincenal, Freelance)"
                                      : "Nombre (ej. Cashea Compra, Netflix, Alquiler)"),
                              hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
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
                          SizedBox(height: OrtizSpace.md),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: (_selectedType == TransactionType.income && _isVariable) 
                                  ? (_selectedCurrency == CurrencyType.eur ? "Monto Mínimo €" : (_selectedCurrency == CurrencyType.usd ? "Monto Mínimo \$" : "Monto Mínimo Bs.")) 
                                  : (_selectedCurrency == CurrencyType.eur ? "0.00 €" : (_selectedCurrency == CurrencyType.usd ? "0.00 \$" : "0.00 Bs.")),
                              hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
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
                            // Cuenta en Bs: monto fijo en Bs, o indexado a USD/EUR (se paga en Bs a la tasa BCV del día)
                            Container(
                              padding: EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: AppColors.nestedTabTrackBg,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                              ),
                              child: Row(
                                children: [
                                  for (final option in const [
                                    (CurrencyType.usd, "USD a tasa BCV"),
                                    (CurrencyType.eur, "EUR a tasa BCV"),
                                  ])
                                    Expanded(
                                      child: GestureDetector(
                                        key: ValueKey('recurring_currency_${option.$1.name}'),
                                        onTap: () => setState(() => _selectedCurrency = option.$1),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.xs),
                                          decoration: BoxDecoration(
                                            color: _selectedCurrency == option.$1
                                                ? AppColors.nestedTabActiveBg
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            option.$2,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: OrtizFontSize.bodySm,
                                              color: _selectedCurrency == option.$1
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
                            SizedBox(height: OrtizSpace.xs),
                            Text(
                              _convertedFromBs
                                  ? "Este pago estaba guardado en Bs: lo pasamos a dólares con la tasa BCV de hoy. Revisa el monto y guarda."
                                  : "El monto está en ${_selectedCurrency == CurrencyType.eur ? 'euros' : 'dólares'} y se paga en Bs a la tasa BCV del día.",
                              style: const TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                            ),
                          ],

                          if (_selectedType == TransactionType.income && !_isOnce) ...[
                            SizedBox(height: OrtizSpace.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "¿Monto variable (Rango Mín-Máx)?",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardText,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _isVariable,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _isVariable = val;
                                      if (!val) {
                                        _maxAmountController.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_isVariable) ...[
                              SizedBox(height: OrtizSpace.md),
                              TextField(
                                controller: _maxAmountController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: _selectedCurrency == CurrencyType.eur ? "Monto Máximo €" : (_selectedCurrency == CurrencyType.usd ? "Monto Máximo \$" : "Monto Máximo Bs."),
                                  hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
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
                          ],

                        ],
                      )],
                    ),

                    // Associations (Account & Pockets)
                    OrtizSection(
                      children: [Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "ASOCIACIONES",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: OrtizIconSize.sm, color: AppColors.primary),
                                onPressed: () => _showAssociationsInfo(context),
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Bolsillo Asociado",
                                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              DropdownButton<String?>(
                                value: _selectedPocketId,
                                underline: SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text("Ninguno", style: TextStyle(color: AppColors.cardSubtitleText)),
                                  ),
                                  ...appState.pockets.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name, style: TextStyle(color: AppColors.cardText)),
                                    );
                                  })
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedPocketId = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      )],
                    ),

                    // Frecuencia y Alertas Section
                    OrtizSection(
                      children: [Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "FRECUENCIA Y PROYECCIÓN",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: OrtizIconSize.sm, color: AppColors.primary),
                                onPressed: () => _showProjectionsInfo(context),
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.lg),
                          if (_selectedType == TransactionType.expense) ...[
                            Text(
                              "TIPO DE GASTO",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.sm),
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
                                      onTap: () => setState(() {
                                        _expenseType = 'recurrent';
                                        _isOnce = false;
                                        _installmentsController.clear();
                                      }),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _expenseType == 'recurrent'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Recurrente",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _expenseType == 'recurrent'
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _expenseType = 'installments';
                                        _isOnce = false;
                                      }),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: _expenseType == 'installments'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Cuotas",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: OrtizFontSize.bodySm,
                                            color: _expenseType == 'installments'
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
                            if (_expenseType == 'installments') ...[
                              SizedBox(height: OrtizSpace.md),
                              TextField(
                                controller: _installmentsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: "Cantidad de cuotas (ej. 6)",
                                  hintStyle: const TextStyle(color: AppColors.cardSubtitleText, fontSize: OrtizFontSize.bodySm),
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
                            SizedBox(height: OrtizSpace.lg),
                          ],
                          if (!_isOnce) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Frecuencia",
                                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                                DropdownButton<SubscriptionFrequency>(
                                  value: _selectedFrequency,
                                  underline: SizedBox(),
                                  dropdownColor: AppColors.cardBackground,
                                  style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                  items: SubscriptionFrequency.values.where((freq) => freq != SubscriptionFrequency.once).map((freq) {
                                    return DropdownMenuItem(
                                      value: freq,
                                      child: Text(freq.value, style: TextStyle(color: AppColors.cardText)),
                                    );
                                  }).toList(),
                                  onChanged: (freq) {
                                    if (freq != null) {
                                      setState(() => _selectedFrequency = freq);
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (_selectedFrequency == SubscriptionFrequency.custom) ...[
                              SizedBox(height: OrtizSpace.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Intervalo en Días",
                                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                  ),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 36,
                                        child: TextField(
                                          controller: _customDaysController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.sm),
                                            filled: true,
                                            fillColor: OrtizPalette.surfaceHigh,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ),
                                      SizedBox(width: OrtizSpace.sm),
                                      Text(
                                        "días",
                                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: OrtizSpace.xl, color: AppColors.cardBorderColor),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isOnce ? "Fecha de Pago" : "Fecha de Inicio / Próximo",
                                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.nestedTabTrackBg,
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                  padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                                ),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() => _startDate = date);
                                  }
                                },
                                child: Text(
                                  formatDate(_startDate),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: OrtizSpace.xl, color: AppColors.cardBorderColor),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Recordatorio Alerta",
                                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                                              ),
                              DropdownButton<NotificationOption>(
                                value: _selectedNotification,
                                underline: SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                                items: NotificationOption.values.map((opt) {
                                  return DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt.value, style: TextStyle(color: AppColors.cardText)),
                                  );
                                }).toList(),
                                onChanged: (opt) {
                                  if (opt != null) {
                                    setState(() => _selectedNotification = opt);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      )],
                    ),

                    // Icon section
                    OrtizSection(
                      children: [Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ICONO",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: _icons.length,
                            itemBuilder: (context, index) {
                              final icon = _icons[index];
                              final isSelected = _selectedIcon == icon;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedIcon = icon),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeColor
                                        : themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected ? OrtizPalette.onAccent : themeColor,
                                    size: OrtizIconSize.md,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      )],
                    ),

                    // Color Section
                    OrtizSection(
                      children: [Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COLOR",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _colors.map((colorHex) {
                              final isSelected = _selectedColorHex == colorHex;
                              final color = parseHexColor(colorHex);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColorHex = colorHex),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.cardText : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      )],
                    ),

                    // Destructive Delete Button
                    if (widget.editingPayment != null) ...[
                      SizedBox(height: OrtizSpace.md),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense.withValues(alpha: 0.08),
                          foregroundColor: AppColors.expense,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        ),
                        onPressed: () => _deletePayment(appState),
                        child: Text(
                          "Eliminar Registro",
                          style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: AppColors.cardSubtitleText),
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
                    onPressed: (_nameController.text.trim().isEmpty || 
                            (double.tryParse(_amountController.text) ?? 0.0) <= 0 ||
                            (!_isOnce && _selectedType == TransactionType.income && _isVariable && (double.tryParse(_maxAmountController.text) ?? 0.0) <= 0) ||
                            (!_isOnce && _selectedType == TransactionType.expense && _installmentsController.text.trim().isNotEmpty && (int.tryParse(_installmentsController.text) ?? 0) <= 0))
                        ? null
                        : () => _savePayment(appState),
                    child: Text(
                      "Guardar",
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
