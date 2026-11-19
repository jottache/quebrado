import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../quebrado/models/currency_type.dart';
import '../../quebrado/models/transaction_category.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../diario/diario.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../../recordatorios/models/reminder_model.dart';
import '../../recordatorios/models/role_model.dart';
import '../models/chat_artifact_model.dart';
import '../../diario/viewmodels/animo_state.dart';
import '../../notas/viewmodels/notas_state.dart';
import '../models/agent_action_record.dart';
import '../models/undo_result.dart';
import 'write_tools/animo_write_tools.dart';
import 'write_tools/diario_write_tools.dart';
import 'write_tools/finanzas_write_tools.dart';
import 'write_tools/habitos_write_tools.dart';
import 'write_tools/notas_write_tools.dart';
import 'write_tools/ortiz_resolver.dart' show currencyParam;
import 'write_tools/reminders_write_tools.dart';
import 'write_tools/write_tool_contract.dart';
import 'write_tools/write_tool_result.dart';
import 'write_tools/write_tool_specs.dart';

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
  final AnimoState? animoState;
  final NotasState? notasState;

  /// Ejecutores de escritura por nombre de herramienta (spec 03).
  final Map<String, WriteToolHandler> _writeHandlers;

  /// Se llama tras cada `saved` directo (no al confirmar una tarjeta, que lo
  /// gestiona `AgenteState`). [record] es nulo si no hay nada que deshacer.
  void Function(AgentActionRecord? record)? onWriteSaved;

  /// Atiende `undoLastAction`: recibe el `undoId` (o null = el último) y
  /// devuelve si se deshizo y el texto para la persona.
  Future<UndoResult> Function(String? undoId)? onUndoRequested;

  final Uuid _uuid = const Uuid();

  // Estado del turno en curso (CA-10, §7).
  String _turnUserText = '';

  /// Se leyó texto libre en este turno.
  bool _untrustedRead = false;

  /// Se leyó texto libre en el turno anterior: se hereda un turno y luego se
  /// limpia (S3-03).
  bool _inheritedUntrustedRead = false;

  /// Ya hubo una escritura directa en este turno (bloquea deshacer).
  bool _directWriteDone = false;

  /// Escrituras directas de este turno.
  int _directWrites = 0;

  /// Tope de escrituras directas por mensaje: desde la siguiente salen como
  /// tarjeta (`too_many_writes`). Alto para no estorbar el uso normal
  /// (auditoría del 2026-11-19, I-2).
  static const int maxDirectWritesPerMessage = 5;

  /// Lista blanca (S3-01): lecturas que solo devuelven números, fechas y
  /// nombres saneados como los del contexto ([contextLine]). Son las únicas
  /// lecturas que NO marcan el turno.
  static const Set<String> trustedReadTools = {
    'getFinancialOverview',
    'calculateCurrencyExchange',
  };

  /// Lecturas con texto libre escrito por la persona o por terceros (notas,
  /// títulos, nombres, propósitos). Es documental: cualquier herramienta que
  /// no sea escritura ni esté en [trustedReadTools] marca el turno, aunque no
  /// esté aquí. `proposeScheduleBigRock` va aquí porque no escribe y devuelve
  /// nombres de roles.
  static const Set<String> untrustedReadTools = {
    'searchSuiteData',
    'searchContacts',
    'getContactDetails',
    'searchDiarioEntries',
    'getPersonalNotes',
    'getUpcomingBirthdays',
    'getHabitsStatus',
    'getReminders',
    'getWeeklySchedule',
    'getRolesCompass',
    'proposeScheduleBigRock',
  };

  /// Texto de `undoLastAction` cuando el turno leyó texto libre (S3-04).
  static const String undoBlockedMessage =
      'Para deshacer un registro usa el botón Deshacer de su mensaje.';

  /// Texto de `undoLastAction` cuando no hay registros en la conversación.
  static const String nothingToUndoMessage =
      'No hay nada que deshacer en esta conversación.';

  /// Largo máximo de un nombre en el contexto vivo (S3-02).
  static const int contextNameMaxLength = 60;

  /// Sanea un nombre para el contexto (S3-02): una sola línea, sin
  /// caracteres de control, espacios colapsados y como mucho
  /// [contextNameMaxLength] caracteres (con «…» si se corta).
  static String contextLine(String text) {
    final flat = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F  ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final chars = flat.runes.toList();
    if (chars.length <= contextNameMaxLength) return flat;
    return '${String.fromCharCodes(chars.take(contextNameMaxLength - 1)).trimRight()}…';
  }

  /// [writeHandlers] solo se inyecta en tests; por defecto se construyen los
  /// ejecutores de cada dominio (Ánimo y Notas solo si se pasan sus estados).
  SuiteRagService({
    required this.appState,
    required this.diarioState,
    required this.habitosState,
    required this.remindersState,
    this.animoState,
    this.notasState,
    List<WriteToolHandler>? writeHandlers,
    this.onWriteSaved,
    this.onUndoRequested,
  }) : _writeHandlers = {
          for (final h in writeHandlers ??
              [
                FinanzasWriteTools(appState),
                DiarioWriteTools(diarioState),
                HabitosWriteTools(habitosState, diario: diarioState),
                RemindersWriteTools(remindersState),
                if (animoState != null) AnimoWriteTools(animoState),
                if (notasState != null) NotasWriteTools(notasState),
              ])
            for (final name in h.toolNames) name: h,
        };

  /// Contexto de escritura del turno en curso.
  WriteContext get turnContext => WriteContext(
        userText: _turnUserText,
        untrustedRead: turnUntrusted,
        writeLimitReached: _directWrites >= maxDirectWritesPerMessage,
      );

  /// `true` si este turno o el anterior leyeron texto libre (CA-10, S3-03).
  bool get turnUntrusted => _untrustedRead || _inheritedUntrustedRead;

  /// Empieza un turno nuevo: [userText] es el texto de todos los mensajes de
  /// la persona en la conversación (ancla de montos). La marca de texto libre
  /// leído pasa al turno nuevo como heredada y se limpia en el siguiente
  /// (S3-03); la escritura directa se reinicia.
  void beginTurn(String userText) {
    _turnUserText = userText;
    _inheritedUntrustedRead = _untrustedRead;
    _untrustedRead = false;
    _directWriteDone = false;
    _directWrites = 0;
  }

  /// `true` si [toolName] es una lectura que marca el turno: toda la que no
  /// sea escritura, `undoLastAction` ni esté en [trustedReadTools] (S3-01).
  bool marksTurnUntrusted(String toolName) =>
      toolName != WriteToolNames.undoLastAction &&
      !_writeHandlers.containsKey(toolName) &&
      !trustedReadTools.contains(toolName);

  /// `true` si hay un ejecutor para [toolName].
  bool hasWriteHandler(String toolName) => _writeHandlers.containsKey(toolName);

  /// Ejecuta una escritura con [ctx]. Nunca lanza: un fallo inesperado del
  /// ejecutor sale como `error`.
  Future<WriteOutcome> runWrite(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    final handler = _writeHandlers[toolName];
    if (handler == null) {
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: 'No pude registrarlo: no sé hacer «$toolName». No se guardó nada.',
      ));
    }
    try {
      return await handler.execute(toolName, args, ctx);
    } catch (e) {
      // Solo el tipo: el texto del error puede llevar datos personales y no
      // debe llegar a Gemini ni a la tarjeta (como en AgenteState.undoAction).
      debugPrint('SuiteRagService.runWrite: falló $toolName (${e.runtimeType}).');
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: 'No pude registrarlo. No se guardó nada.',
      ));
    }
  }

  /// Deshace una escritura. Lanza si no se pudo. Al deshacer un contacto
  /// borra también sus registros de ánimo en memoria (como la pantalla del
  /// contacto; en la base los borra la cascada).
  Future<void> undoWrite(String toolName, Map<String, dynamic> undoPayload) async {
    final handler = _writeHandlers[toolName];
    if (handler == null) throw StateError('No sé deshacer «$toolName».');
    await handler.undo(toolName, undoPayload);
    if (toolName == WriteToolNames.createContact) {
      final contactId = undoPayload['contactId'] as String?;
      if (contactId != null) animoState?.removeLogsForContact(contactId);
    }
  }

  /// Metadata del artefacto para un `saved` o un `proposal` (§2.1).
  static Map<String, dynamic> artifactMetadataFor(
    WriteOutcome outcome, {
    String? undoId,
  }) {
    final r = outcome.result;
    final parts = [for (final p in outcome.summaryParts) p.toJson()];
    if (r.isSaved) {
      return {
        'status': 'saved',
        'action': r.action,
        'recordId': r.recordId,
        'summary': r.summary,
        'summaryTitle': outcome.summaryTitle,
        'summaryParts': parts,
        'route': r.route,
        'undoId': undoId ?? r.undoId,
      };
    }
    return {
      'status': 'pending',
      'action': r.action,
      'reasons': List<String>.from(r.reasons),
      'summary': r.summary,
      'summaryTitle': outcome.summaryTitle,
      'summaryParts': parts,
      'resolved': Map<String, dynamic>.from(r.resolved),
      'options': {
        for (final e in r.options.entries) e.key: List<String>.from(e.value),
      },
      // Solo para la tarjeta («Ver todas»); no va al modelo.
      'allOptions': {
        for (final e in outcome.allOptions.entries) e.key: List<String>.from(e.value),
      },
      'commitArgs': Map<String, dynamic>.from(outcome.commitArgs ?? const {}),
    };
  }

  Future<ToolExecutionResult> _executeWrite(
    String toolName,
    Map<String, dynamic> arguments,
    String sessionId,
  ) async {
    final outcome = await runWrite(toolName, arguments, turnContext);
    final result = outcome.result;
    if (!result.isSaved && !result.isProposal) {
      return ToolExecutionResult(resultData: result.toJson());
    }

    final resultData = result.toJson();
    String? undoId;
    if (result.isSaved) {
      _directWriteDone = true;
      _directWrites++;
      undoId = result.undoId ??
          (outcome.undoPayload != null ? _uuid.v4() : null);
      if (undoId != null) resultData['undoId'] = undoId;
    }
    final artifact = ChatArtifactModel(
      sessionId: sessionId,
      type: ArtifactType.actionProposal,
      title: outcome.summaryTitle ?? result.summary ?? toolName,
      content: result.summary ?? '',
      metadata: artifactMetadataFor(outcome, undoId: undoId),
    );
    if (result.isSaved) {
      final payload = outcome.undoPayload;
      onWriteSaved?.call(undoId != null && payload != null
          ? AgentActionRecord(
              undoId: undoId,
              sessionId: sessionId,
              artifactId: artifact.id,
              toolName: toolName,
              profileId: outcome.profileId,
              undoPayload: payload,
            )
          : null);
    }
    return ToolExecutionResult(resultData: resultData, generatedArtifact: artifact);
  }

  Future<ToolExecutionResult> _executeUndoLast(Map<String, dynamic> arguments) async {
    final undoId = arguments['undoId']?.toString();
    final handler = onUndoRequested;
    // Tras leer texto libre (este turno o el anterior) Ortiz no deshace: lo
    // hace la persona con el botón del mensaje (S3-04).
    final UndoResult result;
    if (turnUntrusted) {
      result = const UndoResult.failed(undoBlockedMessage);
    } else if (handler == null) {
      result = const UndoResult.failed(nothingToUndoMessage);
    } else if (_directWriteDone) {
      // Tras escribir en este mensaje, Ortiz no deshace (lo hace la persona
      // con el botón). Un deshacer exitoso marca el turno igual, pero ya no
      // impide escribir después: el tope es [maxDirectWritesPerMessage].
      result = const UndoResult.failed(undoBlockedMessage);
    } else {
      result = await handler(undoId == null || undoId.isEmpty ? null : undoId);
      if (result.ok) _directWriteDone = true;
    }
    return ToolExecutionResult(resultData: {
      'status': result.ok ? 'undone' : 'error',
      'action': WriteToolNames.undoLastAction,
      'message': result.message,
    });
  }

  /// Ejecuta una herramienta: escrituras por su ejecutor, `undoLastAction`
  /// por [onUndoRequested] y el resto como lecturas. Toda lectura fuera de
  /// [trustedReadTools] marca el turno (antes de leer, también si falla) y
  /// va envuelta en `untrusted_content` (CA-10, S3-01).
  Future<ToolExecutionResult> executeFunctionCall(
    String functionName,
    Map<String, dynamic> arguments, {
    required String sessionId,
  }) async {
    if (functionName == WriteToolNames.undoLastAction) {
      return _executeUndoLast(arguments);
    }
    if (_writeHandlers.containsKey(functionName)) {
      return _executeWrite(functionName, arguments, sessionId);
    }
    final untrusted = marksTurnUntrusted(functionName);
    if (untrusted) _untrustedRead = true;
    final res = await _executeReadTool(functionName, arguments, sessionId: sessionId);
    if (untrusted) {
      return ToolExecutionResult(
        resultData: {'untrusted_content': res.resultData},
        generatedArtifact: res.generatedArtifact,
      );
    }
    return res;
  }

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
            return '    · ${contextLine(r.name)}: $rockCount Grandes Rocas definidas';
          }).join('\n');

    final unaddressedAlert = unaddressed.isNotEmpty
        ? '⚠️ ALERTA DE EQUILIBRIO VITAL: Hay ${unaddressed.length} roles vitales sin ninguna Gran Roca esta semana (${unaddressed.map((r) => contextLine(r.name)).join(", ")}).'
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
            return '- ${contextLine(b.name)}: ${b.formattedBirthdate ?? "Sin fecha"} (en ${b.daysUntilBirthday ?? "?"} días$ageStr)';
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

