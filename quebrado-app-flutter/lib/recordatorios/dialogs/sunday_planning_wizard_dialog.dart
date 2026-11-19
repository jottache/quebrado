import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class SundayPlanningWizardDialog extends StatefulWidget {
  const SundayPlanningWizardDialog({super.key});

  @override
  State<SundayPlanningWizardDialog> createState() => _SundayPlanningWizardDialogState();
}

class _SundayPlanningWizardDialogState extends State<SundayPlanningWizardDialog> {
  final _uuid = const Uuid();
  int _currentStep = 0; // 0: Retrospectiva, 1: Grandes Rocas, 2: Agendar la semana
  late TextEditingController _notesCtrl;

  // Mapa temporal de nuevas Grandes Rocas agregadas durante el ritual: roleId -> lista de títulos
  final Map<String, List<String>> _newRocksPerRole = {};
  // Mapa de asignación de día para las grandes rocas: rockTitle -> dayOfWeek (0..6)
  final Map<String, int> _rockScheduledDay = {};

  final List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  @override
  void initState() {
    super.initState();
    final state = Provider.of<RemindersState>(context, listen: false);
    _notesCtrl = TextEditingController(text: state.currentWeeklyPlan?.reflectionNotes ?? '');
    // El sábado y el domingo se planifica la semana siguiente.
    WidgetsBinding.instance.addPostFrameCallback((_) => _changeWeek(state.suggestedPlanningMonday));
  }

  Future<void> _changeWeek(DateTime monday) async {
    final state = Provider.of<RemindersState>(context, listen: false);
    await state.selectWeek(monday);
    if (mounted) _notesCtrl.text = state.currentWeeklyPlan?.reflectionNotes ?? '';
  }

