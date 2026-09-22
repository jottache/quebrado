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

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final roles = state.roles;
    final unaddressed = state.unaddressedRoles;
    final now = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // SIDEBAR IZQUIERDO: BRÚJULA SEMANAL
        // ==========================================
        Container(
          width: 280,
          margin: const EdgeInsets.fromLTRB(16, 12, 0, 16),
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

              Expanded(
                child: ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final role = roles[idx];
                    final rocks = state.bigRocksForRole(role.id);
                    final hasRock = rocks.isNotEmpty;

                    return Container(
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
                                maxLines: 1,
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
                  },
                ),
              ),
            ],
          ),
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
                                                  color: isToday ? RemindersColors.primary : RemindersColors.textPrimary,
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
                                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
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
                                                          color: reminder.isBigRock ? const Color(0xFFD97706) : RemindersColors.primary,
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
                Container(
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
                              const Text(
                                'Bandeja Semanal (Sin Día Asignado)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                                    child: _buildDrawerCard(reminder, role),
                                  ),
                                  child: _buildDrawerCard(reminder, role),
                                );
                              },
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerCard(ReminderModel reminder, RoleModel? role) {
    return Container(
      width: 220,
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
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (role != null) ...[
                Icon(role.iconData, size: 11, color: role.color),
                const SizedBox(width: 4),
                Text(role.name, style: TextStyle(fontSize: 9.5, color: role.color)),
                const SizedBox(width: 6),
              ],
              Text(reminder.quadrant.shortLabel, style: TextStyle(fontSize: 9.5, color: reminder.quadrant.color, fontWeight: FontWeight.bold)),
              if (reminder.isPinned) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
              ],
              const Spacer(),
              const Text('Arrastra a un día', style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayReminderCard(
    BuildContext context,
    RemindersState state,
    ReminderModel reminder,
    RoleModel? role,
  ) {
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
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila Superior: Checkbox, Título, Star
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => state.toggleCompleted(reminder.id),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        reminder.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: reminder.isCompleted ? Colors.green : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        color: reminder.isCompleted ? Colors.grey : RemindersColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.toggleBigRock(reminder.id),
                    child: Icon(
                      reminder.isBigRock ? Icons.star : Icons.star_border,
                      size: 14,
                      color: reminder.isBigRock ? const Color(0xFFD97706) : Colors.grey.shade300,
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
                  if (role != null)
                    Icon(role.iconData, size: 10, color: role.color),
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
                  else
                    Text(
                      '~${reminder.estimatedDurationMinutes}m',
                      style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400),
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
