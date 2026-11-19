/// Especificación única de las herramientas de escritura de Ortiz
/// (`docs/design/ortiz-registra.md` §2.2). De esta lista salen las dos
/// formas de declaración: `FunctionDeclaration` del SDK y el JSON de la API
/// REST, para que no puedan divergir (R-03).
library;

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../recordatorios/models/reminder_model.dart';

enum WriteToolParamType {
  string(SchemaType.string),
  number(SchemaType.number),
  integer(SchemaType.integer),
  boolean(SchemaType.boolean);

  final SchemaType schemaType;
  const WriteToolParamType(this.schemaType);
}

class WriteToolParam {
  final String name;
  final WriteToolParamType type;
  final String description;
  final bool required;

  /// Valores permitidos (solo para `string`).
  final List<String>? enumValues;

  const WriteToolParam(
    this.name,
    this.type,
    this.description, {
    this.required = false,
    this.enumValues,
  });
}

class WriteToolSpec {
  final String name;
  final String description;
  final List<WriteToolParam> params;

  const WriteToolSpec({
    required this.name,
    required this.description,
    required this.params,
  });

  List<String> get requiredParams =>
      [for (final p in params) if (p.required) p.name];
}

/// Nombres de las herramientas de escritura.
abstract final class WriteToolNames {
  static const registerTransaction = 'registerTransaction';
  static const payRecurringPayment = 'payRecurringPayment';
  static const registerDiarioEntry = 'registerDiarioEntry';
  static const createContact = 'createContact';
  static const createReminder = 'createReminder';
  static const createHabit = 'createHabit';
  static const logMood = 'logMood';
  static const markHabitDone = 'markHabitDone';
  static const createNote = 'createNote';
  static const undoLastAction = 'undoLastAction';
}

/// Niveles de `logMood` (§5), de peor a mejor (valence −2…2).
const List<String> moodLevels = [
  'muy_mal',
  'mal',
  'normal',
  'bien',
  'excelente',
];

const String _dateParamDescription =
    'Fecha en formato YYYY-MM-DD. Si la persona no dice otra («ayer», «el lunes»), omítela: se usa hoy.';

const String _resultHint =
    'Se guarda directo si todo está claro; si hay dudas devuelve una propuesta y si falta algo devuelve "missing" con lo que hay que preguntar.';

