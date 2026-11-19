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
import '../../widgets/responsive_breakpoints.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz_animate.dart';

/// Margen inferior de las listas para que el FAB extendido no tape el último
/// hábito (88 = 48 + 32 + 8).
const double _fabClearance = OrtizSize.minTouch + OrtizSpace.xxxl + OrtizSpace.sm;

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
  late final ScrollController _categoryScrollController;
  late final ScrollController _contactScrollController;
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
    _categoryScrollController = ScrollController();
    _contactScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(DateTime(now.year, now.month, now.day), animate: false);
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _categoryScrollController.dispose();
    _contactScrollController.dispose();
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
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: HabitosColors.background,
      appBar: AppBar(
        backgroundColor: HabitosColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: OrtizIconSize.md, color: HabitosColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: HabitosColors.primaryLight,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                border: Border.all(color: HabitosColors.primaryBorder),
              ),
              child: const Icon(
                Icons.track_changes_rounded,
                color: HabitosColors.primary,
                size: OrtizIconSize.md,
              ),
            ),
            const SizedBox(width: OrtizSpace.sm),
            const Text(
              'Hábitos',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: OrtizFontSize.title,
                color: HabitosColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.insights_rounded, color: HabitosColors.textPrimary),
              tooltip: 'Métricas & Consistencia',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HabitosMetricsScreen()),
                );
              },
            ),
            const SizedBox(width: OrtizSpace.xs),
          ],
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HabitosColors.primary),
            )
          : isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna 1: Hábitos del día, filtros y navegación
                    Expanded(
                      flex: 6,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
                        children: [
                          _buildProgressCard(state),
                          const SizedBox(height: OrtizSpace.md),
                          _buildDateNavigator(state),
                          const SizedBox(height: OrtizSpace.md),
                          _buildFilterRow(state),
                          const SizedBox(height: OrtizSpace.md),
                          _buildContactFilterRow(context, state),
                          const SizedBox(height: OrtizSpace.md),
                          if (state.filteredHabits.isEmpty)
                            _buildEmptyState(context)
                          else
                            ..._buildHabitList(context, state),
                        ],
                      ),
                    ),
                    // Línea divisoria vertical
                    Container(
                      width: 1,
                      color: HabitosColors.cardBorder.withValues(alpha: 0.7),
                    ),
                    // Columna 2: Métricas y Progreso en tiempo real
                    const Expanded(
                      flex: 5,
                      child: HabitosMetricsView(
                        padding: EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
                      children: [
                        // 1. Progress Banner Card
                        _buildProgressCard(state),
                        const SizedBox(height: OrtizSpace.md),

                        // 2. Date Navigation Bar
                        _buildDateNavigator(state),
                        const SizedBox(height: OrtizSpace.md),

                        // 3. Filter Chips
                        _buildFilterRow(state),
                        const SizedBox(height: OrtizSpace.md),

                        // 3.1 Contact Filter Chips
                        _buildContactFilterRow(context, state),
                        const SizedBox(height: OrtizSpace.md),

                        // 4. Habits List
                        if (state.filteredHabits.isEmpty)
                          _buildEmptyState(context)
                        else
                          ..._buildHabitList(context, state),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const HabitTerminalEditorDialog(),
          );
        },
        backgroundColor: HabitosColors.primary,
        foregroundColor: OrtizPalette.onAccent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
        icon: const Icon(Icons.add_rounded, size: OrtizIconSize.lg),
        label: const Text(
          'Nuevo Hábito',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.body),
        ),
      ),
    );
  }

  /// Lista de hábitos con entrada escalonada (`ortizStaggered`; respeta
  /// reducir movimiento y no deja Timers al desmontar).
  List<Widget> _buildHabitList(BuildContext context, HabitosState state) {
    final habits = state.filteredHabits;
    return [
      for (var i = 0; i < habits.length; i++)
        ortizStaggered(context, i, _buildHabitCard(context, habits[i], state)),
    ];
  }

  /// Resumen y progreso general del día seleccionado (sin tarjeta).
  Widget _buildProgressCard(HabitosState state) {
    final rate = state.selectedDayCompletionRate;
    final completed = state.selectedDayCompletedCount;
    final total = state.allHabits.length;
    final pct = (rate * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
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
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.w800,
                      color: HabitosColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: OrtizSpace.xxs),
                  Text(
                    total > 0 ? '$completed de $total completados' : 'Sin hábitos registrados',
                    style: const TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.w900,
                      color: HabitosColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                decoration: BoxDecoration(
                  color: HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: HabitosColors.primaryBorder),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: OrtizFontSize.body,
                    fontWeight: FontWeight.w900,
                    color: HabitosColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
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

    // Sin tarjeta: la fila de días va sobre el fondo; lo activo resalta solo.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: OrtizIconSize.lg),
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
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _dateItemWidth,
                        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? HabitosColors.primary
                              : (isToday ? HabitosColors.primaryLight : Colors.transparent),
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                          border: Border.all(
                            color: isSelected
                                ? HabitosColors.primary
                                : (isToday ? HabitosColors.primaryBorder : Colors.transparent),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekdayStr,
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? OrtizPalette.onAccent
                                    : (isToday ? HabitosColors.primary : HabitosColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: OrtizSpace.xxs),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: OrtizFontSize.bodySm,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? OrtizPalette.onAccent
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
            icon: const Icon(Icons.chevron_right_rounded, size: OrtizIconSize.lg),
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
            const SizedBox(width: OrtizSpace.xs),
            TextButton(
              onPressed: () {
                state.selectToday();
                _scrollToDate(DateTime.now(), animate: true);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                backgroundColor: HabitosColors.primaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              ),
              child: const Text(
                'Hoy',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
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

  /// Helper para envolver filas de chips con botones de navegación horizontal en desktop
  Widget _buildScrollableChipRow({
    required BuildContext context,
    required ScrollController controller,
    required Widget child,
  }) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (!isDesktop) {
      return SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: child,
      );
    }

    return Row(
      children: [
        _scrollNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            if (!controller.hasClients) return;
            final target = (controller.offset - 240.0).clamp(0.0, controller.position.maxScrollExtent);
            controller.animateTo(
              target,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          },
          tooltip: 'Desplazar a la izquierda',
        ),
        const SizedBox(width: OrtizSpace.xs),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: child,
          ),
        ),
        const SizedBox(width: OrtizSpace.xs),
        _scrollNavButton(
          icon: Icons.chevron_right_rounded,
          onTap: () {
            if (!controller.hasClients) return;
            final target = (controller.offset + 240.0).clamp(0.0, controller.position.maxScrollExtent);
            controller.animateTo(
              target,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          },
          tooltip: 'Desplazar a la derecha',
        ),
      ],
    );
  }

  Widget _scrollNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: HabitosColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: HabitosColors.cardBorder, width: 1.0),
            ),
            child: Icon(icon, size: OrtizIconSize.sm, color: HabitosColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// Filtros de vista tipo chips minimalistas
  Widget _buildFilterRow(HabitosState state) {
    return _buildScrollableChipRow(
      context: context,
      controller: _categoryScrollController,
      child: Row(
        children: [
          _filterChip(state, 'all', 'Todos'),
          const SizedBox(width: OrtizSpace.sm),
          _filterChip(state, 'good', 'Buenos Hábitos'),
          const SizedBox(width: OrtizSpace.sm),
          _filterChip(state, 'bad', 'Malos Hábitos'),
          if (state.stacks.isNotEmpty) ...[
            const SizedBox(width: OrtizSpace.sm),
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
      borderRadius: BorderRadius.circular(OrtizRadius.dialog),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.dialog),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? OrtizPalette.onAccent : HabitosColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Filtro horizontal por Contacto Asociado del Diario
  Widget _buildContactFilterRow(BuildContext context, HabitosState state) {
    final diarioState = Provider.of<DiarioState>(context);

    // Solo contactos con hábitos activos, de más a menos hábitos (empate: por nombre).
    final habitsPerContact = <String, int>{};
    for (final h in state.allHabits) {
      final cid = h.contactId;
      if (cid != null && cid.isNotEmpty) habitsPerContact[cid] = (habitsPerContact[cid] ?? 0) + 1;
    }
    final contacts = diarioState.contacts.where((c) => habitsPerContact.containsKey(c.id)).toList()
      ..sort((a, b) {
        final byCount = habitsPerContact[b.id]!.compareTo(habitsPerContact[a.id]!);
        return byCount != 0 ? byCount : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: OrtizSpace.xs, bottom: OrtizSpace.xs),
          child: Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: OrtizIconSize.xs, color: HabitosColors.textSecondary),
              const SizedBox(width: OrtizSpace.xs),
              const Text(
                'CONTACTO ASOCIADO',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: HabitosColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (state.selectedContactId != null) ...[
                const SizedBox(width: OrtizSpace.sm),
                InkWell(
                  onTap: () => state.setContactFilter(null),
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quitar filtro',
                          style: TextStyle(
                            fontSize: OrtizFontSize.micro,
                            fontWeight: FontWeight.w700,
                            color: HabitosColors.primary,
                          ),
                        ),
                        SizedBox(width: OrtizSpace.xxs),
                        Icon(Icons.close_rounded, size: OrtizIconSize.xs, color: HabitosColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildScrollableChipRow(
          context: context,
          controller: _contactScrollController,
          child: Row(
            children: [
              _contactFilterChip(
                state: state,
                contactId: null,
                label: 'Todos',
                icon: Icons.people_alt_outlined,
              ),
              ...contacts.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(left: OrtizSpace.sm),
                  child: _contactFilterChip(
                    state: state,
                    contactId: c.id,
                    label: c.name,
                    avatarUrl: c.avatarUrl,
                    count: habitsPerContact[c.id],
                  ),
                );
              }),
              const SizedBox(width: OrtizSpace.sm),
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
      borderRadius: BorderRadius.circular(OrtizRadius.dialog),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
        decoration: BoxDecoration(
          color: isSelected ? HabitosColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.dialog),
          border: Border.all(
            color: isSelected ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: DiarioImageHelper.buildImageWidget(avatarUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: OrtizSpace.xs),
            ] else if (icon != null) ...[
              Icon(icon, size: OrtizIconSize.xs, color: isSelected ? OrtizPalette.onAccent : HabitosColors.textSecondary),
              const SizedBox(width: OrtizSpace.xs),
            ] else ...[
              CircleAvatar(
                radius: 8,
                backgroundColor: isSelected ? OrtizPalette.onAccent.withValues(alpha: 0.15) : HabitosColors.primaryLight,
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: OrtizFontSize.micro,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? OrtizPalette.onAccent : HabitosColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: OrtizSpace.xs),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: OrtizFontSize.caption,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? OrtizPalette.onAccent : HabitosColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: OrtizSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                decoration: BoxDecoration(
                  color: isSelected ? OrtizPalette.onAccent.withValues(alpha: 0.15) : HabitosColors.primaryLight,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: OrtizFontSize.micro,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? OrtizPalette.onAccent : HabitosColors.primary,
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
    // En malos hábitos el contador son las recaídas del día (los registros antiguos guardaban 0).
    final counterVal = habit.isNegative ? state.getRelapseCount(habit.id).toDouble() : currentVal;
    final streak = state.calculateCurrentStreak(habit.id);
    final cleanDays = habit.isNegative ? state.calculateCleanDays(habit.id) : null;
    final diarioState = Provider.of<DiarioState>(context, listen: false);
    final linkedContact = habit.contactId != null
        ? diarioState.contacts.where((c) => c.id == habit.contactId).firstOrNull
        : null;

    // Fila sin tarjeta: la separa de la siguiente una línea `line`.
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HabitosColors.cardBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
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
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? HabitosColors.primary : HabitosColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? HabitosColors.primary : HabitosColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+1',
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.w900,
                          color: isDone ? OrtizPalette.onAccent : HabitosColors.primary,
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
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? HabitosColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? HabitosColors.primary : HabitosColors.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: OrtizPalette.onAccent, size: OrtizIconSize.sm)
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
                      border: Border.all(color: HabitosColors.rose.withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.shield_outlined, color: HabitosColors.rose, size: OrtizIconSize.sm),
                  ),

                const SizedBox(width: OrtizSpace.md),

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
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.w800,
                            color: HabitosColors.textPrimary,
                            decoration: (isDone && !habit.isNegative && habit.type != HabitType.counter) ? TextDecoration.lineThrough : null,
                            decorationColor: HabitosColors.textMuted,
                          ),
                        ),
                        if (habit.description != null && habit.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: OrtizSpace.xxs),
                            child: Text(
                              habit.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.textSecondary),
                            ),
                          ),
                        if (linkedContact != null)
                          Padding(
                            padding: const EdgeInsets.only(top: OrtizSpace.xs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: HabitosColors.primaryLight,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: OrtizIconSize.xs, color: HabitosColors.primary),
                                  const SizedBox(width: OrtizSpace.xs),
                                  Text(
                                    linkedContact.name,
                                    style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w700, color: HabitosColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: OrtizSpace.sm),

                // 3. Insignia de Racha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                  decoration: BoxDecoration(
                    color: habit.isNegative ? HabitosColors.amberLight : HabitosColors.primaryLight,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    border: Border.all(
                      color: (habit.isNegative ? HabitosColors.amber : HabitosColors.primary).withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        habit.isNegative ? Icons.verified_user_rounded : Icons.local_fire_department_rounded,
                        size: OrtizIconSize.xs,
                        color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                      ),
                      const SizedBox(width: OrtizSpace.xxs),
                      Text(
                        habit.isNegative ? '$cleanDays d' : '$streak d',
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w900,
                          color: habit.isNegative ? HabitosColors.amber : HabitosColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Botón de detalle
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: OrtizIconSize.md, color: HabitosColors.textMuted),
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
              const SizedBox(height: OrtizSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.isNegative ? 'RECAÍDAS DEL DÍA' : 'REGISTRO DE HOY',
                          style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: HabitosColors.textSecondary),
                        ),
                        Text(
                          '${counterVal.toInt()} ${habit.unit ?? "veces"}',
                          style: TextStyle(
                            fontSize: OrtizFontSize.body,
                            fontWeight: FontWeight.w900,
                            color: habit.isNegative && counterVal > 0 ? HabitosColors.rose : HabitosColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (counterVal > 0) ...[
                      _circleCountBtn(
                        label: '-1',
                        onTap: () => state.updateHabitValue(habit.id, -1),
                      ),
                      const SizedBox(width: OrtizSpace.sm),
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
              const SizedBox(height: OrtizSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Text(
                      '${currentVal.toInt()} / ${habit.targetValue.toInt()} ${habit.unit ?? ""}',
                      style: const TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.w800,
                        color: HabitosColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _circleCountBtn(
                      label: '-1',
                      onTap: () => state.updateHabitValue(habit.id, -1),
                    ),
                    const SizedBox(width: OrtizSpace.xs),
                    _circleCountBtn(
                      label: '+1',
                      isPrimary: true,
                      onTap: () => state.updateHabitValue(habit.id, 1),
                    ),
                    if (habit.targetValue >= 100) ...[
                      const SizedBox(width: OrtizSpace.xs),
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
              const SizedBox(height: OrtizSpace.md),
              _buildTimerControls(habit, state, isDone),
            ],

            // Controles de Malos Hábitos (Abstinencia)
            if (habit.isNegative) ...[
              const SizedBox(height: OrtizSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: HabitosColors.background,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(color: HabitosColors.cardBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: OrtizIconSize.sm, color: HabitosColors.primary),
                        const SizedBox(width: OrtizSpace.xs),
                        Text(
                          '$cleanDays días libre',
                          style: const TextStyle(
                            fontSize: OrtizFontSize.bodySm,
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
                            backgroundColor: HabitosColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
                            title: const Text(
                              '¿Registrar recaída?',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.titleSm),
                            ),
                            content: const Text(
                              'El contador de días limpios se reiniciará hoy. Sé amable contigo mismo y vuelve a empezar.',
                              style: TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.textSecondary),
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
                                  foregroundColor: OrtizPalette.onAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
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
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                        decoration: BoxDecoration(
                          color: HabitosColors.roseLight,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          border: Border.all(color: HabitosColors.rose.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.report_problem_rounded, size: OrtizIconSize.xs, color: HabitosColors.rose),
                            SizedBox(width: OrtizSpace.xs),
                            Text(
                              'Recaída',
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
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
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
        decoration: BoxDecoration(
          color: isPrimary ? HabitosColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
          border: Border.all(
            color: isPrimary ? HabitosColors.primary : HabitosColors.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: FontWeight.w800,
            color: isPrimary ? OrtizPalette.onAccent : HabitosColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
      decoration: BoxDecoration(
        color: HabitosColors.background,
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        border: Border.all(color: HabitosColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isRunning ? Icons.timer_rounded : Icons.timer_outlined,
            size: OrtizIconSize.sm,
            color: isRunning ? HabitosColors.primary : HabitosColors.textSecondary,
          ),
          const SizedBox(width: OrtizSpace.sm),
          Text(
            '$minutes:$seconds min',
            style: const TextStyle(
              fontSize: OrtizFontSize.body,
              fontWeight: FontWeight.w900,
              color: HabitosColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (!isRunning) ...[
            ElevatedButton.icon(
              onPressed: () => _startTimer(habit, state),
              icon: const Icon(Icons.play_arrow_rounded, size: OrtizIconSize.sm),
              label: Text(isDone ? 'Repetir' : 'Iniciar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HabitosColors.primary,
                foregroundColor: OrtizPalette.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause_rounded, size: OrtizIconSize.sm),
              label: const Text('Pausar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HabitosColors.primary,
                side: const BorderSide(color: HabitosColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              ),
            ),
          ],
          const SizedBox(width: OrtizSpace.xs),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: OrtizIconSize.sm, color: HabitosColors.textSecondary),
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
      padding: const EdgeInsets.all(OrtizSpace.xxxl),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HabitosColors.primaryLight,
              borderRadius: BorderRadius.circular(OrtizRadius.block),
            ),
            child: const Icon(Icons.playlist_add_check_rounded, color: HabitosColors.primary, size: OrtizIconSize.lg),
          ),
          const SizedBox(height: OrtizSpace.md),
          const Text(
            'No hay hábitos en esta sección',
            style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w800, color: HabitosColors.textPrimary),
          ),
          const SizedBox(height: OrtizSpace.xs),
          const Text(
            'Crea tu primer hábito o selecciona otro filtro arriba.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: HabitosColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
