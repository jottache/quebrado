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
import '../models/daily_briefing.dart';
import '../services/daily_briefing_service.dart';
import '../services/gemini_service.dart';
import '../../theme/ortiz_motion.dart';
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

  /// `true` si [GeminiService] llegó por el constructor (tests):
  /// [updateDependencies] no lo reemplaza.
  final bool _geminiInjected;

  // Resumen del día (spec 04, docs/design/resumen-del-dia.md §5).
  final DateTime Function() _clock;
  final Duration _briefingLoadTimeout;
  final DailyBriefingSnapshot? Function(DateTime now)? _briefingSnapshotReader;
  final DailyBriefingService _briefingService;
  AppState? _appState;
  DiarioState? _diarioState;
  AnimoState? _animoState;
  HabitosState? _habitosState;
  RemindersState? _remindersState;
  DailyBriefing? _todayBriefing;
  String? _todayBriefingSignature;
  DailyBriefing? _liveBriefing;
  String? _liveBriefingMessageId;
  Completer<void>? _briefingLoadedWaiter;
  final Duration _briefingUnavailableAfter;
  Timer? _briefingUnavailableTimer;
  bool _briefingDeadlinePassed = false;
  bool _briefingScanning = false;
  bool _briefingRefreshPending = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Tope tras pedir el resumen: una sección que siga `loading` pasa a
  /// `unavailable` (diseño §5, R-01).
  static const Duration briefingUnavailableAfterDefault = Duration(seconds: 10);

  /// [geminiService] y [ragService] solo se inyectan en tests; en la app los
  /// crea [updateDependencies]. También para tests: [clock] (reloj del
  /// resumen del día), [briefingLoadTimeout] (espera máxima a que carguen
  /// los ViewModels; por defecto `OrtizMotion.scanMax`),
  /// [briefingUnavailableAfter] (tope para pasar a `unavailable`; por defecto
  /// [briefingUnavailableAfterDefault]) y [briefingSnapshotReader]
  /// (sustituye a `DailyBriefingSnapshot.fromStates`).
  AgenteState({
    bool autoInit = true,
    AgenteSupabaseService? supabaseService,
    @visibleForTesting GeminiService? geminiService,
    @visibleForTesting SuiteRagService? ragService,
    @visibleForTesting DateTime Function()? clock,
    @visibleForTesting Duration? briefingLoadTimeout,
    @visibleForTesting Duration? briefingUnavailableAfter,
    @visibleForTesting DailyBriefingSnapshot? Function(DateTime now)? briefingSnapshotReader,
    DailyBriefingService briefingService = const DailyBriefingService(),
  })  : _supabaseService = supabaseService ?? AgenteSupabaseService(),
        _geminiService = geminiService,
        _geminiInjected = geminiService != null,
        _ragService = ragService,
        _clock = clock ?? DateTime.now,
        _briefingLoadTimeout = briefingLoadTimeout ?? OrtizMotion.scanMax,
        _briefingUnavailableAfter = briefingUnavailableAfter ?? briefingUnavailableAfterDefault,
        _briefingSnapshotReader = briefingSnapshotReader,
        _briefingService = briefingService {
    _wireRag();
    if (autoInit) {
      _init();
    } else {
      _isInitialized = true;
    }
  }

  /// Ids (UUID, `chat_prompts.id`) de los prompts del sistema, que no son
  /// atajos del chat: hoy solo la instrucción del resumen del día.
  static const Set<String> _systemPromptIds = {kDailyBriefingPromptId};

  static bool _isSystemPrompt(AgentePromptModel p) => _systemPromptIds.contains(p.id);

  // Getters
  List<ChatSessionModel> get sessions => _sessions;
  ChatSessionModel? get currentSession => _currentSession;
  List<ChatMessageModel> get messages => _messages;
  List<ChatArtifactModel> get allArtifacts => _allArtifacts;

  /// Atajos del chat: sin los prompts del sistema (que no se envían como
  /// mensaje de la persona).
  List<AgentePromptModel> get quickPrompts =>
      List.unmodifiable(_quickPrompts.where((p) => !_isSystemPrompt(p)));

  /// Fila editable de la instrucción del resumen del día, si existe.
  AgentePromptModel? get dailyBriefingPrompt {
    for (final p in _quickPrompts) {
      if (p.id == kDailyBriefingPromptId) return p;
    }
    return null;
  }

  /// Instrucción que se manda a Gemini para el resumen del día: el texto de
  /// la fila [kDailyBriefingPromptId] o, si no existe o está vacía, el texto
  /// por defecto [kDailyBriefingDefaultInstruction] (§5.1).
  String get dailyBriefingInstruction {
    final text = dailyBriefingPrompt?.text ?? '';
    return text.trim().isEmpty ? kDailyBriefingDefaultInstruction : text;
  }
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
    _disposed = true;
    _celebrateTimer?.cancel();
    _celebrateTimer = null;
    _cancelBriefingDeadline();
    _completeBriefingWaiter();
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
    _appState = appState;
    _diarioState = diarioState;
    _animoState = animoState;
    _habitosState = habitosState;
    _remindersState = remindersState;
    final deps = [appState, diarioState, habitosState, remindersState, animoState, notasState];
    final unchanged = _ragService != null &&
        deps.length == _deps.length &&
        List.generate(deps.length, (i) => identical(deps[i], _deps[i])).every((same) => same);
    if (!unchanged) {
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
      if (!_geminiInjected) _geminiService = GeminiService(ragService: _ragService!);
    }
    // El ProxyProvider llama aquí cada vez que un ViewModel notifica: se
    // recalcula el resumen (sin Gemini) aunque los estados sean los mismos,
    // una sola vez por microtask (varios ViewModels notifican seguidos).
    // Leer [todayBriefing] antes fuerza el recálculo pendiente.
    if (_briefingRefreshPending) return;
    _briefingRefreshPending = true;
    scheduleMicrotask(_flushBriefingRefresh);
  }

  void _flushBriefingRefresh() {
    if (!_briefingRefreshPending || _disposed) return;
    _briefingRefreshPending = false;
    _refreshBriefing();
  }

  // ---------------------------------------------------------------------------
  // Resumen del día (spec 04, docs/design/resumen-del-dia.md §5)
  // ---------------------------------------------------------------------------

  /// Texto del mensaje de la persona que abre el resumen (§5 paso 1).
  static const String dailyBriefingUserText = 'Resumen del día';

  /// Texto de Ortiz sin Gemini, sin red o con error (CA-07).
  static const String dailyBriefingFallbackText = 'Esto es lo de hoy:';

  /// Texto de Ortiz sin Gemini cuando todo está al día (`isAllClear`).
  static const String dailyBriefingAllClearText =
      'Todo al día: escribiste en el diario, no tienes pagos esta semana y tus hábitos están completos';

  /// Resumen de hoy sin Gemini para la franja y el panel (CA-09); se
  /// recalcula tras cada [updateDependencies]. `null` hasta la primera llamada.
  DailyBriefing? get todayBriefing {
    _flushBriefingRefresh();
    return _todayBriefing;
  }

  /// `true` desde que se pide el resumen hasta que aparece el mensaje de
  /// Ortiz con las filas (la vista no lo deduce del texto).
  bool get isBriefingScanning => _briefingScanning;

  /// Id del mensaje con el resumen de esta ejecución de la app: solo ese
  /// tiene las acciones por fila activas (§5 paso 6).
  String? get liveBriefingMessageId => _liveBriefingMessageId;

  /// Resumen vivo (el del mensaje [liveBriefingMessageId]), con los estados
  /// de pago al día.
  DailyBriefing? get liveBriefing => _liveBriefing;

  DailyBriefingSnapshot _readBriefingSnapshot(DateTime now) {
    try {
      final reader = _briefingSnapshotReader;
      if (reader != null) return reader(now) ?? const DailyBriefingSnapshot();
      final app = _appState, diario = _diarioState, animo = _animoState;
      final habitos = _habitosState, reminders = _remindersState;
      if (app == null || diario == null || animo == null || habitos == null || reminders == null) {
        return const DailyBriefingSnapshot();
      }
      return DailyBriefingSnapshot.fromStates(
        app: app,
        diario: diario,
        animo: animo,
        habitos: habitos,
        reminders: reminders,
        now: now,
      );
    } catch (e) {
      // Sin datos personales: solo el tipo de error. Todo queda «cargando».
      debugPrint('AgenteState: no pude leer los datos del resumen (${e.runtimeType}).');
      return const DailyBriefingSnapshot();
    }
  }

  DailyBriefing _buildBriefing(DateTime now) =>
      _briefingService.build(_readBriefingSnapshot(now), now: now);

  /// Firma del resumen sin `generatedAt` (para notificar solo si cambió).
  static String _briefingSignature(DailyBriefing b) {
    final m = b.toArtifactMetadata()..remove('generatedAt');
    return jsonEncode(m);
  }

  void _refreshBriefing() {
    final briefing = _buildBriefing(_clock());
    _todayBriefing = briefing;
    final signature = _briefingSignature(briefing);
    var changed = signature != _todayBriefingSignature;
    _todayBriefingSignature = signature;
    if (briefing.isFullyLoaded) _completeBriefingWaiter();
    if (_fillLiveLoadingSections()) changed = true;
    // Se llama dentro del build del ProxyProvider: se notifica después.
    if (changed) _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _completeBriefingWaiter() {
    final waiter = _briefingLoadedWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _briefingLoadedWaiter = null;
  }

  /// Espera a que carguen todas las secciones como máximo
  /// [_briefingLoadTimeout] (§5 paso 2).
  Future<void> _waitForBriefingData() async {
    if (_buildBriefing(_clock()).isFullyLoaded) return;
    final waiter = Completer<void>();
    _briefingLoadedWaiter = waiter;
    final timer = Timer(_briefingLoadTimeout, () {
      if (!waiter.isCompleted) waiter.complete();
    });
    await waiter.future;
    timer.cancel();
    if (identical(_briefingLoadedWaiter, waiter)) _briefingLoadedWaiter = null;
  }

  /// Secciones de [fresh] que reemplazan a las que seguían `loading` en
  /// [live]; `null` si ninguna cambió (§5 paso 7). Las demás secciones, y
  /// los estados de pago ya marcados, se quedan como estaban.
  @visibleForTesting
  static DailyBriefing? replaceLoadingSections(DailyBriefing live, DailyBriefing fresh) {
    bool take(BriefingStatus l, BriefingStatus f) =>
        l == BriefingStatus.loading && f != BriefingStatus.loading;
    final diario = take(live.diario.status, fresh.diario.status);
    final mood = take(live.mood.status, fresh.mood.status);
    final payments = take(live.payments.status, fresh.payments.status);
    final birthdays = take(live.birthdays.status, fresh.birthdays.status);
    final habits = take(live.habits.status, fresh.habits.status);
    final reminders = take(live.reminders.status, fresh.reminders.status);
    final rates = take(live.rates.status, fresh.rates.status);
    if (!(diario || mood || payments || birthdays || habits || reminders || rates)) return null;
    return live.copyWith(
      diario: diario ? fresh.diario : null,
      mood: mood ? fresh.mood : null,
      payments: payments ? fresh.payments : null,
      birthdays: birthdays ? fresh.birthdays : null,
      habits: habits ? fresh.habits : null,
      reminders: reminders ? fresh.reminders : null,
      rates: rates ? fresh.rates : null,
    );
  }

  /// Rellena las secciones `loading` del artefacto vivo sin pedir otra vez
  /// el texto a Gemini. Devuelve `true` si cambió algo (notifica quien llama).
  bool _fillLiveLoadingSections() {
    final live = _liveBriefing;
    if (live == null || live.isFullyLoaded) return false;
    final merged = replaceLoadingSections(live, _buildBriefing(live.generatedAt));
    if (merged == null) return false;
    if (merged.isFullyLoaded) _cancelBriefingDeadline();
    return _writeLiveBriefing(merged, notify: false);
  }

  void _cancelBriefingDeadline() {
    _briefingUnavailableTimer?.cancel();
    _briefingUnavailableTimer = null;
  }

  /// Escribe [briefing] en la metadata del artefacto vivo (mensaje y lista
  /// global) y lo persiste si el mensaje ya no está en streaming.
  bool _writeLiveBriefing(DailyBriefing briefing, {required bool notify}) {
    _liveBriefing = briefing;
    final messageId = _liveBriefingMessageId;
    final i = messageId == null ? -1 : _messages.indexWhere((m) => m.id == messageId);
    if (i == -1) return false;
    final msg = _messages[i];
    final ai = msg.artifacts.indexWhere((a) => a.type == ArtifactType.dailyBriefing);
    if (ai == -1) return false;
    final updated = msg.artifacts[ai].copyWith(metadata: briefing.toArtifactMetadata());
    final newMsg = msg.copyWith(artifacts: List<ChatArtifactModel>.from(msg.artifacts)..[ai] = updated);
    _messages[i] = newMsg;
    final g = _allArtifacts.indexWhere((a) => a.id == updated.id);
    if (g != -1) _allArtifacts[g] = updated;
    if (notify && !_disposed) notifyListeners();
    if (!newMsg.isStreaming) unawaited(_saveMessageQuietly(newMsg));
    return true;
  }

  /// Secciones de [b] que siguen `loading` pasan a `unavailable` (tope de
  /// [briefingUnavailableAfterDefault], diseño §5); `null` si no había
  /// ninguna. Una sección `loading` no tiene datos: se reemplaza por una vacía.
  @visibleForTesting
  static DailyBriefing? markLoadingUnavailable(DailyBriefing b) {
    const u = BriefingStatus.unavailable;
    bool loading(BriefingStatus s) => s == BriefingStatus.loading;
    if (b.isFullyLoaded) return null;
    return b.copyWith(
      diario: loading(b.diario.status) ? const BriefingDiario(status: u) : null,
      mood: loading(b.mood.status) ? const BriefingMood(status: u) : null,
      payments: loading(b.payments.status) ? const BriefingPayments(status: u) : null,
      birthdays: loading(b.birthdays.status) ? const BriefingBirthdays(status: u) : null,
      habits: loading(b.habits.status) ? const BriefingHabits(status: u) : null,
      reminders: loading(b.reminders.status) ? const BriefingReminders(status: u) : null,
      rates: loading(b.rates.status) ? const BriefingRates(status: u) : null,
    );
  }

  void _onBriefingDeadline() {
    _briefingUnavailableTimer = null;
    _briefingDeadlinePassed = true;
    if (_disposed) return;
    final live = _liveBriefing;
    if (live == null || _liveBriefingMessageId == null) return;
    final marked = markLoadingUnavailable(live);
    if (marked != null) _writeLiveBriefing(marked, notify: true);
  }

  /// Metadata del artefacto `dailyBriefing` tal como se guarda: sin las
  /// filas ni los montos (S4-02, «no se persiste»). Solo lo que la burbuja
  /// necesita para «Resumen del {fecha} a las {hora}…».
  @visibleForTesting
  static Map<String, dynamic> storedBriefingMetadata(Map<String, dynamic> metadata) => {
        for (final key in const ['version', 'generatedAt', 'period'])
          if (metadata.containsKey(key)) key: metadata[key],
      };

  /// [message] con sus artefactos `dailyBriefing` reducidos a
  /// [storedBriefingMetadata]; el resto, igual.
  static ChatMessageModel _forStorage(ChatMessageModel message) {
    if (!message.artifacts.any((a) => a.type == ArtifactType.dailyBriefing)) return message;
    return message.copyWith(artifacts: [
      for (final a in message.artifacts)
        a.type == ArtifactType.dailyBriefing ? a.copyWith(metadata: storedBriefingMetadata(a.metadata)) : a,
    ]);
  }

  Future<void> _saveMessageQuietly(ChatMessageModel message) async {
    try {
      await _supabaseService.saveMessage(_forStorage(message));
    } catch (e) {
      debugPrint('AgenteState: no pude guardar el mensaje (${e.runtimeType}).');
    }
  }

  void _setMessage(String messageId, ChatMessageModel Function(ChatMessageModel m) change) {
    final i = _messages.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    _messages[i] = change(_messages[i]);
    if (!_disposed) notifyListeners();
  }

  /// Resumen del día en el chat (§5): mensaje de la persona «Resumen del
  /// día», Ortiz pensando hasta [_briefingLoadTimeout] mientras cargan los
  /// ViewModels, mensaje de Ortiz con el artefacto `dailyBriefing` (filas al
  /// instante) y el texto de Gemini en streaming (sin herramientas). Sin
  /// Gemini, sin red o con error: [dailyBriefingFallbackText] o
  /// [dailyBriefingAllClearText]. Nunca muestra un error (CA-07).
  Future<void> runDailyBriefing({DateTime? now}) async {
    if (_isGenerating) return;
    if (_currentSession == null) await startNewSession(initialTitle: dailyBriefingUserText);
    final sessionId = _currentSession!.id;

    final userMessage = ChatMessageModel(
      sessionId: sessionId,
      role: MessageRole.user,
      content: dailyBriefingUserText,
    );
    _messages.add(userMessage);
    _isGenerating = true;
    _briefingScanning = true;
    _statusMessage = 'Revisando tus apps...';
    // Tope de 10 s desde que se pide (diseño §5): cancela el del anterior.
    _briefingUnavailableTimer?.cancel();
    _briefingDeadlinePassed = false;
    _briefingUnavailableTimer = Timer(_briefingUnavailableAfter, _onBriefingDeadline);
    if (!_disposed) notifyListeners();
    unawaited(_saveMessageQuietly(userMessage));

    if (_messages.length <= 2 && _currentSession!.title == 'Nueva conversación') {
      _currentSession = _currentSession!.copyWith(title: dailyBriefingUserText, updatedAt: DateTime.now());
      unawaited(_supabaseService.saveSession(_currentSession!).then((_) {}, onError: (Object _) {}));
    }

    final modelMessageId = const Uuid().v4();
    try {
      await _waitForBriefingData();
      final at = now ?? _clock();
      final built = _buildBriefing(at);
      final briefing = _briefingDeadlinePassed ? (markLoadingUnavailable(built) ?? built) : built;
      final artifact = ChatArtifactModel(
        sessionId: sessionId,
        messageId: modelMessageId,
        type: ArtifactType.dailyBriefing,
        title: dailyBriefingUserText,
        content: '',
        metadata: briefing.toArtifactMetadata(),
        createdAt: at,
      );
      _liveBriefing = briefing;
      _liveBriefingMessageId = modelMessageId;
      _messages.add(ChatMessageModel(
        id: modelMessageId,
        sessionId: sessionId,
        role: MessageRole.model,
        content: '',
        artifacts: [artifact],
        isStreaming: true,
      ));
      _allArtifacts.insert(0, artifact);
      _briefingScanning = false;
      if (briefing.isFullyLoaded) _cancelBriefingDeadline();
      if (!_disposed) notifyListeners();

      var text = '';
      final gemini = _geminiService;
      if (gemini != null) {
        try {
          final stream = gemini.streamDailyBriefing(
            instruction: dailyBriefingInstruction,
            briefingJson: briefing.toGeminiJson(),
          );
          await for (final chunk in stream) {
            text += chunk;
            final shown = text;
            _setMessage(modelMessageId, (m) => m.copyWith(content: shown));
          }
        } catch (e) {
          // Sin datos personales: solo el tipo de error (CA-07).
          debugPrint('AgenteState.runDailyBriefing: sin texto de Gemini (${e.runtimeType}).');
          text = '';
        }
      }
      if (text.trim().isEmpty) {
        final current = _liveBriefing ?? briefing;
        text = current.isAllClear ? dailyBriefingAllClearText : dailyBriefingFallbackText;
      }

      final finalText = text;
      _setMessage(modelMessageId, (m) => m.copyWith(content: finalText, isStreaming: false));
      final i = _messages.indexWhere((m) => m.id == modelMessageId);
      if (i != -1) await _saveMessageQuietly(_messages[i]);
      _currentSession = _currentSession!.copyWith(updatedAt: DateTime.now());
      await _supabaseService.saveSession(_currentSession!);
      await loadSessions();
    } catch (e) {
      debugPrint('AgenteState.runDailyBriefing: falló (${e.runtimeType}).');
      final i = _messages.indexWhere((m) => m.id == modelMessageId);
      if (i != -1 && _messages[i].isStreaming) {
        final m = _messages[i];
        final fixed = m.copyWith(
          content: m.content.trim().isEmpty ? dailyBriefingFallbackText : m.content,
          isStreaming: false,
        );
        _messages[i] = fixed;
        await _saveMessageQuietly(fixed);
      }
    } finally {
      _isGenerating = false;
      _briefingScanning = false;
      _statusMessage = '';
      if (!_disposed) notifyListeners();
    }
  }

  /// Marca a mano el estado de un pago del resumen vivo (p. ej. `dismissed`
  /// al omitirlo). La fila se queda en `items` (CA-10).
  Future<void> markBriefingPayment(String paymentId, BriefingPaymentState state) async {
    final live = _liveBriefing;
    if (live == null) return;
    final items = [
      for (final p in live.payments.items) p.paymentId == paymentId ? p.copyWith(state: state) : p,
    ];
    _writeLiveBriefing(live.copyWith(payments: live.payments.copyWith(items: items)), notify: true);
  }

  /// Marca como pospuesto hasta [until] un recordatorio del resumen vivo
  /// (fila «Posponer», U6): la fila se queda y muestra «Pospuesto a…».
  Future<void> markBriefingReminderSnoozed(String reminderId, DateTime until) async {
    final live = _liveBriefing;
    if (live == null) return;
    final items = [
      for (final r in live.reminders.items) r.id == reminderId ? r.copyWith(snoozedUntil: until) : r,
    ];
    _writeLiveBriefing(live.copyWith(reminders: live.reminders.copyWith(items: items)), notify: true);
  }

  /// Recalcula los pagos del resumen vivo tras pagar o abonar desde una fila
  /// (§6, fila «Pago», CA-10). Para cada fila pendiente (solo [paymentId]
  /// si se indica), con el cálculo nuevo del mismo `generatedAt`:
  /// - si ya no queda ninguna ocurrencia de ese pago, pasa a [confirmedAs]
  ///   (`paid` si la hoja devolvió transacciones, `dismissed` si se omitió)
  ///   y **no desaparece**;
  /// - si quedan (se pagó solo la más antigua, o fue un abono), sigue
  ///   `pending` con lo que falta, los abonos, los conteos y la ocurrencia
  ///   más antigua del cálculo nuevo.
  /// Las filas ya marcadas no cambian.
  Future<void> refreshBriefingPayments({
    String? paymentId,
    BriefingPaymentState? confirmedAs = BriefingPaymentState.paid,
  }) async {
    final live = _liveBriefing;
    if (live == null || live.payments.status != BriefingStatus.ready) return;
    final fresh = _buildBriefing(live.generatedAt).payments;
    if (fresh.status != BriefingStatus.ready) return;
    final byId = {for (final p in fresh.items) p.paymentId: p};
    final items = <BriefingPayment>[];
    for (final p in live.payments.items) {
      if (!p.isPending || (paymentId != null && p.paymentId != paymentId)) {
        items.add(p);
        continue;
      }
      final now = byId[p.paymentId];
      // Sin ocurrencias y sin saber si se pagó u omitió (confirmedAs null):
      // la fila se quita en vez de afirmar un estado que no consta.
      if (now == null && confirmedAs == null) continue;
      items.add(now == null
          ? p.copyWith(state: confirmedAs)
          : p.copyWith(
              oldestOccurrenceDate: now.oldestOccurrenceDate,
              remaining: now.remaining,
              oldestRemaining: now.oldestRemaining,
              partialPaid: now.partialPaid,
              occurrenceCount: now.occurrenceCount,
              overdueCount: now.overdueCount,
            ));
    }
    _writeLiveBriefing(live.copyWith(payments: live.payments.copyWith(items: items)), notify: true);
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
      if (!newMsg.isStreaming) await _supabaseService.saveMessage(_forStorage(newMsg));
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

  /// Reordena los atajos; los índices son los de [quickPrompts] (sin los
  /// prompts del sistema, que se quedan al final y sin cambiar).
  Future<void> reorderQuickPrompts(int oldIndex, int newIndex, {bool persist = true}) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final visible = _quickPrompts.where((p) => !_isSystemPrompt(p)).toList();
    final system = _quickPrompts.where(_isSystemPrompt).toList();
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    for (int i = 0; i < visible.length; i++) {
      visible[i] = visible[i].copyWith(sortOrder: i);
    }
    _quickPrompts = [...visible, ...system];
    notifyListeners();

    if (persist) {
      await _persistPromptsLocally();
      for (final p in visible) {
        await _supabaseService.savePrompt(p);
      }
    }
  }

  /// Guarda la instrucción del resumen del día en la fila
  /// [kDailyBriefingPromptId] (upsert + respaldo local, como los atajos).
  /// Un texto vacío o igual al de por defecto equivale a restaurar (§5.1:
  /// sin fila se usa [kDailyBriefingDefaultInstruction]).
  Future<void> saveDailyBriefingInstruction(String text, {bool persist = true}) async {
    final clean = text.trim();
    if (clean.isEmpty || clean == kDailyBriefingDefaultInstruction.trim()) {
      await resetDailyBriefingInstruction(persist: persist);
      return;
    }
    final now = DateTime.now();
    final existing = dailyBriefingPrompt;
    final prompt = existing != null
        ? existing.copyWith(text: clean)
        : AgentePromptModel(
            id: kDailyBriefingPromptId,
            text: clean,
            label: 'Resumen del día',
            createdAt: now,
            updatedAt: now,
          );
    await saveQuickPrompt(prompt, persist: persist);
  }

  /// Vuelve al texto por defecto borrando la fila [kDailyBriefingPromptId]
  /// (local y en Supabase). Sin fila no hace nada.
  Future<void> resetDailyBriefingInstruction({bool persist = true}) async {
    if (dailyBriefingPrompt == null) return;
    await deleteQuickPrompt(kDailyBriefingPromptId, persist: persist);
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
