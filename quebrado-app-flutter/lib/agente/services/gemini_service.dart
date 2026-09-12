import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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

  GeminiService({required this.ragService});

  GenerativeModel _createModel() {
    final liveSnapshot = ragService.generateLiveContextSnapshot();

    return GenerativeModel(
      model: GeminiConfig.selectedModel,
      apiKey: GeminiConfig.apiKey,
      systemInstruction: Content.system('''
Eres el Asistente Personal Inteligente y Mayordomo Digital de José Ortiz (Jottache) dentro de su suite personal OrtizApp.
Tienes acceso total en tiempo real a los datos y módulos de la suite:
1. Finanzas (Quebrado): cuentas bancarias, balances en USD y Bs., pagos recurrentes, deudas y tasas oficiales (Dólar BCV y Euro).
2. Contactos y Vínculos (Diario Jottache): amigos, familiares, notas personales, teléfonos, cumpleaños y campos personalizados como placas de autos o vehículos.
3. Hábitos y Rutinas: hábitos positivos y negativos, cumplimiento de metas hoy y mejores rachas.
4. Recordatorios: tareas pendientes, vencidas, programadas para hoy, recurrencias (semanal, quincenal, mensual) y prioridades.

$liveSnapshot

Directrices de Respuesta:
- Sé conciso, claro y directo al grano en español. Evita saludos largos innecesarios.
- Cuando te pregunten sobre personas, placas de autos, cumpleaños o tareas, invoca siempre las herramientas correspondientes para obtener datos reales actualizados.
- Cuando te pidan cálculos financieros o conversiones de moneda, usa la tasa oficial actual del BCV y muestra el cálculo de forma clara y ordenada.
- Emplea formato Markdown elegante (negritas, viñetas y tablas) para que la información sea fácil de leer de un vistazo.
'''),
      tools: ragService.getDeclaredTools(),
    );
  }

  /// Envía un mensaje con soporte para streaming y ejecución de Function Calling
  Stream<GeminiStreamResponse> sendMessageStream({
    required String prompt,
    required List<ChatMessageModel> previousMessages,
    required String sessionId,
  }) async* {
    if (!GeminiConfig.isConfigured) {
      yield GeminiStreamResponse(
        textChunk: '⚠️ No se ha configurado la API Key de Gemini. Por favor, ingrésala en la configuración de la app o en el archivo .env.',
        fullText: '⚠️ No se ha configurado la API Key de Gemini. Por favor, ingrésala en la configuración de la app o en el archivo .env.',
        isDone: true,
      );
      return;
    }

    final model = _createModel();

    // 1. Convertir historial previo a Content de Gemini
    final history = <Content>[];
    for (final msg in previousMessages.take(15)) {
      if (msg.isUser) {
        history.add(Content.text(msg.content));
      } else if (msg.isModel && msg.content.isNotEmpty) {
        history.add(Content.model([TextPart(msg.content)]));
      }
    }

    // Agregar el mensaje actual del usuario
    final currentContent = Content.text(prompt);
    final conversation = [...history, currentContent];

    final collectedArtifacts = <ChatArtifactModel>[];
    final executedTools = <Map<String, dynamic>>[];
    String accumulatedText = '';

    try {
      // 2. Primera llamada (puede devolver texto o llamadas a funciones)
      var response = await model.generateContent(conversation);

      // Si Gemini decide llamar a una o varias funciones (Tool Calling)
      while (response.functionCalls.isNotEmpty) {
        final functionCall = response.functionCalls.first;
        final fnName = functionCall.name;
        final fnArgs = functionCall.args;

        executedTools.add({
          'name': fnName,
          'args': fnArgs,
        });

        // Notificar que se está ejecutando la herramienta
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

        // Devolver la respuesta de la función a Gemini
        final functionResponse = Content.functionResponse(
          fnName,
          toolResult.resultData,
        );

        // Continuar el diálogo con la respuesta de la herramienta
        conversation.add(Content.model([FunctionCall(fnName, fnArgs)]));
        conversation.add(functionResponse);

        response = await model.generateContent(conversation);
      }

      // 3. Emitir el texto final resultante
      final finalText = response.text ?? 'He procesado tu consulta.';
      accumulatedText = finalText;

      yield GeminiStreamResponse(
        textChunk: finalText,
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
