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
4. Recordatorios: tareas pendientes, vencidas, programadas para hoy y prioridades.

$liveSnapshot

REGLAS CRÍTICAS DE RESPUESTA:
1. Respuestas Directas y Puntuales:
   - Si el usuario te pregunta por un dato o atributo específico de una persona o contacto (por ejemplo: SOLO la placa del carro, SOLO su teléfono, SOLO su cumpleaños, SOLO su modelo de auto, SOLO su talla de calzado o una nota específica):
     * Responde ÚNICAMENTE ese dato específico con una frase corta, precisa y directa (ejemplo: "La placa del automóvil de Judenys (Hyundai Stylus) es **210RD**.").
     * NUNCA respondas con una tarjeta o ficha completa de contacto (con relación, cumpleaños, teléfono, etc.) si el usuario solo te pidió un dato puntual.
   - Solo muestra la tarjeta o resumen completo del contacto si el usuario te lo solicita explícitamente (por ejemplo: "muéstrame la ficha de...", "dame toda la info de...", "quién es...").

2. Búsqueda Exhaustiva en Registros y Detalles:
   - Los datos específicos de las personas (como automóviles, placas, modelos, tallas de ropa, cuentas bancarias, regalos y notas) están guardados dentro de los `records` / registros del contacto en el Diario.
   - Al buscar información de vehículos, placas, tallas o preferencias, revisa siempre los `records` devueltos por `searchContacts` o invoca `getContactDetails` o `searchDiarioEntries`.
   - Recuerda que un contacto puede identificarse tanto por su nombre ("Judenys Borges") como por su apodo ("Yaku").

3. Estilo:
   - Sé conciso, elegante y directo al grano en español. Evita saludos largos innecesarios.
   - Destaca siempre los datos clave en negrita (ej: **210RD**, **Bs. 42.15**).
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
