import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/covey_quadrant.dart';
import '../models/reminder_model.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

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

  @override
  void initState() {
    super.initState();
    final state = Provider.of<RemindersState>(context, listen: false);
    _notesCtrl = TextEditingController(text: state.currentWeeklyPlan?.reflectionNotes ?? '');
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
      // Asignar por defecto a lunes o martes
      _rockScheduledDay[title.trim()] = 0;
    });
  }

  void _removeRock(String roleId, String title) {
    setState(() {
      _newRocksPerRole[roleId]?.remove(title);
      _rockScheduledDay.remove(title);
    });
  }

  Future<void> _completeWizard() async {
    final state = Provider.of<RemindersState>(context, listen: false);

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

        await state.saveReminder(rock);
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎯 ¡Semana planificada con éxito bajo los principios de Stephen Covey!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final roles = state.roles;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ritual Dominical de Planificación',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                          ),
                          Text(
                            'Hábito 3: "Primero lo Primero" - Semana ${state.currentWeeklyPlan?.formattedRange ?? ""}',
                            style: const TextStyle(fontSize: 12, color: RemindersColors.textMuted),
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
              const SizedBox(height: 16),

              // Barra de Pasos Visual
              Row(
                children: [
                  _buildStepIndicator(0, '1. Retrospectiva', Icons.rate_review_outlined),
                  const Expanded(child: Divider(thickness: 1.5, indent: 8, endIndent: 8)),
                  _buildStepIndicator(1, '2. Grandes Rocas', Icons.star_outline),
                  const Expanded(child: Divider(thickness: 1.5, indent: 8, endIndent: 8)),
                  _buildStepIndicator(2, '3. Agendar la Semana', Icons.calendar_month_outlined),
                ],
              ),
              const SizedBox(height: 20),

              // Contenido según el paso actual
              Expanded(
                child: _buildCurrentStepContent(state, roles),
              ),

              const SizedBox(height: 16),
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
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      onPressed: _completeWizard,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green.shade100
                    : isActive
                        ? RemindersColors.primaryLight
                        : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check : icon,
                size: 16,
                color: isDone
                    ? Colors.green.shade800
                    : isActive
                        ? RemindersColors.primary
                        : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? RemindersColors.textPrimary : RemindersColors.textMuted,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book, color: RemindersColors.primary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso 1: Revisa tu Misión y los Logros de la Semana Pasada',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RemindersColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Antes de escribir nuevas tareas, conecta con tus principios fundamentales. Evalúa con sinceridad cómo atendiste cada dimensión de tu vida.',
                        style: TextStyle(fontSize: 12, color: RemindersColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Declaración de Propósito de tus Roles Activos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RemindersColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...roles.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(r.iconData, color: r.color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.purposeStatement ?? 'Sin declaración de propósito configurada aún',
                        style: TextStyle(
                          fontSize: 12,
                          color: r.purposeStatement != null ? Colors.grey.shade700 : Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          const Text(
            'Notas de Retrospectiva Semanal:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RemindersColors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '¿Qué salió bien esta semana? ¿Qué imprevistos del C3 o C4 me distrajeron? ¿Qué debo afilar para la próxima semana?...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Color(0xFF059669), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Elige de 1 a 3 Grandes Rocas para CADA rol. Son las metas de alto impacto que harán que esta semana sea verdaderamente efectiva.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final role = roles[idx];
              final existingRocks = state.bigRocksForRole(role.id);
              final newRocks = _newRocksPerRole[role.id] ?? [];
              final totalRocks = existingRocks.length + newRocks.length;
              final isUnderAllocated = totalRocks == 0;

              final inputCtrl = TextEditingController();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnderAllocated ? Colors.amber.shade300 : Colors.grey.shade200,
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
                            Icon(role.iconData, color: role.color, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              role.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUnderAllocated ? Colors.amber.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUnderAllocated ? Colors.amber.shade400 : Colors.green.shade400,
                            ),
                          ),
                          child: Text(
                            '$totalRocks / 3 Rocas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isUnderAllocated ? Colors.amber.shade900 : Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isUnderAllocated)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          '⚠️ Atención: Este rol no tiene ninguna Gran Roca definida para la semana.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Rocas ya existentes en la app
                    ...existingRocks.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              const Text('(Ya agendada)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        )),

                    // Nuevas rocas agregadas en el ritual
                    ...newRocks.map((title) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_outline, size: 16, color: RemindersColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
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
                                hintStyle: const TextStyle(fontSize: 12),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (val) {
                                _addRockToRole(role.id, val);
                                inputCtrl.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
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
            const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'No agregaste nuevas Grandes Rocas.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tus Grandes Rocas existentes ya están en el cronograma semanal.',
              style: TextStyle(color: RemindersColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_available, color: Color(0xFF7C3AED), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Coloca las Grandes Rocas PRIMERO en el calendario semanal. Si dejas que el día a día empiece sin agendarlas, la arena (urgencias del C3 y C4) ocupará todo tu tiempo.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: rocksWithRole.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final roleId = rocksWithRole[i].key;
              final rockTitle = rocksWithRole[i].value;
              final role = roles.firstWhere((r) => r.id == roleId, orElse: () => roles.first);
              final currentDay = _rockScheduledDay[rockTitle] ?? 0;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(role.iconData, color: role.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rockTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Rol: ${role.name}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: currentDay,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(8),
                      items: List.generate(7, (dayIdx) {
                        return DropdownMenuItem<int>(
                          value: dayIdx,
                          child: Text(
                            _dayNames[dayIdx],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
