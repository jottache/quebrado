import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../diario/diario.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../../recordatorios/models/reminder_model.dart';
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
    final upcomingBirthdays = diarioState.getUpcomingBirthdays(limit: 3);

    final habitsRate = (habitosState.todayCompletionRate * 100).round();
    final habitStreak = habitosState.bestCurrentStreak;

    final overdueReminders = remindersState.overdueCount;
    final todayReminders = remindersState.todayCount;

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
- Contactos y Vínculos (Diario Jottache):
  * Total de contactos guardados: $contactsCount
  * Próximos cumpleaños:
$bdaysStr
- Hábitos y Rutinas:
  * Progreso de hábitos hoy: $habitsRate%
  * Mejor racha actual: $habitStreak días
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
            'proposeCreateDiarioEntry',
            'Propone registrar una nueva entrada, nota, apunte o bitácora en el Diario Jottache (asociada a un contacto o personal/general) mostrando una tarjeta interactiva con botones de Confirmar y Negar antes de guardarla. Úsala cuando el usuario diga "entrada", "nota", "anota esto", "guarda un apunte", o relate hechos, dolencias, síntomas, sucesos, gustos, medidas o comentarios sobre alguien.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título descriptivo y breve de la nota o entrada (ej: "Dolor de espalda cerca del cuello", "Gusto culinario", "Talla de calzado").'),
                'contentText': Schema(SchemaType.string, description: 'Texto detallado o relato completo de la nota o entrada.'),
                'contactName': Schema(SchemaType.string, description: 'Nombre o apodo del contacto al que se asocia la nota si aplica (ej: "Mariana Dávila", "Carlos").'),
                'category': Schema(SchemaType.string, description: 'Categoría sugerida opcional (ej: "salud", "alimentos", "regalos", "vehiculos", "general").'),
              },
              requiredProperties: ['title', 'contentText'],
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
            'name': 'proposeCreateDiarioEntry',
            'description': 'Propone registrar una nueva entrada, nota, apunte o bitácora en el Diario Jottache (asociada a un contacto o personal/general) mostrando una tarjeta interactiva con botones de Confirmar y Negar antes de guardarla. Úsala cuando el usuario diga "entrada", "nota", "anota esto", "guarda un apunte", o relate hechos, dolencias, síntomas, sucesos, gustos, medidas o comentarios sobre alguien.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'title': {'type': 'STRING', 'description': 'Título descriptivo y breve de la nota o entrada (ej: "Dolor de espalda cerca del cuello", "Gusto culinario", "Talla de calzado").'},
                'contentText': {'type': 'STRING', 'description': 'Texto detallado o relato completo de la nota o entrada.'},
                'contactName': {'type': 'STRING', 'description': 'Nombre o apodo del contacto al que se asocia la nota si aplica (ej: "Mariana Dávila", "Carlos").'},
                'category': {'type': 'STRING', 'description': 'Categoría sugerida opcional (ej: "salud", "alimentos", "regalos", "vehiculos", "general").'},
              },
              'required': ['title', 'contentText'],
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

    return {
      'id': c.id,
      'name': c.name,
      'nickname': c.nickname ?? '',
      'relationship': c.relationship ?? '',
      'phone': c.phone ?? 'No registrado',
      'birthdate': c.birthdate != null
          ? '${c.birthdate!.day}/${c.birthdate!.month}/${c.birthdate!.year}'
          : 'No registrado',
      'notes': c.notes ?? '',
      'records': recordsData,
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
          final contact = diarioState.getContactById(e.contactId);
          final categoryName = diarioState.categories
              .firstWhere(
                (c) => c.id == e.categoryId,
                orElse: () => DiarioCategory(id: '', contactId: '', name: 'General', icon: ''),
              )
              .name;
          return {
            'contactName': contact?.name ?? 'Desconocido',
            'contactNickname': contact?.nickname ?? '',
            'entryTitle': e.title,
            'category': categoryName,
            'details': e.contentData,
            'notes': e.contentText ?? '',
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

          if (inTitle || inText || inData || tokenMatch || contactMatch) {
            final categoryName = diarioState.categories
                .firstWhere(
                  (c) => c.id == e.categoryId,
                  orElse: () => DiarioCategory(id: '', contactId: '', name: 'General', icon: ''),
                )
                .name;

            final fieldsList = <String>[];
            e.contentData.forEach((key, val) {
              if (val != null && val.toString().trim().isNotEmpty) {
                fieldsList.add('$key: $val');
              }
            });

            matches.add({
              'contactName': contact?.name ?? 'Desconocido',
              'contactNickname': contact?.nickname ?? '',
              'entryTitle': e.title,
              'category': categoryName,
              'details': e.contentData,
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

      case 'getUpcomingBirthdays':
        final limit = int.tryParse(arguments['limit']?.toString() ?? '5') ?? 5;
        final list = diarioState.getUpcomingBirthdays(limit: limit);
        final now = DateTime.now();
        final bdaysData = list.map((b) {
          int? nextAge;
          if (b.birthdate != null) {
            int age = now.year - b.birthdate!.year;
            final bdayThisYear = DateTime(now.year, b.birthdate!.month, b.birthdate!.day);
            if (now.isAfter(bdayThisYear)) age += 1;
            nextAge = age;
          }
          return {
            'name': b.name,
            'formattedBirthdate': b.formattedBirthdate,
            'daysUntilBirthday': b.daysUntilBirthday,
            'nextAge': nextAge,
          };
        }).toList();

        final artifact = ChatArtifactModel(
          sessionId: sessionId,
          type: ArtifactType.table,
          title: 'Próximos Cumpleaños',
          content: list.map((b) => '| ${b.name} | ${b.formattedBirthdate ?? "N/A"} | en ${b.daysUntilBirthday} días |').join('\n'),
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

      case 'proposeCreateDiarioEntry':
        final title = (arguments['title']?.toString() ?? 'Nueva entrada').trim();
        final contentText = (arguments['contentText']?.toString() ?? '').trim();
        final contactName = arguments['contactName']?.toString().trim();
        final category = arguments['category']?.toString().trim() ?? 'salud';

        DiarioContact? targetContact;
        if (contactName != null && contactName.isNotEmpty) {
          targetContact = _findContact(contactName);
        }

        final contactDisplay = targetContact != null
            ? targetContact.name
            : (contactName != null && contactName.isNotEmpty ? contactName : 'General');

        final summaryList = <Map<String, String>>[
          {'label': 'Título', 'value': title},
          {'label': 'Contacto', 'value': contactDisplay},
          if (category.isNotEmpty) {'label': 'Categoría', 'value': category},
          {'label': 'Detalle', 'value': contentText.length > 80 ? '${contentText.substring(0, 80)}...' : contentText},
        ];

        final artifact = ChatArtifactModel(
          id: const Uuid().v4(),
          sessionId: sessionId,
          type: ArtifactType.actionProposal,
          title: 'Nueva Entrada: $title',
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
              'category': category,
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
