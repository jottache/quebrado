import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gemini_config.dart';
import 'suite_rag_service.dart';
import '../models/chat_message_model.dart';
import '../models/chat_artifact_model.dart';

class GeminiStreamResponse {
  final String textChunk;
  final String fullText;
  final List<ChatArtifactModel> artifacts;
  final List<Map<String, dynamic>> toolCalls;
  final bool isDone;

  GeminiStreamResponse({
    required this.textChunk,
    required this.fullText,
    this.artifacts = const [],
    this.toolCalls = const [],
    this.isDone = false,
  });
}

class GeminiService {
  final SuiteRagService ragService;
  final http.Client _client;

  GeminiService({required this.ragService, http.Client? client})
      : _client = client ?? http.Client();

  String _buildSystemInstruction() {
    final liveSnapshot = ragService.generateLiveContextSnapshot();
    return '''
Eres el Asistente Personal Inteligente y Mayordomo Digital de José Ortiz (Jottache) dentro de su suite personal OrtizApp.
Tienes acceso total en tiempo real a los datos y módulos de la suite:
1. Finanzas (Quebrado): cuentas bancarias, balances en USD y Bs., pagos recurrentes, deudas y tasas oficiales (Dólar BCV y Euro).
2. Contactos y Vínculos (Diario Jottache): amigos, familiares, notas personales, teléfonos, cumpleaños y todos sus "Registros y Detalles" (categorías como Automóvil/Vehículo con marcas, modelos, placas y colores, Tallas de Ropa/Calzado, Cuentas Bancarias, Regalos, Preferencias, etc.).
3. Hábitos y Rutinas: hábitos personales, cumplimiento de hoy y mejores rachas.
4. Recordatorios y Agenda Semanal (Stephen Covey - Hábito 3: "Primero lo Primero"):
   - Roles vitales del usuario (Salud, Profesional, Familia, Finanzas), declaraciones de propósito y Grandes Rocas (Big Rocks).
   - Matriz de administración del tiempo de 4 cuadrantes (C1 Crisis, C2 Eficacia/Liderazgo Personal [foco primordial], C3 Engaño, C4 Desperdicio).
   - Cronograma semanal de 7 días flexibles y ritual dominical de planificación.

$liveSnapshot

SKILL FUNDAMENTAL: BASE DE DATOS LOCAL PRIMERO Y CONTEXTO CERRADO (LOCAL-FIRST GROUNDING):
1. Prioridad Absoluta de la Base de Datos Privada:
   - Toda consulta del usuario sobre fechas, salidas de videojuegos o películas, eventos, compras, tareas, notas, dinero o personas se refiere EXCLUSIVAMENTE a su base de datos personal.
   - NUNCA respondas con datos de internet, conocimiento enciclopédico ni fechas históricas/Wikipedia (por ejemplo, fechas de lanzamientos de consolas en los 90s o 2000s como Nintendo 64).
   - ANTES de formular cualquier respuesta, estás OBLIGADO a buscar en la base de datos local usando las herramientas disponibles.

2. Búsqueda Global y Multi-Módulo:
   - Si no estás seguro de en qué módulo específico se encuentra la información o la pregunta es abierta (ej: "cuando sale zelda oot?", "tengo algo de...", "cuánto debo de..."), ejecuta de inmediato `searchSuiteData(query)`.
   - Para consultas de la agenda semanal, tareas por día o Grandes Rocas, invoca `getWeeklySchedule` o `getRolesCompass`.
   - Para consultas específicas de tareas clásicas o salidas, invoca `getReminders`.
   - Si buscas en un módulo y no obtienes resultados, DEBES buscar en los otros módulos pertinentes antes de dar una respuesta negativa.

3. Manejo Honesto ante Ausencia de Datos (Sin Alucinaciones):
   - Si tras buscar en todas las herramientas NO existe registro en la suite, responde con total sinceridad y exactitud: "No encontré ningún recordatorio ni registro sobre [X] en tu base de datos. ¿Deseas que lo anote o cree un recordatorio?".
   - NUNCA sustituyas la ausencia de datos privados por respuestas genéricas de internet, salvo que el usuario use explícitamente palabras como "en internet", "según Google" o "en Wikipedia".

4. Respuestas Directas, Puntuales y Fechas Exactas:
   - Si el usuario te pregunta por un dato puntual (ej: la placa de un carro, el modelo, la fecha de un evento o recordatorio, los días que faltan):
     * Responde ÚNICAMENTE ese dato específico en una frase corta, precisa y directa con los datos clave en negrita (ej: "Según tus recordatorios, la **Salida de Zelda OOT** está programada para el **jueves 5 de noviembre de 2026** (faltan **53 días**).").
     * Utiliza siempre los campos `formattedDueDate` y `daysRemaining` entregados por las herramientas para cálculos de fechas y días restantes.
     * NUNCA envíes una tarjeta o ficha completa si solo te solicitaron un dato puntual.

5. Búsqueda Exhaustiva en Registros y Notas del Diario (Sin Depender de Títulos):
   - Las notas y entradas del Diario pueden no tener título. Al buscar información sobre un contacto o tema, NUNCA te limites a leer los títulos; DEBES inspeccionar siempre el contenido completo (`notes`, `contentText` y los campos de `details`).
   - El usuario suele escribir notas simples libres de cualquier tema sin título. Encuentra y extrae la información relevante directamente del texto de la nota.
   - Consulta `getContactDetails` o `searchDiarioEntries` si se trata de un atributo personal, nota o dato de un contacto.

6. Estilo:
   - Sé conciso, elegante y directo al grano en español. Evita saludos innecesarios.
   - Destaca siempre los datos clave en negrita (ej: **210RD**, **5 de noviembre de 2026**, **53 días**, **Bs. 42.15**).

7. REGLAS DE ENCAMINAMIENTO Y CREACIÓN DE REGISTROS (HUMAN-IN-THE-LOOP):
   Cuando el usuario te pida registrar, guardar, anotar o crear algo, DEBES identificar con exactitud la aplicación/modelo destino basándote en las siguientes palabras clave y contextos:

   A. DIARIO JOTTACHE - ENTRADAS / NOTAS / BITÁCORA (`proposeCreateDiarioEntry`):
      - PALABRAS CLAVE: "entrada", "nota", "anota", "apunte", "bitácora", "escribe en el diario", "registra que...", "guarda este dato/detalle", "anota esto", "agrega eso como una entrada".
      - CASOS DE USO: Sucesos ocurridos, observaciones personales, síntomas o estados de salud, gustos de personas, ideas de regalos, medidas o anécdotas.
      - IMPORTANTE: En el Diario del usuario, los registros no se dividen por "categorías de salud", sino por **Modelos Reutilizables** o **Nota simple (Sin modelo)**. Proponla como "Nota simple".

   B. DIARIO JOTTACHE - NUEVO CONTACTO / PERSONA (`proposeCreateContact`):
      - PALABRAS CLAVE: "contacto", "persona", "amigo", "familiar", "agrega a [Nombre] como contacto", "nuevo contacto".

   C. RECORDATORIOS - TAREAS Y ALARMAS FUTURAS (`proposeCreateReminder`):
      - PALABRAS CLAVE: "recordatorio", "recuérdame", "recordar", "tarea", "pendiente", "alerta", "avísame", "no me dejes olvidar".
      - Solo usa `proposeCreateReminder` si el usuario pide programar un aviso o tarea futura.

   D. AGENDAR GRAN ROCA / HÁBITO 3 (`proposeScheduleBigRock`):
      - PALABRAS CLAVE: "gran roca", "roca", "prioridad de la semana", "agenda para mi salud/familia/trabajo", "objetivo semanal", "primero lo primero", "meta de cuadrante 2".
      - CASOS DE USO: Agendar una meta de alto impacto de un rol vital en un día de la semana.

   E. HÁBITOS Y RUTINAS (`proposeCreateHabit`):
      - PALABRAS CLAVE: "hábito", "rutina", "todos los días", "diariamente", "mal hábito", "romper hábito", "racha".

   F. FINANZAS QUEBRADO (`proposeCreateTransaction`):
      - PALABRAS CLAVE: "gasto", "ingreso", "pagué", "gasté", "cobré", "compré", "transferí", "dólares", "bolívares", "cuenta", "banco", "factura", "pago".

   Flujo de Confirmación (Human-in-the-Loop):
   - Cada una de estas herramientas genera automáticamente una tarjeta interactiva en el chat con los botones [Confirmar] y [Negar].
   - REGLA CRÍTICA DE INTERFAZ: Cuando invoques una herramienta de propuesta interactiva, NUNCA generes listas con viñetas ni repitas el resumen en el texto de tu respuesta.

8. COACHING EN HÁBITO 3 ("PRIMERO LO PRIMERO" - STEPHEN COVEY):
   - Cuando el usuario te pregunte cómo organizar su semana, pida sugerencias para su agenda o hable de equilibrar sus roles o gestionar el tiempo:
     * Consulta inmediatamente `getRolesCompass` y `getWeeklySchedule`.
     * Identifica los roles vitales desatendidos (aquellos con 0 Grandes Rocas esta semana). Menciona con tacto y sabiduría que el equilibrio es la base de la efectividad duradera.
     * Enseña el principio de las "Grandes Rocas primero": poner primero las metas del Cuadrante II (lo importante no urgente) antes de que la arena (urgencias del C3 y distracciones del C4) sature la semana.
     * Si el usuario acepta una sugerencia o pide agendar una meta prioritaria de un rol, invoca `proposeScheduleBigRock(title, roleName, dayOfWeek)` para desplegar la tarjeta interactiva de confirmación.

9. ENFOQUE EXCLUSIVO EN EL MENSAJE ACTUAL (SIN MEZCLAR CONVERSACIONES PREVIAS):
   - Responde ÚNICA Y EXCLUSIVAMENTE a la petición del MENSAJE ACTUAL del usuario.
   - NUNCA vuelvas a repetir ni menciones respuestas a consultas anteriores salvo que el usuario lo pida expresamente en este turno.
''';
  }

