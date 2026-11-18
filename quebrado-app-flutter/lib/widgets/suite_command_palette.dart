// Paleta de comandos `Ctrl/⌘+K` de la suite (spec 02, PA-02;
// docs/design/ortiz-home.md §5). Generaliza el patrón visual de
// `recordatorios/dialogs/command_palette_dialog.dart` (que no se toca).
// Las entradas llegan desde fuera (el catálogo `SuiteAction` las arma).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ortiz_space.dart';
import '../theme/ortiz_tokens.dart';
import '../theme/ortiz_type.dart';
import 'responsive_breakpoints.dart';

/// Secciones de la paleta, en el orden en que se muestran.
enum PaletteSection {
  apps('Apps'),
  actions('Acciones rápidas'),
  ortiz('Ortiz');

  const PaletteSection(this.label);
  final String label;
}

/// Una fila de la paleta.
class PaletteEntry {
  const PaletteEntry({
    required this.title,
    required this.section,
    required this.icon,
    required this.onSelected,
    this.color,
    this.appLabel,
    this.keywords = '',
  });

  final String title;
  final PaletteSection section;
  final IconData icon;

  /// Color del icono y del punto de la app (p. ej. `SuiteApp.x.color`).
  final Color? color;

  /// Nombre de la app que se muestra a la derecha (acciones rápidas).
  final String? appLabel;

  /// Palabras clave extra para el filtro.
  final String keywords;

  /// Se ejecuta después de cerrar la paleta.
  final VoidCallback onSelected;

  String get _haystack => normalizePaletteText('$title ${appLabel ?? ''} $keywords');
}

/// Minúsculas y sin tildes («Hábitos» → «habitos»).
String normalizePaletteText(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i == -1 ? ch : to[i]);
  }
  return b.toString();
}

/// Filtra [entries] por [query]: cada palabra debe aparecer en
/// título + app + palabras clave. Primero las que empiezan por la búsqueda,
/// luego el resto, respetando sección y orden original.
List<PaletteEntry> filterPaletteEntries(List<PaletteEntry> entries, String query) {
  final q = normalizePaletteText(query.trim());
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final matches = words.isEmpty
      ? List<PaletteEntry>.of(entries)
      : entries.where((e) => words.every(e._haystack.contains)).toList();
  final result = <PaletteEntry>[];
  for (final section in PaletteSection.values) {
    final inSection = matches.where((e) => e.section == section).toList();
    if (q.isEmpty) {
      result.addAll(inSection);
    } else {
      result
        ..addAll(inSection.where((e) => normalizePaletteText(e.title).startsWith(q)))
        ..addAll(inSection.where((e) => !normalizePaletteText(e.title).startsWith(q)));
    }
  }
  return result;
}

/// Abre la paleta. [onAskOrtiz] añade, sin resultados, la fila
/// «Pregúntale a Ortiz: «{búsqueda}»» (solo con Gemini).
Future<void> showSuiteCommandPalette(
  BuildContext context, {
  required List<PaletteEntry> entries,
  ValueChanged<String>? onAskOrtiz,
}) async {
  final action = await showDialog<VoidCallback>(
    context: context,
    builder: (_) => SuiteCommandPalette(entries: entries, onAskOrtiz: onAskOrtiz),
  );
  // Primero se cierra la paleta y después se ejecuta.
  action?.call();
}

class SuiteCommandPalette extends StatefulWidget {
  const SuiteCommandPalette({super.key, required this.entries, this.onAskOrtiz});

  final List<PaletteEntry> entries;
  final ValueChanged<String>? onAskOrtiz;

  @override
  State<SuiteCommandPalette> createState() => _SuiteCommandPaletteState();
}

