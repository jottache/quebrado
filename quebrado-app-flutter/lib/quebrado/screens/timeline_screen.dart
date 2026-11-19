import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../viewmodels/app_state.dart';
import '../models/timeline_event.dart';
import '../models/timeline_day_summary.dart';
import '../models/currency_type.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../widgets/helpers.dart';
import '../widgets/timeline_event_row.dart';
import '../widgets/currency_pill.dart';
import '../dialogs/purchase_simulation_bottom_sheet.dart';
import '../services/db_helper.dart';
import '../dialogs/day_actions_dialog.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
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

  String _selectedType = 'all'; // 'all', 'income', 'expense', 'suggestion', 'exchange'
  final int _selectedDays = 365; // 30, 90, 365
  String? _selectedRecurringId;
  String? _selectedPocketId;
  String _selectedCurrencyFilter = 'all'; // 'all', 'usd', 'bs': moneda con la que se paga

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
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
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
                      color: OrtizPalette.line,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Sobre la Proyección Financiera",
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "¿Qué es el Dinero Seguro?",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "Es el saldo líquido mínimo proyectado que tendrán tus cuentas consolidadas en los próximos 12 meses. Este saldo define dos límites clave para hoy:\n\n"
                  "• Límite de Ahorro: El monto máximo que puedes mover a tus bolsillos de reserva. Al guardarlo allí, tu patrimonio neto no disminuye y proteges tu dinero para metas futuras.\n\n"
                  "• Límite de Gasto: El monto máximo que puedes gastar libremente hoy en cualquier consumo. Esto reduce tu patrimonio permanentemente, pero es seguro hacerlo porque no afectará tus pagos y obligaciones proyectadas.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "¿Cómo funciona la Proyección a 1 Año?",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "El Timeline simula día a día tus transacciones recurrentes registradas (como sueldos, alquileres, cuotas de Cashea o suscripciones). En cada evento verás un balance proyectado estimado, lo que te permite anticipar momentos de bajo flujo de caja.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Importancia de la Cuenta/Bolsillo",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "• Los eventos asociados a una cuenta afectan directamente tu dinero disponible en tus cuentas.\n• Los eventos asociados a un bolsillo se descuentan del ahorro acumulado en ese bolsillo, protegiendo tu dinero del día a día.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.xxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
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
        padding: EdgeInsets.all(OrtizSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(OrtizRadius.sheet),
          border: Border.all(
            color: AppColors.expense.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: OrtizPalette.onAccent,
                    size: OrtizIconSize.md,
                  ),
                ),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Meta Diaria de Ventas / Trabajo",
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.expense,
                  size: OrtizIconSize.sm,
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),
            Text(
              "Generar ${formatUSD(dailyRequiredIncome)} extra / día",
              style: TextStyle(
                fontSize: OrtizFontSize.display,
                fontWeight: FontWeight.w900,
                color: AppColors.expense,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              "Para cubrir '$minReason' el ${formatDate(minDate)} sin caer en saldo negativo, necesitas producir un promedio de ${formatUSD(dailyRequiredIncome)} diarios adicionales sobre tu mínimo habitual de ${formatUSD(baseIncome)}.\n\nMeta diaria total recomendada: ${formatUSD(totalDailyTarget)} al día (durante los próximos $daysToDeficit días).",
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.expense.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            SizedBox(height: OrtizSpace.md),
            Center(
              child: Text(
                "Toca aquí para ver la explicación detallada paso a paso",
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense.withValues(alpha: 0.8),
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
      if (ev.isCashFlow && ev.type == TransactionType.income) {
        final usd = ev.amountUSD ?? ev.amount;
        totalIncomeInPeriod += usd;
        incomeCounts[ev.title] = (incomeCounts[ev.title] ?? 0) + 1;
        incomeAmounts[ev.title] = (incomeAmounts[ev.title] ?? 0.0) + usd;
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
        final usd = ev.amountUSD ?? ev.amount;
        pocketsNeeded += usd;
        pocketReserves[ev.pocketName!] =
            (pocketReserves[ev.pocketName!] ?? 0.0) + usd;
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
      if (ev.isCashFlow && ev.type == TransactionType.expense) {
        final usd = ev.amountUSD ?? ev.amount;
        recurringExpensesNeeded += usd;
        expenseCounts[ev.title] = (expenseCounts[ev.title] ?? 0) + 1;
        expenseAmounts[ev.title] =
            (expenseAmounts[ev.title] ?? 0.0) + usd;
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
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
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
                      color: OrtizPalette.line,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                SizedBox(height: OrtizSpace.xl),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: AppColors.expense,
                        size: OrtizIconSize.md,
                      ),
                    ),
                    SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        "Explicación de tu Meta Diaria",
                        style: TextStyle(
                          fontSize: OrtizFontSize.titleSm,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: OrtizSpace.xl),
                Text(
                  "Aquí tienes el desglose paso a paso de tus cuentas para entender de dónde sale esta meta:",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),

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
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        ...pocketDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: OrtizSpace.sm,
                              bottom: OrtizSpace.xs,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: OrtizSpace.sm),
                      ],
                      if (expenseDetails.isNotEmpty) ...[
                        Text(
                          "Gastos programados en el período:",
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        ...expenseDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: OrtizSpace.sm,
                              bottom: OrtizSpace.xs,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
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
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(totalNeeded),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(initialLiquid),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "Ingresos mínimos estimados en el período:",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      if (incomeDetails.isNotEmpty)
                        ...incomeDetails.map(
                          (det) => Padding(
                            padding: EdgeInsets.only(
                              left: OrtizSpace.sm,
                              bottom: OrtizSpace.xs,
                            ),
                            child: Text(
                              det,
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                color: AppColors.cardSubtitleText,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.only(left: OrtizSpace.sm),
                          child: Text(
                            "• Sin ingresos programados",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(totalAvailable),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(totalNeeded),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total disponible estimado:",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                          Text(
                            formatUSD(totalAvailable),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            formatUSD(deficit),
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  borderColor: AppColors.primary.withValues(alpha: 0.2),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Para conseguir los ${formatUSD(deficit)} que te faltan antes del día del pago, dividimos ese monto entre los $daysToDeficit días que te quedan para trabajar:",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "• ${formatUSD(deficit)} / $daysToDeficit días = ${formatUSD(dailyRequiredIncome)} diarios adicionales.",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      Text(
                        "Por lo tanto, tu meta de ventas o ingresos diarios totales recomendada para cubrir todo sin deudas es de:",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        "• ${formatUSD(baseIncome)} (Tu mínimo habitual) + ${formatUSD(dailyRequiredIncome)} (El extra necesario) = ${formatUSD(totalDailyTarget)} al día.",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                      ),
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    ),
                    child: Text(
                      "Entendido",
                      style: TextStyle(
                        fontSize: OrtizFontSize.body,
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

    // Saldo mínimo de cada cuenta según el motor (incluye los cambios $→Bs sugeridos)
    for (var ev in events) {
      final balances = ev.accountBalances;
      if (balances == null) continue;
      for (final acc in accounts) {
        final bal = balances[acc.id];
        if (bal == null) continue;
        if (bal < minBalances[acc.id]!) {
          minBalances[acc.id] = bal;
          minDates[acc.id] = ev.date;
          minReasons[acc.id] = ev.title;
        }
      }
    }

    // Bolívares de los próximos 30 días
    final bsAccountNames = accounts.where((a) => a.currency == CurrencyType.bsBCV).map((a) => a.name).toSet();
    double bsNeeded = 0.0;
    double bsIncoming = 0.0;
    for (var ev in events) {
      if (!ev.isCashFlow) continue;
      final paidInBs = ev.currency == CurrencyType.bsBCV || bsAccountNames.contains(ev.accountName);
      if (!paidInBs) continue;
      final bs = ev.currency == CurrencyType.bsBCV ? ev.amount : (ev.amountUSD ?? 0.0) * bcvRate;
      if (ev.type == TransactionType.expense) {
        bsNeeded += bs;
      } else {
        bsIncoming += bs;
      }
    }
    final exchangeEvents = events.where((ev) => ev.isExchangeSuggestion).toList();
    final totalToSellUSD = exchangeEvents.fold(0.0, (sum, ev) => sum + ev.amount);

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
      if (ev.type == TransactionType.income && ev.isCashFlow) {
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
                ev.isCashFlow &&
                ev.date.isBefore(firstIncomeEvent!.date),
          )
          .toList();

      for (var ev in preCobroExpenses) {
        totalPreCobroExpensesUSD += ev.amountUSD ?? appState.convertToUSD(amount: ev.amount, from: ev.currency);
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
            topLeft: Radius.circular(OrtizRadius.sheet),
            topRight: Radius.circular(OrtizRadius.sheet),
          ),
        ),
        padding: EdgeInsets.all(OrtizSpace.xl),
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
                      color: OrtizPalette.line,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                SizedBox(height: OrtizSpace.xl),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        color: AppColors.primary,
                        size: OrtizIconSize.lg,
                      ),
                    ),
                    SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        "Resumen de Proyección",
                        style: TextStyle(
                          fontSize: OrtizFontSize.title,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: OrtizSpace.lg),
                Text(
                  "Este resumen analiza tus cuentas físicas y bolsillos durante los próximos 30 días para ayudarte a tomar decisiones financieras inteligentes.",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: OrtizSpace.xl),

                Text(
                  "Saldos Actuales en Cuentas",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.sm),
                ...accounts.map((acc) {
                  final balanceFormatted = acc.currency == CurrencyType.usd
                      ? "\$${acc.balance.toStringAsFixed(2)}"
                      : "${acc.balance.toStringAsFixed(2)} Bs.";
                  return Container(
                    margin: EdgeInsets.only(bottom: OrtizSpace.sm),
                    padding: EdgeInsets.symmetric(
                      horizontal: OrtizSpace.md,
                      vertical: OrtizSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: OrtizPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      border: Border.all(color: OrtizPalette.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          acc.name,
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                        ),
                        Text(
                          balanceFormatted,
                          style: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cardText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: OrtizSpace.xl),

                // Cash flow period breakdown section
                Text(
                  "Análisis del Flujo de Caja (Próximos 30 Días)",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.sm),
                Container(
                  padding: EdgeInsets.all(OrtizSpace.lg),
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.block),
                    border: Border.all(color: OrtizPalette.line),
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
                              size: OrtizIconSize.sm,
                            ),
                            SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Período Pre-Cobro (Hoy al cobro)",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: OrtizSpace.xs),
                                  Text(
                                    "Tienes ${preCobroExpenses.length} egresos programados antes de tu próximo ingreso. Suman un equivalente aproximado de \$${totalPreCobroExpensesUSD.toStringAsFixed(2)}.\n"
                                    "${preCobroExpenses.isNotEmpty ? 'Egresos: ${preCobroExpenses.map((e) => e.title).join(', ')}.' : 'Sin egresos programados.'}",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.caption,
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
                              size: OrtizIconSize.sm,
                            ),
                            SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Día de Cobro (${formatDate(firstIncomeEvent.date)})",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: OrtizSpace.xs),
                                  Text(
                                    "Se proyecta recibir '${firstIncomeEvent.title}' de ${firstIncomeEvent.currency == CurrencyType.usd ? '\$' : ''}${firstIncomeEvent.amount.toStringAsFixed(2)}${firstIncomeEvent.currency == CurrencyType.bsBCV ? ' Bs.' : ''}.\n"
                                    "Esto incrementará tu balance líquido proyectado.",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.caption,
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
                              size: OrtizIconSize.sm,
                            ),
                            SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Período Post-Cobro",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardText,
                                    ),
                                  ),
                                  SizedBox(height: OrtizSpace.xs),
                                  Text(
                                    "Posterior a tu cobro, la app continuará descontando los gastos programados y provisionando tus bolsillos de ahorro automáticamente.",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.caption,
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
                              size: OrtizIconSize.sm,
                            ),
                            SizedBox(width: OrtizSpace.sm),
                            Expanded(
                              child: Text(
                                "No se proyectan ingresos recurrentes en los próximos 30 días. Tu presupuesto dependerá completamente del saldo actual disponible en tus cuentas.",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
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
                SizedBox(height: OrtizSpace.xl),

                if (deficitAccounts.isNotEmpty) ...[
                  Text(
                    "Sugerencias de Transferencia e Intercambio",
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.sm),
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
                      margin: EdgeInsets.only(bottom: OrtizSpace.md),
                      padding: EdgeInsets.all(OrtizSpace.lg),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
                        border: Border.all(
                          color: AppColors.expense.withValues(alpha: 0.2),
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
                                size: OrtizIconSize.md,
                              ),
                              SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Text(
                                  "Déficit Proyectado en ${acc.name}",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.sm),
                          Text(
                            "Tu balance en '${acc.name}' caerá a -$amountFormatted (aprox. -$usdEquivFormatted) el $dateStr debido al gasto '$reason'.",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              color: AppColors.cardSubtitleText,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.sm),
                            decoration: BoxDecoration(
                              color: OrtizPalette.surfaceHigh,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.primary,
                                  size: OrtizIconSize.sm,
                                ),
                                SizedBox(width: OrtizSpace.xs),
                                Expanded(
                                  child: Text(
                                    solutionText,
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.caption,
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
                  SizedBox(height: OrtizSpace.xl),
                ],

                if (bsNeeded > 0 || exchangeEvents.isNotEmpty) ...[
                  Text(
                    "Bolívares (30 Días)",
                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                  ),
                  SizedBox(height: OrtizSpace.sm),
                  Container(
                    key: ValueKey('projection_bs_summary'),
                    width: double.infinity,
                    padding: EdgeInsets.all(OrtizSpace.md),
                    decoration: BoxDecoration(
                      color: OrtizPalette.warnTint,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      border: Border.all(color: OrtizPalette.warnBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gastos en Bs: Bs. ${bsNeeded.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                        Text("Ingresos en Bs: Bs. ${bsIncoming.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                        Text("Bs disponibles hoy: Bs. ${appState.liquidBalanceBs.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText)),
                        SizedBox(height: OrtizSpace.xs),
                        Text(
                          exchangeEvents.isEmpty
                              ? "Tus Bs alcanzan: no necesitas vender dólares."
                              : "Tendrás que vender \$${totalToSellUSD.toStringAsFixed(2)} en total:",
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: OrtizPalette.warn),
                        ),
                        ...exchangeEvents.map((ev) => Text(
                              "• ${formatDate(ev.date)}: \$${ev.amount.toStringAsFixed(2)} → Bs. ${(ev.exchangeAmountBs ?? 0).toStringAsFixed(2)}",
                              style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
                            )),
                      ],
                    ),
                  ),
                  SizedBox(height: OrtizSpace.xl),
                ],

                Text(
                  "Retenciones Proyectadas para Bolsillos (30 Días)",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                SizedBox(height: OrtizSpace.sm),
                if (pocketProvisions.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                    child: Text(
                      "No se proyectan retenciones automáticas de bolsillos en los próximos 30 días.",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        color: AppColors.cardSubtitleText,
                      ),
                    ),
                  )
                else
                  ...pocketProvisions.entries.map((entry) {
                    return Container(
                      margin: EdgeInsets.only(bottom: OrtizSpace.sm),
                      padding: EdgeInsets.symmetric(
                        horizontal: OrtizSpace.md,
                        vertical: OrtizSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: OrtizPalette.accentTint,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Apartar para '${entry.key}'",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          Text(
                            "\$${entry.value.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.w900,
                              color: OrtizPalette.accent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: OrtizSpace.xl),

                Container(
                  padding: EdgeInsets.all(OrtizSpace.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(OrtizRadius.block),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
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
                            size: OrtizIconSize.sm,
                          ),
                          SizedBox(width: OrtizSpace.sm),
                          Text(
                            "Dinero Seguro actual: \$${appState.liquidBalanceUSD.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.sm),
                      Text(
                        "El Dinero Seguro representa la cantidad de efectivo neto que te queda libre después de restar los saldos reservados para tus bolsillos de ahorro. Si mantienes tus retenciones en orden, nunca correrás el riesgo de quedar en saldo negativo.",
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: OrtizSpace.xxl),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                    ),
                    child: Text(
                      "Cerrar Resumen",
                      style: TextStyle(
                        fontSize: OrtizFontSize.body,
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
      margin: EdgeInsets.only(bottom: OrtizSpace.lg),
      padding: EdgeInsets.all(OrtizSpace.lg),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? OrtizPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: Border.all(
          color: borderColor ?? OrtizPalette.line,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: FontWeight.bold,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: OrtizSpace.sm),
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
              SizedBox(width: OrtizSpace.sm),
              _buildFilterChip(
                label: "Ingresos",
                selected: _selectedType == 'income',
                onTap: () => setState(() {
                  _selectedType = 'income';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: OrtizSpace.sm),
              _buildFilterChip(
                label: "Gastos",
                selected: _selectedType == 'expense',
                onTap: () => setState(() {
                  _selectedType = 'expense';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: OrtizSpace.sm),
              _buildFilterChip(
                label: "Sugerencias",
                selected: _selectedType == 'suggestion',
                onTap: () => setState(() {
                  _selectedType = 'suggestion';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
              SizedBox(width: OrtizSpace.sm),
              _buildFilterChip(
                label: "Cambios \$→Bs",
                selected: _selectedType == 'exchange',
                onTap: () => setState(() {
                  _selectedType = 'exchange';
                  _selectedRecurringId = null;
                  _selectedPocketId = null;
                }),
              ),
            ],
          ),
        ),
        
        // Filtro por moneda de pago
        SizedBox(height: OrtizSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          child: Row(
            children: [
              Text("Moneda:", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardSubtitleText)),
              SizedBox(width: OrtizSpace.sm),
              for (final option in const [('all', 'Todas'), ('usd', 'Dólares \$'), ('bs', 'Bolívares Bs')]) ...[
                _buildFilterChip(
                  label: option.$2,
                  selected: _selectedCurrencyFilter == option.$1,
                  onTap: () => setState(() => _selectedCurrencyFilter = option.$1),
                ),
                SizedBox(width: OrtizSpace.sm),
              ],
            ],
          ),
        ),

        // Secondary filter row
        if (_selectedType == 'income' || _selectedType == 'expense') ...[
          SizedBox(height: OrtizSpace.sm),
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
                        padding: EdgeInsets.only(left: OrtizSpace.sm),
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
          SizedBox(height: OrtizSpace.sm),
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
                        padding: EdgeInsets.only(left: OrtizSpace.sm),
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
        padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.nestedTabTrackBg,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: FontWeight.bold,
            color: selected ? OrtizPalette.onAccent : AppColors.mainTabInactiveText,
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
        final matchesType = event.type == TransactionType.income && event.isCashFlow;
        if (!matchesType) return false;
        if (_selectedRecurringId != null) {
          return event.recurringPaymentId == _selectedRecurringId;
        }
        return true;
      }
      if (_selectedType == 'expense') {
        final matchesType = event.type == TransactionType.expense && event.isCashFlow;
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
      if (_selectedType == 'exchange') return event.isExchangeSuggestion;
      return true;
    }).where((event) {
      // Moneda: los cambios $→Bs aparecen en ambas
      if (_selectedCurrencyFilter == 'all' || event.isExchangeSuggestion) return true;
      final paid = paidCurrencyOf(event);
      return _selectedCurrencyFilter == 'usd' ? paid == CurrencyType.usd : paid != CurrencyType.usd;
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
    double dayExchangeUSD = 0;
    double dayExchangeBs = 0;
    double finalBalanceUSD = 0;
    double finalLiquidBalanceUSD = 0;
    double finalBsBalance = 0;

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
            exchangeUSD: dayExchangeUSD,
            exchangeBs: dayExchangeBs,
            finalBalanceUSD: finalBalanceUSD,
            finalLiquidBalanceUSD: finalLiquidBalanceUSD,
            finalBsBalance: finalBsBalance,
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
        dayExchangeUSD = 0;
        dayExchangeBs = 0;
      }

      finalBalanceUSD = event.projectedBalanceUSD;
      finalLiquidBalanceUSD = event.projectedLiquidBalanceUSD;
      finalBsBalance = event.projectedBsBalance;

      // Cambio de divisa sugerido: no es ingreso ni gasto
      if (event.isExchangeSuggestion) {
        dayExchangeUSD += event.amount;
        dayExchangeBs += event.exchangeAmountBs ?? 0.0;
        listItems.add(event);
        continue;
      }

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

      // 1. Monto del evento en $ (el motor ya lo calcula según la moneda y la cuenta)
      final double eventAmountInUSD =
          event.amountUSD ?? appState.convertToUSD(amount: event.amount, from: event.currency);

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
        exchangeUSD: dayExchangeUSD,
        exchangeBs: dayExchangeBs,
        finalBalanceUSD: finalBalanceUSD,
        finalLiquidBalanceUSD: finalLiquidBalanceUSD,
        finalBsBalance: finalBsBalance,
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
                child: OrtizSection(
                  children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(OrtizSpace.sm),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: AppColors.primary,
                              size: OrtizIconSize.md,
                            ),
                          ),
                          SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Text(
                              "Planificación de Dinero Seguro",
                              style: TextStyle(
                                fontSize: OrtizFontSize.body,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardText,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: OrtizIconSize.md,
                            ),
                            onPressed: () => _showTimelineInfo(context),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Container(
                        padding: EdgeInsets.all(OrtizSpace.lg),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(OrtizRadius.block),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
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
                                  size: OrtizIconSize.sm,
                                ),
                                SizedBox(width: OrtizSpace.sm),
                                Text(
                                  "Ahorro o Gasto Libre Extra",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.md),
                            Text(
                              formatUSD(maxToSave),
                              style: TextStyle(
                                fontSize: OrtizFontSize.display,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.sm),
                            Text(
                              "Dinero adicional que puedes ahorrar en tus bolsillos o gastar libremente en antojos hoy sin afectar tus pagos planificados.",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                color: AppColors.cardSubtitleText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: OrtizSpace.md),
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
                          fontSize: OrtizFontSize.bodySm,
                          color: AppColors.cardSubtitleText,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: OrtizSpace.lg),
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
                                size: OrtizIconSize.sm,
                              ),
                              label: Text("Simular"),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: OrtizSpace.md),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _showTimelineSummaryBottomSheet(context),
                              icon: Icon(Icons.analytics_outlined, size: OrtizIconSize.sm),
                              label: Text("Resumen"),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ],
                ),
              ),
              if (safeAmount < 0 && minDate != null) ...[
                _buildSalesGoalCard(context, safeAmount, minDate, minReason ?? ''),
              ],
              SizedBox(height: OrtizSpace.xxl),

              // Timeline header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                  SizedBox(width: OrtizSpace.sm),
                  Text(
                    "Timeline de Proyección ($periodTitle)",
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: OrtizSpace.md),

              // Filters UI
              Showcase(
                key: _filterTimelineKey,
                title: "Filtros de Proyección",
                description: "Filtra el listado por ingresos, gastos o 'Sugerencias'. Las Sugerencias son recomendaciones automáticas que te indican cuándo y cuánto transferir a tus bolsillos de ahorro para pre-fondear cuotas futuras y proteger tu saldo líquido.",
                child: _buildFilterChips(),
              ),
              SizedBox(height: OrtizSpace.md),
            ]
          );
        }

        if (filteredEvents.isEmpty) {
          return Showcase(
            key: _timelineListKey,
            title: "Agenda de Proyección Futura",
            description: "Aquí verás la evolución de tus saldos día a día. Actualmente está vacía porque no tienes obligaciones recurrentes registradas. Cuando agregues cobros o pagos programados en la pestaña 'Recurrentes', verás el flujo proyectado y sugerencias inteligentes de ahorro.",
            child: OrtizEmptyState(
              icon: Icons.timeline_rounded,
              title: "Sin Proyecciones",
              message:
                  "No hay transacciones programadas para el filtro seleccionado en este período.",
            ),
          );
        }

        final listIndex = index - 1;
        final item = listItems[listIndex];
        if (item is String) {
          return Padding(
            padding: EdgeInsets.only(
              top: OrtizSpace.xl,
              bottom: OrtizSpace.sm,
              left: OrtizSpace.xs,
              right: OrtizSpace.xs,
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
                    SizedBox(width: OrtizSpace.sm),
                    Text(
                      item,
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
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
                    size: OrtizIconSize.md,
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
            padding: EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xxl),
            child: Row(
              children: [
                SizedBox(width: 48), // 40 (timeline) + 8 (spacing in TimelineEventRow)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(OrtizSpace.md),
                    decoration: BoxDecoration(
                      color: OrtizPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      border: Border.all(color: OrtizPalette.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Resumen del Día", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        SizedBox(height: OrtizSpace.sm),
                        
                        // Ingresos
                        if (item.incomeNativeUSD > 0 || item.incomeNativeBs > 0 || item.incomeNativeEur > 0) ...[
                          Text("Ingresos:", style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText)),
                          if (item.incomeNativeUSD > 0)
                            Text("  - USD: \$${item.incomeNativeUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.income)),
                          if (item.incomeNativeBs > 0)
                            Text("  - Bs: ${item.incomeNativeBs.toStringAsFixed(2)} (BCV: \$${item.incomeBsConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.income)),
                          if (item.incomeNativeEur > 0)
                            Text("  - EUR: ${item.incomeNativeEur.toStringAsFixed(2)} (BCV: \$${item.incomeEurConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.income)),
                          SizedBox(height: OrtizSpace.xs),
                        ],

                        // Gastos
                        if (item.expenseNativeUSD > 0 || item.expenseNativeBs > 0 || item.expenseNativeEur > 0) ...[
                          Text("Gastos:", style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText)),
                          if (item.expenseNativeUSD > 0)
                            Text("  - USD: \$${item.expenseNativeUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          if (item.expenseNativeBs > 0)
                            Text("  - Bs: ${item.expenseNativeBs.toStringAsFixed(2)} (BCV: \$${item.expenseBsConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          if (item.expenseNativeEur > 0)
                            Text("  - EUR: ${item.expenseNativeEur.toStringAsFixed(2)} (BCV: \$${item.expenseEurConvertedUsd.toStringAsFixed(2)})", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          SizedBox(height: OrtizSpace.xs),
                        ],

                        if (item.exchangeUSD > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Vender \$ (sugerido):", style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText)),
                              Text("\$${item.exchangeUSD.toStringAsFixed(2)} → Bs. ${item.exchangeBs.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.warn)),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.xs),
                        ],
                        if (item.pocketUSD > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Bolsillos (Sugerido):", style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText)),
                              Text("\$${item.pocketUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.accent)),
                            ],
                          ),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Balance General Final:", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                            Text("\$${item.finalBalanceUSD.toStringAsFixed(2)}", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                          ],
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Dinero Libre Final:", style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: AppColors.cardText)),
                            Text(
                              "\$${item.finalLiquidBalanceUSD.toStringAsFixed(2)}"
                              "${item.finalBsBalance.abs() >= 0.01 ? ' · Bs. ${item.finalBsBalance.toStringAsFixed(2)}' : ''}",
                              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
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
          ).ortizStaggered(context, listIndex);
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
