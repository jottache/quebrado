import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_artifact_model.dart';
import '../models/agente_prompt_model.dart';
import '../models/agent_action_record.dart';
import '../models/undo_result.dart';
import '../services/gemini_service.dart';
import '../services/suite_rag_service.dart';
import '../services/write_tools/write_tool_contract.dart';
import '../../diario/viewmodels/animo_state.dart';
import '../../notas/viewmodels/notas_state.dart';
import '../services/agente_supabase_service.dart';
import '../widgets/ortiz_face.dart' show OrtizMood;
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
  bool _isInitialized = false;

  /// Cuánto dura la alegría de Ortiz tras [celebrate] (spec 02).
  static const Duration celebrateDuration = Duration(milliseconds: 1800);
  Timer? _celebrateTimer;

  /// Registros de Deshacer por conversación, solo en memoria (§4, PA-02).
  final Map<String, List<AgentActionRecord>> _actionsBySession = {};

  /// Estados con los que se construyó [_ragService] (para no rehacerlo en
  /// cada `notifyListeners` del ProxyProvider).
  List<Object?> _deps = const [];

  /// [geminiService] y [ragService] solo se inyectan en tests; en la app los
  /// crea [updateDependencies].
  AgenteState({
    bool autoInit = true,
    AgenteSupabaseService? supabaseService,
    @visibleForTesting GeminiService? geminiService,
    @visibleForTesting SuiteRagService? ragService,
  })  : _supabaseService = supabaseService ?? AgenteSupabaseService(),
        _geminiService = geminiService,
        _ragService = ragService {
    _wireRag();
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
  bool get isInitialized => _isInitialized;

  /// Ánimo de la cara de Ortiz (docs/design/ortiz-face.md §2.6): pensando
  /// mientras genera sin texto todavía; hablando cuando ya llega la
  /// respuesta; contento tras [celebrate] (solo gana al reposo); en reposo en
  /// otro caso.
  OrtizMood get ortizMood {
    if (_isGenerating) {
      final last = _messages.isEmpty ? null : _messages.last;
      return last != null && last.isModel && last.content.isNotEmpty
          ? OrtizMood.talking
          : OrtizMood.thinking;
    }
    return _celebrateTimer != null ? OrtizMood.happy : OrtizMood.idle;
  }

  /// Pone a Ortiz contento durante [celebrateDuration] (p. ej., al guardar
  /// algo) y luego vuelve al ánimo que toque.
  void celebrate() {
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(celebrateDuration, () {
      _celebrateTimer = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _celebrateTimer?.cancel();
    _celebrateTimer = null;
    super.dispose();
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
    required AnimoState animoState,
    required NotasState notasState,
  }) {
    final deps = [appState, diarioState, habitosState, remindersState, animoState, notasState];
    if (_ragService != null &&
        deps.length == _deps.length &&
        List.generate(deps.length, (i) => identical(deps[i], _deps[i])).every((same) => same)) {
      return;
    }
    _deps = deps;
    _ragService = SuiteRagService(
      appState: appState,
      diarioState: diarioState,
      habitosState: habitosState,
      remindersState: remindersState,
      animoState: animoState,
      notasState: notasState,
    );
    _wireRag();
    _geminiService = GeminiService(ragService: _ragService!);
  }

  void _wireRag() {
    final rag = _ragService;
    if (rag == null) return;
    rag.onWriteSaved = _onWriteSaved;
    rag.onUndoRequested = (undoId) => undoId == null ? undoLast() : undoAction(undoId);
  }

  // ---------------------------------------------------------------------------
  // Registros de Ortiz: Deshacer y confirmar (spec 03, §4)
  // ---------------------------------------------------------------------------

  /// Registros de Deshacer de una conversación (solo lectura, para tests y UI).
  List<AgentActionRecord> actionsFor(String sessionId) =>
      List.unmodifiable(_actionsBySession[sessionId] ?? const []);

  void _onWriteSaved(AgentActionRecord? record) {
    if (record != null) {
      _actionsBySession.putIfAbsent(record.sessionId, () => []).add(record);
    }
    celebrate();
  }

  /// Texto de todos los mensajes de la persona de la conversación actual
  /// (ancla de montos, CA-10 §7.2).
  String get _userText =>
      _messages.where((m) => m.isUser).map((m) => m.content).join('\n');

  /// `true` si el artefacto tiene un registro no deshecho en la conversación
  /// actual. Tras recargar la app es `false` (el registro vivía en memoria).
  bool canUndo(String artifactId) {
    final list = _actionsBySession[_currentSession?.id] ?? const [];
    return list.any((r) => r.artifactId == artifactId && !r.undone);
  }

  /// Texto cuando deshacer falla por un error inesperado (el detalle va solo
  /// a `debugPrint`).
  static const String undoFailedMessage =
      'No pude deshacerlo. Inténtalo de nuevo o bórralo desde su app.';

  /// Deshace un registro de la conversación actual. [UndoResult.ok] dice si
  /// se deshizo; si no, [UndoResult.message] trae el motivo en español
  /// (p. ej. «Cambia al libro X para deshacerlo.»).
  Future<UndoResult> undoAction(String undoId) async {
    final list = _actionsBySession[_currentSession?.id] ?? const <AgentActionRecord>[];
    AgentActionRecord? record;
    for (final r in list) {
      if (r.undoId == undoId) record = r;
    }
    if (record == null) {
      return const UndoResult.failed(SuiteRagService.nothingToUndoMessage);
    }
    if (record.undone) return const UndoResult.failed('Ya estaba deshecho.');
    final rag = _ragService;
    if (rag == null) {
      return const UndoResult.failed(
          'No pude deshacerlo: el motor del agente no está listo.');
    }
    try {
      await rag.undoWrite(record.toolName, record.undoPayload);
    } on StateError catch (e) {
      // Los ejecutores lanzan StateError con un motivo en español para la
      // persona (p. ej. el libro equivocado).
      return UndoResult.notice(e.message);
    } catch (e) {
      // Sin datos personales: solo la herramienta y el tipo de error.
      debugPrint('AgenteState.undoAction: falló deshacer ${record.toolName} (${e.runtimeType}).');
      return const UndoResult.failed(undoFailedMessage);
    }
    record.undone = true;
    await _updateArtifact(record.artifactId, (m) => m['status'] = 'undone');
    return const UndoResult.done();
  }

  /// Deshace el último registro no deshecho de la conversación actual.
  Future<UndoResult> undoLast() async {
    final list = _actionsBySession[_currentSession?.id] ?? const <AgentActionRecord>[];
    for (final r in list.reversed) {
      if (!r.undone) return undoAction(r.undoId);
    }
    return const UndoResult.failed(SuiteRagService.nothingToUndoMessage);
  }

  /// Tarjetas que se están confirmando ahora (evita un doble guardado).
  final Set<String> _confirming = {};

  /// Confirma una tarjeta de propuesta: vuelve a ejecutar la escritura con
  /// `commitArgs ⊕ choices` y la confirmación de la persona (§2.2, «un solo
  /// camino de guardado»). La metadata del artefacto pasa al estado
  /// resultante; si falta algo o falla, sigue `pending` con `lastError`.
  /// Es idempotente: si la tarjeta ya no está `pending` o se está
  /// confirmando, no hace nada.
  Future<void> confirmProposal(
    String artifactId, {
    Map<String, dynamic> choices = const {},
  }) async {
    final art = _findArtifact(artifactId);
    if (art == null || art.metadata['status'] != 'pending') return;
    if (!_confirming.add(artifactId)) return;
    try {
      await _confirmPending(art, choices);
    } finally {
      _confirming.remove(artifactId);
    }
  }

  Future<void> _confirmPending(
    ChatArtifactModel art,
    Map<String, dynamic> choices,
  ) async {
    final artifactId = art.id;
    final action = art.metadata['action']?.toString() ?? '';
    final commitArgs = art.metadata['commitArgs'];
    final rag = _ragService;

    // Tarjetas sin ejecutor (p. ej. Gran Roca): se conserva el comportamiento
    // anterior, solo se marca como confirmada.
    if (commitArgs is! Map || rag == null || !rag.hasWriteHandler(action)) {
      await _updateArtifact(artifactId, (m) => m['status'] = 'confirmed');
      return;
    }

    final outcome = await rag.runWrite(
      action,
      {...Map<String, dynamic>.from(commitArgs), ...choices},
      WriteContext(userText: _userText, confirmedByUser: true),
    );
    final result = outcome.result;
    if (result.isSaved) {
      final payload = outcome.undoPayload;
      final undoId = result.undoId ?? (payload != null ? const Uuid().v4() : null);
      final metadata = SuiteRagService.artifactMetadataFor(outcome, undoId: undoId);
      await _updateArtifact(artifactId, (m) => m
        ..clear()
        ..addAll(metadata));
      _onWriteSaved(undoId != null && payload != null
          ? AgentActionRecord(
              undoId: undoId,
              sessionId: art.sessionId,
              artifactId: artifactId,
              toolName: action,
              profileId: outcome.profileId,
              undoPayload: payload,
            )
          : null);
    } else if (result.isProposal) {
      final metadata = SuiteRagService.artifactMetadataFor(outcome);
      await _updateArtifact(artifactId, (m) => m
        ..clear()
        ..addAll(metadata));
    } else {
      final message = result.isMissing
          ? 'Falta: ${result.missing.join(', ')}.'
          : (result.message ?? 'No pude registrarlo. No se guardó nada.');
      await _updateArtifact(artifactId, (m) => m['lastError'] = message);
    }
  }

  /// Niega una tarjeta de propuesta: queda «Cancelado» y no se guarda nada.
  /// Borra `commitArgs` antes de persistir (S3-07): la tarjeta cancelada no
  /// los usa y no se guardan copias de datos personales.
  Future<void> rejectProposal(String artifactId) async {
    final art = _findArtifact(artifactId);
    if (art == null || art.metadata['status'] != 'pending') return;
    if (_confirming.contains(artifactId)) return;
    await _updateArtifact(artifactId, (m) {
      m['status'] = 'cancelled';
      m.remove('commitArgs');
    });
  }

  /// Artefactos de un trozo del streaming fusionados con los del mensaje en
  /// la lista: si un artefacto ya está en el mensaje, gana el local (Gemini
  /// no cambia un artefacto tras crearlo; lo cambian confirmar, negar o
  /// deshacer mientras se genera).
  static List<ChatArtifactModel> mergeStreamedArtifacts(
    List<ChatArtifactModel> local,
    List<ChatArtifactModel> streamed,
  ) {
    final byId = {for (final a in local) a.id: a};
    return [for (final a in streamed) byId[a.id] ?? a];
  }

  ChatArtifactModel? _findArtifact(String artifactId) {
    for (final msg in _messages) {
      for (final a in msg.artifacts) {
        if (a.id == artifactId) return a;
      }
    }
    return null;
  }

  /// Cambia la metadata del artefacto en su mensaje (y en la lista global),
  /// notifica y persiste el mensaje con sus artefactos.
  Future<bool> _updateArtifact(
    String artifactId,
    void Function(Map<String, dynamic> metadata) mutate,
  ) async {
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final idx = msg.artifacts.indexWhere((a) => a.id == artifactId);
      if (idx == -1) continue;
      final old = msg.artifacts[idx];
      final metadata = Map<String, dynamic>.from(old.metadata);
      mutate(metadata);
      final updated = old.copyWith(metadata: metadata, messageId: old.messageId ?? msg.id);
      final artifacts = List<ChatArtifactModel>.from(msg.artifacts)..[idx] = updated;
      final newMsg = msg.copyWith(artifacts: artifacts);
      _messages[i] = newMsg;
      final g = _allArtifacts.indexWhere((a) => a.id == artifactId);
      if (g != -1) _allArtifacts[g] = updated;
      notifyListeners();
      if (!newMsg.isStreaming) await _supabaseService.saveMessage(newMsg);
      return true;
    }
    return false;
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
    _actionsBySession.remove(sessionId);
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

    // Turno nuevo para el ejecutor (CA-10): ancla de montos y flags a cero.
    _ragService?.beginTurn(_userText);

    try {
      final stream = _geminiService!.sendMessageStream(
        prompt: cleanPrompt,
        previousMessages: _messages.where((m) => m.id != modelMessageId).toList(),
        sessionId: sessionId,
      );

      await for (final chunk in stream) {
        final shownIdx = _messages.indexWhere((m) => m.id == modelMessageId);
        final shown = shownIdx != -1 ? _messages[shownIdx] : modelMessage;
        modelMessage = modelMessage.copyWith(
          content: chunk.fullText,
          artifacts: mergeStreamedArtifacts(shown.artifacts, chunk.artifacts),
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

      // Finalizar mensaje. Los artefactos llevan el id del mensaje para que
      // `getMessages` los vuelva a unir al recargar (status/route incluidos).
      // Se parte del mensaje en la lista: puede tener metadata ya cambiada.
      final finalIdx = _messages.indexWhere((m) => m.id == modelMessageId);
      final current = finalIdx != -1 ? _messages[finalIdx] : modelMessage;
      modelMessage = current.copyWith(
        isStreaming: false,
        artifacts: [
          for (final a in current.artifacts)
            a.messageId == null ? a.copyWith(messageId: modelMessageId) : a,
        ],
      );
      if (finalIdx != -1) {
        _messages[finalIdx] = modelMessage;
      }
      for (final a in modelMessage.artifacts) {
        final g = _allArtifacts.indexWhere((x) => x.id == a.id);
        if (g != -1) _allArtifacts[g] = a;
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
