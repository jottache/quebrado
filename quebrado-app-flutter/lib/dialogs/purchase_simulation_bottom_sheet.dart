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
import '../widgets/claymorphic_card.dart';

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
  SubscriptionFrequency _installmentsFrequency =
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
    final tomorrow = today.add(const Duration(days: 1));
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

    Future.delayed(const Duration(seconds: 2), () {
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

        final initialId = const Uuid().v4();
        final installmentsId = const Uuid().v4();
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
          startDate: _targetDate!.add(const Duration(days: 14)),
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
          id: const Uuid().v4(),
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
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3.5,
          ),
          const SizedBox(height: 24),
          const Text(
            "Realizando simulación de compra para",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cardSubtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _nameController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : themeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? themeColor : themeColor.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : themeColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(AppState appState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClaymorphicCard(
            cornerRadius: 24,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isInstallments = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isInstallments
                                ? AppColors.primary
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "Ahorro",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_isInstallments
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isInstallments = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isInstallments
                                ? AppColors.primary
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "Cashea",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isInstallments
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "INFORMACIÓN DE LA SIMULACIÓN",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardSubtitleText,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Nombre (ej. PlayStation 5)",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _nameError,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.cardText,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _isInstallments
                              ? "Monto total del producto"
                              : "Monto del producto",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: _amountError,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.cardText,
                        ),
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[100],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CurrencyType>(
                            value: _currency,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 14,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _casheaInitialController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: "Monto inicial (Cuota inicial)",
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _casheaInitialError,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.cardText,
                    ),
                    onChanged: (_) {
                      if (_casheaInitialError != null) {
                        setState(() => _casheaInitialError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "NÚMERO DE CUOTAS CASHEA",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [3, 6, 12].map((count) {
                      final isSelected = _installmentsCount == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _installmentsCount = count),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color.fromARGB(255, 255, 230, 7)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color.fromARGB(
                                          255,
                                          220,
                                          200,
                                          0,
                                        ),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  "$count Cuotas",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        255,
                        230,
                        7,
                      ).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(
                          255,
                          255,
                          230,
                          7,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color.fromARGB(255, 180, 160, 0),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Frecuencia fija: Cada 14 días (Modelo catorcenal de Cashea)",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isInstallments) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "PRIORIDAD DE AHORRO",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildPriorityButton(1, "Alta", Colors.red[400]!),
                      const SizedBox(width: 8),
                      _buildPriorityButton(2, "Media", Colors.orange[400]!),
                      const SizedBox(width: 8),
                      _buildPriorityButton(3, "Baja", Colors.blue[400]!),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isInstallments
                          ? "Fecha de Compra"
                          : "Fecha Límite Estimada",
                      style: const TextStyle(
                        fontSize: 13,
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
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
                                          const Duration(days: 30),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_dateError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                    child: Text(
                      _dateError!,
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
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
      duration: const Duration(milliseconds: 500),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isInstallments
                            ? "Con tu flujo actual, no es viable pagar las cuotas de esta compra. El saldo líquido proyectado quedaría en negativo en al menos una de las fechas de pago."
                            : "Con tu flujo actual, no es viable realizar esta compra para el ${_simulatedPocket?.targetDate != null ? formatDate(_simulatedPocket!.targetDate!) : ''}. La app extenderá automáticamente los ahorros hasta el ${_viableDate != null ? formatDate(_viableDate!) : 'futuro'}.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isInstallments
                            ? "¡Es viable! Tu flujo de caja actual soporta el pago de estas cuotas."
                            : "¡Es viable! Tu flujo de caja actual soporta esta meta de ahorro para la fecha indicada.",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Toggle Filter: "Solo Simulación" is first, "Timeline Completo" is second!
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_showFullTimeline
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_showFullTimeline
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            "Solo Simulación (${simulatedSuggestions.length})",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_showFullTimeline
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !_showFullTimeline
                                  ? AppColors.primary
                                  : Colors.grey[600],
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _showFullTimeline
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _showFullTimeline
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            "Timeline Completo",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _showFullTimeline
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _showFullTimeline
                                  ? AppColors.primary
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Timeline List
            Expanded(
              child: listItems.isEmpty
                  ? Center(
                      child: Text(
                        "No hay sugerencias que mostrar.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom: _showFullTimeline ? 80 : 20,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 20.0,
                              bottom: 8.0,
                              left: 4.0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
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
                                : const [],
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
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _scrollToNextSuggestion(appState, listItems),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Ir a sugerencia (${_currentScrollSuggestionIndex + 1}/${simulatedSuggestions.length})",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
                  _isSimulated
                      ? "Simulación"
                      : (_isLoading ? "Simulando..." : "Simular"),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
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
            const SizedBox(height: 12),

            // Action Buttons at the bottom
            if (!_isLoading) ...[
              if (!_isSimulated)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _runSimulation(appState),
                        child: const Text(
                          "Simular",
                          style: TextStyle(
                            fontSize: 15,
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => setState(() => _isSimulated = false),
                        child: const Text(
                          "Volver a configurar",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cerrar",
                          style: TextStyle(
                            fontSize: 15,
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