  static String _formatShort(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

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

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addRockToRole(String roleId, String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      _newRocksPerRole.putIfAbsent(roleId, () => []);
      _newRocksPerRole[roleId]!.add(title.trim());
      // Por defecto, el primer día de la semana planificada que aún no pasó.
      _rockScheduledDay[title.trim()] = _firstUpcomingDayIndex();
    });
  }

  int _firstUpcomingDayIndex() {
    final monday = Provider.of<RemindersState>(context, listen: false).currentMonday;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 7; i++) {
      if (!DateTime(monday.year, monday.month, monday.day + i).isBefore(today)) return i;
    }
    return 0;
  }

  void _removeRock(String roleId, String title) {
    setState(() {
      _newRocksPerRole[roleId]?.remove(title);
      _rockScheduledDay.remove(title);
    });
  }

  Future<void> _completeWizard() async {
    final state = Provider.of<RemindersState>(context, listen: false);
    var failed = 0;

    // 1. Guardar notas de retrospectiva
    await state.saveWeeklyPlanNotes(_notesCtrl.text.trim());

    // 2. Crear y guardar cada una de las Grandes Rocas definidas
    for (final entry in _newRocksPerRole.entries) {
      final roleId = entry.key;
      for (final title in entry.value) {
        final dayIndex = _rockScheduledDay[title] ?? 0;
        final monday = state.currentMonday;
        final scheduledDate = DateTime(
          monday.year,
          monday.month,
          monday.day + dayIndex,
          9,
          0,
        );

        final rock = ReminderModel(
          id: _uuid.v4(),
          title: title,
          notes: 'Gran Roca definida durante el Ritual Dominical de Planificación',
          priority: ReminderPriority.p1Urgent,
          status: ReminderStatus.pending,
          dueAt: scheduledDate,
          roleId: roleId,
          weeklyPlanId: state.currentWeeklyPlan?.id,
          quadrant: CoveyQuadrant.q2ImportantNotUrgent,
          isBigRock: true,
          scheduledDayOfWeek: dayIndex,
          estimatedDurationMinutes: 60,
          tags: ['gran-roca', 'q2', 'ritual-dominical'],
        );

        if (!await state.saveReminder(rock)) failed++;
      }
    }

    if (mounted) {
      final monday = state.currentMonday;
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(failed == 0
              ? '🎯 Semana del ${_formatShort(monday)} al ${_formatShort(sunday)} planificada con éxito.'
              : '⚠️ $failed ${failed == 1 ? "Gran Roca no se pudo" : "Grandes Rocas no se pudieron"} guardar en la nube. Revisa tu conexión y vuelve a intentarlo.'),
          backgroundColor: failed == 0 ? RemindersColors.completed : OrtizPalette.warn,
          duration: Duration(seconds: failed == 0 ? 4 : 8),
        ),
      );
    }
  }

  /// Selector de la semana que se está planificando.
  Widget _buildWeekSelector(RemindersState state) {
    final monday = state.currentMonday;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final offset = state.selectedWeekOffset;
    final thisMonday = RemindersState.thisWeekMonday();
    final nextMonday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day + 7);

    Widget quickChip(String label, DateTime target, int targetOffset) {
      final selected = offset == targetOffset;
      return ChoiceChip(
        key: ValueKey('wizard_week_chip_$targetOffset'),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => _changeWeek(target),
        selectedColor: OrtizPalette.warnTint,
        labelStyle: TextStyle(
          fontSize: OrtizFontSize.bodySm,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? OrtizPalette.warn : RemindersColors.textPrimary,
        ),
        side: BorderSide(color: selected ? OrtizPalette.warn : RemindersColors.cardBorder),
        visualDensity: VisualDensity.compact,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
      decoration: BoxDecoration(
        color: OrtizPalette.warnTint,
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        border: Border.all(color: OrtizPalette.warnBorder),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _changeWeek(DateTime(monday.year, monday.month, monday.day - 7)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Planificando: ${_formatShort(monday)} – ${_formatShort(sunday)}',
                    key: const ValueKey('wizard_week_range'),
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: OrtizPalette.warn),
                  ),
                  Text(
                    _weekRelativeLabel(offset),
                    style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.warn),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _changeWeek(DateTime(monday.year, monday.month, monday.day + 7)),
              ),
              if (state.isLoadingWeek)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          quickChip('Esta semana', thisMonday, 0),
          quickChip('Próxima semana', nextMonday, 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final roles = state.roles;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con Progreso de 3 Pasos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: OrtizPalette.warnTint,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        child: const Icon(Icons.wb_sunny_outlined, color: OrtizPalette.warn),
                      ),
                      const SizedBox(width: OrtizSpace.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ritual Dominical de Planificación',
                            style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                          ),
                          const Text(
                            'Hábito 3: "Primero lo Primero"',
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.sm),
              _buildWeekSelector(state),
              const SizedBox(height: OrtizSpace.md),

              // Barra de Pasos Visual
              Row(
                children: [
                  Flexible(flex: 3, child: _buildStepIndicator(0, '1. Retrospectiva', Icons.rate_review_outlined)),
                  const Expanded(child: Divider(thickness: 1.5, indent: 8, endIndent: 8)),
                  Flexible(flex: 3, child: _buildStepIndicator(1, '2. Grandes Rocas', Icons.star_outline)),
                  const Expanded(child: Divider(thickness: 1.5, indent: 8, endIndent: 8)),
                  Flexible(flex: 3, child: _buildStepIndicator(2, '3. Agendar la Semana', Icons.calendar_month_outlined)),
                ],
              ),
              const SizedBox(height: OrtizSpace.xl),

              // Contenido según el paso actual
              Expanded(
                child: _buildCurrentStepContent(state, roles),
              ),

              const SizedBox(height: OrtizSpace.lg),
              // Botones de Navegación Inferior
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Anterior'),
                    )
                  else
                    const SizedBox.shrink(),
                  if (_currentStep < 2)
                    FilledButton(
                      onPressed: () => setState(() => _currentStep++),
                      child: const Text('Siguiente Paso'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: RemindersColors.completed),
                      onPressed: _completeWizard,
                      icon: const Icon(Icons.check_circle_outline, size: OrtizIconSize.md),
                      label: const Text('¡Semana Planificada con Éxito!'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return InkWell(
      onTap: () => setState(() => _currentStep = stepIndex),
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(OrtizSpace.xs),
              decoration: BoxDecoration(
                color: isDone
                    ? OrtizPalette.surfaceHigh
                    : isActive
                        ? RemindersColors.primaryLight
                        : OrtizPalette.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check : icon,
                size: OrtizIconSize.sm,
                color: isDone
                    ? OrtizPalette.ok
                    : isActive
                        ? RemindersColors.primary
                        : RemindersColors.textSecondary,
              ),
            ),
            const SizedBox(width: OrtizSpace.xs),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? RemindersColors.textPrimary : RemindersColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(RemindersState state, List<RoleModel> roles) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Retrospective(roles);
      case 1:
        return _buildStep2BigRocks(state, roles);
      case 2:
        return _buildStep3Schedule(roles);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // PASO 1: RETROSPECTIVA Y MISIÓN
  // ==========================================
  Widget _buildStep1Retrospective(List<RoleModel> roles) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(OrtizSpace.md),
            decoration: BoxDecoration(
              color: OrtizPalette.surfaceHigh,
              borderRadius: BorderRadius.circular(OrtizRadius.field),
              border: Border.all(color: RemindersColors.cardBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book, color: RemindersColors.primary, size: OrtizIconSize.lg),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso 1: Revisa tu Misión y los Logros de la Semana Pasada',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body, color: RemindersColors.textPrimary),
                      ),
                      SizedBox(height: OrtizSpace.xs),
                      Text(
                        'Antes de escribir nuevas tareas, conecta con tus principios fundamentales. Evalúa con sinceridad cómo atendiste cada dimensión de tu vida.',
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrtizSpace.lg),
          const Text(
            'Declaración de Propósito de tus Roles Activos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm, color: RemindersColors.textPrimary),
          ),
          const SizedBox(height: OrtizSpace.sm),
          ...roles.map((r) => Container(
                margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
                padding: const EdgeInsets.all(OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  border: Border.all(color: RemindersColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(r.iconData, color: r.color, size: OrtizIconSize.md),
                    const SizedBox(width: OrtizSpace.sm),
                    Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                    ),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: Text(
                        r.purposeStatement ?? 'Sin declaración de propósito configurada aún',
                        style: TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: r.purposeStatement != null ? RemindersColors.textSecondary : RemindersColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: OrtizSpace.lg),
          const Text(
            'Notas de Retrospectiva Semanal:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm, color: RemindersColors.textPrimary),
          ),
          const SizedBox(height: OrtizSpace.xs),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '¿Qué salió bien esta semana? ¿Qué imprevistos del C3 o C4 me distrajeron? ¿Qué debo afilar para la próxima semana?...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              contentPadding: const EdgeInsets.all(OrtizSpace.md),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PASO 2: DEFINIR GRANDES ROCAS (BIG ROCKS)
  // ==========================================
  Widget _buildStep2BigRocks(RemindersState state, List<RoleModel> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(OrtizSpace.md),
          decoration: BoxDecoration(
            color: OrtizPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            border: Border.all(color: RemindersColors.cardBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.flag_outlined, color: RemindersColors.completed, size: OrtizIconSize.md),
              SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  'Elige de 1 a 3 Grandes Rocas para CADA rol. Son las metas de alto impacto que harán que esta semana sea verdaderamente efectiva.',
                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.fg, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OrtizSpace.md),
        Expanded(
          child: ListView.separated(
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: OrtizSpace.md),
            itemBuilder: (context, idx) {
              final role = roles[idx];
              final existingRocks = state.bigRocksForRole(role.id);
              final newRocks = _newRocksPerRole[role.id] ?? [];
              final totalRocks = existingRocks.length + newRocks.length;
              final isUnderAllocated = totalRocks == 0;

              final inputCtrl = TextEditingController();

              return Container(
                padding: const EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                  border: Border.all(
                    color: isUnderAllocated ? OrtizPalette.warnBorder : RemindersColors.cardBorder,
                    width: isUnderAllocated ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(role.iconData, color: role.color, size: OrtizIconSize.md),
                            const SizedBox(width: OrtizSpace.sm),
                            Text(
                              role.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: isUnderAllocated ? OrtizPalette.warnTint : OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            border: Border.all(
                              color: isUnderAllocated ? OrtizPalette.warnBorder : OrtizPalette.ok,
                            ),
                          ),
                          child: Text(
                            '$totalRocks / 3 Rocas',
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.bold,
                              color: isUnderAllocated ? OrtizPalette.warn : OrtizPalette.ok,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isUnderAllocated)
                      Padding(
                        padding: const EdgeInsets.only(top: OrtizSpace.xs, bottom: OrtizSpace.xs),
                        child: Text(
                          '⚠️ Atención: Este rol no tiene ninguna Gran Roca definida para la semana.',
                          style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.warn, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: OrtizSpace.sm),

                    // Rocas ya existentes en la app
                    ...existingRocks.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: OrtizSpace.xs),
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                          decoration: BoxDecoration(
                            color: OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            border: Border.all(color: RemindersColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: OrtizIconSize.sm, color: OrtizPalette.warn),
                              const SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Text(r.title, style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600)),
                              ),
                              const Text('(Ya agendada)', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted)),
                            ],
                          ),
                        )),

                    // Nuevas rocas agregadas en el ritual
                    ...newRocks.map((title) => Container(
                          margin: const EdgeInsets.only(bottom: OrtizSpace.xs),
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                          decoration: BoxDecoration(
                            color: OrtizPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            border: Border.all(color: RemindersColors.primaryBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_outline, size: OrtizIconSize.sm, color: RemindersColors.primary),
                              const SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: Text(title, style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: OrtizIconSize.sm, color: RemindersColors.overdue),
                                onPressed: () => _removeRock(role.id, title),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        )),

                    // Campo de entrada rápida de nueva Gran Roca
                    if (totalRocks < 3)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: inputCtrl,
                              decoration: InputDecoration(
                                hintText: 'Escribe una Gran Roca para ${role.name}...',
                                hintStyle: const TextStyle(fontSize: OrtizFontSize.bodySm),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                              ),
                              onSubmitted: (val) {
                                _addRockToRole(role.id, val);
                                inputCtrl.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: RemindersColors.primary),
                            onPressed: () {
                              _addRockToRole(role.id, inputCtrl.text);
                              inputCtrl.clear();
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PASO 3: AGENDAR PRIMERO LAS ROCAS
  // ==========================================
  Widget _buildStep3Schedule(List<RoleModel> roles) {
    final monday = Provider.of<RemindersState>(context).currentMonday;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Lista plana de todas las nuevas rocas para asignar a días
    final List<MapEntry<String, String>> rocksWithRole = [];
    for (final entry in _newRocksPerRole.entries) {
      for (final rockTitle in entry.value) {
        rocksWithRole.add(MapEntry(entry.key, rockTitle));
      }
    }

    if (rocksWithRole.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: OrtizIconSize.xxl, color: RemindersColors.completed),
            const SizedBox(height: OrtizSpace.md),
            const Text(
              'No agregaste nuevas Grandes Rocas.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
            ),
            const SizedBox(height: OrtizSpace.xs),
            const Text(
              'Tus Grandes Rocas existentes ya están en el cronograma semanal.',
              style: TextStyle(color: RemindersColors.textMuted, fontSize: OrtizFontSize.bodySm),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(OrtizSpace.md),
          decoration: BoxDecoration(
            color: RemindersColors.primaryLight,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            border: Border.all(color: RemindersColors.primaryBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_available, color: RemindersColors.primary, size: OrtizIconSize.md),
              SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  'Coloca las Grandes Rocas PRIMERO en el calendario semanal. Si dejas que el día a día empiece sin agendarlas, la arena (urgencias del C3 y C4) ocupará todo tu tiempo.',
                  style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.fg, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OrtizSpace.md),
        Expanded(
          child: ListView.separated(
            itemCount: rocksWithRole.length,
            separatorBuilder: (_, __) => const SizedBox(height: OrtizSpace.sm),
            itemBuilder: (context, i) {
              final roleId = rocksWithRole[i].key;
              final rockTitle = rocksWithRole[i].value;
              final role = roles.firstWhere((r) => r.id == roleId, orElse: () => roles.first);
              final currentDay = _rockScheduledDay[rockTitle] ?? 0;

              return Container(
                padding: const EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  border: Border.all(color: RemindersColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(role.iconData, color: role.color, size: OrtizIconSize.md),
                    const SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rockTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
                          Text('Rol: ${role.name}', style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: OrtizSpace.md),
                    DropdownButton<int>(
                      value: currentDay,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      items: List.generate(7, (dayIdx) {
                        final date = DateTime(monday.year, monday.month, monday.day + dayIdx);
                        final isPast = date.isBefore(today);
                        return DropdownMenuItem<int>(
                          value: dayIdx,
                          child: Text(
                            '${_dayNames[dayIdx]} ${_formatShort(date)}${isPast ? " · ya pasó" : ""}',
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.w600,
                              color: isPast ? RemindersColors.textMuted : null,
                            ),
                          ),
                        );
                      }),
                      onChanged: (newDay) {
                        if (newDay != null) {
                          setState(() {
                            _rockScheduledDay[rockTitle] = newDay;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
