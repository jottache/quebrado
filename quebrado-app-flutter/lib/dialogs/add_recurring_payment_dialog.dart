import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../models/recurring_payment.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../models/account.dart';

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
      _selectedCurrency = pay.currency == CurrencyType.bsBCV ? CurrencyType.usd : pay.currency;
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
        _maxAmountController.text = pay.maxAmount!.toStringAsFixed(2);
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

  void _deletePayment(AppState appState) {
    if (widget.editingPayment != null) {
      appState.deleteRecurringPayment(widget.editingPayment!.id);
      Navigator.pop(context);
    }
  }

  void _showAssociationsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "¿Cómo funcionan las Asociaciones?",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Bolsillo Asociado (Opcional)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "• Si es un Ingreso: El simulador sumará este monto periódicamente al balance del bolsillo de ahorro seleccionado para ver cómo crece.\n• Si es un Gasto/Deuda (ej. Cashea): El simulador restará este cobro directamente del fondo del bolsillo, en lugar de consumirte el efectivo libre de tu cuenta.",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Entendido"),
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
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "¿Cómo funciona la Información Básica?",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Planificación Recurrente vs Única",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Te permite programar ingresos o egresos a futuro. Pueden ocurrir una sola vez (Pago Único) o repetirse periódicamente (Frecuencia recurrente como mensual, quincenal, etc.).",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Cuenta Asociada",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Define de qué cuenta física (efectivo o banco) ingresará o se debitará el dinero real cuando se ejecute la transacción programada.",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Tipo de Gasto / Cuotas",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "• Pago Único: Se ejecuta una sola vez en la fecha indicada.\n• Cuotas: Permite definir una cantidad limitada de pagos (ej. 6 cuotas de Cashea). Deja el campo vacío si el cobro es ilimitado (ej. suscripciones como Netflix).",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Entendido"),
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
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Proyecciones y Cuotas",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cardText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Frecuencia e Inicio",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Indica cada cuánto tiempo se repite el movimiento y la fecha en la que se cobrará o recibirá el primer pago.",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Deuda Finita / Cuotas Limitadas",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Ideal para compras a cuotas (ej. Cashea a 6 cuotas). Si activas esta opción, el simulador dejará de proyectar gastos una vez que se alcance el número de cuotas establecido, mostrando cada cuota numerada (ej. Cuota 2/6) en el Timeline.",
                        style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Entendido"),
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
                  widget.editingPayment == null ? "Nuevo Pago / Ingreso" : "Editar Registro",
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

            // Scrollable fields
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type selector tab (Ingreso / Gasto)
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
                              onTap: () => setState(() => _selectedType = TransactionType.income),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedType == TransactionType.income
                                      ? AppColors.primary.withOpacity(0.85)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _isOnce ? "Ingreso Programado" : "Ingreso Recurrente",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedType == TransactionType.income
                                        ? Colors.white
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
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedType == TransactionType.expense
                                      ? AppColors.expense.withOpacity(0.85)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Gasto / Deuda",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedType == TransactionType.expense
                                        ? Colors.white
                                        : AppColors.nestedTabInactiveText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Information Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "INFORMACIÓN BÁSICA",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                                onPressed: () => _showBasicInfo(context),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Cuenta Asociada",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              DropdownButton<String>(
                                value: _selectedAccountId,
                                underline: const SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: 13),
                                items: filteredAccounts.map((acc) {
                                  final symbol = acc.currency == CurrencyType.usd ? "\$" : "Bs.";
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Text("${acc.name} ($symbol)", style: const TextStyle(color: AppColors.cardText)),
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
                          Divider(height: 20, color: Colors.black.withOpacity(0.08)),
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
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: (_selectedType == TransactionType.income && _isVariable) ? "Monto Mínimo" : "Monto",
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
                            // VES account: interactive tabs for USD, VES, EUR
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
                                      onTap: () => setState(() => _selectedCurrency = CurrencyType.usd),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedCurrency == CurrencyType.usd
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "USD (\$)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _selectedCurrency == CurrencyType.usd
                                                ? AppColors.nestedTabActiveText
                                                : AppColors.nestedTabInactiveText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedCurrency = CurrencyType.eur),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedCurrency == CurrencyType.eur
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
                                            color: _selectedCurrency == CurrencyType.eur
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
                          ],

                          if (_selectedType == TransactionType.income && !_isOnce) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "¿Monto variable (Rango Mín-Máx)?",
                                  style: TextStyle(
                                    fontSize: 13,
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
                              const SizedBox(height: 12),
                              TextField(
                                controller: _maxAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: "Monto Máximo",
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
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ],

                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Associations (Account & Pockets)
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "ASOCIACIONES",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                                onPressed: () => _showAssociationsInfo(context),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Bolsillo Asociado",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              DropdownButton<String?>(
                                value: _selectedPocketId,
                                underline: const SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: 13),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Ninguno", style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...appState.pockets.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name, style: const TextStyle(color: AppColors.cardText)),
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
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Frecuencia y Alertas Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "FRECUENCIA Y PROYECCIÓN",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardSubtitleText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                                onPressed: () => _showProjectionsInfo(context),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_selectedType == TransactionType.expense) ...[
                            Text(
                              "TIPO DE GASTO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                      onTap: () => setState(() {
                                        _expenseType = 'recurrent';
                                        _isOnce = false;
                                        _installmentsController.clear();
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _expenseType == 'recurrent'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Recurrente",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _expenseType == 'installments'
                                              ? AppColors.nestedTabActiveBg
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Cuotas",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                              const SizedBox(height: 12),
                              TextField(
                                controller: _installmentsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: "Cantidad de cuotas (ej. 6)",
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
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                          if (!_isOnce) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Frecuencia",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                ),
                                DropdownButton<SubscriptionFrequency>(
                                  value: _selectedFrequency,
                                  underline: const SizedBox(),
                                  dropdownColor: AppColors.cardBackground,
                                  style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: 13),
                                  items: SubscriptionFrequency.values.where((freq) => freq != SubscriptionFrequency.once).map((freq) {
                                    return DropdownMenuItem(
                                      value: freq,
                                      child: Text(freq.value, style: const TextStyle(color: AppColors.cardText)),
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
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Intervalo en Días",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
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
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                            filled: true,
                                            fillColor: Colors.grey[100],
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "días",
                                        style: TextStyle(fontSize: 13, color: AppColors.cardSubtitleText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                            Divider(height: 20, color: Colors.black.withOpacity(0.08)),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isOnce ? "Fecha de Pago" : "Fecha de Inicio / Próximo",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.nestedTabTrackBg,
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 20, color: Colors.black.withOpacity(0.08)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Recordatorio Alerta",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cardText),
                                                              ),
                              DropdownButton<NotificationOption>(
                                value: _selectedNotification,
                                underline: const SizedBox(),
                                dropdownColor: AppColors.cardBackground,
                                style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold, fontSize: 13),
                                items: NotificationOption.values.map((opt) {
                                  return DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt.value, style: const TextStyle(color: AppColors.cardText)),
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
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icon section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ICONO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                        : themeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected ? Colors.white : themeColor,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color Section
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COLOR",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                      color: isSelected ? Colors.black87 : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Destructive Delete Button
                    if (widget.editingPayment != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense.withOpacity(0.08),
                          foregroundColor: AppColors.expense,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _deletePayment(appState),
                        child: const Text(
                          "Eliminar Registro",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                    onPressed: (_nameController.text.trim().isEmpty || 
                            (double.tryParse(_amountController.text) ?? 0.0) <= 0 ||
                            (!_isOnce && _selectedType == TransactionType.income && _isVariable && (double.tryParse(_maxAmountController.text) ?? 0.0) <= 0) ||
                            (!_isOnce && _selectedType == TransactionType.expense && _installmentsController.text.trim().isNotEmpty && (int.tryParse(_installmentsController.text) ?? 0) <= 0))
                        ? null
                        : () => _savePayment(appState),
                    child: const Text(
                      "Guardar",
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
