import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../agente/dialogs/agente_settings_dialog.dart';
import '../agente/dialogs/prompt_editor_dialog.dart';
import '../agente/models/agente_prompt_model.dart';
import '../agente/services/gemini_config.dart';
import '../agente/viewmodels/agente_state.dart';
import '../agente/widgets/ortiz_chat_view.dart';
import '../agente/widgets/ortiz_face.dart';
import '../theme/ortiz_motion.dart';
import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import '../widgets/responsive_breakpoints.dart';
import '../widgets/responsive_sheet_helper.dart';

/// Mensaje que envía el chip «Resumen del día» (spec 02; la spec 04 cambia
/// su comportamiento).
const String ortizDailySummaryPrompt = 'Dame el resumen del día';

/// Aviso del inicio cuando Ortiz no tiene Gemini configurado.
const String ortizOfflineMessage =
    'Ortiz no está conectado; las acciones rápidas siguen funcionando.';

/// Saludo según la hora local (docs/design/ortiz-home.md §2.3):
/// 05:00–11:59 «Buenos días», 12:00–18:59 «Buenas tardes» y el resto
/// «Buenas noches».
String ortizGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Buenos días';
  if (h >= 12 && h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

const List<String> _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const List<String> _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Cabecera del panel de hoy: «HOY · MAR 17 NOV».
String ortizTodayLabel(DateTime now) {
  final day = _weekdays[now.weekday - 1];
  final month = _months[now.month - 1];
  return 'HOY · $day ${now.day} $month'.toUpperCase();
}

/// Largo máximo de la etiqueta de un atajo de consulta en su chip.
const int _promptChipMaxChars = 28;

/// Ciclo del flote suave de la cara del saludo (±[OrtizSpace.xs] en Y).
const Duration _heroFloatPeriod = Duration(seconds: 5);

/// Inicio de la app: la conversación con Ortiz (spec 02, paso 5;
/// docs/design/ortiz-home.md §2).
///
/// - `< 840`: barra superior con ☰ ([onOpenMenu]), cara + «Ortiz» + estado y
///   «Nueva conversación».
/// - `≥ 840`: la misma cabecera dentro de la columna del chat, sin ☰ (el
///   riel lo pone el shell).
/// - `≥ 1200`: además, el panel «Hoy» a la derecha (Q1).
///
/// No depende del catálogo de acciones: el shell le pasa sus chips en
/// [quickChips]. Lee [AgenteState] del árbol de providers.
class OrtizHomeScreen extends StatefulWidget {
  const OrtizHomeScreen({
    super.key,
    this.onOpenMenu,
    this.quickChips = const [],
    this.todayStrip,
    this.todayPanel,
    this.chatFocusNode,
    this.clock,
    @visibleForTesting this.geminiConfigured,
  });

  /// Abre el menú lateral (☰, solo en compact).
  final VoidCallback? onOpenMenu;

  /// Chips de las acciones rápidas del catálogo, en orden. Van después de
  /// «Resumen del día» y antes de los atajos de consulta.
  final List<Widget> quickChips;

  /// Franja de hoy bajo el saludo (spec 04). Sin ella no ocupa espacio.
  final Widget? todayStrip;

  /// Contenido del panel «Hoy» (spec 04). Sin él, «El resumen de hoy llega
  /// pronto.».
  final Widget? todayPanel;

  /// Foco del campo del chat, para el atajo `/` del shell.
  final FocusNode? chatFocusNode;

  /// Reloj para el saludo y la fecha del panel (inyectable en tests).
  final DateTime Function()? clock;

  /// Solo en tests: fuerza si Gemini está configurado. En la app se lee de
  /// [GeminiConfig.isConfigured].
  final bool? geminiConfigured;

  @override
  State<OrtizHomeScreen> createState() => _OrtizHomeScreenState();
}

class _OrtizHomeScreenState extends State<OrtizHomeScreen> {
  FocusNode? _ownFocusNode;
  final ScrollController _chipsScroll = ScrollController();

  FocusNode get _focusNode =>
      widget.chatFocusNode ?? (_ownFocusNode ??= FocusNode());

  bool get _connected => widget.geminiConfigured ?? GeminiConfig.isConfigured;

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    _chipsScroll.dispose();
    super.dispose();
  }

  Future<void> _newConversation(AgenteState agente) async {
    if (agente.messages.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    await agente.startNewSession();
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _openAgentSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const AgenteSettingsDialog(),
    );
    // La clave pudo cambiar: se vuelve a leer `GeminiConfig`.
    if (mounted) setState(() {});
  }

  Future<void> _addQuickPrompt(AgenteState agente) async {
    final prompt = await PromptEditorDialog.show(context);
    if (prompt != null) await agente.saveQuickPrompt(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final agente = context.watch<AgenteState>();
    final connected = _connected;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final showPanel = ResponsiveBreakpoints.isExpanded(context);
    final now = (widget.clock ?? DateTime.now)();

    final header = _HeaderTitle(agente: agente, connected: connected);
    final newConversation = IconButton(
      tooltip: 'Nueva conversación',
      icon: const Icon(Icons.add_comment_outlined),
      onPressed: () => _newConversation(agente),
    );

    final chat = OrtizChatView(
      focusNode: _focusNode,
      enabled: connected,
      showShortcutHint: isDesktop,
      emptyBuilder: (context) => _Greeting(
        now: now,
        mood: agente.ortizMood,
        connected: connected,
        large: isDesktop,
        todayStrip: widget.todayStrip,
        onConnect: _openAgentSettings,
      ),
      aboveInput: _buildAboveInput(context, agente, connected),
    );

    final center = Column(
      children: [
        if (isDesktop)
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OrtizSize.chatMaxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    OrtizSpace.lg, OrtizSpace.md, OrtizSpace.sm, OrtizSpace.sm),
                child: Row(
                  children: [Expanded(child: header), newConversation],
                ),
              ),
            ),
          ),
        Expanded(child: chat),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: t.bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                tooltip: 'Menú',
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onOpenMenu,
              ),
              title: header,
              actions: [newConversation],
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: center),
          if (showPanel) ...[
            const VerticalDivider(width: OrtizStroke.hairline, thickness: OrtizStroke.hairline),
            SizedBox(
              // Q1: el panel solo existe desde 1200 px, con su ancho expanded.
              width: OrtizSize.todayPanelWidthExpanded,
              child: _TodayPanel(now: now, child: widget.todayPanel),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildAboveInput(BuildContext context, AgenteState agente, bool connected) {
    final t = OrtizTokens.of(context);
    final chips = <Widget>[
      if (connected)
        _SummaryChip(onPressed: () => agente.sendMessage(ortizDailySummaryPrompt)),
      ...widget.quickChips,
      if (connected) ...[
        SizedBox(
          height: OrtizIconSize.lg,
          child: VerticalDivider(
            width: OrtizStroke.hairline,
            thickness: OrtizStroke.hairline,
            color: t.line,
          ),
        ),
        for (final prompt in agente.quickPrompts) _promptChip(t, agente, prompt),
        Tooltip(
          message: 'Nuevo atajo de consulta',
          child: ActionChip(
            label: const Text('＋ Atajo'),
            onPressed: () => _addQuickPrompt(agente),
          ),
        ),
      ],
    ];

    final showOfflineLine = !connected && agente.messages.isNotEmpty;
    if (chips.isEmpty && !showOfflineLine) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showOfflineLine)
          Padding(
            padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
            child: Text(ortizOfflineMessage,
                style: OrtizType.bodySm.copyWith(color: t.muted)),
          ),
        if (chips.isNotEmpty)
          ResponsiveHorizontalScroll(
            controller: _chipsScroll,
            child: SingleChildScrollView(
              controller: _chipsScroll,
              scrollDirection: Axis.horizontal,
              child: Row(spacing: OrtizSpace.sm, children: chips),
            ),
          ),
      ],
    );
  }

  Widget _promptChip(OrtizTokens t, AgenteState agente, AgentePromptModel prompt) {
    final name = prompt.displayName;
    final label = name.length > _promptChipMaxChars
        ? '${name.substring(0, _promptChipMaxChars - 1)}…'
        : name;
    return ActionChip(
      avatar: Icon(Icons.bolt_rounded, size: OrtizIconSize.sm, color: t.muted),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () => agente.sendMessage(prompt.text),
    );
  }
}

