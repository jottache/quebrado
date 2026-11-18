import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../viewmodels/app_state.dart';
import '../models/saving_pocket.dart';
import '../models/timeline_event.dart';
import '../models/currency_type.dart';
import '../models/recurring_payment.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../widgets/timeline_event_row.dart';
import '../widgets/helpers.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class PurchaseSimulationBottomSheet extends StatefulWidget {
  const PurchaseSimulationBottomSheet({super.key});

  @override
  State<PurchaseSimulationBottomSheet> createState() =>
      _PurchaseSimulationBottomSheetState();
}

class _PurchaseSimulationBottomSheetState
    extends State<PurchaseSimulationBottomSheet> {
  bool _isSimulated = false;
  bool _isLoading = false;
  bool _showFullTimeline = false; // "Solo simulación" is first and default!

  bool _isInstallments = false; // Toggle: false = Ahorro, true = Cashea
  int _installmentsCount = 3; // Choice: 3, 6, 12
  final SubscriptionFrequency _installmentsFrequency =
      SubscriptionFrequency.biweekly; // Fixed to biweekly (Cada 14 días)
  String? _installmentsCountError;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _casheaInitialController =
      TextEditingController();
  CurrencyType _currency = CurrencyType.usd;
  DateTime? _targetDate; // Fecha de compra
  int _priority = 1; // Default priority (Alta) so it competes on equal footing

  // Validation errors
  String? _nameError;
  String? _amountError;
  String? _casheaInitialError;
  String? _dateError;

  // Results
  List<TimelineEvent> _simulationEvents = [];
  SavingPocket? _simulatedPocket;
  List<String> _simulatedPaymentIds = [];
  List<RecurringPayment> _simulatedPayments = [];
  bool _isFeasible = true;
  DateTime? _viableDate;

  final ScrollController _scrollController = ScrollController();
  int _currentScrollSuggestionIndex = 0;
  List<double> _suggestionOffsets = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _casheaInitialController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _suggestionOffsets.isEmpty) return;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Threshold is the center of the viewport minus half of estimated card height (47.0)
    final threshold = currentOffset + (viewportHeight / 2) - 47.0;

    int nextIndex = 0;
    for (int i = 0; i < _suggestionOffsets.length; i++) {
      if (_suggestionOffsets[i] > threshold) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex != _currentScrollSuggestionIndex) {
      setState(() {
        _currentScrollSuggestionIndex = nextIndex;
      });
    }
  }

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

  void _runSimulation(AppState appState) {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? "Ingresa el nombre del producto"
          : null;

      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        _amountError = "Ingresa un monto";
      } else {
        final amountRaw = double.tryParse(amountText.replaceAll(',', '.')) ?? 0;
        if (amountRaw <= 0) {
          _amountError = "Ingresa un monto mayor a 0";
        } else {
          _amountError = null;
        }
      }

      if (_isInstallments) {
        final initialText = _casheaInitialController.text.trim();
        if (initialText.isEmpty) {
          _casheaInitialError = "Ingresa la inicial";
        } else {
          final initialRaw =
              double.tryParse(initialText.replaceAll(',', '.')) ?? 0;
          final amountRaw =
              double.tryParse(amountText.replaceAll(',', '.')) ?? 0;
          if (initialRaw < 0) {
            _casheaInitialError = "La inicial no puede ser negativa";
          } else if (initialRaw >= amountRaw) {
            _casheaInitialError = "La inicial debe ser menor al monto total";
          } else {
            _casheaInitialError = null;
          }
        }
      } else {
        _casheaInitialError = null;
      }

      _dateError = _targetDate == null ? "Selecciona una fecha" : null;
      _installmentsCountError = null;
    });

    if (_nameError != null ||
        _amountError != null ||
        _casheaInitialError != null ||
        _dateError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;

      final amountRaw =
          double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ??
          0;
      final amountUSD = _currency == CurrencyType.usd
          ? amountRaw
          : amountRaw / appState.bcvRate;

      if (_isInstallments) {
        final initialRaw =
            double.tryParse(
              _casheaInitialController.text.trim().replaceAll(',', '.'),
            ) ??
            0;
        final installmentsAmount = amountRaw - initialRaw;
        final amountPerInstallment = installmentsAmount / _installmentsCount;

        final initialId = Uuid().v4();
        final installmentsId = Uuid().v4();
        _simulatedPaymentIds = [initialId, installmentsId];

        final initialPayment = RecurringPayment(
          id: initialId,
          name: "${_nameController.text.trim()} (Inicial Cashea)",
          amount: initialRaw,
          currency: _currency,
          frequency: SubscriptionFrequency.monthly,
          startDate: _targetDate!,
          notificationOption: NotificationOption.none,
          icon: 'shopping_bag',
          colorHex: '#FFE607',
          type: TransactionType.expense,
          totalInstallments: 1,
        );

        final installmentsPayment = RecurringPayment(
          id: installmentsId,
          name: "${_nameController.text.trim()} (Cuota Cashea)",
          amount: amountPerInstallment,
          currency: _currency,
          frequency: SubscriptionFrequency.biweekly, // Cada 14 días
          startDate: _targetDate!.add(Duration(days: 14)),
          notificationOption: NotificationOption.none,
          icon: 'shopping_bag',
          colorHex: '#FFE607',
          type: TransactionType.expense,
          totalInstallments: _installmentsCount,
        );

        _simulatedPayments = [initialPayment, installmentsPayment];

        _simulationEvents = appState.getTimelineEvents(
          365 * 2,
          virtualPayments: _simulatedPayments,
        );

        _isFeasible = true;
        _viableDate = null;
        _simulatedPocket = null; // Ensure pocket is null for installments mode

        for (final event in _simulationEvents) {
          if (event.projectedLiquidBalanceUSD < 0) {
            _isFeasible = false;
            break;
          }
        }
      } else {
        _simulatedPocket = SavingPocket(
          id: Uuid().v4(),
          name: _nameController.text.trim(),
          targetAmountUSD: amountUSD,
          currentAmountUSD: 0,
          targetDate: _targetDate,
          priority: _priority,
          icon: 'star',
          colorHex: '#FF9F0A',
        );

        _simulatedPaymentIds = [];
        _simulatedPayments = [];

        _simulationEvents = appState.getTimelineEvents(
          365 * 2,
          virtualPockets: [_simulatedPocket!],
        );

        _isFeasible = appState.isPocketTargetDateFeasible(
          _simulatedPocket!,
          virtualPockets: [_simulatedPocket!],
        );
        _viableDate = appState.getViableTargetDate(
          _simulatedPocket!,
          virtualPockets: [_simulatedPocket!],
        );
      }

      setState(() {
        _isLoading = false;
        _isSimulated = true;
      });
    });
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3.5,
          ),
          SizedBox(height: OrtizSpace.xxl),
          Text(
            "Realizando simulación de compra para",
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              color: AppColors.cardSubtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: OrtizSpace.xs),
          Text(
            _nameController.text.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: OrtizFontSize.titleSm,
              fontWeight: FontWeight.w900,
              color: AppColors.cardText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityButton(int val, String label, Color themeColor) {
    final isSelected = _priority == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = val),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(
              color: isSelected ? themeColor : themeColor.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: FontWeight.bold,
              color: isSelected ? OrtizPalette.onAccent : themeColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(AppState appState) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrtizSection(
            children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isInstallments = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: !_isInstallments
                                ? AppColors.primary
                                : OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          child: Center(
                            child: Text(
                              "Ahorro",
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: !_isInstallments
                                    ? OrtizPalette.onAccent
                                    : OrtizPalette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isInstallments = true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: _isInstallments
                                ? AppColors.primary
                                : OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          child: Center(
                            child: Text(
                              "Cashea",
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.bold,
                                color: _isInstallments
                                    ? OrtizPalette.onAccent
                                    : OrtizPalette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: OrtizSpace.xl),
                Text(
                  "INFORMACIÓN DE LA SIMULACIÓN",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardSubtitleText,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Nombre (ej. PlayStation 5)",
                    hintStyle: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                    contentPadding: EdgeInsets.all(OrtizSpace.md),
                    filled: true,
                    fillColor: OrtizPalette.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _nameError,
                  ),
                  style: TextStyle(
                    fontSize: OrtizFontSize.body,
                    color: AppColors.cardText,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                SizedBox(height: OrtizSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _isInstallments
                              ? "Monto total del producto"
                              : "Monto del producto",
                          hintStyle: TextStyle(
                            color: OrtizPalette.muted,
                            fontSize: OrtizFontSize.bodySm,
                          ),
                          contentPadding: EdgeInsets.all(OrtizSpace.md),
                          filled: true,
                          fillColor: OrtizPalette.surfaceHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            borderSide: BorderSide.none,
                          ),
                          errorText: _amountError,
                        ),
                        style: TextStyle(
                          fontSize: OrtizFontSize.body,
                          color: AppColors.cardText,
                        ),
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: OrtizSpace.md),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: OrtizSpace.md,
                          vertical: OrtizSpace.xxs,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                          color: OrtizPalette.surfaceHigh,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CurrencyType>(
                            value: _currency,
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              color: AppColors.cardText,
                              fontWeight: FontWeight.bold,
                            ),
                            items: CurrencyType.values.map((cur) {
                              return DropdownMenuItem(
                                value: cur,
                                child: Text(cur.name.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _currency = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isInstallments) ...[
                  SizedBox(height: OrtizSpace.md),
                  TextField(
                    controller: _casheaInitialController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: "Monto inicial (Cuota inicial)",
                      hintStyle: TextStyle(
                        color: OrtizPalette.muted,
                        fontSize: OrtizFontSize.bodySm,
                      ),
                      contentPadding: EdgeInsets.all(OrtizSpace.md),
                      filled: true,
                      fillColor: OrtizPalette.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _casheaInitialError,
                    ),
                    style: TextStyle(
                      fontSize: OrtizFontSize.body,
                      color: AppColors.cardText,
                    ),
                    onChanged: (_) {
                      if (_casheaInitialError != null) {
                        setState(() => _casheaInitialError = null);
                      }
                    },
                  ),
                  SizedBox(height: OrtizSpace.lg),
                  Text(
                    "NÚMERO DE CUOTAS CASHEA",
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [3, 6, 12].map((count) {
                      final isSelected = _installmentsCount == count;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _installmentsCount = count),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? OrtizPalette.warn
                                    : OrtizPalette.surfaceHigh,
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                border: isSelected
                                    ? Border.all(
                                        color: AppColors.casheaBrand,
                                        width: OrtizStroke.focus,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  "$count Cuotas",
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? OrtizPalette.fg
                                        : OrtizPalette.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: OrtizSpace.md),
                  Container(
                    padding: EdgeInsets.all(OrtizSpace.md),
                    decoration: BoxDecoration(
                      color: AppColors.casheaBrand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      border: Border.all(
                        color: AppColors.casheaBrand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: OrtizPalette.warn,
                          size: OrtizIconSize.sm,
                        ),
                        SizedBox(width: OrtizSpace.sm),
                        Expanded(
                          child: Text(
                            "Frecuencia fija: Cada 14 días (Modelo catorcenal de Cashea)",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              color: OrtizPalette.fg,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isInstallments) ...[
                  SizedBox(height: OrtizSpace.lg),
                  Text(
                    "PRIORIDAD DE AHORRO",
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.sm),
                  Row(
                    children: [
                      _buildPriorityButton(1, "Alta", OrtizPalette.bad),
                      SizedBox(width: OrtizSpace.sm),
                      _buildPriorityButton(2, "Media", OrtizPalette.warn),
                      SizedBox(width: OrtizSpace.sm),
                      _buildPriorityButton(3, "Baja", OrtizPalette.ok),
                    ],
                  ),
                ],
                SizedBox(height: OrtizSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isInstallments
                          ? "Fecha de Compra"
                          : "Fecha Límite Estimada",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardText,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.nestedTabTrackBg,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: OrtizSpace.md,
                              vertical: OrtizSpace.sm,
                            ),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  _targetDate ??
                                  (_isInstallments
                                      ? DateTime.now()
                                      : DateTime.now().add(
                                          Duration(days: 30),
                                        )),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _targetDate = date;
                                _dateError = null;
                              });
                            }
                          },
                          child: Text(
                            _targetDate != null
                                ? formatDate(_targetDate!)
                                : "Seleccionar fecha",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: OrtizFontSize.bodySm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_dateError != null)
                  Padding(
                    padding: EdgeInsets.only(top: OrtizSpace.xs, left: OrtizSpace.xs),
                    child: Text(
                      _dateError!,
                      style: TextStyle(
                        color: AppColors.expense,
                        fontSize: OrtizFontSize.caption,
                      ),
                    ),
                  ),
              ],
            ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToNextSuggestion(AppState appState, List<dynamic> listItems) {
    if (_suggestionOffsets.isEmpty) return;

    final targetIndex =
        _currentScrollSuggestionIndex % _suggestionOffsets.length;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Scroll to center the target suggestion card in the middle of the viewport
    final targetOffset =
        (_suggestionOffsets[targetIndex] - (viewportHeight / 2) + 47.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );

    _scrollController.animateTo(
      targetOffset,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildResults(AppState appState) {
    final simulatedName = _nameController.text.trim();
    final simulatedSuggestions = _simulationEvents.where((e) {
      if (_isInstallments) {
        return e.recurringPaymentId != null &&
            _simulatedPaymentIds.contains(e.recurringPaymentId);
      } else {
        return e.pocketName == simulatedName;
      }
    }).toList();

    // Filter events based on toggle
    List<TimelineEvent> filteredEvents = _simulationEvents;
    if (!_showFullTimeline) {
      filteredEvents = simulatedSuggestions;
    }

    // Build grouped list items with date headers
    final List<dynamic> listItems = [];
    String? currentHeader;
    for (final event in filteredEvents) {
      final header = _getDateHeader(event.date);
      if (header != currentHeader) {
        currentHeader = header;
        listItems.add(header);
      }
      listItems.add(event);
    }

    // We compute the suggestion offsets for the scroll listener and next button
    final List<double> suggestionOffsets = [];
    double currentOffset = 0.0;
    for (int i = 0; i < listItems.length; i++) {
      final item = listItems[i];
      if (item is TimelineEvent) {
        bool isSimulatedEvent = _isInstallments
            ? (item.recurringPaymentId != null &&
                  _simulatedPaymentIds.contains(item.recurringPaymentId))
            : item.pocketName == simulatedName;
        if (isSimulatedEvent) {
          suggestionOffsets.add(currentOffset);
        }
      }
      if (item is String) {
        currentOffset += 44.0;
      } else {
        final ev = item as TimelineEvent;
        double cardHeight = 92.0;
        // Dynamically adjust estimated height if the title wraps to two lines
        if (ev.title.length > 28) {
          cardHeight += 16.0;
        }
        currentOffset += cardHeight;
      }
    }
    // Update the list of offsets so the scroll listener can read it
    _suggestionOffsets = suggestionOffsets;

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

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warnings / Recommendations
            if (!_isFeasible)
              Container(
                padding: EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: OrtizPalette.warn.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: OrtizPalette.warn.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: OrtizPalette.warn,
                      size: OrtizIconSize.md,
                    ),
                    SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        _isInstallments
                            ? "Con tu flujo actual, no es viable pagar las cuotas de esta compra. El saldo líquido proyectado quedaría en negativo en al menos una de las fechas de pago."
                            : "Con tu flujo actual, no es viable realizar esta compra para el ${_simulatedPocket?.targetDate != null ? formatDate(_simulatedPocket!.targetDate!) : ''}. La app extenderá automáticamente los ahorros hasta el ${_viableDate != null ? formatDate(_viableDate!) : 'futuro'}.",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: OrtizPalette.warn,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: OrtizPalette.ok.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: OrtizPalette.ok.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: OrtizPalette.ok,
                      size: OrtizIconSize.md,
                    ),
                    SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        _isInstallments
                            ? "¡Es viable! Tu flujo de caja actual soporta el pago de estas cuotas."
                            : "¡Es viable! Tu flujo de caja actual soporta esta meta de ahorro para la fecha indicada.",
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: OrtizPalette.ok,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: OrtizSpace.lg),

            // Toggle Filter: "Solo Simulación" is first, "Timeline Completo" is second!
            Container(
              decoration: BoxDecoration(
                color: OrtizPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(OrtizRadius.field),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showFullTimeline = false;
                        _currentScrollSuggestionIndex = 0;
                      }),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: !_showFullTimeline
                              ? OrtizPalette.line
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                        child: Center(
                          child: Text(
                            "Solo Simulación (${simulatedSuggestions.length})",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: !_showFullTimeline
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !_showFullTimeline
                                  ? AppColors.primary
                                  : OrtizPalette.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showFullTimeline = true;
                        _currentScrollSuggestionIndex = 0;
                      }),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: _showFullTimeline
                              ? OrtizPalette.line
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                        child: Center(
                          child: Text(
                            "Timeline Completo",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: _showFullTimeline
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _showFullTimeline
                                  ? AppColors.primary
                                  : OrtizPalette.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: OrtizSpace.lg),

            // Timeline List
            Expanded(
              child: listItems.isEmpty
                  ? Center(
                      child: Text(
                        "No hay sugerencias que mostrar.",
                        style: TextStyle(color: OrtizPalette.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom: _showFullTimeline
                            ? OrtizSize.minTouch + OrtizSpace.xxxl
                            : OrtizSpace.xl,
                      ),
                      physics: BouncingScrollPhysics(),
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];
                        if (item is String) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: OrtizSpace.xl,
                              bottom: OrtizSpace.sm,
                              left: OrtizSpace.xs,
                            ),
                            child: Row(
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
                          );
                        } else {
                          final event = item as TimelineEvent;
                          return TimelineEventRow(
                            event: event,
                            isFirst: index == firstEventIndex,
                            isLast: index == lastEventIndex,
                            virtualPockets: _simulatedPocket != null
                                ? [_simulatedPocket!]
                                : [],
                            virtualPayments: _simulatedPayments,
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
        // Scroll button centered at the bottom of the list!
        if (simulatedSuggestions.isNotEmpty && _showFullTimeline)
          Positioned(
            bottom: OrtizSpace.lg,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _scrollToNextSuggestion(appState, listItems),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: OrtizSpace.lg,
                    vertical: OrtizSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: OrtizPalette.onAccent,
                        size: OrtizIconSize.md,
                      ),
                      SizedBox(width: OrtizSpace.xs),
                      Text(
                        "Ir a sugerencia (${_currentScrollSuggestionIndex + 1}/${simulatedSuggestions.length})",
                        style: TextStyle(
                          color: OrtizPalette.onAccent,
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

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
        heightFactor: 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: OrtizPalette.faint,
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
                  _isSimulated
                      ? "Simulación"
                      : (_isLoading ? "Simulando..." : "Simular"),
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Body
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                child: _isLoading
                    ? _buildLoader()
                    : (_isSimulated
                          ? _buildResults(appState)
                          : _buildFormFields(appState)),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Action Buttons at the bottom
            if (!_isLoading) ...[
              if (!_isSimulated)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancelar",
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.bold,
                            color: OrtizPalette.muted,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _runSimulation(appState),
                        child: Text(
                          "Simular",
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                        ),
                        onPressed: () => setState(() => _isSimulated = false),
                        child: Text(
                          "Volver a configurar",
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cerrar",
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