${generateRegistrationCatalogs(now: now)}''';
  }

  /// Tope de elementos por lista en [generateRegistrationCatalogs].
  static const int catalogListLimit = 60;

  /// Sección «CATÁLOGOS PARA REGISTRAR» del contexto (spec 03, diseño §7):
  /// los nombres que Ortiz puede pasar a las herramientas de escritura.
  /// Cuentas sin saldos; categorías con los mismos nombres que resuelve
  /// `FinanzasWriteTools` (sin «Cambio de Divisa», subcategorías
  /// «Padre › Hija»). Cada lista se corta en [catalogListLimit] y cada
  /// nombre pasa por [contextLine] (S3-02).
  String generateRegistrationCatalogs({DateTime? now}) {
    final today = now ?? DateTime.now();
    final iso = _isoDay(today);
    const weekDays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final readable = '${weekDays[today.weekday - 1]} ${today.day} de ${months[today.month - 1]} de ${today.year}';

    List<String> categoryNames(TransactionCategoryType type) => [
          for (final c in FinanzasWriteTools.categoryItemsFor(appState.categories, type))
            contextLine(c.displayName),
        ];

    final defaultIds = {
      for (final c in CurrencyType.values) appState.defaultAccountIdFor(c),
    }..remove(null);
    final accounts = [
      for (final a in appState.accounts)
        '${contextLine(a.name)} (${currencyParam(a.currency)})'
            '${defaultIds.contains(a.id) ? ' [predeterminada]' : ''}',
    ];

    final habits = [for (final h in habitosState.allHabits) contextLine(h.title)];

    final pendingByPayment = <String, DateTime>{};
    for (final o in appState.pendingPaymentsToday) {
      final prev = pendingByPayment[o.payment.id];
      if (prev == null || o.occurrenceDate.isBefore(prev)) {
        pendingByPayment[o.payment.id] = o.occurrenceDate;
      }
    }
    final payments = <String>[];
    for (final p in appState.recurringPayments) {
      final pending = pendingByPayment[p.id];
      final next = pending ?? FinanzasWriteTools.nextOccurrenceAfter(p, today);
      if (next == null) continue;
      final when = pending != null ? 'pendiente desde ${_isoDay(pending)}' : 'próxima ${_isoDay(next)}';
      final variable = p.isVariable ? ' (variable)' : '';
      payments.add('${contextLine(p.name)} · ${currencyParam(p.currency)} ${p.amount.toStringAsFixed(2)}$variable · $when');
    }

    final noteCategories = notasState == null
        ? const <String>[]
        : [for (final c in notasState!.categories) contextLine(c.name)];

    // Libros de Finanzas para `bookName` (el abierto marcado).
    final books = [
      for (final p in appState.profiles)
        if ((p['name'] ?? '').trim().isNotEmpty)
          '${contextLine(p['name']!)}'
              '${p['id'] == appState.activeDbName ? ' [abierto]' : ''}',
    ];

    return '''
