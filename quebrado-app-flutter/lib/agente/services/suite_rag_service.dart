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

  /// Especificación directa en formato JSON para la API REST de Gemini (soporte thoughtSignature y role user)
  List<Map<String, dynamic>> getToolsJson() {
    return [
      {
        'functionDeclarations': [
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
            'description': 'Consulta los recordatorios y tareas pendientes, vencidas o programadas para hoy.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'filter': {
                  'type': 'STRING',
                  'description': 'Filtro: "all", "overdue", "today", o "upcoming".',
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
        ],
      },
    ];
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
        final tokens = q.split(RegExp(r'[\s,]+')).where((t) => t.length > 1).toList();

        DiarioContact? contact;
        try {
          contact = diarioState.contacts.firstWhere((c) {
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
          contact = null;
        }

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