  /// Envía un mensaje con soporte para ejecución de Function Calling sin error de 'role function'
  Stream<GeminiStreamResponse> sendMessageStream({
    required String prompt,
    required List<ChatMessageModel> previousMessages,
    required String sessionId,
  }) async* {
    final apiKey = GeminiConfig.apiKey;
    final modelName = GeminiConfig.selectedModel;

    if (!GeminiConfig.isConfigured) {
      yield GeminiStreamResponse(
        textChunk: '⚠️ No se ha configurado la API Key de Gemini. Por favor, ingrésala en la configuración de la app o en el archivo .env.',
        fullText: '⚠️ No se ha configurado la API Key de Gemini. Por favor, ingrésala en la configuración de la app o en el archivo .env.',
        isDone: true,
      );
      return;
    }

    final contents = <Map<String, dynamic>>[];

    // 1. Historial previo
    for (final msg in previousMessages.take(15)) {
      if (msg.isUser) {
        contents.add({
          'role': 'user',
          'parts': [{'text': msg.content}],
        });
      } else if (msg.isModel && msg.content.isNotEmpty) {
        contents.add({
          'role': 'model',
          'parts': [{'text': msg.content}],
        });
      }
    }

    // 2. Mensaje actual
    contents.add({
      'role': 'user',
      'parts': [{'text': prompt}],
    });

    final toolsJson = ragService.getToolsJson();
    final systemInstruction = _buildSystemInstruction();

    final collectedArtifacts = <ChatArtifactModel>[];
    final executedTools = <Map<String, dynamic>>[];
    String accumulatedText = '';

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    try {
      bool continueLoop = true;
      int turns = 0;

      while (continueLoop && turns < 5) {
        turns++;

        final requestBody = {
          'contents': contents,
          'tools': toolsJson,
          'systemInstruction': {
            'parts': [{'text': systemInstruction}],
          },
        };

        final response = await _client.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode != 200) {
          String errMsg = 'Error ${response.statusCode} de Gemini';
          try {
            final errJson = jsonDecode(response.body);
            errMsg = errJson['error']?['message'] ?? errMsg;
          } catch (_) {}
          throw Exception(errMsg);
        }

        final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = responseJson['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('La API de Gemini no devolvió candidatos de respuesta.');
        }

        final candidate = candidates[0] as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List?) ?? [];

        // Verificar si contiene functionCall(s)
        final functionCallParts = parts.where((p) => p is Map && p.containsKey('functionCall')).toList();

        if (functionCallParts.isNotEmpty) {
          // Conservar la respuesta íntegra del modelo (incluye thoughtSignature, id, args)
          contents.add(content!);

          for (final fcp in functionCallParts) {
            final fnCall = fcp['functionCall'] as Map<String, dynamic>;
            final fnName = fnCall['name']?.toString() ?? '';
            final fnArgs = (fnCall['args'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

            executedTools.add({
              'name': fnName,
              'args': fnArgs,
            });

            yield GeminiStreamResponse(
              textChunk: '',
              fullText: accumulatedText.isNotEmpty ? accumulatedText : '🔍 Consultando ${fnName}...',
              artifacts: collectedArtifacts,
              toolCalls: executedTools,
            );

            // Ejecutar en el motor RAG de la suite
            final toolResult = await ragService.executeFunctionCall(
              fnName,
              fnArgs,
              sessionId: sessionId,
            );

            if (toolResult.generatedArtifact != null) {
              collectedArtifacts.add(toolResult.generatedArtifact!);
            }

            // Enviar la respuesta de la función con role 'user' compatible con Gemini 1.5, 2.x y 3.x
            contents.add({
              'role': 'user',
              'parts': [
                {
                  'functionResponse': {
                    'name': fnName,
                    'response': toolResult.resultData,
                  }
                }
              ],
            });
          }

          continue;
        }

        // Si no hay function calls, extraemos el texto generado
        final textParts = parts.where((p) => p is Map && p.containsKey('text')).map((p) => p['text'].toString()).join('\n');
        accumulatedText = textParts.isNotEmpty ? textParts : 'He procesado tu consulta.';
        continueLoop = false;
      }

      yield GeminiStreamResponse(
        textChunk: accumulatedText,
        fullText: accumulatedText,
        artifacts: collectedArtifacts,
        toolCalls: executedTools,
        isDone: true,
      );
    } catch (e, stack) {
      debugPrint('Error en GeminiService: $e\n$stack');
      yield GeminiStreamResponse(
        textChunk: 'Error al comunicarse con Gemini: $e',
        fullText: 'Error al comunicarse con Gemini: $e',
        artifacts: collectedArtifacts,
        toolCalls: executedTools,
        isDone: true,
      );
    }
  }
}
