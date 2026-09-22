import 'package:flutter/material.dart';
import '../theme/reminders_colors.dart';
import 'role_manager_dialog.dart';
import 'sunday_planning_wizard_dialog.dart';

class CoveyGuideDialog extends StatefulWidget {
  const CoveyGuideDialog({super.key});

  @override
  State<CoveyGuideDialog> createState() => _CoveyGuideDialogState();
}

class _CoveyGuideDialogState extends State<CoveyGuideDialog> {
  int _currentStep = 0;

  final List<_GuideStepData> _steps = [
    _GuideStepData(
      title: 'Roles Vitales & Brújula',
      subtitle: 'La dirección (la brújula) siempre precede a la velocidad (el reloj)',
      icon: Icons.explore_rounded,
      color: const Color(0xFF3B82F6),
      contentBuilder: (context) => const _RolesGuideContent(),
    ),
    _GuideStepData(
      title: 'El Ritual Dominical',
      subtitle: 'El hábito sagrado semanal de planificación y conexión con tu misión',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFFD97706),
      contentBuilder: (context) => const _SundayRitualGuideContent(),
    ),
    _GuideStepData(
      title: 'Grandes Rocas vs Arena',
      subtitle: 'Coloca primero las piedras grandes en tu jarra; la arena se acomodará sola',
      icon: Icons.star_rounded,
      color: const Color(0xFF10B981),
      contentBuilder: (context) => const _BigRocksGuideContent(),
    ),
    _GuideStepData(
      title: 'Agenda Semanal Flexible',
      subtitle: 'Organización a escala semanal con Drag & Drop y Bandeja sin asignar',
      icon: Icons.calendar_view_week_rounded,
      color: const Color(0xFF6366F1),
      contentBuilder: (context) => const _WeeklyScheduleGuideContent(),
    ),
    _GuideStepData(
      title: 'La Matriz de Covey (2x2)',
      subtitle: 'El Cuadrante II (Importante, No Urgente) es el núcleo de la alta eficacia',
      icon: Icons.grid_view_rounded,
      color: const Color(0xFF059669),
      contentBuilder: (context) => const _MatrixGuideContent(),
    ),
    _GuideStepData(
      title: 'Captura NLP y Coach Ortiz',
      subtitle: 'Comandos ultrarrápidos de captura y supervisión proactiva con IA',
      icon: Icons.psychology_rounded,
      color: const Color(0xFF8B5CF6),
      contentBuilder: (context) => const _NlpAndAgentGuideContent(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeStep = _steps[_currentStep];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 860,
          maxHeight: 740,
        ),
        child: Column(
          children: [
            // ==========================================
            // HEADER PRINCIPAL
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activeStep.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(activeStep.icon, color: activeStep.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'GUÍA PASO A PASO: HÁBITO 3',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: activeStep.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Paso ${_currentStep + 1} de ${_steps.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activeStep.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: RemindersColors.textPrimary,
                          ),
                        ),
                        Text(
                          activeStep.subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    tooltip: 'Cerrar Guía',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ==========================================
            // BARRA DE PASOS HORIZONTAL
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_steps.length, (idx) {
                    final s = _steps[idx];
                    final isSelected = idx == _currentStep;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _currentStep = idx),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? s.color.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? s.color.withOpacity(0.5) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                s.icon,
                                size: 14,
                                color: isSelected ? s.color : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${idx + 1}. ${s.title.split(" ")[0]}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? s.color : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ==========================================
            // CUERPO DEL PASO ACTUAL
            // ==========================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: activeStep.contentBuilder(context),
              ),
            ),

            // ==========================================
            // BARRA INFERIOR DE NAVEGACIÓN Y ACCIONES
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Anterior', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const Spacer(),
                  // Botón de acción rápida contextual
                  if (_currentStep == 0)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(context: context, builder: (_) => const RoleManagerDialog());
                      },
                      icon: const Icon(Icons.pie_chart_outline_rounded, size: 15),
                      label: const Text('Configurar Mis Roles Vitales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else if (_currentStep == 1 || _currentStep == 2)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(context: context, builder: (_) => const SundayPlanningWizardDialog());
                      },
                      icon: const Icon(Icons.wb_sunny_rounded, size: 15),
                      label: const Text('Abrir Ritual Dominical', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (_currentStep < _steps.length - 1)
                    FilledButton.icon(
                      onPressed: () => setState(() => _currentStep++),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Siguiente Paso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: RemindersColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('¡Listo para Empezar!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder contentBuilder;

  _GuideStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.contentBuilder,
  });
}

// =============================================================================
// CONTENIDO DEL PASO 1: ROLES VITALES & BRÚJULA
// =============================================================================
class _RolesGuideContent extends StatelessWidget {
  const _RolesGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«La mayoría de los sistemas de tiempo se concentran en la velocidad: hacer las cosas más rápido (el reloj). '
              'El Hábito 3 se concentra en la dirección: asegurarte de que la escalera esté apoyada en la pared correcta (la brújula).»',
          author: 'Stephen R. Covey',
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 18),
        const Text(
          '1. ¿Qué es un Rol Vital?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'No eres solo tu trabajo o tus estudios. Una vida plena abarca múltiples dimensiones de responsabilidad y significado. '
          'Tus Roles Vitales son las facetas fundamentales en las que quieres dejar un legado y mantener un equilibrio ecológico.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 14),

        // Tarjetas de Dimensiones de Covey
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRoleCard(
                title: 'Dimensión Física',
                roleExample: 'Salud & Vitalidad',
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF10B981),
                desc: 'Ejercicio, descanso reparador, nutrición y prevención médica.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRoleCard(
                title: 'Dimensión Mental',
                roleExample: 'Profesional & Aprendiz',
                icon: Icons.psychology_rounded,
                color: const Color(0xFF3B82F6),
                desc: 'Lectura, proyectos de valor, capacitación continua y foco.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRoleCard(
                title: 'Dimensión Espiritual',
                roleExample: 'Individuo / Conexión',
                icon: Icons.spa_rounded,
                color: const Color(0xFF8B5CF6),
                desc: 'Meditación, valores centrales, clarificación de visión y paz mental.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRoleCard(
                title: 'Dimensión Social/Emocional',
                roleExample: 'Familia & Relaciones',
                icon: Icons.favorite_rounded,
                color: const Color(0xFFEF4444),
                desc: 'Tiempo de calidad sin distracciones con las personas que amas.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNoticeBanner(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          title: 'Regla de Oro: Ningún rol en 0',
          desc: 'Si durante la semana tienes 0 Grandes Rocas en un rol vital, el sistema y el Agente Ortiz te mostrarán una Alerta de Desbalance. El éxito en un área nunca compensa el fracaso en tu hogar o tu salud.',
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DEL PASO 2: EL RITUAL DOMINICAL
// =============================================================================
class _SundayRitualGuideContent extends StatelessWidget {
  const _SundayRitualGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«La perspectiva semanal es el puente ideal entre el día a día caótico y los grandes objetivos a largo plazo. '
              'Planificar por semanas permite mantener el rumbo de la brújula y la flexibilidad del reloj.»',
          author: 'Stephen R. Covey',
          color: const Color(0xFFD97706),
        ),
        const SizedBox(height: 18),
        const Text(
          'El Hábito Sagrado: 20 a 30 minutos cada Domingo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'No esperes al lunes por la mañana para decidir qué harás; el lunes las urgencias ajenas ya habrán tomado el control. '
          'El Ritual Dominical es tu espacio de tranquilidad para diseñar tu semana de forma proactiva.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 14),

        _buildStepTimelineItem(
          number: '1',
          title: 'Conectar y Evaluar (Retrospectiva)',
          desc: 'Revisa tu semana anterior: ¿Qué Grandes Rocas lograste? ¿Qué imprevistos surgieron? Reflexiona sobre tu enunciado de misión personal.',
          color: const Color(0xFF3B82F6),
        ),
        _buildStepTimelineItem(
          number: '2',
          title: 'Seleccionar Grandes Rocas por Rol',
          desc: 'Para cada rol vital, pregúntate: "¿Qué es lo ÚNICO o más importante que puedo hacer esta semana para generar el mayor impacto positivo?". Elige de 1 a 3 Grandes Rocas.',
          color: const Color(0xFFD97706),
        ),
        _buildStepTimelineItem(
          number: '3',
          title: 'Agendar en Días Específicos (Reservar el Espacio)',
          desc: 'Asigna cada roca a un día concreto de la semana. Bloquea ese tiempo sagrado como si fuera una cita ineludible con un médico.',
          color: const Color(0xFF10B981),
          isLast: true,
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DEL PASO 3: GRANDES ROCAS VS ARENA
// =============================================================================
class _BigRocksGuideContent extends StatelessWidget {
  const _BigRocksGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«La clave no es priorizar lo que está en tu agenda, sino agendar tus prioridades.»',
          author: 'Stephen R. Covey',
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 18),
        const Text(
          'La Metáfora del Frasco de Cristal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, size: 36, color: Color(0xFF475569)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Si primero llenas el frasco con grava y arena (mensajes, redes sociales, llamadas irrelevantes, pedidos imprevistos), '
                  'luego no habrá espacio para las piedras grandes. '
                  'Pero si colocas las piedras grandes PRIMERO, toda la arena y la grava encontrarán su lugar alrededor.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '¿Cómo distinguir una Gran Roca de una simple tarea?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 8),
        _buildComparisonRow(
          good: 'Gran Roca (No Negociable):',
          goodExample: '«Entrenar 45 min en gimnasio», «Reunión estratégica Q3 con socio», «Cena exclusiva con mi pareja»',
          bad: 'Arena / Grava (Tareas cotidianas):',
          badExample: '«Responder 20 emails», «Comprar café», «Revisar notificaciones de Slack»',
        ),
        const SizedBox(height: 14),
        _buildNoticeBanner(
          icon: Icons.star_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          title: 'Distintivo Visual de Gran Roca',
          desc: 'En la aplicación, las Grandes Rocas tienen un fondo dorado cálido, borde ambarino y una estrella ★ distintiva. Al capturar, puedes escribir *rock* o !rock para marcarla al instante.',
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DEL PASO 4: AGENDA SEMANAL FLEXIBLE
// =============================================================================
class _WeeklyScheduleGuideContent extends StatelessWidget {
  const _WeeklyScheduleGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«Una agenda rígida se rompe ante el primer imprevisto. '
              'Un marco semanal flexible permite adaptarse a los cambios manteniendo la brújula en mente.»',
          author: 'Stephen R. Covey',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 18),
        const Text(
          'Características de la Agenda Semanal (7 Días)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 10),

        _buildFeatureExplainer(
          icon: Icons.touch_app_rounded,
          title: 'Drag & Drop Interactivo entre Días',
          desc: '¿Tuvo tu hijo una urgencia el martes? No hay problema: simplemente arrastra la Gran Roca al miércoles o jueves. El sistema actualiza el día agendado de forma inmediata.',
        ),
        const SizedBox(height: 10),
        _buildFeatureExplainer(
          icon: Icons.inbox_rounded,
          title: 'Bandeja Semanal Sin Asignar (Drawer Inferior)',
          desc: 'Si capturas una tarea durante la semana y aún no sabes qué día realizarla, se guarda en la Bandeja Semanal. Desde allí, puedes arrastrarla al día que consideres más conveniente.',
        ),
        const SizedBox(height: 10),
        _buildFeatureExplainer(
          icon: Icons.explore_rounded,
          title: 'Sidebar de Brújula Siempre Visible',
          desc: 'A la izquierda de tu pantalla de escritorio tienes siempre visibles tus roles, tu misión y el conteo de rocas. Así nunca perderás de vista tus verdaderas prioridades.',
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DEL PASO 5: LA MATRIZ DE COVEY (2x2)
// =============================================================================
class _MatrixGuideContent extends StatelessWidget {
  const _MatrixGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«Lo que es importante rara vez es urgente, y lo que es urgente rara vez es importante.»',
          author: 'Dwight D. Eisenhower (Popularizado por Stephen Covey)',
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 18),
        const Text(
          'Los 4 Cuadrantes del Tiempo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 10),

        // Grid 2x2 visual
        Row(
          children: [
            Expanded(
              child: _buildQuadrantCard(
                code: 'C1',
                title: 'CRISIS',
                subtitle: 'Urgente & Importante',
                desc: 'Problemas apremiantes, fechas límite inminentes, emergencias. Debes resolverlo, pero vivir aquí genera agotamiento y estrés continuo.',
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuadrantCard(
                code: 'C2 ★',
                title: 'EFICACIA & LIDERAZGO',
                subtitle: 'Importante, NO Urgente',
                desc: 'Prevención, salud, construcción de relaciones, planificación, aprendizaje. ¡El cuadrante donde ocurre el crecimiento real! Apunta a tener >60% aquí.',
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                isHighlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuadrantCard(
                code: 'C3',
                title: 'EL ENGAÑO',
                subtitle: 'Urgente, NO Importante',
                desc: 'Interrupciones, llamadas innecesarias, urgencias de otras personas. Parece importante porque es urgente, pero no contribuye a tu misión. Aprende a decir NO.',
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuadrantCard(
                code: 'C4',
                title: 'DESPERDICIO',
                subtitle: 'Ni Urgente ni Importante',
                desc: 'Procrastinación, scroll infinito, televisión pasiva sin propósito, actividades de escape. Minimizalo o elimínalo de tu vida.',
                color: const Color(0xFF64748B),
                bgColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildNoticeBanner(
          icon: Icons.bolt_rounded,
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFECFDF5),
          title: 'Medidor de Enfoque en C2',
          desc: 'En la vista de Matriz 2x2 encontrarás una barra superior que calcula en tiempo real qué porcentaje de tus tareas pertenece al Cuadrante II. La meta es superar el 60% para lograr alta eficacia.',
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DEL PASO 6: CAPTURA RÁPIDA NLP Y COACH ORTIZ
// =============================================================================
class _NlpAndAgentGuideContent extends StatelessWidget {
  const _NlpAndAgentGuideContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightQuote(
          quote: '«Capturar tus ideas y prioridades en segundos libera tu mente para pensar, crear y actuar con intención.»',
          author: 'Filosofía Super-App Jottache',
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 18),
        const Text(
          '1. Atajos de Captura Ultrarrápida (NLP)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Escribe en lenguaje natural en la barra superior. El motor extraerá automáticamente cuadrantes, roles, rocas y fechas:',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),

        _buildNlpCheatSheetItem(
          code: '!c1, !c2, !c3, !c4',
          label: 'Asigna el Cuadrante de Covey',
          example: 'Planificar menú saludable !c2',
        ),
        _buildNlpCheatSheetItem(
          code: '*rock*, !rock, !piedra',
          label: 'Marca como Gran Roca Semanal',
          example: 'Terminar arquitectura de software *rock* !c2',
        ),
        _buildNlpCheatSheetItem(
          code: '@NombreDelRol',
          label: 'Asigna a un Rol Vital',
          example: 'Cena con María @Familia mañana a las 8pm',
        ),
        _buildNlpCheatSheetItem(
          code: '~30m, ~45m, ~1h, ~2h',
          label: 'Establece Duración Estimada',
          example: 'Lectura libro Hábito 3 ~45m',
        ),

        const SizedBox(height: 18),
        const Text(
          '2. El Agente Ortiz como tu Coach del Hábito 3',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RemindersColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'En el chat de la super-app, el Agente Ortiz tiene acceso a tu brújula semanal y cronograma en tiempo real:',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),

        _buildFeatureExplainer(
          icon: Icons.question_answer_rounded,
          title: 'Consultas inteligentes',
          desc: 'Pregúntale: "¿Cómo está mi balance de roles esta semana?", "¿Tengo algún rol descuidado?" o "¿Qué Grandes Rocas tengo programadas para mañana?".',
        ),
        const SizedBox(height: 8),
        _buildFeatureExplainer(
          icon: Icons.flash_on_rounded,
          title: 'Propuesta de Rocas en 1 Toque',
          desc: 'Ortiz puede redactar y sugerirte agendar una Gran Roca con su duración, cuadrante y rol. Te mostrará una tarjeta de propuesta que confirmas con un solo toque.',
        ),
      ],
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

Widget _buildHighlightQuote({
  required String quote,
  required String author,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quote,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade800,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '— $author',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildRoleCard({
  required String title,
  required String roleExample,
  required IconData icon,
  required Color color,
  required String desc,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Ej: $roleExample',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.25),
        ),
      ],
    ),
  );
}

Widget _buildNoticeBanner({
  required IconData icon,
  required Color color,
  required Color bgColor,
  required String title,
  required String desc,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildStepTimelineItem({
  required String number,
  required String title,
  required String desc,
  required Color color,
  bool isLast = false,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 48,
              color: Colors.grey.shade300,
            ),
        ],
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: RemindersColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildComparisonRow({
  required String good,
  required String goodExample,
  required String bad,
  required String badExample,
}) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                  children: [
                    TextSpan(text: '$good ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: goodExample),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
                  children: [
                    TextSpan(text: '$bad ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: badExample),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildFeatureExplainer({
  required IconData icon,
  required String title,
  required String desc,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildQuadrantCard({
  required String code,
  required String title,
  required String subtitle,
  required String desc,
  required Color color,
  required Color bgColor,
  bool isHighlight = false,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isHighlight ? color : color.withOpacity(0.3),
        width: isHighlight ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            if (isHighlight)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FOCO PRINCIPAL',
                  style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.25),
        ),
      ],
    ),
  );
}

Widget _buildNlpCheatSheetItem({
  required String code,
  required String label,
  required String example,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D28D9),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Ejemplo: "$example"',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
