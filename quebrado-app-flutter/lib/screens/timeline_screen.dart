import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../viewmodels/app_state.dart';
import '../models/timeline_event.dart';
import '../models/timeline_day_summary.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../widgets/timeline_event_row.dart';
import '../dialogs/purchase_simulation_bottom_sheet.dart';
import '../services/db_helper.dart';
import '../dialogs/day_actions_dialog.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final GlobalKey _dineroSeguroKey = GlobalKey();
  final GlobalKey _filterTimelineKey = GlobalKey();
  final GlobalKey _timelineListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    if (appState.shouldShowTimelineTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTimelineTutorialDirectly();
      });
    }
  }

  void _scrollToShowcasePosition() {
    try {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        scrollable.position.animateTo(
          180.0, // Scroll down past the balance banner
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint("Error scrolling to timeline showcase: $e");
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final hasSeen = await DatabaseHelper.instance.getSetting('tutorial_timeline_seen');
    if (hasSeen != 'true') {
      if (mounted) {
        _scrollToShowcasePosition();
        ShowCaseWidget.of(context).startShowCase([
          _dineroSeguroKey,
          _filterTimelineKey,
          _timelineListKey,
        ]);
        await DatabaseHelper.instance.setSetting('tutorial_timeline_seen', 'true');
      }
    }
  }

  void _triggerTimelineTutorialDirectly() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.shouldShowTimelineTutorial = false; // Reset trigger
    _scrollToShowcasePosition();
    ShowCaseWidget.of(context).startShowCase([
      _dineroSeguroKey,
      _filterTimelineKey,
      _timelineListKey,
    ]);
    DatabaseHelper.instance.setSetting('tutorial_timeline_seen', 'true');
  }

  String _selectedType = 'all'; // 'all', 'income', 'expense', 'suggestion'
  final int _selectedDays = 365; // 30, 90, 365
  String? _selectedRecurringId;
  String? _selectedPocketId;

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return "Hoy";
    } else if (eventDate == tomorrow) {
      return "Mañana";
    } else {
      final daysOfWeek = [
        "Domingo",
        "Lunes",
        "Martes",
        "Miércoles",
        "Jueves",
        "Viernes",
        "Sábado",
      ];
      final dayName = daysOfWeek[date.weekday % 7];
      final dayStr = date.day.toString().padLeft(2, '0');
      final monthStr = date.month.toString().padLeft(2, '0');

      if (date.year == now.year) {
        return "$dayName $dayStr/$monthStr";
      } else {
        return "$dayName $dayStr/$monthStr/${date.year}";
      }
    }
  }

  void _showTimelineInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
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
                  "Sobre la Proyección Financiera",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "¿Qué es el Dinero Seguro?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Es el saldo líquido mínimo proyectado que tendrán tus cuentas consolidadas en los próximos 12 meses. Este saldo define dos límites clave para hoy:\n\n"
                  "• Límite de Ahorro: El monto máximo que puedes mover a tus bolsillos de reserva. Al guardarlo allí, tu patrimonio neto no disminuye y proteges tu dinero para metas futuras.\n\n"
                  "• Límite de Gasto: El monto máximo que puedes gastar libremente hoy en cualquier consumo. Esto reduce tu patrimonio permanentemente, pero es seguro hacerlo porque no afectará tus pagos y obligaciones proyectadas.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "¿Cómo funciona la Proyección a 1 Año?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "El Timeline simula día a día tus transacciones recurrentes registradas (como sueldos, alquileres, cuotas de Cashea o suscripciones). En cada evento verás un balance proyectado estimado, lo que te permite anticipar momentos de bajo flujo de caja.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Importancia de la Cuenta/Bolsillo",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "• Los eventos asociados a una cuenta afectan directamente tu dinero disponible en tus cuentas.\n• Los eventos asociados a un bolsillo se descuentan del ahorro acumulado en ese bolsillo, protegiendo tu dinero del día a día.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Entendido"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesGoalCard(
    BuildContext context,
    double safeAmount,
    DateTime minDate,
    String minReason,
  ) {
    final appState = Provider.of<AppState>(context, listen: false);
    final baseIncome = appState.totalDailyMinimumIncomeUSD;
    final deficit = -safeAmount;
    final today = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final target = minDate.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    int daysToDeficit = target.difference(today).inDays;
    if (daysToDeficit <= 0) daysToDeficit = 1;
    final dailyRequiredIncome = deficit / daysToDeficit;
    final totalDailyTarget = baseIncome + dailyRequiredIncome;

    return GestureDetector(
      onTap: () => _showSalesGoalExplanationBottomSheet(
        context,
        safeAmount,
        minDate,
        minReason,
        baseIncome,
        dailyRequiredIncome,
        daysToDeficit,
      ),
      child: Container(
        padding: EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.expense.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Meta Diaria de Ventas / Trabajo",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.expense,
                  size: 14,
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              "Generar ${formatUSD(dailyRequiredIncome)} extra / día",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.expense,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Para cubrir '$minReason' el ${formatDate(minDate)} sin caer en saldo negativo, necesitas producir un promedio de ${formatUSD(dailyRequiredIncome)} diarios adicionales sobre tu mínimo habitual de ${formatUSD(baseIncome)}.\n\nMeta diaria total recomendada: ${formatUSD(totalDailyTarget)} al día (durante los próximos $daysToDeficit días).",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.expense.withOpacity(0.9),
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                "Toca aquí para ver la explicación detallada paso a paso",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense.withOpacity(0.8),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSalesGoalExplanationBottomSheet(
    BuildContext context,
    double safeAmount,
    DateTime minDate,
    String minReason,
    double baseIncome,
    double dailyRequiredIncome,
    int daysToDeficit,
  ) {
    final deficit = -safeAmount;
    final totalDailyTarget = baseIncome + dailyRequiredIncome;
    final appState = Provider.of<AppState>(context, listen: false);
    final initialLiquid = appState.liquidBalanceUSD;

    // Simulate events in period
    final events = appState.getTimelineEvents(daysToDeficit);

    // Group incomes in period
    double totalIncomeInPeriod = 0.0;
    Map<String, int> incomeCounts = {};
    Map<String, double> incomeAmounts = {};
    for (var ev in events) {
      if (!ev.isSuggestion && ev.type == TransactionType.income) {
        totalIncomeInPeriod += ev.amount;
        incomeCounts[ev.title] = (incomeCounts[ev.title] ?? 0) + 1;
        incomeAmounts[ev.title] = (incomeAmounts[ev.title] ?? 0.0) + ev.amount;
      }
    }

    List<String> incomeDetails = [];
    incomeCounts.forEach((title, count) {
      final totalForThis = incomeAmounts[title]!;
      if (count == 1) {
        incomeDetails.add("• Ingreso '$title': ${formatUSD(totalForThis)}");
      } else {
        incomeDetails.add(
          "• $count días de '$title': ${formatUSD(totalForThis)} (${formatUSD(totalForThis / count)} c/u)",
        );
      }
    });

    // Group pocket reserves in period
    double pocketsNeeded = 0.0;
    Map<String, double> pocketReserves = {};
    for (var ev in events) {
      if (ev.isSuggestion &&
          ev.type == TransactionType.expense &&
          ev.pocketName != null) {
        pocketsNeeded += ev.amount;
        pocketReserves[ev.pocketName!] =
            (pocketReserves[ev.pocketName!] ?? 0.0) + ev.amount;
      }
    }

    List<String> pocketDetails = [];
    pocketReserves.forEach((name, amount) {
      pocketDetails.add(
        "• Reserva para Bolsillo '$name': ${formatUSD(amount)}",
      );
    });

    // Group expenses in period
    double recurringExpensesNeeded = 0.0;
    Map<String, int> expenseCounts = {};
    Map<String, double> expenseAmounts = {};
    for (var ev in events) {
      if (!ev.isSuggestion && ev.type == TransactionType.expense) {
        recurringExpensesNeeded += ev.amount;
        expenseCounts[ev.title] = (expenseCounts[ev.title] ?? 0) + 1;
        expenseAmounts[ev.title] =
            (expenseAmounts[ev.title] ?? 0.0) + ev.amount;
      }
    }

    List<String> expenseDetails = [];
    expenseCounts.forEach((title, count) {
      final totalForThis = expenseAmounts[title]!;
      if (count == 1) {
        expenseDetails.add("• Gasto '$title': ${formatUSD(totalForThis)}");
      } else {
        expenseDetails.add(
          "• $count cobros de '$title': ${formatUSD(totalForThis)}",
        );
      }
    });

    final totalNeeded = pocketsNeeded + recurringExpensesNeeded;
    final totalAvailable = initialLiquid + totalIncomeInPeriod;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
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
                SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: AppColors.expense,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Explicación de tu Meta Diaria",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  "Aquí tienes el desglose paso a paso de tus cuentas para entender de dónde sale esta meta:",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.cardText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),

                // PASO 1
                _buildStepCard(
                  title: "Paso 1: ¿Qué necesitas pagar o ahorrar?",
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pocketDetails.isNotEmpty) ...[
                        Text(
                          "Reservas para tus Bolsillos:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        SizedBox(height: 4),
                        ...pocketDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: 8.0,
                              bottom: 4.0,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                      if (expenseDetails.isNotEmpty) ...[
                        Text(
                          "Gastos programados en el período:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        SizedBox(height: 4),
                        ...expenseDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: 8.0,
                              bottom: 4.0,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        ),
                      ],
                      Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total necesario:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(totalNeeded),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // PASO 2
                _buildStepCard(
                  title: "Paso 2: ¿Con cuánto dinero contarás?",
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Dinero disponible en tus cuentas hoy:",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(initialLiquid),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Ingresos mínimos estimados en el período:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (incomeDetails.isNotEmpty)
                        ...incomeDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: 8.0,
                              bottom: 4.0,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            "• Sin ingresos programados",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                        ),
                      Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total disponible estimado:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(totalAvailable),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // PASO 3
                _buildStepCard(
                  title: "Paso 3: El faltante (Tu brecha)",
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Dinero necesario para cubrir todo:",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(totalNeeded),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total disponible estimado:",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(totalAvailable),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Faltante a cubrir:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(deficit),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // PASO 4
                _buildStepCard(
                  title: "Paso 4: La Solución (Tu meta de ventas)",
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  borderColor: AppColors.primary.withOpacity(0.2),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Para conseguir los ${formatUSD(deficit)} que te faltan antes del día del pago, dividimos ese monto entre los $daysToDeficit días que te quedan para trabajar:",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "• ${formatUSD(deficit)} / $daysToDeficit días = ${formatUSD(dailyRequiredIncome)} diarios adicionales.",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Por lo tanto, tu meta de ventas o ingresos diarios totales recomendada para cubrir todo sin deudas es de:",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "• ${formatUSD(baseIncome)} (Tu mínimo habitual) + ${formatUSD(dailyRequiredIncome)} (El extra necesario) = ${formatUSD(totalDailyTarget)} al día.",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Entendido",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showTimelineSummaryBottomSheet(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final accounts = appState.accounts;
    final bcvRate = appState.bcvRate;

    final events = appState.getTimelineEvents(30);
    Map<String, double> tempBalances = {
      for (var acc in accounts) acc.id: acc.balance,
    };
    Map<String, double> minBalances = {
      for (var acc in accounts) acc.id: acc.balance,
    };
    Map<String, DateTime> minDates = {};
    Map<String, String> minReasons = {};

    for (var ev in events) {
      if (ev.isSuggestion) continue;

      if (ev.recurringPaymentId != null) {
        final paymentIndex = appState.recurringPayments.indexWhere(
          (p) => p.id == ev.recurringPaymentId,
        );
        if (paymentIndex != -1) {
          final payment = appState.recurringPayments[paymentIndex];
          final accId =
              payment.accountId ??
              (payment.currency == CurrencyType.usd
                  ? 'default_usd'
                  : 'default_ves');
          final accIndex = accounts.indexWhere((a) => a.id == accId);
          if (accIndex != -1) {
            final acc = accounts[accIndex];
            double amountInAccCurrency = ev.amount;
            if (payment.currency != acc.currency) {
              if (payment.currency == CurrencyType.usd) {
                amountInAccCurrency = ev.amount * bcvRate;
              } else {
                amountInAccCurrency = bcvRate > 0 ? ev.amount / bcvRate : 0.0;
              }
            }

            if (ev.type == TransactionType.income) {
              tempBalances[accId] =
                  (tempBalances[accId] ?? 0.0) + amountInAccCurrency;
            } else {
              tempBalances[accId] =
                  (tempBalances[accId] ?? 0.0) - amountInAccCurrency;
            }

            if (tempBalances[accId]! < minBalances[accId]!) {
              minBalances[accId] = tempBalances[accId]!;
              minDates[accId] = ev.date;
              minReasons[accId] = ev.title;
            }
          }
        }
      }
    }

    final deficitAccounts = accounts
        .where((acc) => minBalances[acc.id]! < 0)
        .toList();

    Map<String, double> pocketProvisions = {};
    for (var ev in events) {
      if (ev.isSuggestion &&
          ev.type == TransactionType.expense &&
          ev.pocketName != null) {
        pocketProvisions[ev.pocketName!] =
            (pocketProvisions[ev.pocketName!] ?? 0.0) + ev.amount;
      }
    }

    // Analyze Cash Flow Periods (Pre-Cobro and Post-Cobro)
    TimelineEvent? firstIncomeEvent;
    for (var ev in events) {
      if (ev.type == TransactionType.income && !ev.isSuggestion) {
        firstIncomeEvent = ev;
        break;
      }
    }

    List<TimelineEvent> preCobroExpenses = [];
    double totalPreCobroExpensesUSD = 0.0;
    if (firstIncomeEvent != null) {
      preCobroExpenses = events
          .where(
            (ev) =>
                ev.type == TransactionType.expense &&
                !ev.isSuggestion &&
                ev.date.isBefore(firstIncomeEvent!.date),
          )
          .toList();

      for (var ev in preCobroExpenses) {
        double amtUSD = ev.amount;
        if (ev.currency == CurrencyType.bsBCV) {
          amtUSD = bcvRate > 0 ? ev.amount / bcvRate : 0.0;
        }
        totalPreCobroExpensesUSD += amtUSD;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
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
                SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Resumen de Proyección",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  "Este resumen analiza tus cuentas físicas y bolsillos durante los próximos 30 días para ayudarte a tomar decisiones financieras inteligentes.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20),

                Text(
                  "Saldos Actuales en Cuentas",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 10),
                ...accounts.map((acc) {
                  final balanceFormatted = acc.currency == CurrencyType.usd
                      ? "\$${acc.balance.toStringAsFixed(2)}"
                      : "${acc.balance.toStringAsFixed(2)} Bs.";
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          acc.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        Text(
                          balanceFormatted,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cardText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 20),

                // Cash flow period breakdown section
                Text(
                  "Análisis del Flujo de Caja (Próximos 30 Días)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstIncomeEvent != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              color: AppColors.expense,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Período Pre-Cobro (Hoy al cobro)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Tienes ${preCobroExpenses.length} egresos programados antes de tu próximo ingreso. Suman un equivalente aproximado de \$${totalPreCobroExpensesUSD.toStringAsFixed(2)}.\n"
                                    "${preCobroExpenses.isNotEmpty ? 'Egresos: ${preCobroExpenses.map((e) => e.title).join(', ')}.' : 'Sin egresos programados.'}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cardSubtitleText,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: AppColors.income,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Día de Cobro (${formatDate(firstIncomeEvent.date)})",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Se proyecta recibir '${firstIncomeEvent.title}' de ${firstIncomeEvent.currency == CurrencyType.usd ? '\$' : ''}${firstIncomeEvent.amount.toStringAsFixed(2)}${firstIncomeEvent.currency == CurrencyType.bsBCV ? ' Bs.' : ''}.\n"
                                    "Esto incrementará tu balance líquido proyectado.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cardSubtitleText,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Período Post-Cobro",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Posterior a tu cobro, la app continuará descontando los gastos programados y provisionando tus bolsillos de ahorro automáticamente.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cardSubtitleText,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "No se proyectan ingresos recurrentes en los próximos 30 días. Tu presupuesto dependerá completamente del saldo actual disponible en tus cuentas.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.cardSubtitleText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),

                if (deficitAccounts.isNotEmpty) ...[
                  Text(
                    "Sugerencias de Transferencia e Intercambio",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: 10),
                  ...deficitAccounts.map((acc) {
                    final defAmount = -minBalances[acc.id]!;
                    final defUSD = acc.currency == CurrencyType.usd
                        ? defAmount
                        : (bcvRate > 0 ? defAmount / bcvRate : 0.0);
                    final dateStr = formatDate(minDates[acc.id]!);
                    final reason = minReasons[acc.id];
                    final amountFormatted = acc.currency == CurrencyType.usd
                        ? "\$${defAmount.toStringAsFixed(2)}"
                        : "${defAmount.toStringAsFixed(2)} Bs.";
                    final usdEquivFormatted = "\$${defUSD.toStringAsFixed(2)}";

                    // Dynamic selection of USD accounts with positive balance
                    final usdAccounts = accounts
                        .where(
                          (a) =>
                              a.currency == CurrencyType.usd && a.balance > 0,
                        )
                        .toList();

                    String solutionText = "";
                    if (usdAccounts.isEmpty) {
                      solutionText =
                          "Solución Recomendada: Actualmente no tienes saldo disponible en tus otras cuentas en dólares para transferir. Te sugerimos depositar o registrar ingresos adicionales antes del $dateStr para cubrir este compromiso a tiempo.";
                    } else {
                      final accountsStr = usdAccounts
                          .map(
                            (a) =>
                                "'${a.name}' (\$${a.balance.toStringAsFixed(2)})",
                          )
                          .join(' o ');
                      solutionText =
                          "Solución Recomendada: Como tienes saldo disponible en tus cuentas en dólares ($accountsStr), te sugerimos transferir o cambiar el equivalente a $usdEquivFormatted ($amountFormatted) a tu cuenta '${acc.name}' antes del $dateStr. Al momento de registrar este pago, la app te ofrecerá hacer esta transferencia de forma automática para evitar saldos negativos.";
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.expense.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: AppColors.expense,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Déficit Proyectado en ${acc.name}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Tu balance en '${acc.name}' caerá a -$amountFormatted (aprox. -$usdEquivFormatted) el $dateStr debido al gasto '$reason'.",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.cardSubtitleText,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    solutionText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.cardText,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 20),
                ],

                Text(
                  "Retenciones Proyectadas para Bolsillos (30 Días)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: 10),
                if (pocketProvisions.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "No se proyectan retenciones automáticas de bolsillos en los próximos 30 días.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.cardSubtitleText,
                      ),
                    ),
                  )
                else
                  ...pocketProvisions.entries.map((entry) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Apartar para '${entry.key}'",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            "\$${entry.value.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: 20),

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Dinero Seguro actual: \$${appState.liquidBalanceUSD.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "El Dinero Seguro representa la cantidad de efectivo neto que te queda libre después de restar los saldos reservados para tus bolsillos de ahorro. Si mantienes tus retenciones en orden, nunca correrás el riesgo de quedar en saldo negativo.",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Cerrar Resumen",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildStepCard({
    required String title,
    required Widget content,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Colors.white.withOpacity(
              0.04,
            ), // use subtle white transparency to look glassmorphic on dark/light backgrounds
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final appState = Provider.of<AppState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: "Todos",
                selected: _selectedType == 'all',
                onTap: () => setState(() {
                  _selectedType = 'all';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: 8),
              _buildFilterChip(
                label: "Ingresos",
                selected: _selectedType == 'income',
                onTap: () => setState(() {
                  _selectedType = 'income';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: 8),
              _buildFilterChip(
                label: "Gastos",
                selected: _selectedType == 'expense',
                onTap: () => setState(() {
                  _selectedType = 'expense';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: 8),
              _buildFilterChip(
                label: "Sugerencias",
                selected: _selectedType == 'suggestion',
                onTap: () => setState(() {
                  _selectedType = 'suggestion';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
            ],
          ),
        ),
        
        // Secondary filter row
        if (_selectedType == 'income' || _selectedType == 'expense') ...[
          SizedBox(height: 10),
          Builder(
            builder: (context) {
              final typeFilter = _selectedType == 'income' ? TransactionType.income : TransactionType.expense;
              final relevantRecurrents = appState.recurringPayments.where((p) => p.type == typeFilter).toList();
              
              if (relevantRecurrents.isEmpty) return SizedBox.shrink();
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: "Todos",
                      selected: _selectedRecurringId == null,
                      onTap: () => setState(() => _selectedRecurringId = null),
                    ),
                    ...relevantRecurrents.map((p) {
                      return Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: _buildFilterChip(
                          label: p.name,
                          selected: _selectedRecurringId == p.id,
                          onTap: () => setState(() => _selectedRecurringId = p.id),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }
          ),
        ] else if (_selectedType == 'suggestion') ...[
          SizedBox(height: 10),
          Builder(
            builder: (context) {
              final relevantPockets = appState.pockets;
              if (relevantPockets.isEmpty) return SizedBox.shrink();
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: "Todos",
                      selected: _selectedPocketId == null,
                      onTap: () => setState(() => _selectedPocketId = null),
                    ),
                    ...relevantPockets.map((p) {
                      return Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: _buildFilterChip(
                          label: p.name,
                          selected: _selectedPocketId == p.id,
                          onTap: () => setState(() => _selectedPocketId = p.id),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.nestedTabTrackBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.mainTabInactiveText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final events = appState.getTimelineEvents(_selectedDays);
    final safeExplanation = appState.safeToSaveExplanation;
    final safeAmount = safeExplanation['amount'] as double;
    final minDate = safeExplanation['date'] as DateTime?;
    final minReason = safeExplanation['reason'] as String?;
    final maxToSave = safeAmount > 0 ? safeAmount : 0.0;

    // Apply type filter
    final filteredEvents = events.where((event) {
      if (_selectedType == 'all') return true;
      if (_selectedType == 'income') {
        final matchesType = event.type == TransactionType.income && !event.isSuggestion;
        if (!matchesType) return false;
        if (_selectedRecurringId != null) {
          return event.recurringPaymentId == _selectedRecurringId;
        }
        return true;
      }
      if (_selectedType == 'expense') {
        final matchesType = event.type == TransactionType.expense && !event.isSuggestion;
        if (!matchesType) return false;
        if (_selectedRecurringId != null) {
          return event.recurringPaymentId == _selectedRecurringId;
        }
        return true;
      }
      if (_selectedType == 'suggestion') {
        if (!event.isSuggestion) return false;
        if (_selectedPocketId != null) {
          return event.pocketId == _selectedPocketId;
        }
        return true;
      }
      return true;
    }).toList();

    // Build grouped list items
    final List<dynamic> listItems = [];
    String? currentHeader;

    double dayIncomeNativeUSD = 0;
    double dayIncomeNativeBs = 0;
    double dayIncomeBsConvertedUsd = 0;
    double dayIncomeNativeEur = 0;
    double dayIncomeEurConvertedUsd = 0;
    
    double dayExpenseNativeUSD = 0;
    double dayExpenseNativeBs = 0;
    double dayExpenseBsConvertedUsd = 0;
    double dayExpenseNativeEur = 0;
    double dayExpenseEurConvertedUsd = 0;
    
    double dayPocketUSD = 0;
    double finalBalanceUSD = 0;
    double finalLiquidBalanceUSD = 0;

    for (int i = 0; i < filteredEvents.length; i++) {
      final event = filteredEvents[i];
      final header = _getDateHeader(event.date);

      if (header != currentHeader) {
        if (currentHeader != null) {
          listItems.add(TimelineDaySummaryEvent(
            incomeNativeUSD: dayIncomeNativeUSD,
            incomeNativeBs: dayIncomeNativeBs,
            incomeBsConvertedUsd: dayIncomeBsConvertedUsd,
            incomeNativeEur: dayIncomeNativeEur,
            incomeEurConvertedUsd: dayIncomeEurConvertedUsd,
            expenseNativeUSD: dayExpenseNativeUSD,
            expenseNativeBs: dayExpenseNativeBs,
            expenseBsConvertedUsd: dayExpenseBsConvertedUsd,
            expenseNativeEur: dayExpenseNativeEur,
            expenseEurConvertedUsd: dayExpenseEurConvertedUsd,
            pocketUSD: dayPocketUSD,
            finalBalanceUSD: finalBalanceUSD,
            finalLiquidBalanceUSD: finalLiquidBalanceUSD,
          ));
        }

        currentHeader = header;
        listItems.add(header);
        
        // Reset counters
        dayIncomeNativeUSD = 0;
        dayIncomeNativeBs = 0;
        dayIncomeBsConvertedUsd = 0;
        dayIncomeNativeEur = 0;
        dayIncomeEurConvertedUsd = 0;
        
        dayExpenseNativeUSD = 0;
        dayExpenseNativeBs = 0;
        dayExpenseBsConvertedUsd = 0;
        dayExpenseNativeEur = 0;
        dayExpenseEurConvertedUsd = 0;
        
        dayPocketUSD = 0;
      }

      finalBalanceUSD = event.projectedBalanceUSD;
      finalLiquidBalanceUSD = event.projectedLiquidBalanceUSD;

      double amountNativeUSD = 0.0;
      double amountNativeBs = 0.0;
      double amountBsConvertedUsd = 0.0;
      double amountNativeEur = 0.0;
      double amountEurConvertedUsd = 0.0;

      // Determine target currency (if account is present, use its currency, else use event currency)
      var targetCurrency = event.currency;
      if (event.accountName != null) {
        try {
          final targetAcc = appState.accounts.firstWhere((a) => a.name == event.accountName);
          targetCurrency = targetAcc.currency;
        } catch (_) {}
      }

      // 1. Calculate the amount in USD based on the event's original currency.
      double eventAmountInUSD = 0.0;
      if (event.currency == CurrencyType.usd) {
        eventAmountInUSD = event.amount;
      } else if (event.currency == CurrencyType.bsBCV) {
        eventAmountInUSD = appState.bcvRate > 0 ? event.amount / appState.bcvRate : 0.0;
      } else if (event.currency == CurrencyType.eur) {
        eventAmountInUSD = appState.euroRate > 0 ? event.amount / appState.euroRate : 0.0;
      }

      // 2. Allocate it to the correct target bucket based on targetCurrency.
      if (targetCurrency == CurrencyType.usd) {
        amountNativeUSD = eventAmountInUSD;
      } else if (targetCurrency == CurrencyType.bsBCV) {
        amountNativeBs = eventAmountInUSD * appState.bcvRate;
        amountBsConvertedUsd = eventAmountInUSD;
      } else if (targetCurrency == CurrencyType.eur) {
        amountNativeEur = eventAmountInUSD * appState.euroRate;
        amountEurConvertedUsd = eventAmountInUSD;
      }

      if (event.isSuggestion) {
        // Pockets logic currently aggregates all converted to USD
        dayPocketUSD += eventAmountInUSD;
      } else if (event.type == TransactionType.income) {
        dayIncomeNativeUSD += amountNativeUSD;
        dayIncomeNativeBs += amountNativeBs;
        dayIncomeBsConvertedUsd += amountBsConvertedUsd;
        dayIncomeNativeEur += amountNativeEur;
        dayIncomeEurConvertedUsd += amountEurConvertedUsd;
      } else if (event.type == TransactionType.expense) {
        dayExpenseNativeUSD += amountNativeUSD;
        dayExpenseNativeBs += amountNativeBs;
        dayExpenseBsConvertedUsd += amountBsConvertedUsd;
        dayExpenseNativeEur += amountNativeEur;
        dayExpenseEurConvertedUsd += amountEurConvertedUsd;
      }

      listItems.add(event);
    }
    
    if (currentHeader != null) {
      listItems.add(TimelineDaySummaryEvent(
        incomeNativeUSD: dayIncomeNativeUSD,
        incomeNativeBs: dayIncomeNativeBs,
        incomeBsConvertedUsd: dayIncomeBsConvertedUsd,
        incomeNativeEur: dayIncomeNativeEur,
        incomeEurConvertedUsd: dayIncomeEurConvertedUsd,
        expenseNativeUSD: dayExpenseNativeUSD,
        expenseNativeBs: dayExpenseNativeBs,
        expenseBsConvertedUsd: dayExpenseBsConvertedUsd,
        expenseNativeEur: dayExpenseNativeEur,
        expenseEurConvertedUsd: dayExpenseEurConvertedUsd,
        pocketUSD: dayPocketUSD,
        finalBalanceUSD: finalBalanceUSD,
        finalLiquidBalanceUSD: finalLiquidBalanceUSD,
      ));
    }

    int firstEventIndex = -1;
    int lastEventIndex = -1;
    if (filteredEvents.isNotEmpty) {
      firstEventIndex = listItems.indexWhere((item) => item is TimelineEvent);
      for (int i = listItems.length - 1; i >= 0; i--) {
        if (listItems[i] is TimelineEvent) {
          lastEventIndex = i;
          break;
        }
      }
    }

    const periodTitle = "1 Año";

    return SliverList.builder(
      itemCount: listItems.isEmpty ? 2 : listItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Safe to Save Card - Flat White Card with black/teal contrast to match design
              Showcase(
                key: _dineroSeguroKey,
                title: "Dinero Seguro y Límites",
                description: "Muestra tu 'Dinero Seguro', que es el dinero disponible actual libre de obligaciones. Si tu saldo cae por debajo de cero en el futuro, verás una meta diaria recomendada para cubrir el déficit.",
                child: ClaymorphicCard(
                  cornerRadius: 24,
                  padding: EdgeInsets.all(20.0),
                  backgroundColor: AppColors.cardBackground,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Planificación de Dinero Seguro",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: () => _showTimelineInfo(context),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Ahorro o Gasto Libre Extra",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              formatUSD(maxToSave),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Dinero adicional que puedes ahorrar en tus bolsillos o gastar libremente en antojos hoy sin afectar tus pagos planificados.",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cardSubtitleText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        safeAmount < 0
                            ? "¡Alerta de déficit! Tu dinero proyectado caerá por debajo de cero, llegando a ${formatUSD(safeAmount)} el ${formatDate(minDate!)} debido al compromiso '$minReason'. No deberías ahorrar ni realizar gastos discrecionales hasta solucionar este déficit."
                            : (minDate != null
                                  ? "El simulador YA reservó el dinero para tus pagos futuros (incluyendo '$minReason' y demás compromisos del ${formatDate(minDate)}). Estos límites representan dinero ADICIONAL y LIBRE que puedes ahorrar o gastar en antojos hoy sin arriesgar tus pagos."
                                  : (appState.recurringPayments.any(
                                          (p) => p.type == TransactionType.expense,
                                        )
                                        ? "Tienes gastos programados, pero tus ingresos proyectados los cubren por completo. ¡Es seguro destinar tu dinero disponible actual al ahorro en bolsillos o a gastos libres!"
                                        : "No tienes gastos programados en tu agenda. ¡Es seguro destinar todo tu dinero disponible actual al ahorro en bolsillos o a gastos libres!")),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      PurchaseSimulationBottomSheet(),
                                );
                              },
                              icon: Icon(
                                Icons.shopping_cart_checkout_rounded,
                                size: 18,
                              ),
                              label: Text("Simular"),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppColors.primary.withOpacity(0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _showTimelineSummaryBottomSheet(context),
                              icon: Icon(Icons.analytics_outlined, size: 18),
                              label: Text("Resumen"),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppColors.primary.withOpacity(0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
              if (safeAmount < 0 && minDate != null) ...[
                SizedBox(height: 16),
                _buildSalesGoalCard(context, safeAmount, minDate, minReason ?? ''),
              ],
              SizedBox(height: 24),

              // Timeline header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Timeline de Proyección ($periodTitle)",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Filters UI
              Showcase(
                key: _filterTimelineKey,
                title: "Filtros de Proyección",
                description: "Filtra el listado por ingresos, gastos o 'Sugerencias'. Las Sugerencias son recomendaciones automáticas que te indican cuándo y cuánto transferir a tus bolsillos de ahorro para pre-fondear cuotas futuras y proteger tu saldo líquido.",
                child: _buildFilterChips(),
              ),
              SizedBox(height: 12),
            ]
          );
        }

        if (filteredEvents.isEmpty) {
          return Showcase(
            key: _timelineListKey,
            title: "Agenda de Proyección Futura",
            description: "Aquí verás la evolución de tus saldos día a día. Actualmente está vacía porque no tienes obligaciones recurrentes registradas. Cuando agregues cobros o pagos programados en la pestaña 'Recurrentes', verás el flujo proyectado y sugerencias inteligentes de ahorro.",
            child: ClaymorphicCard(
              padding: EdgeInsets.symmetric(
                vertical: 36.0,
                horizontal: 24.0,
              ),
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timeline_rounded,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Sin Proyecciones",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "No hay transacciones programadas para el filtro seleccionado en este período.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.cardSubtitleText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final listIndex = index - 1;
        final item = listItems[listIndex];
        if (item is String) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20.0,
              bottom: 8.0,
              left: 4.0,
              right: 4.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    final dayEvents = events
                        .where((e) => _getDateHeader(e.date) == item)
                        .toList();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => DayActionsBottomSheet(
                        headerText: item,
                        dayEvents: dayEvents,
                      ),
                    );
                  },
                  constraints: BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          );
        } else if (item is TimelineDaySummaryEvent) {
          return Padding(
            padding: EdgeInsets.only(top: 8, bottom: 24),
            child: Row(
              children: [
                SizedBox(width: 48), // 40 (timeline) + 8 (spacing in TimelineEventRow)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Resumen del Día", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        SizedBox(height: 8),
                        
                        // Ingresos
                        if (item.incomeNativeUSD > 0 || item.incomeNativeBs > 0 || item.incomeNativeEur > 0) ...[
                          Text("Ingresos:", style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText)),
                          if (item.incomeNativeUSD > 0)
                            Text("  - USD: \$${item.incomeNativeUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income)),
                          if (item.incomeNativeBs > 0)
                            Text("  - Bs: ${item.incomeNativeBs.toStringAsFixed(2)} (BCV: \$${item.incomeBsConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income)),
                          if (item.incomeNativeEur > 0)
                            Text("  - EUR: ${item.incomeNativeEur.toStringAsFixed(2)} (BCV: \$${item.incomeEurConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income)),
                          SizedBox(height: 6),
                        ],

                        // Gastos
                        if (item.expenseNativeUSD > 0 || item.expenseNativeBs > 0 || item.expenseNativeEur > 0) ...[
                          Text("Gastos:", style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText)),
                          if (item.expenseNativeUSD > 0)
                            Text("  - USD: \$${item.expenseNativeUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          if (item.expenseNativeBs > 0)
                            Text("  - Bs: ${item.expenseNativeBs.toStringAsFixed(2)} (BCV: \$${item.expenseBsConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          if (item.expenseNativeEur > 0)
                            Text("  - EUR: ${item.expenseNativeEur.toStringAsFixed(2)} (BCV: \$${item.expenseEurConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          SizedBox(height: 6),
                        ],

                        if (item.pocketUSD > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Bolsillos (Sugerido):", style: TextStyle(fontSize: 11, color: AppColors.cardSubtitleText)),
                              Text("\$${item.pocketUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Container(height: 1, color: AppColors.primary.withOpacity(0.1)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Balance General Final:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                            Text("\$${item.finalBalanceUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Dinero Libre Final:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                            Text("\$${item.finalLiquidBalanceUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          final event = item as TimelineEvent;
          final row = TimelineEventRow(
            event: event,
            isFirst: listIndex == firstEventIndex,
            isLast: listIndex == lastEventIndex,
          );
          if (listIndex == firstEventIndex) {
            return Showcase(
              key: _timelineListKey,
              title: "Agenda de Proyección Futura",
              description: "Esta lista detalla cronológicamente cómo afectarán tus cobros y pagos programados al saldo de tus cuentas. También verás sugerencias automáticas del simulador para transferir fondos a tus bolsillos y evitar saldo negativo.",
              child: row,
            );
          }
          return row;
        }
      },
    );
  }
}