/// Cara + «Ortiz» + línea de estado (barra superior o cabecera del centro).
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.agente, required this.connected});

  final AgenteState agente;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final generating = agente.isGenerating;
    final Color dot;
    final String status;
    if (generating) {
      dot = t.accent;
      status = agente.statusMessage.isNotEmpty ? agente.statusMessage : 'Pensando…';
    } else if (connected) {
      dot = t.ok;
      status = 'Conectado a 5 apps';
    } else {
      dot = t.warn;
      status = 'Sin conectar';
    }

    return Row(
      children: [
        ExcludeSemantics(
          child: OrtizFace(mood: agente.ortizMood, size: OrtizIconSize.xl),
        ),
        const SizedBox(width: OrtizSpace.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ortiz',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OrtizType.title.copyWith(color: t.fg)),
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Container(
                      width: OrtizSize.dot,
                      height: OrtizSize.dot,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: OrtizSpace.xs),
                    Flexible(
                      child: Text(status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OrtizType.caption.copyWith(color: t.muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Saludo del chat vacío: cara grande, «{Saludo}, soy Ortiz.», subtítulo (o
/// el aviso sin Gemini) y la franja de hoy.
class _Greeting extends StatefulWidget {
  const _Greeting({
    required this.now,
    required this.mood,
    required this.connected,
    required this.large,
    required this.onConnect,
    this.todayStrip,
  });

  final DateTime now;
  final OrtizMood mood;
  final bool connected;
  final bool large;
  final VoidCallback onConnect;
  final Widget? todayStrip;

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: _heroFloatPeriod);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OrtizMotion.reduced(context)) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final titleStyle =
        (widget.large ? OrtizType.displayLg : OrtizType.display).copyWith(color: t.fg);
    final subtitleStyle = OrtizType.body.copyWith(color: t.muted);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: OrtizSpace.lg, vertical: OrtizSpace.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 2 * OrtizSpace.xxl),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OrtizSize.readableWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                          0, math.sin(_float.value * 2 * math.pi) * OrtizSpace.xs),
                      child: child,
                    ),
                    child: ExcludeSemantics(
                      child: OrtizFace(mood: widget.mood, size: OrtizSize.faceHero),
                    ),
                  ),
                  const SizedBox(height: OrtizSpace.lg),
                  Text('${ortizGreeting(widget.now)}, soy Ortiz.',
                      textAlign: TextAlign.center, style: titleStyle),
                  Text('¿Qué hacemos hoy?',
                      textAlign: TextAlign.center, style: titleStyle),
                  const SizedBox(height: OrtizSpace.sm),
                  if (widget.connected)
                    Text(
                      'Tengo a la vista tus finanzas, el diario, los hábitos, '
                      'los recordatorios y las notas.',
                      textAlign: TextAlign.center,
                      style: subtitleStyle,
                    )
                  else ...[
                    Text(ortizOfflineMessage,
                        textAlign: TextAlign.center, style: subtitleStyle),
                    const SizedBox(height: OrtizSpace.sm),
                    TextButton(
                      onPressed: widget.onConnect,
                      child: const Text('Conectar a Ortiz'),
                    ),
                  ],
                  const SizedBox(height: OrtizSpace.lg),
                  widget.todayStrip ?? const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip «Resumen del día»: el único `accent` de la vista.
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return ActionChip(
      avatar: Icon(Icons.wb_sunny_outlined, size: OrtizIconSize.sm, color: t.onAccent),
      label: const Text('Resumen del día'),
      labelStyle: TextStyle(color: t.onAccent),
      backgroundColor: t.accent,
      side: BorderSide.none,
      onPressed: onPressed,
    );
  }
}

/// Panel «Hoy» (≥ 1200): cabecera con la fecha y el contenido de la spec 04.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.now, this.child});

  final DateTime now;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: Padding(
        padding: const EdgeInsets.all(OrtizSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ortizTodayLabel(now), style: OrtizType.caption.copyWith(color: t.muted)),
            const SizedBox(height: OrtizSpace.lg),
            Expanded(
              child: child ??
                  Text('El resumen de hoy llega pronto.',
                      style: OrtizType.bodySm.copyWith(color: t.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
