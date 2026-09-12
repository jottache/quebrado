import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_artifact_model.dart';
import '../models/agente_prompt_model.dart';
import '../services/gemini_service.dart';
import '../services/suite_rag_service.dart';
import '../services/agente_supabase_service.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../quebrado/services/db_helper.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';

class AgenteState extends ChangeNotifier {
  final AgenteSupabaseService _supabaseService;
  GeminiService? _geminiService;
  SuiteRagService? _ragService;

  List<ChatSessionModel> _sessions = [];
  ChatSessionModel? _currentSession;
  List<ChatMessageModel> _messages = [];
  List<ChatArtifactModel> _allArtifacts = [];
  List<AgentePromptModel> _quickPrompts = [];

  bool _isGenerating = false;
  String _statusMessage = '';
  bool _isLauncherChatExpanded = false;
  bool _isInitialized = false;

  AgenteState({bool autoInit = true, AgenteSupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? AgenteSupabaseService() {
    if (autoInit) {
      _init();
    } else {
      _isInitialized = true;
    }
  }

  // Getters
  List<ChatSessionModel> get sessions => _sessions;
  ChatSessionModel? get currentSession => _currentSession;
  List<ChatMessageModel> get messages => _messages;
  List<ChatArtifactModel> get allArtifacts => _allArtifacts;
  List<AgentePromptModel> get quickPrompts => List.unmodifiable(_quickPrompts);
  bool get isGenerating => _isGenerating;
  String get statusMessage => _statusMessage;
  bool get isLauncherChatExpanded => _isLauncherChatExpanded;
  bool get isInitialized => _isInitialized;

  void setLauncherChatExpanded(bool expanded) {
    if (_isLauncherChatExpanded != expanded) {
      _isLauncherChatExpanded = expanded;
      notifyListeners();
    }
  }

  void _init() async {
    await loadSessions();
    await loadAllArtifacts();
    await loadQuickPrompts();
    if (_sessions.isNotEmpty) {
      await selectSession(_sessions.first.id);
    } else {
      await startNewSession();
    }
    _isInitialized = true;
    notifyListeners();
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

  Future<void> loadQuickPrompts() async {
    List<AgentePromptModel> loaded = [];

    // 1. Intentar cargar desde Supabase
    try {
      final remote = await _supabaseService.getPrompts();
      if (remote.isNotEmpty) {
        loaded = remote;
      }
    } catch (_) {}

    // 2. Si no hay remotos o falla, cargar desde SQLite
    if (loaded.isEmpty) {
      try {
        final localJson = await DatabaseHelper.instance
            .getSetting('agente_custom_prompts')
            .timeout(const Duration(milliseconds: 300));
        if (localJson != null && localJson.isNotEmpty) {
          final decoded = jsonDecode(localJson) as List;
          loaded = decoded.map((m) => AgentePromptModel.fromMap(Map<String, dynamic>.from(m))).toList();
        }
      } catch (_) {}
    }

    _quickPrompts = loaded;
    _sortPrompts();
    notifyListeners();
  }

  void _sortPrompts() {
    _quickPrompts.sort((a, b) {
      final orderComp = a.sortOrder.compareTo(b.sortOrder);
      if (orderComp != 0) return orderComp;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Future<void> _persistPromptsLocally() async {
    try {
      final listMap = _quickPrompts.map((p) => p.toMap()).toList();
      await DatabaseHelper.instance
          .setSetting('agente_custom_prompts', jsonEncode(listMap))
          .timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  void setQuickPrompts(List<AgentePromptModel> prompts) {
    _quickPrompts = List.from(prompts);
    _sortPrompts();
    notifyListeners();
  }

  Future<void> saveQuickPrompt(AgentePromptModel prompt, {bool persist = true}) async {
    final idx = _quickPrompts.indexWhere((p) => p.id == prompt.id);
    if (idx != -1) {
      _quickPrompts[idx] = prompt.copyWith(updatedAt: DateTime.now());
    } else {
      final newSortOrder = _quickPrompts.isNotEmpty
          ? (_quickPrompts.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1)
          : 0;
      _quickPrompts.add(prompt.copyWith(sortOrder: newSortOrder));
    }
    _sortPrompts();
    notifyListeners();

    if (persist) {
      await _persistPromptsLocally();
      await _supabaseService.savePrompt(prompt);
    }
  }

  Future<void> deleteQuickPrompt(String promptId, {bool persist = true}) async {
    _quickPrompts.removeWhere((p) => p.id == promptId);
    notifyListeners();

    if (persist) {
      await _persistPromptsLocally();
      await _supabaseService.deletePrompt(promptId);
    }
  }

  Future<void> reorderQuickPrompts(int oldIndex, int newIndex, {bool persist = true}) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _quickPrompts.removeAt(oldIndex);
    _quickPrompts.insert(newIndex, item);
    for (int i = 0; i < _quickPrompts.length; i++) {
      _quickPrompts[i] = _quickPrompts[i].copyWith(sortOrder: i);
    }
    notifyListeners();

    if (persist) {
      await _persistPromptsLocally();
      for (final p in _quickPrompts) {
        await _supabaseService.savePrompt(p);
      }
    }
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