### CATÁLOGOS PARA REGISTRAR (libro ${contextLine(appState.activeProfileName)}):
- Fecha de hoy: $iso ($readable)
- Libros de Finanzas (bookName; categorías y cuentas de abajo son del libro abierto):
${_catalogList(books)}
- Categorías de gasto:
${_catalogList(categoryNames(TransactionCategoryType.expense))}
- Categorías de ingreso:
${_catalogList(categoryNames(TransactionCategoryType.income))}
- Cuentas (nombre y moneda usd/ves/eur):
${_catalogList(accounts)}
- Hábitos activos:
${_catalogList(habits)}
- Pagos recurrentes (nombre · moneda y monto · fecha):
${_catalogList(payments)}
- Categorías de Notas:
${_catalogList(noteCategories)}
''';
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Lista con viñetas, cortada en [catalogListLimit] con «y N más».
  static String _catalogList(List<String> items) {
    if (items.isEmpty) return '  · (ninguna)';
    final shown = items.take(catalogListLimit).map((e) => '  · $e');
    final rest = items.length - catalogListLimit;
    return [...shown, if (rest > 0) '  · y $rest más'].join('\n');
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
          // Herramientas de escritura (spec 03): una sola lista de
          // especificaciones genera esta forma y la de `getToolsJson`.
          ...writeToolFunctionDeclarations(),
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
          // Herramientas de escritura (spec 03), misma fuente que el SDK.
          ...writeToolDeclarationsJson(),
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
  Future<ToolExecutionResult> _executeReadTool(
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

        // Lectura de la lista blanca (S3-01): al modelo solo le llegan los
        // nombres saneados, como en los catálogos del contexto.
        return ToolExecutionResult(
          resultData: {
            'totalBalanceUsd': totalUsd,
            'totalBalanceBs': totalBs,
            'bcvRate': appState.bcvRate,
            'euroRate': appState.euroRate,
            'accounts': [
              for (final a in accountsData) {...a, 'name': contextLine(a['name'] as String)},
            ],
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
        // Fin de semana → próxima semana; si el usuario está viendo otra semana, esa.
        final monday = remindersState.suggestedPlanningMonday;
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

      default:
        return ToolExecutionResult(
          resultData: {'error': 'Función no reconocida: $functionName'},
        );
    }
  }
}
