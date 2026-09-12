import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_artifact_model.dart';
import '../services/gemini_service.dart';
import '../services/suite_rag_service.dart';
import '../services/agente_supabase_service.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';

class AgenteState extends ChangeNotifier {
  final AgenteSupabaseService _supabaseService = AgenteSupabaseService();
  GeminiService? _geminiService;
  SuiteRagService? _ragService;

  List<ChatSessionModel> _sessions = [];
  ChatSessionModel? _currentSession;
  List<ChatMessageModel> _messages = [];
  List<ChatArtifactModel> _allArtifacts = [];

  bool _isGenerating = false;
  String _statusMessage = '';
  bool _isLauncherChatExpanded = false;

  AgenteState() {
    _init();
  }

  // Getters
  List<ChatSessionModel> get sessions => _sessions;
  ChatSessionModel? get currentSession => _currentSession;
  List<ChatMessageModel> get messages => _messages;
  List<ChatArtifactModel> get allArtifacts => _allArtifacts;
  bool get isGenerating => _isGenerating;
  String get statusMessage => _statusMessage;
  bool get isLauncherChatExpanded => _isLauncherChatExpanded;

  void setLauncherChatExpanded(bool expanded) {
    if (_isLauncherChatExpanded != expanded) {
      _isLauncherChatExpanded = expanded;
      notifyListeners();
    }
  }

  void _init() async {
    await loadSessions();
    await loadAllArtifacts();
    if (_sessions.isNotEmpty) {
      await selectSession(_sessions.first.id);
    } else {
      await startNewSession();
    }
  }

  /// Actualiza las dependencias vivas de la suite para el motor RAG
  void updateDependencies({
    required AppState appState,
    required DiarioState diarioState,
    required HabitosState habitosState,
    required RemindersState remindersState,
  }) {
    _ragService = SuiteRagService(
      appState: appState,
      diarioState: diarioState,
      habitosState: habitosState,
      remindersState: remindersState,
    );
    _geminiService = GeminiService(ragService: _ragService!);
  }

  Future<void> loadSessions() async {
    _sessions = await _supabaseService.getSessions();
    notifyListeners();
  }

  Future<void> loadAllArtifacts() async {
    _allArtifacts = await _supabaseService.getAllArtifacts();
    notifyListeners();
  }

  Future<void> selectSession(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _currentSession = _sessions[idx];
    } else {
      _currentSession = ChatSessionModel(id: sessionId);
    }

    _messages = await _supabaseService.getMessages(sessionId);
    notifyListeners();
  }

  Future<void> startNewSession({String? initialTitle}) async {
    final newSession = ChatSessionModel(
      id: const Uuid().v4(),
      title: initialTitle ?? 'Nueva conversación',
    );
    _currentSession = newSession;
    _messages = [];

    await _supabaseService.saveSession(newSession);
    _sessions.insert(0, newSession);
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    await _supabaseService.deleteSession(sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      if (_sessions.isNotEmpty) {
        await selectSession(_sessions.first.id);
      } else {
        await startNewSession();
      }
    }
    notifyListeners();
  }

  /// Envía un mensaje en la sesión activa y procesa streaming + tool execution
  Future<void> sendMessage(String text) async {
    final cleanPrompt = text.trim();
    if (cleanPrompt.isEmpty || _isGenerating) return;

    if (_currentSession == null) {
      await startNewSession(initialTitle: cleanPrompt.length > 25 ? '${cleanPrompt.substring(0, 25)}...' : cleanPrompt);
    }

    final sessionId = _currentSession!.id;

    // 1. Mensaje del usuario
    final userMessage = ChatMessageModel(
      sessionId: sessionId,
      role: MessageRole.user,
      content: cleanPrompt,
    );

    _messages.add(userMessage);
    _isGenerating = true;
    _statusMessage = 'Pensando...';
    notifyListeners();

    // Guardar mensaje de usuario en Supabase
    _supabaseService.saveMessage(userMessage);

    // Si es el primer mensaje de la sesión, renombrar la sesión
    if (_messages.length <= 2 && _currentSession!.title == 'Nueva conversación') {
      final newTitle = cleanPrompt.length > 30 ? '${cleanPrompt.substring(0, 30)}...' : cleanPrompt;
      _currentSession = _currentSession!.copyWith(title: newTitle, updatedAt: DateTime.now());
      _supabaseService.saveSession(_currentSession!);
    }

    // 2. Placeholder para la respuesta del modelo en streaming
    final modelMessageId = const Uuid().v4();
    var modelMessage = ChatMessageModel(
      id: modelMessageId,
      sessionId: sessionId,
      role: MessageRole.model,
      content: '',
      isStreaming: true,
    );
    _messages.add(modelMessage);
    notifyListeners();

    if (_geminiService == null) {
      modelMessage = modelMessage.copyWith(
        content: 'Error: El motor del agente no está listo.',
        isStreaming: false,
      );
      _messages[_messages.length - 1] = modelMessage;
      _isGenerating = false;
      notifyListeners();
      return;
    }

    try {
      final stream = _geminiService!.sendMessageStream(
        prompt: cleanPrompt,
        previousMessages: _messages.where((m) => m.id != modelMessageId).toList(),
        sessionId: sessionId,
      );

      await for (final chunk in stream) {
        modelMessage = modelMessage.copyWith(
          content: chunk.fullText,
          artifacts: chunk.artifacts,
          toolCalls: chunk.toolCalls,
          isStreaming: !chunk.isDone,
        );

        if (chunk.toolCalls.isNotEmpty) {
          final lastTool = chunk.toolCalls.last['name']?.toString() ?? '';
          _statusMessage = 'Consultando $lastTool...';
        }

        final idx = _messages.indexWhere((m) => m.id == modelMessageId);
        if (idx != -1) {
          _messages[idx] = modelMessage;
          notifyListeners();
        }

        // Si se generaron artefactos nuevos, agregarlos a la lista global
        for (final art in chunk.artifacts) {
          if (!_allArtifacts.any((a) => a.id == art.id)) {
            _allArtifacts.insert(0, art);
          }
        }
      }

      // Finalizar mensaje
      modelMessage = modelMessage.copyWith(isStreaming: false);
      final finalIdx = _messages.indexWhere((m) => m.id == modelMessageId);
      if (finalIdx != -1) {
        _messages[finalIdx] = modelMessage;
      }

      // Guardar mensaje final y artefactos en Supabase
      await _supabaseService.saveMessage(modelMessage);

      // Actualizar timestamp de sesión
      _currentSession = _currentSession!.copyWith(updatedAt: DateTime.now());
      await _supabaseService.saveSession(_currentSession!);

      await loadSessions();
    } catch (e) {
      debugPrint('Error procesando respuesta de Gemini en AgenteState: $e');
      final finalIdx = _messages.indexWhere((m) => m.id == modelMessageId);
      if (finalIdx != -1) {
        _messages[finalIdx] = modelMessage.copyWith(
          content: 'Lo siento, ocurrió un error al procesar tu solicitud: $e',
          isStreaming: false,
        );
      }
    } finally {
      _isGenerating = false;
      _statusMessage = '';
      notifyListeners();
    }
  }
}
