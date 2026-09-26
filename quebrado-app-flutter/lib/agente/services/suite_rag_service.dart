import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../diario/diario.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../../recordatorios/models/reminder_model.dart';
import '../../recordatorios/models/role_model.dart';
import '../models/chat_artifact_model.dart';

class ToolExecutionResult {
  final Map<String, dynamic> resultData;
  final ChatArtifactModel? generatedArtifact;

  ToolExecutionResult({
    required this.resultData,
    this.generatedArtifact,
  });
}

class SuiteRagService {
  final AppState appState;
  final DiarioState diarioState;
  final HabitosState habitosState;
  final RemindersState remindersState;

  SuiteRagService({
    required this.appState,
    required this.diarioState,
    required this.habitosState,
    required this.remindersState,
  });

  /// Genera un resumen contextual vivo de la suite para alimentar las System Instructions
  String generateLiveContextSnapshot() {
    final now = DateTime.now();
    final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final dateStr = '${weekDays[now.weekday - 1]} ${now.day} de ${months[now.month - 1]} de ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final totalUsd = appState.totalBalanceUSD;
    final totalBs = totalUsd * appState.bcvRate;
    final bcv = appState.bcvRate;
    final euro = appState.euroRate;

    final contactsCount = diarioState.contacts.length;
    final personalNotesCount = diarioState.personalEntries.length;
    final upcomingBirthdays = diarioState.getUpcomingBirthdays(limit: 3);

    final habitsRate = (habitosState.todayCompletionRate * 100).round();
    final habitStreak = habitosState.bestCurrentStreak;

    final overdueReminders = remindersState.overdueCount;
    final todayReminders = remindersState.todayCount;
    final weekPlan = remindersState.currentWeeklyPlan;
    final weekRange = weekPlan?.formattedRange ?? 'Semana en curso';
    final rolesList = remindersState.roles;
    final unaddressed = remindersState.unaddressedRoles;
    final q1Count = remindersState.q1Count;
    final q2Count = remindersState.q2Count;
    final q3Count = remindersState.q3Count;
    final q4Count = remindersState.q4Count;
    final q2Focus = remindersState.q2FocusPercentage;
    final bigRocks = remindersState.bigRocksForCurrentWeek;
    final bigRocksDone = bigRocks.where((r) => r.isCompleted).length;

    final rolesSummary = rolesList.isEmpty
        ? '    · Sin roles configurados'
        : rolesList.map((r) {
            final rockCount = remindersState.countBigRocksForRole(r.id);
            return '    · ${r.name}: $rockCount Grandes Rocas definidas';
          }).join('\n');

    final unaddressedAlert = unaddressed.isNotEmpty
        ? '⚠️ ALERTA DE EQUILIBRIO VITAL: Hay ${unaddressed.length} roles vitales sin ninguna Gran Roca esta semana (${unaddressed.map((r) => r.name).join(", ")}).'
        : '✅ Equilibrio de vida óptimo: Todos los roles vitales tienen al menos una Gran Roca definida.';

    final bdaysStr = upcomingBirthdays.isEmpty
        ? 'No hay cumpleaños próximos registrados.'
        : upcomingBirthdays.map((b) {
            int? nextAge;
            if (b.birthdate != null) {
              final nowYear = now.year;
              int age = nowYear - b.birthdate!.year;
              final bdayThisYear = DateTime(nowYear, b.birthdate!.month, b.birthdate!.day);
              if (now.isAfter(bdayThisYear)) age += 1;
              nextAge = age;
            }
            final ageStr = nextAge != null ? ', cumplirá $nextAge años' : '';
            return '- ${b.name}: ${b.formattedBirthdate ?? "Sin fecha"} (en ${b.daysUntilBirthday ?? "?"} días$ageStr)';
          }).join('\n');

    return '''
### INFORMACIÓN EN TIEMPO REAL DEL USUARIO (ORTIZAPP SUITE):
- Fecha y hora actual del sistema: $dateStr
- Usuario: José Ortiz (Jottache)
- Contexto monetario: Venezuela (Tasas oficiales: Dólar BCV = Bs. ${bcv.toStringAsFixed(2)}, Euro = Bs. ${euro.toStringAsFixed(2)})
- Finanzas (Quebrado):
  * Balance total estimado: \$${totalUsd.toStringAsFixed(2)} USD / Bs. ${totalBs.toStringAsFixed(2)}
  * Cuentas activas: ${appState.accounts.length}
  * Pagos pendientes hoy: ${appState.pendingPaymentsToday.length}
- Contactos y Diario (Diario Jottache):
  * Total de contactos guardados: $contactsCount
  * Total de notas personales registradas: $personalNotesCount
  * Próximos cumpleaños:
$bdaysStr
- Hábitos y Rutinas:
  * Progreso de hábitos hoy: $habitsRate%
  * Mejor racha actual: $habitStreak días
- Agenda y Planificación Semanal (Stephen Covey - Hábito 3: "Primero lo Primero"):
  * Plan Semanal Activo: $weekRange
  * Foco en Cuadrante II (Eficacia y Prevención): ${q2Focus.toStringAsFixed(0)}% (C1 Crisis: $q1Count, C2 Eficacia: $q2Count, C3 Engaño: $q3Count, C4 Desperdicio: $q4Count)
  * Progreso de Grandes Rocas: $bigRocksDone / ${bigRocks.length} completadas
  * Roles Vitales del usuario:
$rolesSummary
  * Estado de Balance: $unaddressedAlert
- Recordatorios y Tareas:
  * Recordatorios vencidos: $overdueReminders
  * Recordatorios programados para hoy: $todayReminders
''';
  }

