import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../agente/dialogs/agente_settings_dialog.dart';
import '../agente/dialogs/prompt_editor_dialog.dart';
import '../agente/models/agente_prompt_model.dart';
import '../agente/models/daily_briefing.dart';
import '../agente/services/gemini_config.dart';
import '../agente/viewmodels/agente_state.dart';
import '../agente/widgets/briefing_block.dart';
import '../agente/widgets/ortiz_chat_view.dart';
import '../agente/widgets/ortiz_face.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../theme/ortiz_motion.dart';
import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import '../theme/suite_apps.dart';
import '../widgets/briefing_actions.dart';
import '../widgets/ortiz/ortiz.dart';
import '../widgets/responsive_breakpoints.dart';
import '../widgets/responsive_sheet_helper.dart';

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
    final briefing = agente.todayBriefing;
    // U4: la franja se oculta en ≥ 1200, donde el panel ya lo muestra todo.
    final Widget? todayStrip = showPanel
        ? null
        : widget.todayStrip ??
            (briefing == null
                ? null
                : _TodayStrip(
                    highlights: briefing.highlights,
                    onTap: agente.isGenerating ? null : () => agente.runDailyBriefing(),
                  ));
    final Widget? todayPanel = widget.todayPanel ??
        (briefing == null
            ? null
            : SingleChildScrollView(
                child: BriefingBlock(
                  briefing: briefing,
                  variant: BriefingBlockVariant.panel,
                  actionsEnabled: true,
                  activeBookId: context.select<AppState?, String?>((s) => s?.activeDbName),
                  activeBookName: context.select<AppState?, String?>((s) => s?.activeProfileName),
                  onAction: (action) => runBriefingAction(context, action),
                ),
              ));

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
        todayStrip: todayStrip,
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
              child: _TodayPanel(now: now, child: todayPanel),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildAboveInput(BuildContext context, AgenteState agente, bool connected) {
    final t = OrtizTokens.of(context);
    final chips = <Widget>[
      // Spec 04 (U1): también sin Gemini (CA-07); desactivado mientras Ortiz
      // responde, para no duplicar el resumen.
      _SummaryChip(onPressed: agente.isGenerating ? null : () => agente.runDailyBriefing()),
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

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    // Desactivado, el chip queda sobre `surface`: `onAccent` no se leería.
    final fg = onPressed == null ? t.muted : t.onAccent;
    return ActionChip(
      avatar: Icon(Icons.wb_sunny_outlined, size: OrtizIconSize.sm, color: fg),
      label: const Text('Resumen del día'),
      labelStyle: TextStyle(color: fg),
      backgroundColor: t.accent,
      side: BorderSide.none,
      onPressed: onPressed,
    );
  }
}

/// Color del punto de cada etiqueta de la franja (U4): el de su app.
SuiteApp _highlightApp(BriefingHighlightCategory category) => switch (category) {
      BriefingHighlightCategory.payments => SuiteApp.finanzas,
      BriefingHighlightCategory.reminders => SuiteApp.recordatorios,
      BriefingHighlightCategory.birthdays ||
      BriefingHighlightCategory.journal ||
      BriefingHighlightCategory.allClear =>
        SuiteApp.diario,
      BriefingHighlightCategory.habits => SuiteApp.habitos,
    };

/// Franja de hoy bajo el saludo (spec 04, U4): hasta 3 etiquetas sin
/// nombres ni montos; tocar cualquiera lanza el resumen del día.
class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.highlights, required this.onTap});

  final List<BriefingHighlight> highlights;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final items = highlights.take(DailyBriefing.maxHighlights).toList();
    final Widget strip = items.isEmpty
        ? const SizedBox.shrink(key: ValueKey('today-strip-empty'))
        : Wrap(
            key: const ValueKey('today-strip'),
            alignment: WrapAlignment.center,
            spacing: OrtizSpace.sm,
            runSpacing: OrtizSpace.sm,
            children: [
              for (final h in items)
                Tooltip(
                  message: '${h.label}. Ver el resumen del día',
                  excludeFromSemantics: true,
                  child: Semantics(
                    button: true,
                    enabled: onTap != null,
                    label: '${h.label}. Ver el resumen del día',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(OrtizRadius.pill),
                      child: ConstrainedBox(
                        // Objetivo táctil ≥ 48 alrededor de la píldora.
                        constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: h.kind == BriefingHighlightKind.allClear
                              ? _AllClearPill(label: h.label)
                              : OrtizPill(label: h.label, dotColor: _highlightApp(h.category).color),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
    final duration = OrtizMotion.of(context, OrtizMotion.base);
    if (duration == Duration.zero) return strip;
    return AnimatedSwitcher(duration: duration, switchInCurve: OrtizMotion.ease, child: strip);
  }
}

/// Etiqueta «Todo al día» de la franja (U4): la misma píldora neutra que
/// `OrtizPill(dotColor:)` (fondo `surface`, texto `muted`), con
/// `OrtizSuccessMark` pequeño en lugar del punto.
class _AllClearPill extends StatelessWidget {
  const _AllClearPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(OrtizRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorativa: el texto ya dice el estado.
            const ExcludeSemantics(
              child: SizedBox.square(
                dimension: OrtizIconSize.sm,
                child: FittedBox(child: OrtizSuccessMark()),
              ),
            ),
            const SizedBox(width: OrtizSpace.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OrtizType.caption.copyWith(color: t.muted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
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