class _SuiteCommandPaletteState extends State<SuiteCommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _rowKeys = <int, GlobalKey>{};
  int _highlight = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim();

  /// Filas ejecutables visibles (incluye «Pregúntale a Ortiz» sin resultados).
  List<VoidCallback> _actions(List<PaletteEntry> visible) {
    if (visible.isNotEmpty) return [for (final e in visible) e.onSelected];
    final ask = widget.onAskOrtiz;
    if (ask != null && _query.isNotEmpty) {
      final q = _query;
      return [() => ask(q)];
    }
    return const [];
  }

  void _run(VoidCallback action) => Navigator.of(context).pop(action);

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _highlight = (_highlight + delta) % count);
    final ctx = _rowKeys[_highlight]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: delta > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<VoidCallback> actions) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1, actions.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1, actions.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (actions.isNotEmpty) _run(actions[_highlight.clamp(0, actions.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        (key == LogicalKeyboardKey.keyK && (keys.isControlPressed || keys.isMetaPressed))) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final visible = filterPaletteEntries(widget.entries, _query);
    final actions = _actions(visible);
    if (_highlight >= actions.length) _highlight = 0;

    final rows = <Widget>[];
    var index = 0;
    PaletteSection? current;
    for (final e in visible) {
      if (e.section != current) {
        current = e.section;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.xs),
          child: Text(e.section.label.toUpperCase(), style: OrtizType.caption.copyWith(color: t.muted)),
        ));
      }
      rows.add(_row(t, index, e.icon, e.color ?? t.fg, e.title, e.appLabel, e.color, actions[index]));
      index++;
    }
    if (visible.isEmpty && _query.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.all(OrtizSpace.lg),
        child: Text('Nada coincide con «$_query».', style: OrtizType.bodySm.copyWith(color: t.muted)),
      ));
      if (actions.isNotEmpty) {
        rows.add(_row(t, 0, Icons.auto_awesome_rounded, t.accent, 'Pregúntale a Ortiz: «$_query»', null, null, actions[0]));
      }
    }

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(
        top: isDesktop ? OrtizSpace.xxxl : OrtizSpace.lg,
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        bottom: OrtizSpace.lg,
      ),
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.dialog),
        side: BorderSide(color: t.line, width: OrtizStroke.hairline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: OrtizSize.paletteMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Focus(
          onKeyEvent: (node, event) => _onKey(node, event, actions),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: t.muted, size: OrtizIconSize.md),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Busca una app o una acción…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onChanged: (_) => setState(() => _highlight = 0),
                      ),
                    ),
                    _KeyBadge(label: 'ESC', tokens: t),
                  ],
                ),
              ),
              const Divider(height: OrtizStroke.hairline),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
                ),
              ),
              if (isDesktop) ...[
                const Divider(height: OrtizStroke.hairline),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                  child: Wrap(
                    spacing: OrtizSpace.lg,
                    children: [
                      _hint(t, '↑↓', 'Moverte'),
                      _hint(t, '↵', 'Abrir'),
                      _hint(t, 'Esc', 'Cerrar'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(OrtizTokens t, String key, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyBadge(label: key, tokens: t),
          const SizedBox(width: OrtizSpace.xs),
          Text(label, style: OrtizType.caption.copyWith(color: t.muted)),
        ],
      );

  Widget _row(OrtizTokens t, int i, IconData icon, Color iconColor, String title, String? appLabel,
      Color? appColor, VoidCallback action) {
    final selected = i == _highlight;
    final key = _rowKeys.putIfAbsent(i, GlobalKey.new);
    return Semantics(
      key: key,
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
        child: MouseRegion(
          onHover: (_) {
            if (_highlight != i) setState(() => _highlight = i);
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            onTap: () => _run(action),
            child: Container(
              constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
              decoration: BoxDecoration(
                color: selected ? t.surfaceHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
              child: Row(
                children: [
                  Icon(icon, size: OrtizIconSize.md, color: iconColor),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: OrtizType.body.copyWith(color: t.fg)),
                  ),
                  if (appLabel != null) ...[
                    const SizedBox(width: OrtizSpace.sm),
                    Container(
                      width: OrtizSize.dot,
                      height: OrtizSize.dot,
                      decoration: BoxDecoration(color: appColor ?? t.muted, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: OrtizSpace.xs),
                    Text(appLabel, style: OrtizType.caption.copyWith(color: t.muted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.label, required this.tokens});

  final String label;
  final OrtizTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: Border.all(color: tokens.line, width: OrtizStroke.hairline),
      ),
      child: Text(label, style: OrtizType.caption.copyWith(color: tokens.muted)),
    );
  }
}