  /// Declaraciones de herramientas (Function Declarations) para el Tool Calling de Gemini
  List<Tool> getDeclaredTools() {
    return [
      Tool(
        functionDeclarations: [
          FunctionDeclaration(
            'searchSuiteData',
            'Busca de forma global y simultánea en TODA la base de datos de la suite (Recordatorios, Notas y Contactos de Diario, Cuentas y Pagos de Finanzas, y Hábitos) por palabra clave o término. Úsala siempre primero cuando la pregunta sea abierta o no sepas exactamente en qué módulo está la información.',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Término a buscar en toda la base de datos (ej: "Zelda", "reunión", "pago", "placa", "auto", "médico").',
                ),
              },
              requiredProperties: ['query'],
            ),
          ),
          FunctionDeclaration(
            'searchContacts',
            'Busca en la libreta de contactos y sus registros (vehículos, placas, tallas, notas, apodos, relaciones).',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Término a buscar (ej: "Juan", "Yaku", "placa 210RD", "automóvil", "hunday", "médico").',
                ),
              },
              requiredProperties: ['query'],
            ),
          ),
          FunctionDeclaration(
            'getContactDetails',
            'Obtiene todos los datos y registros detallados de un contacto (automóviles, placas, tallas de ropa, cuentas bancarias, notas, etc.) por su nombre, apodo o ID.',
            Schema(
              SchemaType.object,
              properties: {
                'nameOrQuery': Schema(
                  SchemaType.string,
                  description: 'Nombre, apodo o ID del contacto (ej: "Yaku", "Judenys Borges", "Carlos").',
                ),
              },
              requiredProperties: ['nameOrQuery'],
            ),
          ),
          FunctionDeclaration(
            'searchDiarioEntries',
            'Busca directamente en todas las notas, registros y campos específicos del diario (útil para encontrar placas de autos, marcas, modelos, tallas, regalos o cualquier detalle).',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Texto a buscar en registros (ej: "placa", "210RD", "hunday", "stylus", "talla", "banco").',
                ),
              },
              requiredProperties: ['query'],
            ),
          ),
          FunctionDeclaration(
            'getPersonalNotes',
            'Obtiene las notas personales del usuario (reflexiones, apuntes, pensamientos o notas libres no asociadas a contactos), permitiendo filtrar por texto, tema o fecha.',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Texto o término a buscar en las notas personales (opcional).',
                ),
                'dateFilter': Schema(
                  SchemaType.string,
                  description: 'Filtro de fecha o periodo (ej: "2026-09-16", "septiembre", "hoy", "ayer", "semana") (opcional).',
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'getUpcomingBirthdays',
            'Obtiene la lista de los próximos cumpleaños ordenados por cercanía con los días restantes y la edad a cumplir.',
            Schema(
              SchemaType.object,
              properties: {
                'limit': Schema(
                  SchemaType.integer,
                  description: 'Cantidad máxima de cumpleaños a obtener (por defecto 5).',
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'getFinancialOverview',
            'Obtiene un resumen completo de las finanzas: cuentas bancarias, balances en USD y Bs, tasa BCV y pagos pendientes.',
            Schema(
              SchemaType.object,
              properties: {},
            ),
          ),
          FunctionDeclaration(
            'calculateCurrencyExchange',
            'Calcula la conversión exacta entre USD, Bolívares (VES/Bs) y Euros según la tasa oficial BCV del sistema.',
            Schema(
              SchemaType.object,
              properties: {
                'amount': Schema(SchemaType.number, description: 'Monto a convertir.'),
                'fromCurrency': Schema(SchemaType.string, description: 'Moneda origen: usd, bs, o eur.'),
                'toCurrency': Schema(SchemaType.string, description: 'Moneda destino: usd, bs, o eur.'),
              },
              requiredProperties: ['amount', 'fromCurrency', 'toCurrency'],
            ),
          ),
          FunctionDeclaration(
            'getHabitsStatus',
            'Consulta el estado de los hábitos personales de hoy, el porcentaje de cumplimiento y la mejor racha activa.',
            Schema(
              SchemaType.object,
              properties: {},
            ),
          ),
          FunctionDeclaration(
            'getReminders',
            'Consulta los recordatorios y tareas pendientes, vencidas, programadas o por búsqueda textual de título, notas o tags.',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Término opcional para buscar en títulos, notas o tags (ej: "Zelda", "reunión", "médico", "compra").',
                ),
                'filter': Schema(
                  SchemaType.string,
                  description: 'Filtro opcional: "all", "overdue", "today", o "upcoming".',
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'createReminder',
            'Crea un nuevo recordatorio o tarea en el sistema de Recordatorios.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título de la tarea o recordatorio.'),
                'priority': Schema(
                  SchemaType.string,
                  description: 'Prioridad: p1_urgent, p2_high, p3_medium, p4_low.',
                ),
                'recurrence': Schema(
                  SchemaType.string,
                  description: 'Recurrencia opcional: none, daily, weekly, biweekly, monthly, yearly.',
                ),
              },
              requiredProperties: ['title'],
            ),
          ),
          FunctionDeclaration(
            'getWeeklySchedule',
            'Obtiene el cronograma semanal completo (Lunes a Domingo) de la Agenda del Hábito 3 de Stephen Covey, detallando las actividades y Grandes Rocas asignadas por día, y las tareas pendientes en la bandeja semanal.',
            Schema(
              SchemaType.object,
              properties: {
                'dayOfWeek': Schema(
                  SchemaType.string,
                  description: 'Filtro opcional por día específico: "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo", o "hoy". Si se omite, retorna toda la semana.',
                ),
                'onlyBigRocks': Schema(
                  SchemaType.boolean,
                  description: 'Si es true, solo retorna las Grandes Rocas (metas prioritarias) de la semana.',
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'getRolesCompass',
            'Obtiene la Brújula de Roles Vitales del usuario (ej: Salud, Profesional, Familia, Finanzas), sus declaraciones de propósito y las Grandes Rocas asignadas esta semana, señalando roles desatendidos con 0 rocas para preservar el equilibrio vital.',
            Schema(
              SchemaType.object,
              properties: {},
            ),
          ),
          FunctionDeclaration(
            'proposeScheduleBigRock',
            'Propone agendar una Gran Roca (meta de alto impacto del Cuadrante II) en un rol vital específico y en un día determinado de la semana, mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título o meta de la Gran Roca.'),
                'roleName': Schema(SchemaType.string, description: 'Nombre del rol vital al que pertenece (ej: "Salud", "Profesional", "Familia", "Finanzas").'),
                'dayOfWeek': Schema(SchemaType.string, description: 'Día de la semana sugerido para agendarla (ej: "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo").'),
                'estimatedDurationMinutes': Schema(SchemaType.integer, description: 'Duración estimada en minutos (por defecto 60).'),
                'notes': Schema(SchemaType.string, description: 'Notas explicativas de por qué es una Gran Roca prioritaria.'),
              },
              requiredProperties: ['title', 'roleName'],
            ),
          ),
          FunctionDeclaration(
            'proposeCreateDiarioEntry',
            'Propone registrar una nueva entrada, nota, apunte o bitácora en el Diario Jottache (asociada a un contacto o personal/general) mostrando una tarjeta interactiva con botones de Confirmar y Negar antes de guardarla. Úsala cuando el usuario diga "entrada", "nota", "anota esto", "guarda un apunte", o relate hechos, dolencias, síntomas, sucesos, gustos, medidas o comentarios sobre alguien.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título opcional de la nota o entrada. Si el usuario no proporciona un título, déjalo vacío ("") o null ya que no es obligatorio poner título a las notas.'),
                'contentText': Schema(SchemaType.string, description: 'Texto detallado o relato completo de la nota o entrada.'),
                'contactName': Schema(SchemaType.string, description: 'Nombre o apodo del contacto al que se asocia la nota si aplica (ej: "Mariana Dávila", "Carlos").'),
                'templateName': Schema(SchemaType.string, description: 'Modelo o plantilla reutilizable opcional si aplica (ej: "Automóvil / Vehículo", "Tallas de Ropa / Calzado", "Cuenta Bancaria / Pago Móvil", "Preferencia Gastronómica", "Idea de Regalo / Deseo", "Mascota de Contacto"). Si es una nota libre o relato general, dejar vacío o "Nota simple".'),
                'date': Schema(SchemaType.string, description: 'Fecha opcional del registro en formato YYYY-MM-DD (ej: "2026-09-14"). Si no se especifica, se usa la fecha de hoy.'),
                'category': Schema(SchemaType.string, description: 'Categoría interna sugerida opcional (ej: "salud", "alimentos", "regalos", "vehiculos", "general").'),
              },
              requiredProperties: ['contentText'],
            ),
          ),
          FunctionDeclaration(
            'proposeCreateContact',
            'Propone la creación de un nuevo contacto en el Diario Jottache mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo. Úsala siempre que el usuario pida agregar, registrar o crear un contacto, familiar, amigo o persona.',
            Schema(
              SchemaType.object,
              properties: {
                'name': Schema(SchemaType.string, description: 'Nombre completo o de pila del contacto.'),
                'nickname': Schema(SchemaType.string, description: 'Apodo o sobrenombre opcional.'),
                'relationship': Schema(SchemaType.string, description: 'Vínculo o relación (ej: "Hermano", "Amigo", "Compañero", "Madre").'),
                'phone': Schema(SchemaType.string, description: 'Número de teléfono o WhatsApp.'),
                'age': Schema(SchemaType.integer, description: 'Edad en años si el usuario la menciona (ej: 38).'),
                'birthdate': Schema(SchemaType.string, description: 'Fecha de nacimiento en formato YYYY-MM-DD si se conoce.'),
                'notes': Schema(SchemaType.string, description: 'Notas o detalles adicionales.'),
              },
              requiredProperties: ['name'],
            ),
          ),
          FunctionDeclaration(
            'proposeCreateReminder',
            'Propone la creación de un nuevo recordatorio o tarea en Recordatorios mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo. Úsala cuando el usuario pida crear o agendar una tarea o recordatorio.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título o concepto de la tarea/recordatorio.'),
                'priority': Schema(SchemaType.string, description: 'Prioridad: p1_urgent, p2_high, p3_medium, p4_low.'),
                'recurrence': Schema(SchemaType.string, description: 'Recurrencia opcional: none, daily, weekly, biweekly, monthly, yearly.'),
                'dueAt': Schema(SchemaType.string, description: 'Fecha y hora estimada (formato ISO 8601 ej: "2026-09-15T10:00:00").'),
                'notes': Schema(SchemaType.string, description: 'Notas o comentarios adicionales.'),
              },
              requiredProperties: ['title'],
            ),
          ),
          FunctionDeclaration(
            'proposeCreateHabit',
            'Propone la creación de un nuevo hábito o rutina personal en Hábitos mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Nombre del hábito (ej: "Meditar 10 min", "No comer azúcar").'),
                'isNegative': Schema(SchemaType.boolean, description: 'true si es un mal hábito a evitar/romper, false si es positivo para construir.'),
              },
              requiredProperties: ['title'],
            ),
          ),
          FunctionDeclaration(
            'proposeCreateTransaction',
            'Propone registrar un nuevo movimiento financiero (gasto o ingreso) en Finanzas Quebrado mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Descripción o concepto del movimiento (ej: "Almuerzo", "Cobro freelance").'),
                'amount': Schema(SchemaType.number, description: 'Monto del movimiento financiero.'),
                'type': Schema(SchemaType.string, description: 'Tipo de transacción: "expense" (gasto) o "income" (ingreso).'),
                'currency': Schema(SchemaType.string, description: 'Moneda: "usd" o "ves".'),
                'accountName': Schema(SchemaType.string, description: 'Nombre de la cuenta si se especificó (ej: "Banesco", "Zelle", "Efectivo").'),
              },
              requiredProperties: ['title', 'amount'],
            ),
          ),
        ],
      ),
    ];
  }

  /// Especificación directa en formato JSON para la API REST de Gemini (soporte thoughtSignature y role user)
  List<Map<String, dynamic>> getToolsJson() {
    return [
      {
        'functionDeclarations': [
          {
            'name': 'searchSuiteData',
            'description': 'Busca de forma global y simultánea en TODA la base de datos de la suite (Recordatorios, Notas y Contactos de Diario, Cuentas y Pagos de Finanzas, y Hábitos) por palabra clave o término. Úsala siempre primero cuando la pregunta sea abierta o no sepas exactamente en qué módulo está la información.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {
                  'type': 'STRING',
                  'description': 'Término a buscar en toda la base de datos (ej: "Zelda", "reunión", "pago", "placa", "auto", "médico").',
                },
              },
              'required': ['query'],
            },
          },
          {
            'name': 'searchContacts',
            'description': 'Busca en la libreta de contactos y sus registros (vehículos, placas, tallas, notas, apodos, relaciones).',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {
                  'type': 'STRING',
                  'description': 'Término a buscar (ej: "Juan", "Yaku", "placa 210RD", "automóvil", "hunday", "médico").',
                },
              },
              'required': ['query'],
            },
          },
          {
            'name': 'getContactDetails',
            'description': 'Obtiene todos los datos y registros detallados de un contacto (automóviles, placas, tallas de ropa, cuentas bancarias, notas, etc.) por su nombre, apodo o ID.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'nameOrQuery': {
                  'type': 'STRING',
                  'description': 'Nombre, apodo o ID del contacto (ej: "Yaku", "Judenys Borges", "Carlos").',
                },
              },
              'required': ['nameOrQuery'],
            },
          },
          {
            'name': 'searchDiarioEntries',
            'description': 'Busca directamente en todas las notas, registros y campos específicos del diario (útil para encontrar placas de autos, marcas, modelos, tallas, regalos o cualquier detalle).',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {
                  'type': 'STRING',
                  'description': 'Texto a buscar en registros (ej: "placa", "210RD", "hunday", "stylus", "talla", "banco").',
                },
              },
              'required': ['query'],
            },
          },
          {
            'name': 'getPersonalNotes',
            'description': 'Obtiene las notas personales del usuario (reflexiones, apuntes, pensamientos o notas libres no asociadas a contactos), permitiendo filtrar por texto, tema o fecha.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {
                  'type': 'STRING',
                  'description': 'Texto o término a buscar en las notas personales (opcional).',
                },
                'dateFilter': {
                  'type': 'STRING',
                  'description': 'Filtro de fecha o periodo (ej: "2026-09-16", "septiembre", "hoy", "ayer", "semana") (opcional).',
                },
              },
            },
          },
          {
            'name': 'getUpcomingBirthdays',
            'description': 'Obtiene la lista de los próximos cumpleaños ordenados por cercanía con los días restantes y la edad a cumplir.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'limit': {
                  'type': 'INTEGER',
                  'description': 'Cantidad máxima de cumpleaños a obtener (por defecto 5).',
                },
              },
            },
          },
          {
            'name': 'getFinancialOverview',
            'description': 'Obtiene un resumen completo de las finanzas: cuentas bancarias, balances en USD y Bs, tasa BCV y pagos pendientes.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {},
            },
          },
          {
            'name': 'calculateCurrencyExchange',
            'description': 'Calcula la conversión exacta entre USD, Bolívares (VES/Bs) y Euros según la tasa oficial BCV del sistema.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'amount': {'type': 'NUMBER', 'description': 'Monto a convertir.'},
                'fromCurrency': {'type': 'STRING', 'description': 'Moneda origen: usd, bs, o eur.'},
                'toCurrency': {'type': 'STRING', 'description': 'Moneda destino: usd, bs, o eur.'},
              },
              'required': ['amount', 'fromCurrency', 'toCurrency'],
            },
          },
          {
            'name': 'getHabitsStatus',
            'description': 'Consulta el estado de los hábitos personales de hoy, el porcentaje de cumplimiento y la mejor racha activa.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {},
            },
          },
          {
            'name': 'getReminders',
            'description': 'Consulta los recordatorios y tareas pendientes, vencidas, programadas o por búsqueda textual de título, notas o tags.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {
                  'type': 'STRING',
                  'description': 'Término opcional para buscar en títulos, notas o tags (ej: "Zelda", "reunión", "médico", "compra").',
                },
                'filter': {
                  'type': 'STRING',
                  'description': 'Filtro opcional: "all", "overdue", "today", o "upcoming".',
                },
              },
            },
          },
          {
            'name': 'createReminder',
            'description': 'Crea un nuevo recordatorio o tarea en el sistema de Recordatorios.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Título de la tarea o recordatorio.'},
                'priority': {
                  'type': 'STRING',
                  'description': 'Prioridad: p1_urgent, p2_high, p3_medium, p4_low.',
                },
                'recurrence': {
                  'type': 'STRING',
                  'description': 'Recurrencia opcional: none, daily, weekly, biweekly, monthly, yearly.',
                },
              },
              'required': ['title'],
            },
          },
          {
            'name': 'getWeeklySchedule',
            'description': 'Obtiene el cronograma semanal completo (Lunes a Domingo) de la Agenda del Hábito 3 de Stephen Covey, detallando las actividades y Grandes Rocas asignadas por día, y las tareas pendientes en la bandeja semanal.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'dayOfWeek': {
                  'type': 'STRING',
                  'description': 'Filtro opcional por día específico: "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo", o "hoy".',
                },
                'onlyBigRocks': {
                  'type': 'BOOLEAN',
                  'description': 'Si es true, solo retorna las Grandes Rocas de la semana.',
                },
              },
            },
          },
          {
            'name': 'getRolesCompass',
            'description': 'Obtiene la Brújula de Roles Vitales del usuario (ej: Salud, Profesional, Familia, Finanzas), sus declaraciones de propósito y las Grandes Rocas asignadas esta semana, señalando roles desatendidos con 0 rocas.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {},
            },
          },
          {
            'name': 'proposeScheduleBigRock',
            'description': 'Propone agendar una Gran Roca (meta de alto impacto del Cuadrante II) en un rol vital específico y en un día determinado de la semana, mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Título o meta de la Gran Roca.'},
                'roleName': {'type': 'STRING', 'description': 'Nombre del rol vital al que pertenece (ej: "Salud", "Profesional", "Familia", "Finanzas").'},
                'dayOfWeek': {'type': 'STRING', 'description': 'Día de la semana sugerido para agendarla (ej: "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo").'},
                'estimatedDurationMinutes': {'type': 'INTEGER', 'description': 'Duración estimada en minutos (por defecto 60).'},
                'notes': {'type': 'STRING', 'description': 'Notas explicativas de por qué es una Gran Roca prioritaria.'},
              },
              'required': ['title', 'roleName'],
            },
          },
          {
            'name': 'proposeCreateDiarioEntry',
            'description': 'Propone registrar una nueva entrada, nota, apunte o bitácora en el Diario Jottache (asociada a un contacto o personal/general) mostrando una tarjeta interactiva con botones de Confirmar y Negar antes de guardarla. Úsala cuando el usuario diga "entrada", "nota", "anota esto", "guarda un apunte", o relate hechos, dolencias, síntomas, sucesos, gustos, medidas o comentarios sobre alguien.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Título opcional de la nota o entrada. Si el usuario no dio título, dejar vacío ("") o null ya que no es obligatorio.'},
                'contentText': {'type': 'STRING', 'description': 'Texto detallado o relato completo de la nota o entrada.'},
                'contactName': {'type': 'STRING', 'description': 'Nombre o apodo del contacto al que se asocia la nota si aplica (ej: "Mariana Dávila", "Carlos").'},
                'templateName': {'type': 'STRING', 'description': 'Modelo o plantilla reutilizable opcional (ej: "Automóvil / Vehículo", "Tallas de Ropa / Calzado", "Cuenta Bancaria / Pago Móvil", "Preferencia Gastronómica", "Idea de Regalo / Deseo", "Mascota de Contacto"). Si es libre, dejar vacío o "Nota simple".'},
                'date': {'type': 'STRING', 'description': 'Fecha opcional del registro en formato YYYY-MM-DD (ej: "2026-09-14"). Si no se especifica, se usa la fecha de hoy.'},
                'category': {'type': 'STRING', 'description': 'Categoría interna sugerida opcional (ej: "salud", "alimentos", "regalos", "vehiculos", "general").'},
              },
              'required': ['contentText'],
            },
          },
          {
            'name': 'proposeCreateContact',
            'description': 'Propone la creación de un nuevo contacto en el Diario Jottache mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo. Úsala siempre que el usuario pida agregar, registrar o crear un contacto, familiar, amigo o persona.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'name': {'type': 'STRING', 'description': 'Nombre completo o de pila del contacto.'},
                'nickname': {'type': 'STRING', 'description': 'Apodo o sobrenombre opcional.'},
                'relationship': {'type': 'STRING', 'description': 'Vínculo o relación (ej: "Hermano", "Amigo", "Compañero", "Madre").'},
                'phone': {'type': 'STRING', 'description': 'Número de teléfono o WhatsApp.'},
                'age': {'type': 'INTEGER', 'description': 'Edad en años si el usuario la menciona (ej: 38).'},
                'birthdate': {'type': 'STRING', 'description': 'Fecha de nacimiento en formato YYYY-MM-DD si se conoce.'},
                'notes': {'type': 'STRING', 'description': 'Notas o detalles adicionales.'},
              },
              'required': ['name'],
            },
          },
          {
            'name': 'proposeCreateReminder',
            'description': 'Propone la creación de un nuevo recordatorio o tarea en Recordatorios mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo. Úsala cuando el usuario pida crear o agendar una tarea o recordatorio.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Título o concepto de la tarea/recordatorio.'},
                'priority': {'type': 'STRING', 'description': 'Prioridad: p1_urgent, p2_high, p3_medium, p4_low.'},
                'recurrence': {'type': 'STRING', 'description': 'Recurrencia opcional: none, daily, weekly, biweekly, monthly, yearly.'},
                'dueAt': {'type': 'STRING', 'description': 'Fecha y hora estimada (formato ISO 8601 ej: "2026-09-15T10:00:00").'},
                'notes': {'type': 'STRING', 'description': 'Notas o comentarios adicionales.'},
              },
              'required': ['title'],
            },
          },
          {
            'name': 'proposeCreateHabit',
            'description': 'Propone la creación de un nuevo hábito o rutina personal en Hábitos mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Nombre del hábito (ej: "Meditar 10 min", "No comer azúcar").'},
                'isNegative': {'type': 'BOOLEAN', 'description': 'true si es un mal hábito a evitar/romper, false si es positivo para construir.'},
              },
              'required': ['title'],
            },
          },
          {
            'name': 'proposeCreateTransaction',
            'description': 'Propone registrar un nuevo movimiento financiero (gasto o ingreso) en Finanzas Quebrado mostrando una tarjeta interactiva en el chat con botones de Confirmar y Negar antes de guardarlo.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Descripción o concepto del movimiento (ej: "Almuerzo", "Cobro freelance").'},
                'amount': {'type': 'NUMBER', 'description': 'Monto del movimiento financiero.'},
                'type': {'type': 'STRING', 'description': 'Tipo de transacción: "expense" (gasto) o "income" (ingreso).'},
                'currency': {'type': 'STRING', 'description': 'Moneda: "usd" o "ves".'},
                'accountName': {'type': 'STRING', 'description': 'Nombre de la cuenta si se especificó (ej: "Banesco", "Zelle", "Efectivo").'},
              },
              'required': ['title', 'amount'],
            },
          },
        ],
      },
    ];
  }

  DiarioContact? _findContact(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();

    try {
      return diarioState.contacts.firstWhere((c) {
        final matchDirect = c.id.toLowerCase() == q ||
            c.name.toLowerCase() == q ||
            (c.nickname ?? '').toLowerCase() == q;
        final matchContains = c.name.toLowerCase().contains(q) ||
            (c.nickname ?? '').toLowerCase().contains(q);
        final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
            c.name.toLowerCase().contains(t) ||
            (c.nickname ?? '').toLowerCase().contains(t));
        return matchDirect || matchContains || tokenMatch;
      });
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _serializeContactWithRecords(DiarioContact c) {
    final entries = diarioState.getEntriesForContact(c.id);
    final recordsData = entries.map((e) {
      final categoryName = diarioState.categories
          .firstWhere(
            (cat) => cat.id == e.categoryId,
            orElse: () => DiarioCategory(id: '', contactId: '', name: 'General', icon: ''),
          )
          .name;

      final fieldsList = <String>[];
      e.contentData.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          fieldsList.add('$key: $val');
        }
      });

      return {
        'title': e.title,
        'category': categoryName,
        'details': e.contentData,
        if (fieldsList.isNotEmpty) 'summary': fieldsList.join(', '),
        if (e.contentText != null && e.contentText!.trim().isNotEmpty)
          'notes': e.contentText,
      };
    }).toList();

    final mentions = diarioState.getEntriesMentioningContact(c.id);
    final mentionsData = mentions.map((e) {
      final originName = e.isPersonal
          ? 'Nota Personal'
          : (diarioState.getContactById(e.contactId)?.name ?? 'Otro Contacto');
      return {
        'title': e.title.isNotEmpty ? e.title : 'Sin título',
        'origin': originName,
        'date': e.formattedDate,
        if (e.contentText != null && e.contentText!.trim().isNotEmpty)
          'notes': e.contentText,
        'details': e.contentData,
      };
    }).toList();

    return {
      'id': c.id,
      'name': c.name,
      'nickname': c.nickname ?? '',
      'relationship': c.relationship ?? '',
      'phone': c.phone ?? 'No registrado',
      'birthdate': c.birthdate != null
          ? '${c.birthdate!.day}/${c.birthdate!.month}/${c.birthdate!.year}'
          : 'No registrado',
      'currentAge': c.currentAge != null ? '${c.currentAge} años' : 'Desconocida',
      'daysUntilBirthday': c.daysUntilBirthday,
      'ageOnUpcomingBirthday': c.ageOnUpcomingBirthday != null ? '${c.ageOnUpcomingBirthday} años' : null,
      'notes': c.notes ?? '',
      'records': recordsData,
      'mentionsInOtherNotes': mentionsData,
    };
  }

  /// Ejecución local de herramientas y generación automática de Artefactos estructurados
  Future<ToolExecutionResult> executeFunctionCall(
    String functionName,
    Map<String, dynamic> arguments, {
    required String sessionId,
  }) async {
    switch (functionName) {
      case 'searchSuiteData':
        final q = (arguments['query']?.toString() ?? '').toLowerCase().trim();
        final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();
        final now = DateTime.now();
        final todayDate = DateTime(now.year, now.month, now.day);
        final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

        // 1. Recordatorios
        final remindersMatches = remindersState.allReminders.where((r) {
          final inTitle = r.title.toLowerCase().contains(q);
          final inNotes = (r.notes ?? '').toLowerCase().contains(q);
          final inTags = r.tags.any((t) => t.toLowerCase().contains(q));
          final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
              r.title.toLowerCase().contains(t) ||
              (r.notes ?? '').toLowerCase().contains(t) ||
              r.tags.any((tag) => tag.toLowerCase().contains(t)));
          return inTitle || inNotes || inTags || tokenMatch;
        }).map((r) {
          int? daysRemaining;
          String? formattedDate;
          if (r.dueAt != null) {
            final due = r.dueAt!.toLocal();
            final dueDate = DateTime(due.year, due.month, due.day);
            daysRemaining = dueDate.difference(todayDate).inDays;
            formattedDate = '${weekDays[due.weekday - 1]} ${due.day} de ${months[due.month - 1]} de ${due.year}';
          }
          return {
            'id': r.id,
            'title': r.title,
            'priority': r.priority.label,
            'status': r.status.label,
            'dueAt': r.dueAt?.toIso8601String(),
            'formattedDueDate': formattedDate,
            'formattedDueTime': r.formattedDueTime,
            'daysRemaining': daysRemaining,
            'notes': r.notes ?? '',
            'tags': r.tags,
          };
        }).toList();

        // 2. Diario (Contactos y Entradas)
        final contactMatches = diarioState.contacts.where((c) {
          final inName = c.name.toLowerCase().contains(q);
          final inNick = (c.nickname ?? '').toLowerCase().contains(q);
          final inNotes = (c.notes ?? '').toLowerCase().contains(q);
          final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
              c.name.toLowerCase().contains(t) ||
              (c.nickname ?? '').toLowerCase().contains(t));
          return inName || inNick || inNotes || tokenMatch;
        }).map((c) => _serializeContactWithRecords(c)).toList();

        final entryMatches = diarioState.entries.where((e) {
          final inTitle = e.title.toLowerCase().contains(q);
          final inText = (e.contentText ?? '').toLowerCase().contains(q);
          final inData = e.contentData.values.any((v) => v.toString().toLowerCase().contains(q));
          final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
              e.title.toLowerCase().contains(t) ||
              (e.contentText ?? '').toLowerCase().contains(t) ||
              e.contentData.values.any((v) => v.toString().toLowerCase().contains(t)));
          return inTitle || inText || inData || tokenMatch;
        }).map((e) {
          final isPersonal = e.contactId == 'personal' || e.contactId.isEmpty;
          final contact = isPersonal ? null : diarioState.getContactById(e.contactId);
          final categoryName = diarioState.categories
              .firstWhere(
                (c) => c.id == e.categoryId,
                orElse: () => DiarioCategory(
                  id: '',
                  contactId: '',
                  name: isPersonal ? 'Notas Personales' : 'General',
                  icon: isPersonal ? '📝' : '',
                ),
              )
              .name;
          return {
            'isPersonalNote': isPersonal,
            'contactName': isPersonal ? 'Nota Personal (Usuario)' : (contact?.name ?? 'Contacto no encontrado'),
            'contactNickname': contact?.nickname ?? '',
            'entryTitle': e.title,
            'category': categoryName,
            'details': e.contentData,
            'notes': e.contentText ?? '',
            'date': e.formattedDate,
          };
        }).toList();

        // 3. Finanzas (Cuentas y Pagos Pendientes)
        final accountMatches = appState.accounts.where((a) {
          final inName = a.name.toLowerCase().contains(q);
          final inCurr = a.currency.name.toLowerCase().contains(q);
          return inName || inCurr;
        }).map((a) => {
          'name': a.name,
          'currency': a.currency.name.toUpperCase(),
          'balance': a.balance,
        }).toList();

        final pendingPaymentMatches = appState.pendingPaymentsToday.where((p) {
          final inName = p.payment.name.toLowerCase().contains(q);
          return inName;
        }).map((p) => {
          'name': p.payment.name,
          'amount': p.payment.amount,
          'currency': p.payment.currency.name.toUpperCase(),
          'dueDate': p.occurrenceDate.toIso8601String(),
        }).toList();

        // 4. Hábitos
        final habitMatches = habitosState.allHabits.where((h) {
          final inTitle = h.title.toLowerCase().contains(q);
          final tokenMatch = tokens.isNotEmpty && tokens.any((t) => h.title.toLowerCase().contains(t));
          return inTitle || tokenMatch;
        }).map((h) => {
          'title': h.title,
          'isNegative': h.isNegative,
          'streak': habitosState.calculateCurrentStreak(h.id),
        }).toList();

        final totalMatches = remindersMatches.length + contactMatches.length + entryMatches.length + accountMatches.length + pendingPaymentMatches.length + habitMatches.length;

        return ToolExecutionResult(
          resultData: {
            'query': q,
            'totalMatches': totalMatches,
            'reminders': remindersMatches,
            'diarioContacts': contactMatches,
            'diarioEntries': entryMatches,
            'finanzasAccounts': accountMatches,
            'finanzasPendingPayments': pendingPaymentMatches,
            'habits': habitMatches,
          },
        );

      case 'searchContacts':
        final q = (arguments['query']?.toString() ?? '').toLowerCase().trim();
        final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();

        final results = diarioState.contacts.where((c) {
          final inName = c.name.toLowerCase().contains(q);
          final inNickname = (c.nickname ?? '').toLowerCase().contains(q);
          final inPhone = (c.phone ?? '').toLowerCase().contains(q);
          final inNotes = (c.notes ?? '').toLowerCase().contains(q);
          final inRel = (c.relationship ?? '').toLowerCase().contains(q);

          final tokenNameMatch = tokens.isNotEmpty && tokens.any((t) =>
              c.name.toLowerCase().contains(t) ||
              (c.nickname ?? '').toLowerCase().contains(t));

          final entries = diarioState.getEntriesForContact(c.id);
          final inEntries = entries.any((e) {
            final inTitle = e.title.toLowerCase().contains(q);
            final inText = (e.contentText ?? '').toLowerCase().contains(q);
            final inData = e.contentData.values.any((v) =>
                v.toString().toLowerCase().contains(q));
            final tokenInEntry = tokens.isNotEmpty && tokens.any((t) =>
                e.title.toLowerCase().contains(t) ||
                (e.contentText ?? '').toLowerCase().contains(t) ||
                e.contentData.values.any((v) => v.toString().toLowerCase().contains(t)));
            return inTitle || inText || inData || (tokenNameMatch && tokenInEntry);
          });

          return inName || inNickname || inPhone || inNotes || inRel || tokenNameMatch || inEntries;
        }).toList();

        final contactsData = results.map((c) => _serializeContactWithRecords(c)).toList();

        // Solo generar un artefacto visual de tarjeta si el usuario lo solicitó explícitamente
        ChatArtifactModel? artifact;
        final wantsCard = q.contains('ficha') || q.contains('tarjeta') || q.contains('perfil') || (q.contains('contacto') && !q.contains('placa') && !q.contains('carro') && !q.contains('auto'));
        if (results.isNotEmpty && wantsCard) {
          final first = results.first;
          artifact = ChatArtifactModel(
            sessionId: sessionId,
            type: ArtifactType.contactCard,
            title: first.displayName,
            content: 'Teléfono: ${first.phone ?? "N/A"}\nCumpleaños: ${first.formattedBirthdate ?? "N/A"}\nRelación: ${first.relationship ?? "N/A"}\nNotas: ${first.notes ?? ""}',
            metadata: {'contacts': contactsData},
          );
        }

        return ToolExecutionResult(
          resultData: {'found': results.length, 'contacts': contactsData},
          generatedArtifact: artifact,
        );

      case 'getContactDetails':
        final q = (arguments['nameOrQuery']?.toString() ?? '').toLowerCase().trim();
        final contact = _findContact(q);

        if (contact == null) {
          return ToolExecutionResult(
            resultData: {
              'found': false,
              'message': 'No se encontró ningún contacto con el nombre o apodo "$q".',
            },
          );
        }

        final contactData = _serializeContactWithRecords(contact);
        return ToolExecutionResult(
          resultData: {
            'found': true,
            'contact': contactData,
          },
        );

      case 'searchDiarioEntries':
        final q = (arguments['query']?.toString() ?? '').toLowerCase().trim();
        final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();

        final matches = <Map<String, dynamic>>[];
        for (final e in diarioState.entries) {
          final inTitle = e.title.toLowerCase().contains(q);
          final inText = (e.contentText ?? '').toLowerCase().contains(q);
          final inData = e.contentData.values.any((v) =>
              v.toString().toLowerCase().contains(q));
          final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
              e.title.toLowerCase().contains(t) ||
              (e.contentText ?? '').toLowerCase().contains(t) ||
              e.contentData.values.any((v) => v.toString().toLowerCase().contains(t)));

          final contact = diarioState.getContactById(e.contactId);
          final contactMatch = contact != null && tokens.isNotEmpty && tokens.any((t) =>
              contact.name.toLowerCase().contains(t) ||
              (contact.nickname ?? '').toLowerCase().contains(t));

          final mentionMatch = e.mentionedContactIds.any((cid) {
            final mc = diarioState.getContactById(cid);
            if (mc == null) return false;
            return mc.name.toLowerCase().contains(q) ||
                (mc.nickname?.toLowerCase().contains(q) ?? false) ||
                (tokens.isNotEmpty && tokens.any((t) => mc.name.toLowerCase().contains(t)));
          });

          if (inTitle || inText || inData || tokenMatch || contactMatch || mentionMatch) {
            final isPersonal = e.contactId == 'personal' || e.contactId.isEmpty;
            final categoryName = diarioState.categories
                .firstWhere(
                  (c) => c.id == e.categoryId,
                  orElse: () => DiarioCategory(
                    id: '',
                    contactId: '',
                    name: isPersonal ? 'Notas Personales' : 'General',
                    icon: isPersonal ? '📝' : '',
                  ),
                )
                .name;

            final fieldsList = <String>[];
            e.contentData.forEach((key, val) {
              if (val != null && val.toString().trim().isNotEmpty) {
                fieldsList.add('$key: $val');
              }
            });

            matches.add({
              'isPersonalNote': isPersonal,
              'contactName': isPersonal ? 'Nota Personal (Usuario)' : (contact?.name ?? 'Contacto no encontrado'),
              'contactNickname': contact?.nickname ?? '',
              'entryTitle': e.title,
              'category': categoryName,
              'date': e.formattedDate,
              'details': e.contentData,
              if (e.mentionedContactIds.isNotEmpty)
                'mentionedContacts': e.mentionedContactIds
                    .map((cid) => diarioState.getContactById(cid)?.name)
                    .whereType<String>()
                    .toList(),
              if (fieldsList.isNotEmpty) 'summary': fieldsList.join(', '),
              if (e.contentText != null && e.contentText!.trim().isNotEmpty)
                'notes': e.contentText,
            });
          }
        }

        return ToolExecutionResult(
          resultData: {
            'found': matches.length,
            'entries': matches,
          },
        );

      case 'getPersonalNotes':
        final q = (arguments['query']?.toString() ?? '').toLowerCase().trim();
        final dateFilter = (arguments['dateFilter']?.toString() ?? '').toLowerCase().trim();
        final now = DateTime.now();

        final monthNames = [
          'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
          'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
        ];

        var personalNotes = diarioState.personalEntries;

        if (dateFilter.isNotEmpty) {
          personalNotes = personalNotes.where((e) {
            final dt = e.createdAt.toLocal();
            final iso = dt.toIso8601String().toLowerCase();
            final formatted = e.formattedDate.toLowerCase();
            final day = dt.day.toString();
            final year = dt.year.toString();
            final monthName = (dt.month >= 1 && dt.month <= 12) ? monthNames[dt.month - 1] : '';

            if (dateFilter == 'hoy') {
              return dt.year == now.year && dt.month == now.month && dt.day == now.day;
            }
            if (dateFilter == 'ayer') {
              final yesterday = now.subtract(const Duration(days: 1));
              return dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
            }
            if (dateFilter == 'semana' || dateFilter == 'esta semana') {
              return now.difference(dt).inDays <= 7;
            }

            return iso.contains(dateFilter) ||
                formatted.contains(dateFilter) ||
                (dateFilter.contains(day) && (dateFilter.contains(year) || dateFilter.contains(monthName)));
          }).toList();
        }

        if (q.isNotEmpty) {
          final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();
          personalNotes = personalNotes.where((e) {
            final inTitle = e.title.toLowerCase().contains(q);
            final inText = (e.contentText ?? '').toLowerCase().contains(q);
            final inData = e.contentData.values.any((v) => v.toString().toLowerCase().contains(q));
            final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
                e.title.toLowerCase().contains(t) ||
                (e.contentText ?? '').toLowerCase().contains(t) ||
                e.contentData.values.any((v) => v.toString().toLowerCase().contains(t)));
            return inTitle || inText || inData || tokenMatch;
          }).toList();
        }

        final notesData = personalNotes.map((e) {
          final fieldsList = <String>[];
          e.contentData.forEach((key, val) {
            if (val != null && val.toString().trim().isNotEmpty) {
              fieldsList.add('$key: $val');
            }
          });

          return {
            'id': e.id,
            'title': e.title,
            'date': e.formattedDate,
            'createdIso': e.createdAt.toIso8601String(),
            'isPinned': e.isPinned,
            'hasPhoto': e.hasPhoto,
            if (fieldsList.isNotEmpty) 'details': fieldsList.join(', '),
            'content': e.contentText ?? '',
          };
        }).toList();

        return ToolExecutionResult(
          resultData: {
            'found': notesData.length,
            'notes': notesData,
            'filterApplied': {
              if (q.isNotEmpty) 'query': q,
              if (dateFilter.isNotEmpty) 'dateFilter': dateFilter,
            },
          },
        );

      case 'getUpcomingBirthdays':
        final limit = int.tryParse(arguments['limit']?.toString() ?? '5') ?? 5;
        final list = diarioState.getUpcomingBirthdays(limit: limit);
        final bdaysData = list.map((b) {
          return {
            'name': b.name,
            'formattedBirthdate': b.formattedBirthdate,
            'daysUntilBirthday': b.daysUntilBirthday,
            'currentAge': b.currentAge,
            'nextAge': b.ageOnUpcomingBirthday,
          };
        }).toList();

        final artifact = ChatArtifactModel(
          sessionId: sessionId,
          type: ArtifactType.table,
          title: 'Próximos Cumpleaños',
          content: list
              .map((b) =>
                  '| ${b.name} | ${b.formattedBirthdate ?? "N/A"} | en ${b.daysUntilBirthday} días (cumplirá ${b.ageOnUpcomingBirthday ?? "N/A"}) |')
              .join('\n'),
          metadata: {'birthdays': bdaysData},
        );

        return ToolExecutionResult(
          resultData: {'birthdays': bdaysData},
          generatedArtifact: artifact,
        );

      case 'getFinancialOverview':
        final accountsData = appState.accounts.map((a) => {
          'name': a.name,
          'balance': a.balance,
          'currency': a.currency.name,
        }).toList();

        final totalUsd = appState.totalBalanceUSD;
        final totalBs = totalUsd * appState.bcvRate;

        final artifact = ChatArtifactModel(
          sessionId: sessionId,
          type: ArtifactType.financialSummary,
          title: 'Resumen Financiero',
          content: 'Total USD: \$${totalUsd.toStringAsFixed(2)}\nTotal Bs: Bs. ${totalBs.toStringAsFixed(2)}\nTasa BCV: Bs. ${appState.bcvRate.toStringAsFixed(2)}',
          metadata: {
            'totalUsd': totalUsd,
            'totalBs': totalBs,
            'bcvRate': appState.bcvRate,
            'euroRate': appState.euroRate,
            'accounts': accountsData,
          },
        );

        return ToolExecutionResult(
          resultData: {
            'totalBalanceUsd': totalUsd,
            'totalBalanceBs': totalBs,
            'bcvRate': appState.bcvRate,
            'euroRate': appState.euroRate,
            'accounts': accountsData,
            'pendingPaymentsCount': appState.pendingPaymentsToday.length,
          },
          generatedArtifact: artifact,
        );

      case 'calculateCurrencyExchange':
        final amount = double.tryParse(arguments['amount']?.toString() ?? '0') ?? 0.0;
        final from = (arguments['fromCurrency']?.toString() ?? 'usd').toLowerCase();
        final to = (arguments['toCurrency']?.toString() ?? 'bs').toLowerCase();
        final bcv = appState.bcvRate;

        double converted = 0.0;
        if (from == 'usd' && to == 'bs') {
          converted = amount * bcv;
        } else if (from == 'bs' && to == 'usd') {
          converted = bcv > 0 ? amount / bcv : 0;
        } else if (from == 'eur' && to == 'bs') {
          converted = amount * appState.euroRate;
        } else {
          converted = amount;
        }

        final artifact = ChatArtifactModel(
          sessionId: sessionId,
          type: ArtifactType.calculation,
          title: 'Conversión de Moneda',
          content: '$amount ${from.toUpperCase()} = ${converted.toStringAsFixed(2)} ${to.toUpperCase()} (Tasa: Bs. ${bcv.toStringAsFixed(2)})',
          metadata: {'amount': amount, 'from': from, 'to': to, 'result': converted, 'rate': bcv},
        );

        return ToolExecutionResult(
          resultData: {
            'originalAmount': amount,
            'fromCurrency': from,
            'toCurrency': to,
            'convertedAmount': converted,
            'appliedRate': bcv,
          },
          generatedArtifact: artifact,
        );

      case 'getHabitsStatus':
        final todayKey = habitosState.todayKey;
        final habitsData = habitosState.allHabits.map((h) => {
          'id': h.id,
          'title': h.title,
          'isNegative': h.isNegative,
          'completedToday': habitosState.isCompleted(h.id, todayKey),
          'currentStreak': habitosState.calculateCurrentStreak(h.id),
        }).toList();

        return ToolExecutionResult(
          resultData: {
            'todayCompletionRate': habitosState.todayCompletionRate,
            'bestCurrentStreak': habitosState.bestCurrentStreak,
            'habits': habitsData,
          },
        );

      case 'getReminders':
        final filter = arguments['filter']?.toString().toLowerCase() ?? 'all';
        final query = arguments['query']?.toString().toLowerCase().trim() ?? '';
        final tokens = query.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();

        List<ReminderModel> list;
        if (filter == 'overdue') {
          list = remindersState.overdueReminders;
        } else if (filter == 'today') {
          list = remindersState.todayReminders;
        } else if (filter == 'upcoming') {
          list = remindersState.upcomingReminders;
        } else {
          list = remindersState.allReminders.where((r) => !r.isCompleted && !r.isArchived).toList();
        }

        if (query.isNotEmpty) {
          list = list.where((r) {
            final inTitle = r.title.toLowerCase().contains(query);
            final inNotes = (r.notes ?? '').toLowerCase().contains(query);
            final inTags = r.tags.any((t) => t.toLowerCase().contains(query));
            final tokenMatch = tokens.isNotEmpty && tokens.any((t) =>
                r.title.toLowerCase().contains(t) ||
                (r.notes ?? '').toLowerCase().contains(t) ||
                r.tags.any((tag) => tag.toLowerCase().contains(t)));
            return inTitle || inNotes || inTags || tokenMatch;
          }).toList();
        }

        final now = DateTime.now();
        final todayDate = DateTime(now.year, now.month, now.day);
        final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

        final remindersData = list.map((r) {
          int? daysRemaining;
          String? formattedDate;
          if (r.dueAt != null) {
            final due = r.dueAt!.toLocal();
            final dueDate = DateTime(due.year, due.month, due.day);
            daysRemaining = dueDate.difference(todayDate).inDays;
            formattedDate = '${weekDays[due.weekday - 1]} ${due.day} de ${months[due.month - 1]} de ${due.year}';
          }

          return {
            'id': r.id,
            'title': r.title,
            'priority': r.priority.label,
            'status': r.status.label,
            'dueAt': r.dueAt?.toIso8601String(),
            'formattedDueDate': formattedDate,
            'formattedDueTime': r.formattedDueTime,
            'daysRemaining': daysRemaining,
            'isRecurring': r.isRecurring,
            'recurrence': r.recurrence.shortLabel,
            'tags': r.tags,
            'notes': r.notes ?? '',
          };
        }).toList();

        return ToolExecutionResult(
          resultData: {'count': list.length, 'reminders': remindersData},
        );

      case 'createReminder':
        final title = arguments['title']?.toString() ?? 'Nuevo recordatorio';
        final pStr = arguments['priority']?.toString();
        final rStr = arguments['recurrence']?.toString();

        final priority = ReminderPriority.fromString(pStr);
        final recurrence = ReminderRecurrence.fromRrule(rStr);

        final newReminder = ReminderModel(
          id: const Uuid().v4(),
          title: title,
          priority: priority,
          rrule: recurrence.rruleString,
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        );

        await remindersState.saveReminder(newReminder);

        return ToolExecutionResult(
          resultData: {
            'success': true,
            'createdReminder': {
              'title': newReminder.title,
              'priority': newReminder.priority.label,
              'dueAt': newReminder.formattedDueTime,
            },
          },
        );

      case 'getWeeklySchedule':
        final dayQuery = arguments['dayOfWeek']?.toString().toLowerCase().trim();
        final onlyBigRocks = arguments['onlyBigRocks'] == true || arguments['onlyBigRocks']?.toString().toLowerCase() == 'true';
        final dayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
        final dayLabels = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

        int? targetDayIndex;
        if (dayQuery != null && dayQuery.isNotEmpty) {
          if (dayQuery == 'hoy' || dayQuery == 'today') {
            targetDayIndex = DateTime.now().weekday - 1;
          } else {
            for (int i = 0; i < dayNames.length; i++) {
              if (dayNames[i].contains(dayQuery) || dayQuery.contains(dayNames[i]) || dayQuery.startsWith(dayNames[i].substring(0, 3))) {
                targetDayIndex = i;
                break;
              }
            }
          }
        }

        final monday = remindersState.currentMonday;
        final weekPlan = remindersState.currentWeeklyPlan;

        Map<String, dynamic> scheduleOutput = {};

        if (targetDayIndex != null) {
          final targetDate = monday.add(Duration(days: targetDayIndex));
          var dayReminders = remindersState.remindersForDayOfWeek(targetDayIndex);
          if (onlyBigRocks) {
            dayReminders = dayReminders.where((r) => r.isBigRock).toList();
          }

          scheduleOutput['day'] = dayLabels[targetDayIndex];
          scheduleOutput['date'] = '${targetDate.day}/${targetDate.month}/${targetDate.year}';
          scheduleOutput['count'] = dayReminders.length;
          scheduleOutput['bigRocksCount'] = dayReminders.where((r) => r.isBigRock).length;
          scheduleOutput['tasks'] = dayReminders.map((r) {
            final role = remindersState.getRoleById(r.roleId);
            return {
              'id': r.id,
              'title': r.title,
              'isBigRock': r.isBigRock,
              'quadrant': r.quadrant.label,
              'role': role?.name ?? 'Sin rol',
              'durationMinutes': r.estimatedDurationMinutes,
              'dueTime': r.dueAt != null ? '${r.dueAt!.hour.toString().padLeft(2, '0')}:${r.dueAt!.minute.toString().padLeft(2, '0')}' : 'Sin hora fija',
              'status': r.status.label,
            };
          }).toList();
        } else {
          scheduleOutput['weekRange'] = weekPlan?.formattedRange ?? 'Semana activa';
          final daysList = <Map<String, dynamic>>[];
          for (int i = 0; i < 7; i++) {
            final date = monday.add(Duration(days: i));
            var dayReminders = remindersState.remindersForDayOfWeek(i);
            if (onlyBigRocks) {
              dayReminders = dayReminders.where((r) => r.isBigRock).toList();
            }

            daysList.add({
              'dayName': dayLabels[i],
              'date': '${date.day}/${date.month}',
              'totalTasks': dayReminders.length,
              'bigRocksCount': dayReminders.where((r) => r.isBigRock).length,
              'tasks': dayReminders.map((r) {
                final role = remindersState.getRoleById(r.roleId);
                return {
                  'id': r.id,
                  'title': r.title,
                  'isBigRock': r.isBigRock,
                  'quadrant': r.quadrant.label,
                  'role': role?.name ?? 'Sin rol',
                  'duration': '~${r.estimatedDurationMinutes}m',
                };
              }).toList(),
            });
          }
          scheduleOutput['days'] = daysList;

          final unscheduled = remindersState.unscheduledWeeklyReminders;
          scheduleOutput['unscheduledCount'] = unscheduled.length;
          scheduleOutput['unscheduledTasks'] = unscheduled.map((r) => {
            'title': r.title,
            'isBigRock': r.isBigRock,
            'quadrant': r.quadrant.label,
          }).toList();
        }

        return ToolExecutionResult(
          resultData: scheduleOutput,
        );

      case 'getRolesCompass':
        final roles = remindersState.roles;
        final unaddressed = remindersState.unaddressedRoles;
        final bigRocks = remindersState.bigRocksForCurrentWeek;

        final rolesList = roles.map((role) {
          final roleRocks = remindersState.bigRocksForRole(role.id);
          return {
            'id': role.id,
            'name': role.name,
            'purposeStatement': role.purposeStatement ?? 'Sin declaración de propósito',
            'bigRocksCount': roleRocks.length,
            'hasBigRock': roleRocks.isNotEmpty,
            'bigRocks': roleRocks.map((r) => {
              'id': r.id,
              'title': r.title,
              'scheduledDay': r.scheduledDayOfWeek != null
                  ? ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][r.scheduledDayOfWeek!]
                  : 'Sin día asignado',
              'status': r.status.label,
            }).toList(),
          };
        }).toList();

        return ToolExecutionResult(
          resultData: {
            'totalRoles': roles.length,
            'unaddressedCount': unaddressed.length,
            'unaddressedRoles': unaddressed.map((r) => r.name).toList(),
            'balanceStatus': unaddressed.isEmpty
                ? 'Equilibrado: Todos los roles vitales tienen al menos una Gran Roca esta semana.'
                : 'Desbalance: Hay ${unaddressed.length} roles vitales sin Grandes Rocas (${unaddressed.map((r) => r.name).join(", ")}).',
            'roles': rolesList,
            'totalBigRocksThisWeek': bigRocks.length,
          },
        );

      case 'proposeScheduleBigRock':
        final title = (arguments['title']?.toString() ?? 'Nueva Gran Roca').trim();
        final roleName = arguments['roleName']?.toString().trim() ?? '';
        final dayQuery = arguments['dayOfWeek']?.toString().toLowerCase().trim() ?? 'lunes';
        final duration = arguments['estimatedDurationMinutes'] is num
            ? (arguments['estimatedDurationMinutes'] as num).toInt()
            : int.tryParse(arguments['estimatedDurationMinutes']?.toString() ?? '60') ?? 60;
        final notes = arguments['notes']?.toString().trim();

        // Buscar rol por coincidencia
        RoleModel? matchedRole;
        if (roleName.isNotEmpty) {
          try {
            matchedRole = remindersState.roles.firstWhere(
              (r) => r.name.toLowerCase().contains(roleName.toLowerCase()) ||
                  roleName.toLowerCase().contains(r.name.toLowerCase()),
            );
          } catch (_) {}
        }
        matchedRole ??= remindersState.roles.isNotEmpty ? remindersState.roles.first : null;

        // Normalizar día
        int dayIndex = 0;
        final dayNamesMatch = ['lunes', 'martes', 'miércoles', 'miercoles', 'jueves', 'viernes', 'sábado', 'sabado', 'domingo'];
        for (int i = 0; i < dayNamesMatch.length; i++) {
          if (dayQuery.contains(dayNamesMatch[i])) {
            if (i == 3) {
              dayIndex = 2; // miercoles sin tilde
            } else if (i == 7) {
              dayIndex = 5; // sabado sin tilde
            } else if (i == 8) {
              dayIndex = 6; // domingo
            } else {
              dayIndex = i;
            }
            if (dayIndex > 6) dayIndex = 6;
            break;
          }
        }

        final dayLabels = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final dayLabel = dayLabels[dayIndex];
        final monday = remindersState.currentMonday;
        final scheduledDate = DateTime(
          monday.year,
          monday.month,
          monday.day + dayIndex,
          9,
          0,
        );

        final summaryList = <Map<String, String>>[
          {'label': 'Gran Roca', 'value': title},
          {'label': 'Rol Vital', 'value': matchedRole?.name ?? 'General'},
          {'label': 'Día Asignado', 'value': '$dayLabel (${scheduledDate.day}/${scheduledDate.month}) a las 9:00 AM'},
          {'label': 'Cuadrante', 'value': 'Cuadrante II (Importante, No Urgente)'},
          {'label': 'Duración estimada', 'value': '$duration min'},
          if (notes != null && notes.isNotEmpty) {'label': 'Propósito / Notas', 'value': notes},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: '⭐ Gran Roca: $title',
          content: 'Stephen Covey enseña a agendar primero las Grandes Rocas para asegurar el equilibrio en tus roles.',
          metadata: {
            'action': 'create_reminder',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'title': title,
              'priority': 'p1_urgent',
              'roleId': matchedRole?.id,
              'quadrant': 'q2_important_not_urgent',
              'isBigRock': true,
              'scheduledDayOfWeek': dayIndex,
              'dueAt': scheduledDate.toIso8601String(),
              'estimatedDurationMinutes': duration,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'schedule_big_rock',
            'message': 'Se ha generado una tarjeta interactiva en el chat con los botones Confirmar o Negar para agendar la Gran Roca "$title" en tu rol ${matchedRole?.name ?? "vital"} el día $dayLabel.',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      case 'proposeCreateDiarioEntry':
        final title = (arguments['title']?.toString() ?? '').trim();
        final contentText = (arguments['contentText']?.toString() ?? '').trim();
        final contactName = arguments['contactName']?.toString().trim();
        final category = arguments['category']?.toString().trim() ?? 'salud';
        final templateName = arguments['templateName']?.toString().trim() ??
            arguments['model']?.toString().trim();

        final dateStr = arguments['date']?.toString().trim();
        DateTime entryDate = DateTime.now();
        if (dateStr != null && dateStr.isNotEmpty) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) entryDate = parsed;
        }

        final now = DateTime.now();
        final isToday = entryDate.year == now.year && entryDate.month == now.month && entryDate.day == now.day;
        final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
        final formattedDateStr = isToday ? 'Hoy' : '${entryDate.day} ${months[entryDate.month - 1]} ${entryDate.year}';

        DiarioContact? targetContact;
        if (contactName != null && contactName.isNotEmpty) {
          targetContact = _findContact(contactName);
        }

        final contactDisplay = targetContact != null
            ? targetContact.name
            : (contactName != null && contactName.isNotEmpty ? contactName : 'General');

        final templateDisplay = (templateName != null &&
                templateName.isNotEmpty &&
                templateName.toLowerCase() != 'nota simple' &&
                !templateName.toLowerCase().contains('sin modelo'))
            ? templateName
            : 'Nota simple (Sin modelo)';

        final autoMentionIds = diarioState.extractMentionedContactIds(contentText);
        if (targetContact != null) {
          autoMentionIds.remove(targetContact.id);
        }

        final summaryList = <Map<String, String>>[
          if (title.isNotEmpty) {'label': 'Título', 'value': title},
          {'label': 'Contacto', 'value': contactDisplay},
          if (autoMentionIds.isNotEmpty)
            {
              'label': 'Menciones',
              'value': autoMentionIds
                  .map((id) => diarioState.getContactById(id)?.name)
                  .whereType<String>()
                  .join(', ')
            },
          {'label': 'Fecha', 'value': formattedDateStr},
          {'label': 'Modelo', 'value': templateDisplay},
          {'label': 'Detalle', 'value': contentText.length > 80 ? '${contentText.substring(0, 80)}...' : contentText},
        ];

        final artifactTitle = title.isNotEmpty
            ? 'Nueva Entrada: $title'
            : (contactDisplay != 'General' ? 'Nueva Nota para $contactDisplay' : 'Nueva Nota');

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: artifactTitle,
          content: 'Por favor confirma si deseas registrar esta entrada en tu Diario Jottache para $contactDisplay.',
          metadata: {
            'action': 'create_diario_entry',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'title': title,
              'contentText': contentText,
              if (contactName != null && contactName.isNotEmpty) 'contactName': contactName,
              if (targetContact != null) 'contactId': targetContact.id,
              if (autoMentionIds.isNotEmpty) 'mentionedContactIds': autoMentionIds,
              'date': entryDate.toIso8601String(),
              'category': category,
              'templateName': templateDisplay,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'create_diario_entry',
            'message': 'Se ha generado una tarjeta interactiva en el chat con los botones Confirmar o Negar para registrar la entrada "$title" en el Diario Jottache para $contactDisplay. Pide al usuario que confirme mediante el botón.',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      case 'proposeCreateContact':
        final name = (arguments['name']?.toString() ?? '').trim();
        final nickname = arguments['nickname']?.toString().trim();
        final relationship = arguments['relationship']?.toString().trim();
        final phone = arguments['phone']?.toString().trim();
        final notes = arguments['notes']?.toString().trim();
        final age = arguments['age'] is num
            ? (arguments['age'] as num).toInt()
            : int.tryParse(arguments['age']?.toString() ?? '');
        String? birthdate = arguments['birthdate']?.toString().trim();

        if ((birthdate == null || birthdate.isEmpty) && age != null && age > 0) {
          final now = DateTime.now();
          birthdate = '${now.year - age}-01-01';
        }

        final summaryList = <Map<String, String>>[
          {'label': 'Nombre', 'value': name.isNotEmpty ? name : 'Sin especificar'},
          if (nickname != null && nickname.isNotEmpty) {'label': 'Apodo', 'value': nickname},
          if (relationship != null && relationship.isNotEmpty) {'label': 'Relación', 'value': relationship},
          if (phone != null && phone.isNotEmpty) {'label': 'Teléfono', 'value': phone},
          if (age != null && age > 0) {'label': 'Edad aprox.', 'value': '$age años'},
          if (birthdate != null && birthdate.isNotEmpty) {'label': 'Cumpleaños', 'value': birthdate},
          if (notes != null && notes.isNotEmpty) {'label': 'Notas', 'value': notes},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: 'Nuevo Contacto: ${name.isNotEmpty ? name : "Sin nombre"}',
          content: 'Por favor confirma si los datos son correctos para registrar este contacto en tu Diario Jottache.',
          metadata: {
            'action': 'create_contact',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'name': name,
              if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
              if (relationship != null && relationship.isNotEmpty) 'relationship': relationship,
              if (phone != null && phone.isNotEmpty) 'phone': phone,
              if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'create_contact',
            'message': 'Se ha generado una tarjeta interactiva en el chat con los botones Confirmar o Negar para crear el contacto "$name". Pide al usuario que confirme mediante el botón.',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      case 'proposeCreateReminder':
        final title = (arguments['title']?.toString() ?? 'Nuevo recordatorio').trim();
        final priority = arguments['priority']?.toString().trim();
        final recurrence = arguments['recurrence']?.toString().trim();
        final dueAt = arguments['dueAt']?.toString().trim();
        final notes = arguments['notes']?.toString().trim();

        final summaryList = <Map<String, String>>[
          {'label': 'Título', 'value': title},
          if (priority != null && priority.isNotEmpty) {'label': 'Prioridad', 'value': priority},
          if (dueAt != null && dueAt.isNotEmpty) {'label': 'Fecha/Hora', 'value': dueAt},
          if (recurrence != null && recurrence.isNotEmpty) {'label': 'Recurrencia', 'value': recurrence},
          if (notes != null && notes.isNotEmpty) {'label': 'Notas', 'value': notes},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: 'Nuevo Recordatorio: $title',
          content: 'Por favor confirma si deseas programar este recordatorio en el sistema.',
          metadata: {
            'action': 'create_reminder',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'title': title,
              if (priority != null && priority.isNotEmpty) 'priority': priority,
              if (recurrence != null && recurrence.isNotEmpty) 'recurrence': recurrence,
              if (dueAt != null && dueAt.isNotEmpty) 'dueAt': dueAt,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'create_reminder',
            'message': 'Se ha generado una tarjeta interactiva en el chat con los botones Confirmar o Negar para crear el recordatorio "$title".',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      case 'proposeCreateHabit':
        final title = (arguments['title']?.toString() ?? 'Nuevo hábito').trim();
        final isNegative = arguments['isNegative'] == true || arguments['isNegative']?.toString().toLowerCase() == 'true';

        final summaryList = <Map<String, String>>[
          {'label': 'Hábito', 'value': title},
          {'label': 'Tipo', 'value': isNegative ? 'Evitar / Romper mal hábito' : 'Construir hábito positivo'},
          {'label': 'Frecuencia', 'value': 'Diario'},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: 'Nuevo Hábito: $title',
          content: 'Por favor confirma si deseas registrar este hábito en tu seguimiento de Hábitos.',
          metadata: {
            'action': 'create_habit',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'title': title,
              'isNegative': isNegative,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'create_habit',
            'message': 'Se ha generado una tarjeta interactiva en el chat con los botones Confirmar o Negar para el hábito "$title".',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      case 'proposeCreateTransaction':
        final title = (arguments['title']?.toString() ?? 'Transacción').trim();
        final amount = (arguments['amount'] as num?)?.toDouble() ?? 0.0;
        final type = arguments['type']?.toString().toLowerCase() == 'income' ? 'income' : 'expense';
        final currency = arguments['currency']?.toString().toLowerCase() ?? 'usd';
        final accountName = arguments['accountName']?.toString().trim();

        final summaryList = <Map<String, String>>[
          {'label': 'Concepto', 'value': title},
          {'label': 'Tipo', 'value': type == 'income' ? 'Ingreso (+)' : 'Gasto (-)'},
          {'label': 'Monto', 'value': '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}'},
          if (accountName != null && accountName.isNotEmpty) {'label': 'Cuenta', 'value': accountName},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: '${type == "income" ? "Ingreso" : "Gasto"}: $title',
          content: 'Por favor confirma si deseas registrar este movimiento financiero en Finanzas Quebrado.',
          metadata: {
            'action': 'create_transaction',
            'status': 'pending',
            'summary': summaryList,
            'data': {
              'amount': amount,
              'type': type,
              'currency': currency,
              'description': title,
              if (accountName != null && accountName.isNotEmpty) 'accountName': accountName,
            },
          },
        );

        return ToolExecutionResult(
          resultData: {
            'status': 'proposed',
            'action': 'create_transaction',
            'message': 'Se ha generado una tarjeta interactiva en el chat para registrar el movimiento de ${amount.toStringAsFixed(2)} ${currency.toUpperCase()}.',
            'summary': summaryList,
          },
          generatedArtifact: artifact,
        );

      default:
        return ToolExecutionResult(
          resultData: {'error': 'Función no reconocida: $functionName'},
        );
    }
  }
}
