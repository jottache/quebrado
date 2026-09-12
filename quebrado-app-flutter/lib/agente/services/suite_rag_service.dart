import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../diario/viewmodels/diario_state.dart';
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
            'searchContacts',
            'Busca en la libreta de contactos y diario personal por nombre, apodo, notas, placas de autos o relaciones.',
            Schema(
              SchemaType.object,
              properties: {
                'query': Schema(
                  SchemaType.string,
                  description: 'Texto a buscar (ej: "Juan", "médico", "placa AB123", "primo").',
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
            'Consulta los recordatorios y tareas pendientes, vencidas o programadas para hoy.',
            Schema(
              SchemaType.object,
              properties: {
                'filter': Schema(
                  SchemaType.string,
                  description: 'Filtro: "all", "overdue", "today", o "upcoming".',
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
        ],
      ),
    ];
  }

  /// Ejecución local de herramientas y generación automática de Artefactos estructurados
  Future<ToolExecutionResult> executeFunctionCall(
    String functionName,
    Map<String, dynamic> arguments, {
    required String sessionId,
  }) async {
    switch (functionName) {
      case 'searchContacts':
        final q = (arguments['query']?.toString() ?? '').toLowerCase().trim();
        final results = diarioState.contacts.where((c) {
          final inName = c.name.toLowerCase().contains(q);
          final inNickname = (c.nickname ?? '').toLowerCase().contains(q);
          final inPhone = (c.phone ?? '').toLowerCase().contains(q);
          final inNotes = (c.notes ?? '').toLowerCase().contains(q);
          final inRel = (c.relationship ?? '').toLowerCase().contains(q);
          return inName || inNickname || inPhone || inNotes || inRel;
        }).toList();

        final contactsData = results.map((c) => {
          'name': c.name,
          'nickname': c.nickname ?? '',
          'relationship': c.relationship ?? '',
          'phone': c.phone ?? 'No registrado',
          'birthdate': c.birthdate != null ? '${c.birthdate!.day}/${c.birthdate!.month}/${c.birthdate!.year}' : 'No registrado',
          'notes': c.notes ?? '',
        }).toList();

        ChatArtifactModel? artifact;
        if (results.isNotEmpty) {
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

        final remindersData = list.map((r) => {
          'id': r.id,
          'title': r.title,
          'priority': r.priority.label,
          'dueAt': r.dueAt?.toIso8601String(),
          'formattedDueTime': r.formattedDueTime,
          'isRecurring': r.isRecurring,
          'recurrence': r.recurrence.shortLabel,
          'tags': r.tags,
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

      default:
        return ToolExecutionResult(
          resultData: {'error': 'Función no reconocida: $functionName'},
        );
    }
  }
}
