import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import '../dialogs/habit_terminal_editor_dialog.dart';
import '../dialogs/habit_detail_cli_dialog.dart';
import 'habitos_metrics_screen.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/widgets/diario_image_helper.dart';

class HabitosHomeScreen extends StatefulWidget {
  const HabitosHomeScreen({super.key});

  @override
  State<HabitosHomeScreen> createState() => _HabitosHomeScreenState();
}

class _HabitosHomeScreenState extends State<HabitosHomeScreen> {
  Timer? _activeTimer;
  String? _timerHabitId;
  int _timerSecondsRemaining = 0;

  late final ScrollController _dateScrollController;
  late final DateTime _startDate;
  static const int _daysPast = 45;
  static const int _daysFuture = 15;
  static const double _dateItemWidth = 54.0;
  static const double _dateItemMargin = 3.0;
  static const double _dateTotalWidth = _dateItemWidth + (_dateItemMargin * 2);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: _daysPast));
    _dateScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(DateTime(now.year, now.month, now.day), animate: false);
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _activeTimer?.cancel();
    super.dispose();
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    if (!_dateScrollController.hasClients) return;

    final targetDate = DateTime(date.year, date.month, date.day);
    final dayIndex = targetDate.difference(_startDate).inDays;
    if (dayIndex < 0 || dayIndex >= (_daysPast + _daysFuture + 1)) return;

    final viewportWidth = _dateScrollController.position.viewportDimension;
    final targetOffset = (dayIndex * _dateTotalWidth) - (viewportWidth / 2) + (_dateTotalWidth / 2);
    final maxScroll = _dateScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    if (animate) {
      _dateScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _dateScrollController.jumpTo(clampedOffset);
    }
  }

  void _startTimer(HabitModel habit, HabitosState state) {
    _activeTimer?.cancel();
    final targetSec = habit.targetValue.toInt();
    final currentVal = state.getValue(habit.id).toInt();
    final remaining = (targetSec - currentVal) > 0 ? (targetSec - currentVal) : targetSec;

    setState(() {
      _timerHabitId = habit.id;
      _timerSecondsRemaining = remaining;
    });

    _activeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSecondsRemaining <= 1) {
        timer.cancel();
        state.updateHabitValue(habit.id, habit.targetValue);
        setState(() {
          _timerHabitId = null;
          _timerSecondsRemaining = 0;
        });
      } else {
        setState(() {
          _timerSecondsRemaining--;
        });
      }
    });
  }

  void _pauseTimer() {
    _activeTimer?.cancel();
    setState(() {
      _timerHabitId = null;
    });
  }

  void _resetTimer(HabitModel habit, HabitosState state) {
    _activeTimer?.cancel();
    state.updateHabitValue(habit.id, -state.getValue(habit.id));
    setState(() {
      _timerHabitId = null;
      _timerSecondsRemaining = habit.targetValue.toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);

    return Scaffold(
      backgroundColor: HabitosColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: HabitosColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: HabitosColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: HabitosColors.primary.withOpacity(0.20),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.track_changes_rounded,
                color: HabitosColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Hábitos',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: HabitosColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: HabitosColors.textPrimary),
            tooltip: 'Métricas & Consistencia',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HabitosMetricsScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HabitosColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                // 1. Progress Banner Card
                _buildProgressCard(state),
                const SizedBox(height: 14),

                // 2. Date Navigation Bar
                _buildDateNavigator(state),
                const SizedBox(height: 14),

                // 3. Filter Chips
                _buildFilterRow(state),
                const SizedBox(height: 12),

                // 3.1 Contact Filter Chips
                _buildContactFilterRow(context, state),
                const SizedBox(height: 14),

                // 4. Habits List
                if (state.filteredHabits.isEmpty)
                  _buildEmptyState(context)
                else
                  ...state.filteredHabits.map((habit) => _buildHabitCard(context, habit, state)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const HabitTerminalEditorDialog(),
          );
        },
        backgroundColor: HabitosColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Nuevo Hábito',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  /// Tarjeta de resumen y progreso general del día seleccionado
  Widget _buildProgressCard(HabitosState state) {
    final rate = state.selectedDayCompletionRate;
    final completed = state.selectedDayCompletedCount;
    final total = state.allHabits.length;
    final pct = (rate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: HabitosColors.primary.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.isViewingToday ? 'PROGRESO DE HOY' : 'DÍA ${state.selectedDateKey}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: HabitosColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total > 0 ? '$completed de $total completados' : 'Sin hábitos registrados',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: HabitosColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HabitosColors.primary.withOpacity(0.20),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: HabitosColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? rate : 0.0,
              minHeight: 8,
              backgroundColor: HabitosColors.primaryLight,
              color: HabitosColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Selector de fecha horizontal con scroll fluido y animación
  Widget _buildDateNavigator(HabitosState state) {
    final selected = state.selectedDate;
    final now = DateTime.now();
    final weekDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    final totalDays = _daysPast + _daysFuture + 1;
    final allDays = List.generate(totalDays, (i) => _startDate.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HabitosColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              final prevDate = state.selectedDate.subtract(const Duration(days: 1));
              state.previousDay();
              _scrollToDate(prevDate, animate: true);
            },
            tooltip: 'Día anterior',
          ),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                controller: _dateScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: allDays.length,
                itemBuilder: (context, index) {
                  final d = allDays[index];
                  final isSelected = d.year == selected.year && d.month == selected.month && d.day == selected.day;
                  final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                  final weekdayStr = weekDays[d.weekday - 1];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _dateItemMargin),
                    child: InkWell(
                      onTap: () {
                        state.selectDate(d);
                        _scrollToDate(d, animate: true);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _dateItemWidth,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? HabitosColors.primary
                              : (isToday ? HabitosColors.primaryLight : Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? HabitosColors.primary
                                : (isToday ? HabitosColors.primary.withOpacity(0.35) : Colors.transparent),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: HabitosColors.primary.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekdayStr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday ? HabitosColors.primary : HabitosColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday ? HabitosColors.primary : HabitosColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              final nextDate = state.selectedDate.add(const Duration(days: 1));
              state.nextDay();
              _scrollToDate(nextDate, animate: true);
            },
            tooltip: 'Día siguiente',
          ),
          if (!state.isViewingToday) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: () {
                state.selectToday();
                _scrollToDate(DateTime.now(), animate: true);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                backgroundColor: HabitosColors.primaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Hoy',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: HabitosColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Filtros de vista tipo chips minimalistas
  Widget _buildFilterRow(HabitosState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(state, 'all', 'Todos'),
          const SizedBox(width: 8),
          _filterChip(state, 'good', 'Buenos Hábitos'),
          const SizedBox(width: 8),
          _filterChip(state, 'bad', 'Malos Hábitos'),
          if (state.stacks.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...state.stacks.map((s) => _filterChip(state, 'stacks', s.name, stackId: s.id)),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(HabitosState state, String filter, String label, {String? stackId}) {
    final isSelected = state.activeFilter == filter && (stackId == null || state.selectedStackId == stackId);

    return InkWell(
      onTap: () => state.setFilter(filter, stackId: stackId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: HabitosColors.primary.withOpacity(0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : HabitosColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Filtro horizontal por Contacto Asociado del Diario
  Widget _buildContactFilterRow(BuildContext context, HabitosState state) {
    final diarioState = Provider.of<DiarioState>(context);
    final contacts = diarioState.contacts;
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: 13, color: HabitosColors.textSecondary),
              const SizedBox(width: 4),
              const Text(
                'CONTACTO ASOCIADO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: HabitosColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (state.selectedContactId != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => state.setContactFilter(null),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quitar filtro',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: HabitosColors.primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.close_rounded, size: 11, color: HabitosColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _contactFilterChip(
                state: state,
                contactId: null,
                label: 'Todos',
                icon: Icons.people_alt_outlined,
              ),
              ...contacts.map((c) {
                final habitsCount = state.allHabits.where((h) => h.contactId == c.id).length;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _contactFilterChip(
                    state: state,
                    contactId: c.id,
                    label: c.name,
                    avatarUrl: c.avatarUrl,
                    count: habitsCount > 0 ? habitsCount : null,
                  ),
                );
              }),
              const SizedBox(width: 8),
              _contactFilterChip(
                state: state,
                contactId: '__none__',
                label: 'Sin vincular',
                icon: Icons.person_off_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactFilterChip({
    required HabitosState state,
    required String? contactId,
    required String label,
    String? avatarUrl,
    IconData? icon,
    int? count,
  }) {
    final isSelected = state.selectedContactId == contactId;

    return InkWell(
      onTap: () => state.setContactFilter(contactId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: HabitosColors.primary.withOpacity(0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: DiarioImageHelper.buildImageWidget(avatarUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : HabitosColors.textSecondary),
              const SizedBox(width: 5),
            ] else ...[
              CircleAvatar(
                radius: 8,
                backgroundColor: isSelected ? Colors.white.withOpacity(0.3) : HabitosColors.primaryLight,
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : HabitosColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : HabitosColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : HabitosColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta de Hábito Minimalista
  Widget _buildHabitCard(BuildContext context, HabitModel habit, HabitosState state) {
    final isDone = state.isCompleted(habit.id);
    final currentVal = state.getValue(habit.id);
    final streak = state.calculateCurrentStreak(habit.id);
    final cleanDays = habit.isNegative ? state.calculateCleanDays(habit.id) : null;
    final diarioState = Provider.of<DiarioState>(context, listen: false);
    final linkedContact = habit.contactId != null
        ? diarioState.contacts.where((c) => c.id == habit.contactId).firstOrNull
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? HabitosColors.primary.withOpacity(0.35) : HabitosColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone ? HabitosColors.primary.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de la Tarjeta: Check / Toggle + Título + Racha + Menú
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Selector de completado (Checkbox redondo para buenos hábitos, +1 para contador infinito, o Escudo para malos)
                if (habit.type == HabitType.counter)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      state.incrementCounter(habit.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? HabitosColors.primary : HabitosColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? HabitosColors.primary : HabitosColors.primary.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+1',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDone ? Colors.white : HabitosColors.primary,
                        ),
                      ),
                    ),
                  )
                else if (!habit.isNegative)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      state.toggleHabitCompletion(habit.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? HabitosColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? HabitosColors.primary : Colors.grey[350]!,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: HabitosColors.roseLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: HabitosColors.rose.withOpacity(0.25), width: 1),
                    ),
                    child: const Icon(Icons.shield_outlined, color: HabitosColors.rose, size: 16),
                  ),

                const SizedBox(width: 12),

                // 2. Título & Detalles
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => HabitDetailCliDialog(habit: habit),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: HabitosColors.textPrimary,
                            decoration: (isDone && !habit.isNegative && habit.type != HabitType.counter) ? TextDecoration.lineThrough : null,
                            decorationColor: HabitosColors.textMuted,
                          ),
                        ),
                        if (habit.description != null && habit.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              habit.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: HabitosColors.textSecondary),
                            ),
                          ),
                        if (linkedContact != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: HabitosColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 12, color: HabitosColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    linkedContact.name,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HabitosColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Insignia de Racha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: habit.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (habit.isNegative ? HabitosColors.amber : HabitosColors.primary).withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        habit.isNegative ? Icons.verified_user_rounded : Icons.local_fire_department_rounded,
                        size: 13,
                        color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        habit.isNegative ? '$cleanDays d' : '$streak d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Botón de detalle
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20, color: HabitosColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => HabitDetailCliDialog(habit: habit),
                    );
                  },
                ),
              ],
            ),

            // Controles de Contador Infinito
            if (habit.type == HabitType.counter) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REGISTRO DE HOY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        Text(
                          '${currentVal.toInt()} ${habit.unit ?? "veces"}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: HabitosColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (currentVal > 0) ...[
                      _circleCountBtn(
                        label: '-1',
                        onTap: () => state.updateHabitValue(habit.id, -1),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _circleCountBtn(
                      label: '+1',
                      isPrimary: true,
                      onTap: () => state.incrementCounter(habit.id),
                    ),
                  ],
                ),
              ),
            ],

            // Controles de Hábito Cuantitativo
            if (habit.type == HabitType.quantitative) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Text(
                      '${currentVal.toInt()} / ${habit.targetValue.toInt()} ${habit.unit ?? ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HabitosColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _circleCountBtn(
                      label: '-1',
                      onTap: () => state.updateHabitValue(habit.id, -1),
                    ),
                    const SizedBox(width: 6),
                    _circleCountBtn(
                      label: '+1',
                      isPrimary: true,
                      onTap: () => state.updateHabitValue(habit.id, 1),
                    ),
                    if (habit.targetValue >= 100) ...[
                      const SizedBox(width: 6),
                      _circleCountBtn(
                        label: '+250',
                        isPrimary: true,
                        onTap: () => state.updateHabitValue(habit.id, 250),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Controles de Temporizador
            if (habit.type == HabitType.timer) ...[
              const SizedBox(height: 12),
              _buildTimerControls(habit, state, isDone),
            ],

            // Controles de Malos Hábitos (Abstinencia)
            if (habit.isNegative) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 16, color: HabitosColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '$cleanDays días libre',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: HabitosColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text(
                              '¿Registrar recaída?',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                            content: const Text(
                              'El contador de días limpios se reiniciará hoy. Sé amable contigo mismo y vuelve a empezar.',
                              style: TextStyle(fontSize: 13, color: HabitosColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar', style: TextStyle(color: HabitosColors.textSecondary)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HabitosColors.rose,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Confirmar Recaída'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          state.reportRelapse(habit.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: HabitosColors.roseLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HabitosColors.rose.withOpacity(0.3), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.report_problem_rounded, size: 13, color: HabitosColors.rose),
                            SizedBox(width: 4),
                            Text(
                              'Recaída',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: HabitosColors.rose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _circleCountBtn({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isPrimary ? HabitosColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isPrimary ? Colors.white : HabitosColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerControls(HabitModel habit, HabitosState state, bool isDone) {
    final isRunning = _timerHabitId == habit.id;
    final totalSec = habit.targetValue.toInt();
    final remainingSec = isRunning ? _timerSecondsRemaining : (totalSec - state.getValue(habit.id).toInt());
    final displaySec = remainingSec > 0 ? remainingSec : 0;
    final minutes = (displaySec / 60).floor().toString().padLeft(2, '0');
    final seconds = (displaySec % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HabitosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HabitosColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isRunning ? Icons.timer_rounded : Icons.timer_outlined,
            size: 18,
            color: isRunning ? HabitosColors.primary : HabitosColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds min',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (!isRunning) ...[
            ElevatedButton.icon(
              onPressed: () => _startTimer(habit, state),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(isDone ? 'Repetir' : 'Iniciar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HabitosColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause_rounded, size: 16),
              label: const Text('Pausar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HabitosColors.primary,
                side: const BorderSide(color: HabitosColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18, color: HabitosColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _resetTimer(habit, state),
            tooltip: 'Reiniciar temporizador',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HabitosColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HabitosColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.playlist_add_check_rounded, color: HabitosColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay hábitos en esta sección',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: HabitosColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Crea tu primer hábito o selecciona otro filtro arriba.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: HabitosColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
