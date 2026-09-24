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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: RemindersColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mover "${reminder.title}" a:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...List.generate(7, (i) {
                    final isCurrent = reminder.scheduledDayOfWeek == i;
                    return ActionChip(
                      avatar: isCurrent ? const Icon(Icons.check, size: 14, color: RemindersColors.primary) : null,
                      label: Text(_dayNames[i]),
                      backgroundColor: isCurrent ? RemindersColors.primaryLight : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        fontSize: 12,
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
                        ? const Icon(Icons.check, size: 14, color: RemindersColors.primary)
                        : null,
                    label: const Text('Bandeja (Sin día)'),
                    backgroundColor: reminder.scheduledDayOfWeek == null
                        ? RemindersColors.primaryLight
                        : Colors.grey.shade100,
                    labelStyle: TextStyle(
                      fontSize: 12,
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
              const SizedBox(height: 8),
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
        // Sub-barra superior de navegación móvil: [ Cronograma Semanal | Brújula (Roles) ]
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
              const SizedBox(width: 4),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? RemindersColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? RemindersColors.primary : Colors.grey.shade700,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDropping
                            ? RemindersColors.primaryLight
                            : isSelected
                                ? RemindersColors.primary
                                : isToday
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? RemindersColors.primary
                              : isToday
                                  ? RemindersColors.primary.withOpacity(0.5)
                                  : Colors.grey.shade200,
                          width: isSelected || isToday || isDropping ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: RemindersColors.primary.withOpacity(0.25),
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
                            _dayNames[dayIndex].substring(0, 3),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday ? RemindersColors.primary : RemindersColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : RemindersColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (bigRockCount > 0)
                                Icon(
                                  Icons.star,
                                  size: 10,
                                  color: isSelected ? Colors.amberAccent : const Color(0xFFD97706),
                                ),
                              if (reminders.isNotEmpty) ...[
                                if (bigRockCount > 0) const SizedBox(width: 2),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white70 : Colors.grey.shade400,
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

        const SizedBox(height: 10),

        // Área del Día Seleccionado (Scrollable, tarjetas amplias y DragTarget)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelectedToday ? RemindersColors.primary.withOpacity(0.6) : Colors.grey.shade200,
                width: isSelectedToday ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelectedToday
                            ? RemindersColors.primaryLight.withOpacity(0.6)
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelectedToday
                                            ? RemindersColors.primary
                                            : RemindersColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDayHeader(selectedDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelectedToday ? FontWeight.bold : FontWeight.normal,
                                        color: isSelectedToday
                                            ? RemindersColors.primary
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (isSelectedToday) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: RemindersColors.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'HOY',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (selectedBigRocks > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: 10, color: Color(0xFFD97706)),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$selectedBigRocks ${selectedBigRocks == 1 ? "Gran Roca" : "Grandes Rocas"}',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      '${selectedReminders.length} ${selectedReminders.length == 1 ? "tarea" : "tareas"}',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botón para agregar tarea directamente a este día
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: RemindersColors.primary, size: 22),
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
                        color: isHovering ? RemindersColors.primaryLight.withOpacity(0.3) : Colors.white,
                        child: selectedReminders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available_outlined, size: 36, color: Colors.grey.shade300),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No hay tareas agendadas para el ${_dayNames[_selectedDayIndex]}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
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
                                            size: 15, color: Color(0xFFD97706)),
                                        label: const Text(
                                          'Planificar Gran Roca',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFFDE68A)),
                                          backgroundColor: const Color(0xFFFFFBEB),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: selectedReminders.length,
                                itemBuilder: (context, rIdx) {
                                  final reminder = selectedReminders[rIdx];
                                  final role = state.getRoleById(reminder.roleId);

                                  return Draggable<ReminderModel>(
                                    data: reminder,
                                    feedback: Material(
                                      elevation: 6,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 240,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: reminder.isBigRock
                                                ? const Color(0xFFD97706)
                                                : RemindersColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          reminder.title,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

        const SizedBox(height: 8),

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
          margin: const EdgeInsets.fromLTRB(16, 12, 0, 16),
          child: _buildCompassCard(context, state, roles, unaddressed, isMobile: false),
        ),

        // ==========================================
        // ÁREA PRINCIPAL: CRONOGRAMA 7 DÍAS
        // ==========================================
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Grilla de los 7 Días de la Semana
                Expanded(
                  child: Row(
                    children: List.generate(7, (dayIndex) {
                      final monday = state.currentMonday;
                      final date = monday.add(Duration(days: dayIndex));
                      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                      final reminders = state.remindersForDayOfWeek(dayIndex);
                      final bigRockCount = reminders.where((r) => r.isBigRock).length;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: dayIndex < 6 ? 8 : 0),
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
                                      ? RemindersColors.primaryLight.withOpacity(0.5)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isHovering
                                        ? RemindersColors.primary
                                        : isToday
                                            ? RemindersColors.primary
                                            : Colors.grey.shade200,
                                    width: isToday || isHovering ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Encabezado del Día
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? RemindersColors.primaryLight
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                                                  fontSize: 11,
                                                  color: isToday
                                                      ? RemindersColors.primary
                                                      : RemindersColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                _formatDayHeader(date),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                  color: isToday ? RemindersColors.primary : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            alignment: WrapAlignment.spaceBetween,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (bigRockCount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.star, size: 10, color: Color(0xFFD97706)),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '$bigRockCount',
                                                        style: const TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF92400E),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Text(
                                                '${reminders.length} ${reminders.length == 1 ? "tarea" : "tareas"}',
                                                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Contenedor de Tareas del Día (Scrollable)
                                    Expanded(
                                      child: reminders.isEmpty
                                          ? Center(
                                              child: Text(
                                                'Arrastra tareas aquí',
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.all(6),
                                              itemCount: reminders.length,
                                              itemBuilder: (context, rIdx) {
                                                final reminder = reminders[rIdx];
                                                final role = state.getRoleById(reminder.roleId);

                                                return Draggable<ReminderModel>(
                                                  data: reminder,
                                                  feedback: Material(
                                                    elevation: 6,
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      width: 180,
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: reminder.isBigRock
                                                              ? const Color(0xFFD97706)
                                                              : RemindersColors.primary,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        reminder.title,
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Encabezado de Brújula
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: RemindersColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.explore_outlined, color: RemindersColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Brújula Semanal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 18, color: RemindersColors.textMuted),
                onPressed: () => _openRoleManager(context),
                tooltip: 'Administrar Roles Vitales',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.currentWeeklyPlan?.formattedRange ?? '',
            style: const TextStyle(fontSize: 11, color: RemindersColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Botón de Ritual Dominical
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _openSundayWizard(context),
            icon: const Icon(Icons.wb_sunny_outlined, size: 16),
            label: const Text(
              'Ritual Dominical',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4338CA),
              backgroundColor: const Color(0xFFEEF2FF),
              side: const BorderSide(color: Color(0xFFC7D2FE)),
              minimumSize: const Size.fromHeight(34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _openGuide(context),
            icon: const Icon(Icons.school_outlined, size: 15, color: Color(0xFF4F46E5)),
            label: const Text(
              '¿Cómo organizarme? (Guía)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Alerta de Balance si hay roles desatendidos
          if (unaddressed.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${unaddressed.length} ${unaddressed.length == 1 ? "rol no tiene" : "roles no tienen"} Gran Roca esta semana (${unaddressed.map((r) => r.name).join(", ")}).',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Lista de Roles con sus Grandes Rocas
          const Text(
            'ROLES VITALES & GRANDES ROCAS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: RemindersColors.textMuted),
          ),
          const SizedBox(height: 8),

          if (isMobile)
            ...roles.map((role) => _buildRoleItem(state, role))
          else
            Expanded(
              child: ListView.separated(
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasRock ? Colors.grey.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(role.iconData, size: 16, color: role.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  role.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: hasRock ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rocks.length} Rocas',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: hasRock ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (role.purposeStatement != null && role.purposeStatement!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                role.purposeStatement!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
          // Listado de rocas para este rol
          if (rocks.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...rocks.map((rock) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rock.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            decoration: rock.isCompleted ? TextDecoration.lineThrough : null,
                            color: rock.isCompleted ? Colors.grey : RemindersColors.textPrimary,
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
      margin: isMobile ? const EdgeInsets.fromLTRB(16, 0, 16, 12) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inbox_outlined, size: 16, color: RemindersColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isMobile ? 'Bandeja Semanal' : 'Bandeja Semanal (Sin Día Asignado)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.unscheduledWeeklyReminders.length}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _showUnscheduledDrawer = !_showUnscheduledDrawer),
                icon: Icon(_showUnscheduledDrawer ? Icons.expand_less : Icons.expand_more, size: 16),
                label: Text(_showUnscheduledDrawer ? 'Ocultar' : 'Mostrar', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (_showUnscheduledDrawer) ...[
            const SizedBox(height: 6),
            if (state.unscheduledWeeklyReminders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '¡Excelente! Todas las tareas de la semana están agendadas en días específicos.',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                ),
              )
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.unscheduledWeeklyReminders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final reminder = state.unscheduledWeeklyReminders[idx];
                    final role = state.getRoleById(reminder.roleId);

                    return Draggable<ReminderModel>(
                      data: reminder,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: reminder.isBigRock ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: reminder.isBigRock ? const Color(0xFFF59E0B) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (reminder.isBigRock) ...[
                const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              if (isMobile)
                InkWell(
                  onTap: () => _showMoveDayModal(context, state, reminder),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drive_file_move_outlined, size: 14, color: RemindersColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (role != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(role.iconData, size: 11, color: role.color),
                    const SizedBox(width: 3),
                    Text(role.name, style: TextStyle(fontSize: 9.5, color: role.color)),
                  ],
                ),
              Text(
                reminder.quadrant.shortLabel,
                style: TextStyle(fontSize: 9.5, color: reminder.quadrant.color, fontWeight: FontWeight.bold),
              ),
              if (reminder.isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: RemindersColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_rounded, size: 8, color: RemindersColors.primary),
                      SizedBox(width: 2),
                      Text(
                        'Fijado',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: RemindersColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isMobile ? 'Toca para mover' : 'Arrastra a un día',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: reminder.isBigRock ? const Color(0xFFF59E0B) : Colors.grey.shade200,
          width: reminder.isBigRock ? 1.5 : 1,
        ),
      ),
      color: reminder.isBigRock ? const Color(0xFFFFFBEB) : Colors.white,
      child: InkWell(
        onTap: () => _openEditor(context, reminder),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        reminder.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 15,
                        color: reminder.isCompleted ? Colors.green : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        color: reminder.isCompleted ? Colors.grey : RemindersColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.toggleBigRock(reminder.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        reminder.isBigRock ? Icons.star : Icons.star_border,
                        size: 15,
                        color: reminder.isBigRock ? const Color(0xFFD97706) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  if (isMobile)
                    InkWell(
                      onTap: () => _showMoveDayModal(context, state, reminder),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Fila Inferior: Cuadrante, Rol, Tiempo
              Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: reminder.quadrant.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      reminder.quadrant.shortLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: reminder.quadrant.color,
                      ),
                    ),
                  ),
                  if (role != null) ...[
                    Icon(role.iconData, size: 10, color: role.color),
                    Text(
                      role.name,
                      style: TextStyle(fontSize: 9, color: role.color, fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (reminder.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: RemindersColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_rounded, size: 7.5, color: RemindersColors.primary),
                          SizedBox(width: 1.5),
                          Text(
                            'Fijado',
                            style: TextStyle(
                              fontSize: 8,
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
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                    )
                  else if (reminder.estimatedDurationMinutes != null)
                    Text(
                      '~${reminder.estimatedDurationMinutes}m',
                      style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
