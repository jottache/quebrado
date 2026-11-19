import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../dialogs/covey_guide_dialog.dart';
import '../dialogs/reminder_editor_dialog.dart';
import '../dialogs/role_manager_dialog.dart';
import '../dialogs/sunday_planning_wizard_dialog.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class WeeklyScheduleView extends StatefulWidget {
  const WeeklyScheduleView({super.key});

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  final List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  bool _showUnscheduledDrawer = true;
  String _mobileWeeklyTab = 'schedule'; // 'schedule' | 'compass'
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    // Iniciar con el día actual de la semana (0=Lunes .. 6=Domingo)
    final nowWeekday = DateTime.now().weekday; // 1=Lunes .. 7=Domingo
    _selectedDayIndex = (nowWeekday - 1).clamp(0, 6);
  }

  void _openEditor(BuildContext context, ReminderModel reminder) {
    showDialog(
      context: context,
      builder: (ctx) => ReminderEditorDialog(reminder: reminder),
    );
  }

  static String _weekRelativeLabel(int offset) {
    switch (offset) {
      case 0:
        return 'Esta semana';
      case 1:
        return 'Próxima semana';
      case -1:
        return 'Semana pasada';
      default:
        return offset > 0 ? 'En $offset semanas' : 'Hace ${-offset} semanas';
    }
  }

  /// Barra ‹ semana › para ver y planificar cualquier semana.
  Widget _buildWeekNavigator(RemindersState state, {bool compact = false}) {
    final monday = state.currentMonday;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final offset = state.selectedWeekOffset;
    final range = '${_formatDayHeader(monday)} – ${_formatDayHeader(sunday)}';
    final t = OrtizTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(
        // Fuera de la semana actual se tiñe de ámbar para que se note.
        color: offset == 0 ? Colors.transparent : OrtizPalette.warnTint,
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        border: Border.all(color: offset == 0 ? t.line : OrtizPalette.warnBorder),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('week_prev'),
            tooltip: 'Semana anterior',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: state.previousWeek,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  range,
                  key: const ValueKey('week_range'),
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.bold,
                    color: RemindersColors.textPrimary,
                  ),
                ),
                Text(
                  _weekRelativeLabel(offset),
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: offset == 0 ? RemindersColors.primary : t.warn,
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoadingWeek)
            const Padding(
              padding: EdgeInsets.only(right: OrtizSpace.xs),
              child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (offset != 0)
            TextButton(
              onPressed: state.goToCurrentWeek,
              style: TextButton.styleFrom(
                foregroundColor: RemindersColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Hoy', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          IconButton(
            key: const ValueKey('week_next'),
            tooltip: 'Semana siguiente',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: state.nextWeek,
          ),
        ],
      ),
    );
  }

  void _openRoleManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const RoleManagerDialog(),
    );
  }

  void _openSundayWizard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const SundayPlanningWizardDialog(),
    );
  }

  void _openGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CoveyGuideDialog(),
    );
  }

  String _formatDayHeader(DateTime date) {
    try {
      return DateFormat('d MMM', 'es').format(date);
    } catch (_) {
      const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  void _showMoveDayModal(BuildContext context, RemindersState state, ReminderModel reminder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.dialog))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      'Mover "${reminder.title}" a:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...List.generate(7, (i) {
                    final isCurrent = reminder.scheduledDayOfWeek == i;
                    return ActionChip(
                      avatar: isCurrent ? const Icon(Icons.check, size: OrtizIconSize.xs, color: RemindersColors.primary) : null,
                      label: Text(_dayNames[i]),
                      backgroundColor: isCurrent ? RemindersColors.primaryLight : OrtizPalette.surfaceHigh,
                      labelStyle: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? RemindersColors.primary : RemindersColors.textPrimary,
                      ),
                      onPressed: () {
                        state.moveReminderToDay(reminder.id, i);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  ActionChip(
                    avatar: reminder.scheduledDayOfWeek == null
                        ? const Icon(Icons.check, size: OrtizIconSize.xs, color: RemindersColors.primary)
                        : null,
                    label: const Text('Bandeja (Sin día)'),
                    backgroundColor: reminder.scheduledDayOfWeek == null
                        ? RemindersColors.primaryLight
                        : OrtizPalette.surfaceHigh,
                    labelStyle: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: reminder.scheduledDayOfWeek == null ? FontWeight.bold : FontWeight.normal,
                      color: reminder.scheduledDayOfWeek == null
                          ? RemindersColors.primary
                          : RemindersColors.textPrimary,
                    ),
                    onPressed: () {
                      state.moveReminderToDay(reminder.id, null);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final roles = state.roles;
    final unaddressed = state.unaddressedRoles;
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        if (isMobile) {
          return _buildMobileLayout(context, state, roles, unaddressed, now);
        } else {
          return _buildDesktopLayout(context, state, roles, unaddressed, now);
        }
      },
    );
  }

  // ===========================================================================
  // LAYOUT MOBILE (< 750px): Pestañas Cronograma / Brújula y Selector de Días
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    RemindersState state,
    List<RoleModel> roles,
    List<RoleModel> unaddressed,
    DateTime now,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.xs, OrtizSpace.lg, 0),
          child: _buildWeekNavigator(state, compact: true),
        ),

        // Sub-barra superior de navegación móvil: [ Cronograma Semanal | Brújula (Roles) ]
        Container(
          margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.xs, OrtizSpace.lg, OrtizSpace.sm),
          padding: const EdgeInsets.all(OrtizSpace.xs),
          decoration: BoxDecoration(
            color: OrtizPalette.surface,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(color: OrtizPalette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSubTabButton(
                  title: 'Cronograma Semanal',
                  icon: Icons.calendar_view_week_rounded,
                  isSelected: _mobileWeeklyTab == 'schedule',
                  onTap: () => setState(() => _mobileWeeklyTab = 'schedule'),
                ),
              ),
              const SizedBox(width: OrtizSpace.xs),
              Expanded(
                child: _buildSubTabButton(
                  title: 'Brújula de Roles',
                  icon: Icons.explore_outlined,
                  badge: unaddressed.isNotEmpty ? '${unaddressed.length}' : null,
                  isSelected: _mobileWeeklyTab == 'compass',
                  onTap: () => setState(() => _mobileWeeklyTab = 'compass'),
                ),
              ),
            ],
          ),
        ),

        // Contenido según la pestaña activa
        Expanded(
          child: _mobileWeeklyTab == 'compass'
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, 0, OrtizSpace.lg, OrtizSpace.lg),
                  child: _buildCompassCard(context, state, roles, unaddressed, isMobile: true),
                )
              : _buildMobileScheduleView(context, state, now),
        ),
      ],
    );
  }

  Widget _buildSubTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? OrtizPalette.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: OrtizIconSize.sm,
              color: isSelected ? RemindersColors.primary : OrtizPalette.muted,
            ),
            const SizedBox(width: OrtizSpace.xs),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? RemindersColors.primary : OrtizPalette.muted,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: OrtizSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                decoration: BoxDecoration(
                  color: OrtizPalette.warn,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.onAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Vista de Cronograma para Móviles: Strip de 7 días + Tarjeta de Día Seleccionado
  Widget _buildMobileScheduleView(
    BuildContext context,
    RemindersState state,
    DateTime now,
  ) {
    final monday = state.currentMonday;
    final selectedDate = monday.add(Duration(days: _selectedDayIndex));
    final isSelectedToday =
        selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
    final selectedReminders = state.remindersForDayOfWeek(_selectedDayIndex);
    final selectedBigRocks = selectedReminders.where((r) => r.isBigRock).length;

    return Column(
      children: [
        // Strip Horizontal de los 7 Días de la Semana
        Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: OrtizSpace.sm),
            itemBuilder: (context, dayIndex) {
              final date = monday.add(Duration(days: dayIndex));
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              final isSelected = dayIndex == _selectedDayIndex;
              final reminders = state.remindersForDayOfWeek(dayIndex);
              final bigRockCount = reminders.where((r) => r.isBigRock).length;

              return DragTarget<ReminderModel>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  state.moveReminderToDay(details.data.id, dayIndex);
                },
                builder: (context, candidateData, rejectedData) {
                  final isDropping = candidateData.isNotEmpty;

                  return InkWell(
                    onTap: () => setState(() => _selectedDayIndex = dayIndex),
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs, horizontal: OrtizSpace.xs),
                      decoration: BoxDecoration(
                        color: isDropping
                            ? RemindersColors.primaryLight
                            : isSelected
                                ? RemindersColors.primary
                                : isToday
                                    ? OrtizPalette.surfaceHigh
                                    : Colors.transparent,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                        border: Border.all(
                          color: isSelected
                              ? RemindersColors.primary
                              : isToday
                                  ? RemindersColors.primary.withValues(alpha: 0.5)
                                  : OrtizPalette.line,
                          width: isSelected || isToday || isDropping ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayNames[dayIndex].substring(0, 3),
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? OrtizPalette.onAccent
                                  : (isToday ? RemindersColors.primary : RemindersColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: OrtizSpace.xxs),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: OrtizFontSize.body,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? OrtizPalette.onAccent : RemindersColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: OrtizSpace.xxs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (bigRockCount > 0)
                                Icon(
                                  Icons.star,
                                  // Celda densa: icono al tamaño del texto micro.
                                  size: OrtizFontSize.micro,
                                  color: isSelected ? OrtizPalette.onAccent : OrtizPalette.warn,
                                ),
                              if (reminders.isNotEmpty) ...[
                                if (bigRockCount > 0) const SizedBox(width: OrtizSpace.xxs),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected ? OrtizPalette.onAccent : OrtizPalette.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: OrtizSpace.sm),

        // Área del Día Seleccionado (Scrollable, tarjetas amplias y DragTarget)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OrtizRadius.block),
              border: Border.all(
                color: isSelectedToday ? RemindersColors.primary.withValues(alpha: 0.6) : OrtizPalette.line,
                width: isSelectedToday ? 1.5 : 1,
              ),
            ),
            child: DragTarget<ReminderModel>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) {
                state.moveReminderToDay(details.data.id, _selectedDayIndex);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;

                return Column(
                  children: [
                    // Header del Día Seleccionado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: isSelectedToday
                            ? RemindersColors.primaryLight.withValues(alpha: 0.6)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.block)),
                        border: const Border(bottom: BorderSide(color: OrtizPalette.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _dayNames[_selectedDayIndex],
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.body,
                                        fontWeight: FontWeight.bold,
                                        color: isSelectedToday
                                            ? RemindersColors.primary
                                            : RemindersColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: OrtizSpace.xs),
                                    Text(
                                      _formatDayHeader(selectedDate),
                                      style: TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
                                        fontWeight: isSelectedToday ? FontWeight.bold : FontWeight.normal,
                                        color: isSelectedToday
                                            ? RemindersColors.primary
                                            : OrtizPalette.muted,
                                      ),
                                    ),
                                    if (isSelectedToday) ...[
                                      const SizedBox(width: OrtizSpace.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                        decoration: BoxDecoration(
                                          color: RemindersColors.primary,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        child: const Text(
                                          'HOY',
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.micro,
                                            fontWeight: FontWeight.bold,
                                            color: OrtizPalette.onAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: OrtizSpace.xxs),
                                Row(
                                  children: [
                                    if (selectedBigRocks > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                        decoration: BoxDecoration(
                                          color: OrtizPalette.warnTint,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: OrtizFontSize.micro, color: OrtizPalette.warn),
                                            const SizedBox(width: OrtizSpace.xxs),
                                            Text(
                                              '$selectedBigRocks ${selectedBigRocks == 1 ? "Gran Roca" : "Grandes Rocas"}',
                                              style: const TextStyle(
                                                fontSize: OrtizFontSize.micro,
                                                fontWeight: FontWeight.bold,
                                                color: OrtizPalette.warn,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: OrtizSpace.xs),
                                    ],
                                    Text(
                                      '${selectedReminders.length} ${selectedReminders.length == 1 ? "tarea" : "tareas"}',
                                      style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botón para agregar tarea directamente a este día
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: RemindersColors.primary, size: OrtizIconSize.lg),
                            tooltip: 'Agregar tarea a este día',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => ReminderEditorDialog(
                                  scheduledDayOfWeek: _selectedDayIndex,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Lista de Tareas para este día
                    Expanded(
                      child: Container(
                        color: isHovering ? RemindersColors.primaryLight.withValues(alpha: 0.3) : Colors.transparent,
                        child: selectedReminders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(OrtizSpace.xxl),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.event_available_outlined, size: OrtizIconSize.xl, color: OrtizPalette.faint),
                                      const SizedBox(height: OrtizSpace.sm),
                                      Text(
                                        'No hay tareas agendadas para el ${_dayNames[_selectedDayIndex]}',
                                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: OrtizSpace.sm),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ReminderEditorDialog(
                                              scheduledDayOfWeek: _selectedDayIndex,
                                              isBigRock: true,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.star_outline_rounded,
                                            size: OrtizIconSize.sm, color: OrtizPalette.warn),
                                        label: const Text(
                                          'Planificar Gran Roca',
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.bold,
                                            color: OrtizPalette.warn,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: OrtizPalette.warnBorder),
                                          backgroundColor: OrtizPalette.warnTint,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(OrtizSpace.sm),
                                itemCount: selectedReminders.length,
                                itemBuilder: (context, rIdx) {
                                  final reminder = selectedReminders[rIdx];
                                  final role = state.getRoleById(reminder.roleId);

                                  return Draggable<ReminderModel>(
                                    data: reminder,
                                    feedback: Material(
                                      elevation: 6,
                                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      child: Container(
                                        width: 240,
                                        padding: const EdgeInsets.all(OrtizSpace.sm),
                                        decoration: BoxDecoration(
                                          color: OrtizPalette.surfaceHigh,
                                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          border: Border.all(
                                            color: reminder.isBigRock
                                                ? OrtizPalette.warn
                                                : RemindersColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          reminder.title,
                                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.25,
                                      child: _buildDayReminderCard(context, state, reminder, role, isMobile: true),
                                    ),
                                    child: _buildDayReminderCard(context, state, reminder, role, isMobile: true),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: OrtizSpace.sm),

        // Bandeja Semanal Inferior (Drawer Colapsable Móvil)
        _buildUnscheduledDrawer(context, state, isMobile: true),
      ],
    );
  }

  // ===========================================================================
  // LAYOUT DESKTOP / TABLET (>= 750px): Dual Pane (Sidebar Brújula + 7 Columnas)
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    RemindersState state,
    List<RoleModel> roles,
    List<RoleModel> unaddressed,
    DateTime now,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // SIDEBAR IZQUIERDO: BRÚJULA SEMANAL
        // ==========================================
        Container(
          width: 280,
          margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, 0, OrtizSpace.lg),
          child: _buildCompassCard(context, state, roles, unaddressed, isMobile: false),
        ),

        // ==========================================
        // ÁREA PRINCIPAL: CRONOGRAMA 7 DÍAS
        // ==========================================
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.lg),
            child: Column(
              children: [
                _buildWeekNavigator(state),
                const SizedBox(height: OrtizSpace.sm),

                // Grilla de los 7 Días de la Semana
                Expanded(
                  child: Row(
                    children: List.generate(7, (dayIndex) {
                      final monday = state.currentMonday;
                      final date = monday.add(Duration(days: dayIndex));
                      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                      final reminders = state.remindersForDayOfWeek(dayIndex);
                      final bigRockCount = reminders.where((r) => r.isBigRock).length;
                      final isLastDay = dayIndex == 6;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: isLastDay ? 0 : OrtizSpace.sm),
                          child: DragTarget<ReminderModel>(
                            onWillAcceptWithDetails: (details) => true,
                            onAcceptWithDetails: (details) {
                              state.moveReminderToDay(details.data.id, dayIndex);
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHovering = candidateData.isNotEmpty;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isHovering
                                      ? RemindersColors.primaryLight.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                  border: Border.all(
                                    color: isHovering
                                        ? RemindersColors.primary
                                        : isToday
                                            ? RemindersColors.primary
                                            : OrtizPalette.line,
                                    width: isToday || isHovering ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Encabezado del Día
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? RemindersColors.primaryLight
                                            : Colors.transparent,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.field)),
                                        border: const Border(bottom: BorderSide(color: OrtizPalette.line)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            alignment: WrapAlignment.spaceBetween,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                _dayNames[dayIndex],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: OrtizFontSize.caption,
                                                  color: isToday
                                                      ? RemindersColors.primary
                                                      : RemindersColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                _formatDayHeader(date),
                                                style: TextStyle(
                                                  fontSize: OrtizFontSize.micro,
                                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                  color: isToday ? RemindersColors.primary : OrtizPalette.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: OrtizSpace.xs),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            alignment: WrapAlignment.spaceBetween,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (bigRockCount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                                  decoration: BoxDecoration(
                                                    color: OrtizPalette.warnTint,
                                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.star, size: OrtizFontSize.micro, color: OrtizPalette.warn),
                                                      const SizedBox(width: OrtizSpace.xxs),
                                                      Text(
                                                        '$bigRockCount',
                                                        style: const TextStyle(
                                                          fontSize: OrtizFontSize.micro,
                                                          fontWeight: FontWeight.bold,
                                                          color: OrtizPalette.warn,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Text(
                                                '${reminders.length} ${reminders.length == 1 ? "tarea" : "tareas"}',
                                                style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Contenedor de Tareas del Día (Scrollable)
                                    Expanded(
                                      child: reminders.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Arrastra tareas aquí',
                                                style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.all(OrtizSpace.xs),
                                              itemCount: reminders.length,
                                              itemBuilder: (context, rIdx) {
                                                final reminder = reminders[rIdx];
                                                final role = state.getRoleById(reminder.roleId);

                                                return Draggable<ReminderModel>(
                                                  data: reminder,
                                                  feedback: Material(
                                                    elevation: 6,
                                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                    child: Container(
                                                      width: 180,
                                                      padding: const EdgeInsets.all(OrtizSpace.sm),
                                                      decoration: BoxDecoration(
                                                        color: OrtizPalette.surfaceHigh,
                                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                                        border: Border.all(
                                                          color: reminder.isBigRock
                                                              ? OrtizPalette.warn
                                                              : RemindersColors.primary,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        reminder.title,
                                                        style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.25,
                                                    child: _buildDayReminderCard(context, state, reminder, role),
                                                  ),
                                                  child: _buildDayReminderCard(context, state, reminder, role),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ==========================================
                // BANDEJA SEMANAL (TAREAS SIN DÍA ASIGNADO)
                // ==========================================
                const SizedBox(height: OrtizSpace.md),
                _buildUnscheduledDrawer(context, state, isMobile: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET COMÚN: TARJETA DE LA BRÚJULA SEMANAL
  // ===========================================================================
  Widget _buildCompassCard(
    BuildContext context,
    RemindersState state,
    List<RoleModel> roles,
    List<RoleModel> unaddressed, {
    required bool isMobile,
  }) {
    // Grupo sobre el fondo, sin tarjeta.
    return Padding(
      padding: const EdgeInsets.all(OrtizSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Encabezado de Brújula
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(OrtizSpace.xs),
                decoration: BoxDecoration(
                  color: RemindersColors.primaryLight,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: const Icon(Icons.explore_outlined, color: RemindersColors.primary, size: OrtizIconSize.md),
              ),
              const SizedBox(width: OrtizSpace.sm),
              const Expanded(
                child: Text(
                  'Brújula Semanal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body, color: RemindersColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: OrtizIconSize.md, color: RemindersColors.textMuted),
                onPressed: () => _openRoleManager(context),
                tooltip: 'Administrar Roles Vitales',
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.xs),
          Text(
            state.currentWeeklyPlan?.formattedRange ?? '',
            style: const TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted),
          ),
          const SizedBox(height: OrtizSpace.md),

          // Botón de Ritual Dominical
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: OrtizPalette.warn,
              foregroundColor: OrtizPalette.onAccent,
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
            ),
            onPressed: () => _openSundayWizard(context),
            icon: const Icon(Icons.wb_sunny_outlined, size: OrtizIconSize.sm),
            label: const Text(
              'Ritual Dominical',
              style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: OrtizSpace.xs),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: RemindersColors.primary,
              backgroundColor: RemindersColors.primaryLight,
              side: const BorderSide(color: RemindersColors.primaryBorder),
              minimumSize: const Size.fromHeight(34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
            ),
            onPressed: () => _openGuide(context),
            icon: const Icon(Icons.school_outlined, size: OrtizIconSize.sm, color: RemindersColors.primary),
            label: const Text(
              '¿Cómo organizarme? (Guía)',
              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: OrtizSpace.md),

          // Alerta de Balance si hay roles desatendidos
          if (unaddressed.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(OrtizSpace.sm),
              decoration: BoxDecoration(
                color: OrtizPalette.warnTint,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                border: Border.all(color: OrtizPalette.warnBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: OrtizIconSize.sm, color: OrtizPalette.warn),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Text(
                      '${unaddressed.length} ${unaddressed.length == 1 ? "rol no tiene" : "roles no tienen"} Gran Roca esta semana (${unaddressed.map((r) => r.name).join(", ")}).',
                      style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.warn, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrtizSpace.md),
          ],

          // Lista de Roles con sus Grandes Rocas
          const Text(
            'ROLES VITALES & GRANDES ROCAS',
            style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: RemindersColors.textMuted),
          ),
          const SizedBox(height: OrtizSpace.sm),

          if (isMobile)
            ...roles.map((role) => _buildRoleItem(state, role))
          else
            Expanded(
              child: ListView.separated(
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: OrtizSpace.sm),
                itemBuilder: (context, idx) => _buildRoleItem(state, roles[idx]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleItem(RemindersState state, RoleModel role) {
    final rocks = state.bigRocksForRole(role.id);
    final hasRock = rocks.isNotEmpty;

    // Fila separada por una línea, sin tarjeta; la píldora marca si falta roca.
    return Container(
      margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
      padding: const EdgeInsets.all(OrtizSpace.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OrtizPalette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(role.iconData, size: OrtizIconSize.sm, color: role.color),
              const SizedBox(width: OrtizSpace.xs),
              Expanded(
                child: Text(
                  role.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                decoration: BoxDecoration(
                  color: hasRock ? OrtizPalette.ok.withValues(alpha: 0.16) : OrtizPalette.warnTint,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: Text(
                  '${rocks.length} Rocas',
                  style: TextStyle(
                    fontSize: OrtizFontSize.micro,
                    fontWeight: FontWeight.bold,
                    color: hasRock ? OrtizPalette.ok : OrtizPalette.warn,
                  ),
                ),
              ),
            ],
          ),
          if (role.purposeStatement != null && role.purposeStatement!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: OrtizSpace.xxs, bottom: OrtizSpace.xs),
              child: Text(
                role.purposeStatement!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted, fontStyle: FontStyle.italic),
              ),
            ),
          // Listado de rocas para este rol
          if (rocks.isNotEmpty) ...[
            const SizedBox(height: OrtizSpace.xs),
            ...rocks.map((rock) => Padding(
                  padding: const EdgeInsets.only(top: OrtizSpace.xxs),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: OrtizIconSize.xs, color: OrtizPalette.warn),
                      const SizedBox(width: OrtizSpace.xs),
                      Expanded(
                        child: Text(
                          rock.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            decoration: rock.isCompleted ? TextDecoration.lineThrough : null,
                            color: rock.isCompleted ? OrtizPalette.muted : RemindersColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET COMÚN: BANDEJA SEMANAL (TAREAS SIN DÍA ASIGNADO)
  // ===========================================================================
  Widget _buildUnscheduledDrawer(
    BuildContext context,
    RemindersState state, {
    required bool isMobile,
  }) {
    return Container(
      margin: isMobile ? const EdgeInsets.fromLTRB(OrtizSpace.lg, 0, OrtizSpace.lg, OrtizSpace.md) : null,
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
      // Sin tarjeta: solo una línea arriba la separa del cronograma.
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OrtizPalette.line)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inbox_outlined, size: OrtizIconSize.sm, color: RemindersColors.primary),
                  const SizedBox(width: OrtizSpace.sm),
                  Text(
                    isMobile ? 'Bandeja Semanal' : 'Bandeja Semanal (Sin Día Asignado)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: OrtizPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Text(
                      '${state.unscheduledWeeklyReminders.length}',
                      style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _showUnscheduledDrawer = !_showUnscheduledDrawer),
                icon: Icon(_showUnscheduledDrawer ? Icons.expand_less : Icons.expand_more, size: OrtizIconSize.sm),
                label: Text(_showUnscheduledDrawer ? 'Ocultar' : 'Mostrar', style: const TextStyle(fontSize: OrtizFontSize.caption)),
              ),
            ],
          ),
          if (_showUnscheduledDrawer) ...[
            const SizedBox(height: OrtizSpace.xs),
            if (state.unscheduledWeeklyReminders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                child: Text(
                  '¡Excelente! Todas las tareas de la semana están agendadas en días específicos.',
                  style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.ok),
                ),
              )
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.unscheduledWeeklyReminders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: OrtizSpace.sm),
                  itemBuilder: (context, idx) {
                    final reminder = state.unscheduledWeeklyReminders[idx];
                    final role = state.getRoleById(reminder.roleId);

                    return Draggable<ReminderModel>(
                      data: reminder,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(OrtizSpace.sm),
                          color: OrtizPalette.surfaceHigh,
                          child: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildDrawerCard(context, state, reminder, role, isMobile: isMobile),
                      ),
                      child: _buildDrawerCard(context, state, reminder, role, isMobile: isMobile),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerCard(
    BuildContext context,
    RemindersState state,
    ReminderModel reminder,
    RoleModel? role, {
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? 240 : 220,
      padding: const EdgeInsets.all(OrtizSpace.sm),
      decoration: BoxDecoration(
        // Ficha arrastrable de la bandeja: fondo `surfaceHigh`, sin sombra.
        color: reminder.isBigRock ? OrtizPalette.warnTint : OrtizPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: reminder.isBigRock ? Border.all(color: OrtizPalette.warnBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (reminder.isBigRock) ...[
                const Icon(Icons.star, size: OrtizIconSize.xs, color: OrtizPalette.warn),
                const SizedBox(width: OrtizSpace.xs),
              ],
              Expanded(
                child: Text(
                  reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
                ),
              ),
              if (isMobile)
                InkWell(
                  onTap: () => _showMoveDayModal(context, state, reminder),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
                    child: Icon(Icons.drive_file_move_outlined, size: OrtizIconSize.xs, color: RemindersColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: OrtizSpace.xs),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (role != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(role.iconData, size: OrtizIconSize.xs, color: role.color),
                    const SizedBox(width: OrtizSpace.xxs),
                    Text(role.name, style: TextStyle(fontSize: OrtizFontSize.micro, color: role.color)),
                  ],
                ),
              Text(
                reminder.quadrant.shortLabel,
                style: TextStyle(fontSize: OrtizFontSize.micro, color: reminder.quadrant.color, fontWeight: FontWeight.bold),
              ),
              if (reminder.isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs, vertical: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: RemindersColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_rounded, size: OrtizFontSize.micro, color: RemindersColors.primary),
                      SizedBox(width: OrtizSpace.xxs),
                      Text(
                        'Fijado',
                        style: TextStyle(
                          fontSize: OrtizFontSize.micro,
                          fontWeight: FontWeight.bold,
                          color: RemindersColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isMobile ? 'Toca para mover' : 'Arrastra a un día',
                style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET COMÚN: TARJETA DE RECORDATORIO DE DÍA
  // ===========================================================================
  Widget _buildDayReminderCard(
    BuildContext context,
    RemindersState state,
    ReminderModel reminder,
    RoleModel? role, {
    bool isMobile = false,
  }) {
    // Sin tarjeta: fila sobre `surfaceHigh`; las Grandes Rocas, en tono ámbar.
    // En escritorio la columna del día es estrecha: iconos más pequeños.
    final rowIconSize = isMobile ? OrtizIconSize.sm : OrtizIconSize.xs;
    return Padding(
      padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
      child: Material(
      color: reminder.isBigRock ? OrtizPalette.warnTint : OrtizPalette.surfaceHigh,
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: InkWell(
        onTap: () => _openEditor(context, reminder),
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila Superior: Checkbox, Título, Star y Botón Mover (en móvil)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => state.toggleCompleted(reminder.id),
                    child: Padding(
                      padding: const EdgeInsets.only(top: OrtizSpace.xxs),
                      child: Icon(
                        reminder.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: rowIconSize,
                        color: reminder.isCompleted ? OrtizPalette.ok : OrtizPalette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.xs),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: OrtizFontSize.caption,
                        fontWeight: FontWeight.w600,
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        color: reminder.isCompleted ? OrtizPalette.muted : RemindersColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.toggleBigRock(reminder.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
                      child: Icon(
                        reminder.isBigRock ? Icons.star : Icons.star_border,
                        size: rowIconSize,
                        color: reminder.isBigRock ? OrtizPalette.warn : OrtizPalette.muted,
                      ),
                    ),
                  ),
                  if (isMobile)
                    InkWell(
                      onTap: () => _showMoveDayModal(context, state, reminder),
                      child: const Padding(
                        padding: EdgeInsets.only(left: OrtizSpace.xs),
                        child: Icon(Icons.more_vert_rounded, size: OrtizIconSize.sm, color: OrtizPalette.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: OrtizSpace.xs),

              // Fila Inferior: Cuadrante, Rol, Tiempo
              Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: reminder.quadrant.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Text(
                      reminder.quadrant.shortLabel,
                      style: TextStyle(
                        fontSize: OrtizFontSize.micro,
                        fontWeight: FontWeight.bold,
                        color: reminder.quadrant.color,
                      ),
                    ),
                  ),
                  if (role != null) ...[
                    Icon(role.iconData, size: OrtizFontSize.micro, color: role.color),
                    Text(
                      role.name,
                      style: TextStyle(fontSize: OrtizFontSize.micro, color: role.color, fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (reminder.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: RemindersColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Celda densa del escritorio: el icono no puede crecer
                          // (antes 7,5 px) sin desbordar la columna del día.
                          Icon(
                            Icons.push_pin_rounded,
                            size: OrtizFontSize.micro - OrtizSpace.xxs,
                            color: RemindersColors.primary,
                          ),
                          SizedBox(width: OrtizSpace.xxs),
                          Text(
                            'Fijado',
                            style: TextStyle(
                              fontSize: OrtizFontSize.micro,
                              fontWeight: FontWeight.bold,
                              color: RemindersColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reminder.dueAt != null)
                    Text(
                      DateFormat('HH:mm').format(reminder.dueAt!.toLocal()),
                      style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted),
                    )
                  else if (reminder.estimatedDurationMinutes != null)
                    Text(
                      '~${reminder.estimatedDurationMinutes}m',
                      style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