/// Lista única de especificaciones de las herramientas de escritura.
final List<WriteToolSpec> writeToolSpecs = List.unmodifiable([
  const WriteToolSpec(
    name: WriteToolNames.registerTransaction,
    description:
        'Registra un gasto o un ingreso en Finanzas. Usa solo el monto que dijo la persona: nunca lo inventes ni lo estimes. $_resultHint',
    params: [
      WriteToolParam('concept', WriteToolParamType.string,
          'Concepto o descripción del movimiento (ej: "Gasolina", "Cobro freelance").',
          required: true),
      // No es obligatorio en el esquema: si la persona no lo dijo, el
      // ejecutor responde `missing: [amount]` y Ortiz pregunta.
      WriteToolParam('amount', WriteToolParamType.number,
          'Monto mayor que cero, tal como lo dijo la persona. Si no lo dijo, omítelo: se devuelve "missing" y hay que preguntarlo.'),
      WriteToolParam('type', WriteToolParamType.string,
          'Tipo: "expense" (gasto) o "income" (ingreso).',
          required: true, enumValues: ['expense', 'income']),
      WriteToolParam('currency', WriteToolParamType.string,
          'Moneda: "usd" (dólares), "ves" (bolívares, Bs) o "eur" (euros).',
          required: true, enumValues: ['usd', 'ves', 'eur']),
      WriteToolParam('categoryName', WriteToolParamType.string,
          'Nombre de la categoría tal como aparece en el contexto (del tipo pedido).',
          required: true),
      WriteToolParam('accountName', WriteToolParamType.string,
          'Nombre de la cuenta si la persona la dijo. Si no, omítela: se usa la predeterminada de la moneda.'),
      WriteToolParam('date', WriteToolParamType.string, _dateParamDescription),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.payRecurringPayment,
    description:
        'Marca como pagado un pago recurrente (ej: "ya pagué el internet"). Paga la ocurrencia pendiente más antigua. Si el monto es menor que lo pendiente, es un pago parcial. $_resultHint',
    params: [
      WriteToolParam('paymentName', WriteToolParamType.string,
          'Nombre del pago recurrente (ej: "Internet", "Alquiler").',
          required: true),
      WriteToolParam('amount', WriteToolParamType.number,
          'Monto pagado si la persona lo dijo. Si no, omítelo: se paga lo pendiente.'),
      WriteToolParam('accountName', WriteToolParamType.string,
          'Cuenta con la que se pagó si la persona la dijo. Si no, omítela.'),
      WriteToolParam('date', WriteToolParamType.string, _dateParamDescription),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.registerDiarioEntry,
    description:
        'Guarda una entrada en el Diario (personal o sobre un contacto): hechos, síntomas, gustos, medidas o comentarios. No crea contactos. $_resultHint',
    params: [
      WriteToolParam('contentText', WriteToolParamType.string,
          'Texto completo de la entrada.',
          required: true),
      WriteToolParam('title', WriteToolParamType.string,
          'Título si la persona lo dio. Si no, omítelo.'),
      WriteToolParam('contactName', WriteToolParamType.string,
          'Nombre o apodo del contacto al que se refiere, si aplica.'),
      WriteToolParam('templateName', WriteToolParamType.string,
          'Plantilla del Diario si aplica (ej: "Tallas de Ropa / Calzado", "Idea de Regalo / Deseo"). Si es una nota libre, omítela.'),
      WriteToolParam('date', WriteToolParamType.string, _dateParamDescription),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.createContact,
    description:
        'Crea un contacto en el Diario. Si la persona solo dice la edad, ponla en las notas: no inventes una fecha de nacimiento. $_resultHint',
    params: [
      WriteToolParam('name', WriteToolParamType.string,
          'Nombre del contacto.',
          required: true),
      WriteToolParam('nickname', WriteToolParamType.string, 'Apodo, si lo hay.'),
      WriteToolParam('relationship', WriteToolParamType.string,
          'Relación (ej: "Hermano", "Amiga", "Compañero").'),
      WriteToolParam('phone', WriteToolParamType.string,
          'Teléfono o WhatsApp, si lo dio.'),
      WriteToolParam('birthdate', WriteToolParamType.string,
          'Fecha de nacimiento YYYY-MM-DD, solo si la persona la dio completa.'),
      WriteToolParam('notes', WriteToolParamType.string,
          'Otros detalles (incluida la edad si solo dijo eso).'),
    ],
  ),
  WriteToolSpec(
    name: WriteToolNames.createReminder,
    description:
        'Crea un recordatorio o tarea. Necesita la fecha y hora: si la persona no la dijo, no la inventes (devuelve "missing" y pregunta). $_resultHint',
    params: [
      const WriteToolParam('title', WriteToolParamType.string,
          'Título del recordatorio.',
          required: true),
      const WriteToolParam('dueAt', WriteToolParamType.string,
          'Fecha y hora en ISO 8601 (ej: "2026-11-18T10:00:00"), según lo que dijo la persona.',
          required: true),
      WriteToolParam('priority', WriteToolParamType.string,
          'Prioridad, solo si la persona la indicó.',
          enumValues: [for (final p in ReminderPriority.values) p.code]),
      WriteToolParam('recurrence', WriteToolParamType.string,
          'Repetición, solo si la persona la indicó.',
          enumValues: [for (final r in ReminderRecurrence.values) r.code]),
      const WriteToolParam('notes', WriteToolParamType.string,
          'Notas adicionales.'),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.createHabit,
    description: 'Crea un hábito nuevo en Hábitos. $_resultHint',
    params: [
      WriteToolParam('title', WriteToolParamType.string,
          'Nombre del hábito (ej: "Meditar 10 min", "No comer azúcar").',
          required: true),
      WriteToolParam('isNegative', WriteToolParamType.boolean,
          'true si es un mal hábito que se quiere dejar; false si es uno que se quiere construir.'),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.logMood,
    description:
        'Registra el ánimo de hoy (balance del día; reemplaza el de hoy si ya había uno). Si lo que dice la persona no encaja en ningún nivel, no adivines: pregunta con los 5 niveles. $_resultHint',
    params: [
      WriteToolParam(
        'level',
        WriteToolParamType.string,
        'Nivel de ánimo según las palabras de la persona: '
            '"muy_mal" (fatal, horrible, pésimo, terrible, muy mal, destrozado); '
            '"mal" (mal, no muy bien, decaído, bajoneado, triste); '
            '"normal" (normal, regular, más o menos, ni bien ni mal, ahí vamos); '
            '"bien" (bien, contento, tranquilo, a gusto); '
            '"excelente" (excelente, muy bien, genial, feliz, de maravilla, increíble).',
        required: true,
        enumValues: moodLevels,
      ),
      WriteToolParam('note', WriteToolParamType.string,
          'Comentario de la persona sobre cómo se siente, si lo dio.'),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.markHabitDone,
    description:
        'Marca un hábito como hecho (ej: "ya leí hoy"). En un hábito de contador suma 1. $_resultHint',
    params: [
      WriteToolParam('habitName', WriteToolParamType.string,
          'Nombre del hábito tal como aparece en el contexto.',
          required: true),
      WriteToolParam('date', WriteToolParamType.string, _dateParamDescription),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.createNote,
    description:
        'Crea una nota o un acuerdo en Notas (ej: "anota un acuerdo: …"). $_resultHint',
    params: [
      WriteToolParam('text', WriteToolParamType.string,
          'Texto de la nota o del acuerdo.',
          required: true),
      WriteToolParam('title', WriteToolParamType.string,
          'Título si la persona lo dio. Si no, omítelo.'),
      WriteToolParam('kind', WriteToolParamType.string,
          '"acuerdo" si la persona habla de un acuerdo; si no, "nota".',
          enumValues: ['nota', 'acuerdo']),
      WriteToolParam('categoryName', WriteToolParamType.string,
          'Categoría de Notas si la persona la dijo.'),
    ],
  ),
  const WriteToolSpec(
    name: WriteToolNames.undoLastAction,
    description:
        'Deshace un registro que Ortiz hizo en esta conversación (ej: "deshaz eso", "no, bórralo"). Sin undoId deshace el último.',
    params: [
      WriteToolParam('undoId', WriteToolParamType.string,
          'Identificador de deshacer devuelto al guardar. Si no se sabe, omítelo.'),
    ],
  ),
]);

/// Busca una especificación por nombre.
WriteToolSpec? writeToolSpecByName(String name) {
  for (final spec in writeToolSpecs) {
    if (spec.name == name) return spec;
  }
  return null;
}

Schema _paramSchema(WriteToolParam p) => Schema(
      p.type.schemaType,
      description: p.description,
      enumValues: p.enumValues,
      format: p.enumValues == null ? null : 'enum',
    );

/// Declaraciones para el SDK `google_generative_ai` (`getDeclaredTools`).
List<FunctionDeclaration> writeToolFunctionDeclarations([
  List<WriteToolSpec>? specs,
]) {
  return [
    for (final spec in specs ?? writeToolSpecs)
      FunctionDeclaration(
        spec.name,
        spec.description,
        Schema(
          SchemaType.object,
          properties: {for (final p in spec.params) p.name: _paramSchema(p)},
          requiredProperties:
              spec.requiredParams.isEmpty ? null : spec.requiredParams,
        ),
      ),
  ];
}

/// Declaraciones en JSON para la API REST, con el mismo formato que
/// `SuiteRagService.getToolsJson()` (cada elemento va dentro de
/// `functionDeclarations`).
List<Map<String, dynamic>> writeToolDeclarationsJson([
  List<WriteToolSpec>? specs,
]) {
  return [
    for (final spec in specs ?? writeToolSpecs)
      {
        'name': spec.name,
        'description': spec.description,
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            for (final p in spec.params)
              p.name: {
                'type': p.type.schemaType.toJson(),
                if (p.enumValues != null) 'format': 'enum',
                'description': p.description,
                if (p.enumValues != null) 'enum': List<String>.from(p.enumValues!),
              },
          },
          if (spec.requiredParams.isNotEmpty) 'required': spec.requiredParams,
        },
      },
  ];
}
