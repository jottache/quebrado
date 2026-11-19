// Registro de Ortiz en el chat (spec 03, docs/design/ortiz-registra.md U2):
// tarjeta de propuesta (`pending`/`cancelled`/`confirmed`, spec 05 + motivos
// y opciones) y resultado (`saved`/`undone`/`error`) como mensaje de Ortiz.
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../quebrado/widgets/default_account_settings.dart';
import '../../quebrado/widgets/helpers.dart';
import '../models/chat_artifact_model.dart';
import '../services/write_tools/ortiz_resolver.dart';
import '../services/write_tools/write_tool_contract.dart';
import '../services/write_tools/write_tool_specs.dart';
import '../theme/agente_colors.dart';
import '../viewmodels/agente_state.dart';
import 'chat_message_bubble.dart';

import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Acción heredada de la tarjeta «Gran Roca» (sin ejecutor de la spec 03).
const String _legacyBigRockAction = 'create_reminder';

/// App de la suite de cada acción (color de la línea y del encabezado).
SuiteApp? _appFor(String action) {
  switch (action) {
    case WriteToolNames.registerTransaction:
    case WriteToolNames.payRecurringPayment:
      return SuiteApp.finanzas;
    case WriteToolNames.registerDiarioEntry:
    case WriteToolNames.createContact:
    case WriteToolNames.logMood:
      return SuiteApp.diario;
    case WriteToolNames.createHabit:
    case WriteToolNames.markHabitDone:
      return SuiteApp.habitos;
    case WriteToolNames.createReminder:
    case _legacyBigRockAction:
      return SuiteApp.recordatorios;
    case WriteToolNames.createNote:
      return SuiteApp.notas;
    default:
      return null;
  }
}

IconData _iconFor(String action) {
  switch (action) {
    case WriteToolNames.registerTransaction:
      return Icons.account_balance_wallet_rounded;
    case WriteToolNames.payRecurringPayment:
      return Icons.event_repeat_rounded;
    case WriteToolNames.registerDiarioEntry:
      return Icons.edit_note_rounded;
    case WriteToolNames.createContact:
      return Icons.person_add_alt_1_rounded;
    case WriteToolNames.logMood:
      return Icons.mood_rounded;
    case WriteToolNames.createHabit:
      return Icons.track_changes_rounded;
    case WriteToolNames.markHabitDone:
      return Icons.task_alt_rounded;
    case WriteToolNames.createReminder:
    case _legacyBigRockAction:
      return Icons.alarm_add_rounded;
    case WriteToolNames.createNote:
      return Icons.sticky_note_2_outlined;
    default:
      return Icons.add_task_rounded;
  }
}

List<SummaryPart> _partsOf(Map<String, dynamic> metadata) {
  final raw = metadata['summaryParts'];
  if (raw is! List) return const [];
  return [
    for (final p in raw)
      if (p is Map) SummaryPart.fromJson(Map<String, dynamic>.from(p)),
  ];
}

Map<String, dynamic> _mapOf(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// Detalle del registro en una sola frase (U2.1): segmentos con « · » (el
/// punto se queda al final de la línea), montos en mono con espacio duro.
Widget _summaryDetail(
  BuildContext context,
  List<SummaryPart> parts, {
  bool struck = false,
}) {
  final t = OrtizTokens.of(context);
  final decoration = struck ? TextDecoration.lineThrough : null;
  final base = OrtizType.body.copyWith(color: t.muted, decoration: decoration);
  final spans = <InlineSpan>[];
  for (var i = 0; i < parts.length; i++) {
    final p = parts[i];
    if (i > 0) spans.add(const TextSpan(text: ' · '));
    switch (p.kind) {
      case SummaryPartKind.amount:
        spans.add(TextSpan(
          text: p.text.replaceAll(' ', ' '),
          style: OrtizType.amount.copyWith(
            color: struck ? t.muted : t.fg,
            decoration: decoration,
          ),
        ));
      case SummaryPartKind.amountSecondary:
        spans.add(TextSpan(
          text: p.text.replaceAll(' ', ' '),
          style: OrtizType.amount.copyWith(color: t.muted, decoration: decoration),
        ));
      case SummaryPartKind.text:
        spans.add(TextSpan(text: p.text));
    }
  }
  return Text.rich(TextSpan(style: base, children: spans));
}

/// Texto de un motivo de la tarjeta (U2.4) y, si lo hay, su ayuda en `muted`.
/// Solo usa la metadata de la tarjeta (`resolved.accountCurrency` para
/// `account_currency_mismatch`).
@visibleForTesting
(String, String?) proposalReasonText(String reason, Map<String, dynamic> metadata) {
  final args = _mapOf(metadata['commitArgs']);
  final resolved = _mapOf(metadata['resolved']);
  final action = _str(metadata['action']) ?? '';
  final account = _str(resolved['accountName']) ?? _str(args['accountName']);
  final currency = currencyFromParam(_str(args['currency']));
  final currencyShort =
      currency == null ? null : defaultAccountCurrencyShort(currency);
  final accountCurrency = currencyFromParam(_str(resolved['accountCurrency']));
  String? amount;
  for (final p in _partsOf(metadata)) {
    if (p.kind == SummaryPartKind.amount) {
      amount = p.text;
      break;
    }
  }

  switch (reason) {
    case 'category_not_found':
      final asked = _str(args['categoryName']);
      return (
        asked == null
            ? 'No encontré esa categoría. Elige una:'
            : 'No encontré la categoría «$asked». Elige una:',
        null,
      );
    case 'category_ambiguous':
      final asked = _str(args['categoryName']);
      return (
        asked == null
            ? 'Hay más de una categoría con ese nombre. Elige una:'
            : 'Hay más de una categoría «$asked». Elige una:',
        null,
      );
    case 'account_currency_mismatch':
      final accCurrency =
          accountCurrency == null ? null : defaultAccountCurrencyShort(accountCurrency);
      if (account != null && accCurrency != null && currencyShort != null) {
        return ('$account es una cuenta en $accCurrency, no en $currencyShort.', null);
      }
      return (
        '${account ?? 'La cuenta'} no es una cuenta en ${currencyShort ?? 'esa moneda'}.',
        null,
      );
    case 'account_contains_match':
    case 'account_partial_match':
      final asked = _str(resolved['requestedAccountName']);
      if (asked != null &&
          account != null &&
          asked.toLowerCase() != account.toLowerCase()) {
        return ('Entendí «$asked» como $account.', null);
      }
      return ('Usé ${account ?? 'la cuenta'}, la más parecida al nombre que dijiste.', null);
    case 'name_not_in_user_text':
      final name = _str(resolved['habit']) ??
          _str(resolved['contactName']) ??
          _str(resolved['paymentName']) ??
          _str(args['habitName']) ??
          _str(args['contactName']) ??
          _str(args['paymentName']);
      return (
        name == null
            ? 'No mencionaste ese nombre; confírmalo para registrarlo.'
            : 'No mencionaste «$name»; confírmalo para registrarlo.',
        null,
      );
    case 'single_account_no_default':
      return (
        'Usé ${account ?? 'la cuenta'}, tu única cuenta en ${currencyShort ?? 'esa moneda'}.',
        'Puedes fijarla como predeterminada en Ajustes.',
      );
    case 'contact_not_found':
      final name = _str(args['contactName']);
      return (
        name == null
            ? 'No encontré ese contacto en tus contactos.'
            : 'No encontré a «$name» en tus contactos.',
        null,
      );
    case 'duplicate_name':
      final isHabit = action == WriteToolNames.createHabit;
      final name = _str(isHabit ? args['title'] : args['name']);
      final what = isHabit ? 'un hábito' : 'un contacto';
      return (
        name == null ? 'Ya tienes $what con ese nombre.' : 'Ya tienes $what llamado «$name».',
        null,
      );
    case 'no_pending_occurrence':
      final payment = _str(resolved['paymentName']) ?? _str(args['paymentName']);
      return ('${payment ?? 'Ese pago'} no tiene un pago pendiente hoy.', null);
    case 'future_date':
      final date = DateTime.tryParse(_str(args['date']) ?? '');
      return (
        date == null ? 'La fecha está en el futuro.' : 'La fecha es ${formatDate(date)}, en el futuro.',
        null,
      );
    case 'past_date':
      final due = DateTime.tryParse(_str(args['dueAt']) ?? '');
      if (due == null) return ('Esa fecha ya pasó.', null);
      final hh = due.hour.toString().padLeft(2, '0');
      final mm = due.minute.toString().padLeft(2, '0');
      return ('La fecha ${formatDate(due)} $hh:$mm ya pasó.', null);
    case 'amount_not_in_user_text':
      return (
        amount == null
            ? 'El monto no salió de tu mensaje. Revísalo.'
            : 'El monto $amount no salió de tu mensaje. Revísalo.',
        null,
      );
    case 'amount_above_due':
      return (
        amount == null
            ? 'El monto es mayor que lo que falta por pagar.'
            : 'El monto $amount es mayor que lo que falta por pagar.',
        null,
      );
    case 'read_untrusted_text':
      return ('Leí tus notas o tu diario en este mensaje; confírmalo tú antes de guardar.', null);
    case 'contact_not_in_user_text':
      final contact = _str(args['contactName']);
      return (
        contact == null
            ? 'No nombraste a ese contacto en tu mensaje. Revísalo.'
            : 'No nombraste a «$contact» en tu mensaje. Revísalo.',
        null,
      );
    case 'too_many_writes':
      return ('Ya guardé varios registros en este mensaje; confirma tú este.', null);
    // Tarjetas guardadas antes del 2026-11-19 (ya no se generan).
    case 'multiple_writes':
      return ('Es el segundo registro de este mensaje; confírmalo tú.', null);
    case 'other_book':
      final book = _str(resolved['bookName']) ?? _str(args['profileName']);
      return (
        book == null
            ? 'Es de otro libro, no del que tienes abierto.'
            : 'Es del libro $book, no del que tienes abierto.',
        'Se guarda allí sin cambiar el libro abierto.',
      );
    default:
      return ('Revisa los datos antes de confirmar.', null);
  }
}

/// Foco del campo del chat para los mensajes de la lista (U3): tras deshacer
/// un registro, el foco vuelve al campo. Lo ponen las vistas de chat
/// alrededor de cada mensaje; sin él, el foco no se mueve.
class ChatInputFocus extends InheritedWidget {
  const ChatInputFocus({super.key, required this.focusNode, required super.child});

  final FocusNode focusNode;

  /// El foco del campo del chat más cercano, o null si no hay.
  static FocusNode? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatInputFocus>()?.focusNode;

  @override
  bool updateShouldNotify(ChatInputFocus oldWidget) => focusNode != oldWidget.focusNode;
}

class ActionProposalCardView extends StatefulWidget {
  final ChatArtifactModel artifact;

  /// Texto de Ortiz (Markdown) que va encima de la línea 1 del resultado.
  final String? leadingText;

  const ActionProposalCardView({super.key, required this.artifact, this.leadingText});

  /// `true` si el estado se pinta como resultado (burbuja), no como tarjeta.
  static bool isResultStatus(Object? status) =>
      status == 'saved' || status == 'undone' || status == 'error';

  @override
  State<ActionProposalCardView> createState() => _ActionProposalCardViewState();
}

class _ActionProposalCardViewState extends State<ActionProposalCardView> {
  bool _isProcessing = false;

  /// Elección de la persona por clave de `options` (sin preselección, C18).
  final Map<String, String> _choices = {};
  bool _showAllCategories = false;

  Map<String, dynamic> get _metadata => widget.artifact.metadata;
  String get _action => _metadata['action']?.toString() ?? '';
  String get _status => _metadata['status']?.toString() ?? 'pending';

  Map<String, List<String>> get _options {
    final raw = _metadata['options'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is List && (e.value as List).isNotEmpty)
          e.key.toString(): [for (final v in e.value as List) v.toString()],
    };
  }

  bool get _allChosen => _options.keys.every(_choices.containsKey);

  Future<void> _handleConfirm() async {
    if (_isProcessing || _status != 'pending' || !_allChosen) return;
    setState(() => _isProcessing = true);
    // Un solo camino de guardado (spec 03, §2.2): lo decide AgenteState.
    await context
        .read<AgenteState>()
        .confirmProposal(widget.artifact.id, choices: Map<String, dynamic>.from(_choices));
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  void _handleCancel() {
    if (_isProcessing || _status != 'pending') return;
    context.read<AgenteState>().rejectProposal(widget.artifact.id);
    showOrtizNotice(context, 'Acción cancelada. No se crearon registros.');
  }

  @override
  Widget build(BuildContext context) {
    final isResult = ActionProposalCardView.isResultStatus(_status);
    return AnimatedSwitcher(
      duration: OrtizMotion.of(context, OrtizMotion.base),
      switchInCurve: OrtizMotion.ease,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: isResult
          ? _ActionResultView(
              key: const ValueKey('result'),
              artifact: widget.artifact,
              leadingText: widget.leadingText,
            )
          : KeyedSubtree(key: const ValueKey('card'), child: _buildCard(context)),
    );
  }

  // -------------------------------------------------------------------------
  // Tarjeta de propuesta (spec 05 + U2.4)
  // -------------------------------------------------------------------------

  /// Lista completa para «Ver todas» de [key], tal como la arma el ejecutor
  /// (`allOptions` de la metadata); vacía si no viene.
  List<String> _allOptionsFor(String key) {
    final raw = _metadata['allOptions'];
    if (raw is! Map) return const [];
    final list = raw[key];
    if (list is! List) return const [];
    return [for (final v in list) v.toString()];
  }

  Widget _buildCard(BuildContext context) {
    final t = OrtizTokens.of(context);
    final app = _appFor(_action);
    final color = app?.color ?? AgenteColors.primary;
    final moduleLabel = app?.label ?? 'OrtizApp';
    final title = _str(_metadata['summaryTitle']) ?? widget.artifact.title;
    // Gran Roca: resumen etiqueta/valor; escrituras de la spec 03: trozos.
    final rawSummary = _metadata['summary'];
    final labelValues = rawSummary is List ? rawSummary : const [];
    final parts = _partsOf(_metadata);
    final chosenCategory = _choices['categoryName'];
    final shownParts = <SummaryPart>[...parts];
    if (chosenCategory != null) {
      var at = 0;
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].kind != SummaryPartKind.text) at = i + 1;
      }
      shownParts.insert(at, SummaryPart(chosenCategory));
    }
    final reasons = [
      for (final r in (_metadata['reasons'] is List ? _metadata['reasons'] as List : const []))
        r.toString(),
    ];
    final isPending = _status == 'pending';
    final lastError = isPending ? _str(_metadata['lastError']) : null;

    return Container(
      margin: const EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xs),
      // Bloque del chat sobre `surface`, sin sombra; el borde marca el estado.
      decoration: BoxDecoration(
        color: AgenteColors.artifactBg,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: Border.all(
          color: _status == 'confirmed'
              ? OrtizPalette.ok.withValues(alpha: 0.5)
              : _status == 'cancelled'
                  ? AgenteColors.artifactBorder
                  : color.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Cabecera con módulo y estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
            color: color.withValues(alpha: 0.09),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(_iconFor(_action), size: OrtizIconSize.md, color: color)),
                const SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        moduleLabel,
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: OrtizFontSize.body,
                          fontWeight: FontWeight.w900,
                          color: OrtizPalette.fg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
          ),

          // 2. Descripción (Gran Roca); en la spec 03 es el resumen unido.
          if (widget.artifact.content.isNotEmpty && parts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.md, OrtizSpace.md, OrtizSpace.xs),
              child: Text(
                widget.artifact.content,
                style: const TextStyle(
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: FontWeight.w600,
                  color: OrtizPalette.muted,
                ),
              ),
            ),

          // 3. Resumen
          if (shownParts.isNotEmpty || labelValues.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.sm, OrtizSpace.md, OrtizSpace.md),
              padding: const EdgeInsets.all(OrtizSpace.md),
              decoration: BoxDecoration(
                color: OrtizPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(OrtizRadius.field),
              ),
              child: shownParts.isNotEmpty
                  ? _summaryDetail(context, shownParts)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: labelValues.map((item) {
                        final label = item['label']?.toString() ?? '';
                        final value = item['value']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 105,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.bold,
                                    color: OrtizPalette.muted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: OrtizFontSize.bodySm,
                                    fontWeight: FontWeight.w800,
                                    color: OrtizPalette.fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

          // 4. Revisa esto: motivos y opciones (solo mientras se puede confirmar)
          if (isPending && (reasons.isNotEmpty || _options.isNotEmpty || lastError != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.md, 0, OrtizSpace.md, OrtizSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in reasons) _buildReason(context, r),
                  for (final e in _options.entries) _buildOptions(context, e.key, e.value),
                  if (lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: OrtizSpace.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Icon(Icons.error_outline_rounded, size: OrtizIconSize.sm, color: t.bad),
                          ),
                          const SizedBox(width: OrtizSpace.sm),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(lastError, style: OrtizType.bodySm.copyWith(color: t.fg)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // 5. Acciones (Negar / Confirmar)
          if (isPending)
            Container(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.md, 0, OrtizSpace.md, OrtizSpace.md),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleCancel,
                      icon: const Icon(Icons.close_rounded, size: OrtizIconSize.sm),
                      label: const Text('Negar'),
                      style: OutlinedButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.padded,
                        foregroundColor: OrtizPalette.bad,
                        side: BorderSide(color: OrtizPalette.bad.withValues(alpha: 0.45)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing || !_allChosen ? null : _handleConfirm,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: OrtizIconSize.sm,
                              height: OrtizIconSize.sm,
                              child: CircularProgressIndicator(strokeWidth: OrtizStroke.focus, color: OrtizPalette.onAccent),
                            )
                          : const Icon(Icons.check_rounded, size: OrtizIconSize.md),
                      label: Text(_isProcessing ? 'Guardando…' : 'Confirmar'),
                      style: ElevatedButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.padded,
                        backgroundColor: OrtizPalette.ok,
                        foregroundColor: OrtizPalette.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReason(BuildContext context, String reason) {
    final t = OrtizTokens.of(context);
    final (text, help) = proposalReasonText(reason, _metadata);
    return Padding(
      padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.help_outline_rounded, size: OrtizIconSize.sm, color: t.warn),
          ),
          const SizedBox(width: OrtizSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: OrtizType.bodySm.copyWith(color: t.fg)),
                if (help != null) Text(help, style: OrtizType.bodySm.copyWith(color: t.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context, String key, List<String> options) {
    final t = OrtizTokens.of(context);
    final isCategory = key == 'categoryName';
    final all = isCategory ? _allOptionsFor(key) : const <String>[];
    final hasMore = all.any((c) => !options.contains(c));
    final shown = isCategory && _showAllCategories && hasMore ? all : options;
    final (prefix, hint) = switch (key) {
      'categoryName' => ('Categoría', 'Elige una categoría para confirmar.'),
      'contactName' => ('Contacto', 'Elige un contacto para confirmar.'),
      'accountName' => ('Cuenta', 'Elige una cuenta para confirmar.'),
      _ => ('Opción', 'Elige una opción para confirmar.'),
    };
    final selected = _choices[key];

    return Padding(
      padding: const EdgeInsets.only(top: OrtizSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: OrtizSpace.sm,
            runSpacing: OrtizSpace.sm,
            children: [
              for (final option in shown)
                Semantics(
                  container: true,
                  button: true,
                  selected: selected == option,
                  label: '$prefix $option',
                  onTap: _isProcessing ? null : () => setState(() => _choices[key] = option),
                  excludeSemantics: true,
                  child: ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: _isProcessing
                        ? null
                        : (_) => setState(() => _choices[key] = option),
                  ),
                ),
              if (isCategory && hasMore && !_showAllCategories)
                ActionChip(
                  avatar: const Icon(Icons.expand_more_rounded, size: OrtizIconSize.sm),
                  label: const Text('Ver todas'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => setState(() => _showAllCategories = true),
                ),
            ],
          ),
          if (selected == null)
            Padding(
              padding: const EdgeInsets.only(top: OrtizSpace.xs),
              child: Text(hint, style: OrtizType.bodySm.copyWith(color: t.muted)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (_status) {
      case 'confirmed':
        return const OrtizPill(
          label: 'Confirmado',
          color: OrtizPalette.ok,
          icon: Icons.check_circle_rounded,
        );
      case 'cancelled':
        return const OrtizPill(label: 'Cancelado', icon: Icons.cancel_rounded);
      case 'pending':
      default:
        return const OrtizPill(
          label: 'Por confirmar',
          color: OrtizPalette.warn,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Resultado: «Listo, registrado.» / «Deshecho.» / error (U2.1–U2.3, U2.5)
// ---------------------------------------------------------------------------

class _ActionResultView extends StatefulWidget {
  const _ActionResultView({super.key, required this.artifact, this.leadingText});

  final ChatArtifactModel artifact;
  final String? leadingText;

  @override
  State<_ActionResultView> createState() => _ActionResultViewState();
}

class _ActionResultViewState extends State<_ActionResultView> {
  bool _undoing = false;
  String? _note;
  bool _noteIsNotice = false;
  final FocusNode _undoFocus = FocusNode(debugLabel: 'Deshacer');

  Map<String, dynamic> get _metadata => widget.artifact.metadata;
  String get _status => _metadata['status']?.toString() ?? 'saved';
  String get _action => _metadata['action']?.toString() ?? '';
  String? get _undoId => _str(_metadata['undoId']);

  @override
  void dispose() {
    _undoFocus.dispose();
    super.dispose();
  }

  Future<void> _undo() async {
    final undoId = _undoId;
    if (undoId == null || _undoing) return;
    setState(() {
      _undoing = true;
      _note = null;
    });
    final result = await context.read<AgenteState>().undoAction(undoId);
    if (!mounted) return;
    setState(() {
      _undoing = false;
      if (!result.ok) {
        _note = result.message;
        _noteIsNotice = result.isNotice;
      }
    });
    // U3: deshecho → el foco vuelve al campo del chat; si falla, se queda en
    // Deshacer (tras reconstruir, cuando el botón vuelve a estar activo).
    final chatFocus = result.ok ? ChatInputFocus.maybeOf(context) : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (result.ok) {
        chatFocus?.requestFocus();
      } else {
        _undoFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final leading = widget.leadingText?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(top: OrtizSpace.xs, bottom: OrtizSpace.xs),
      padding: ChatMessageBubble.bubblePadding,
      decoration: ChatMessageBubble.bubbleDecoration(isUser: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading.isNotEmpty) ...[
            MarkdownBody(data: leading, styleSheet: ChatMessageBubble.botMarkdownStyle()),
            const SizedBox(height: OrtizSpace.sm),
          ],
          if (_status == 'error') _buildError(t) else ..._buildRecord(context, t),
        ],
      ),
    );
  }

  Widget _buildError(OrtizTokens t) {
    final message = _str(_metadata['message']) ??
        _str(_metadata['lastError']) ??
        'No pude registrarlo. No se guardó nada.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.error_outline_rounded, size: OrtizIconSize.sm, color: t.bad),
        ),
        const SizedBox(width: OrtizSpace.sm),
        Flexible(
          child: Semantics(
            liveRegion: true,
            child: Text(message, style: OrtizType.body.copyWith(color: t.fg)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRecord(BuildContext context, OrtizTokens t) {
    final agente = context.watch<AgenteState>();
    final undone = _status == 'undone';
    final alreadyMarked = !undone && _action == WriteToolNames.markHabitDone && _undoId == null;
    final canUndo = _undoId != null && agente.canUndo(widget.artifact.id);
    final app = _appFor(_action);
    final title = _str(_metadata['summaryTitle']) ?? widget.artifact.title;
    final parts = _partsOf(_metadata);
    final route = _str(_metadata['route']);
    final reloadHelp = !undone && !alreadyMarked && !canUndo
        ? 'Ya no se puede deshacer desde aquí; bórralo desde la app.'
        : null;

    final (IconData? icon, String headline) = undone
        ? (Icons.undo_rounded, 'Deshecho.')
        : alreadyMarked
            ? (Icons.check_circle_outline_rounded, 'Ya estaba marcado.')
            : (null, 'Listo, registrado.');

    final undoPressed = !undone && canUndo && !_undoing ? _undo : null;
    void goToRoute() => GoRouter.maybeOf(context)?.go(route!);
    final viewPressed = _undoing ? null : goToRoute;
    final buttonStyle = OutlinedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded);

    return [
      // Línea 1 (se anuncia sin mover el foco).
      Semantics(
        liveRegion: true,
        child: AnimatedSwitcher(
          duration: OrtizMotion.of(context, OrtizMotion.fast),
          switchInCurve: OrtizMotion.ease,
          child: Row(
            key: ValueKey(headline),
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: icon == null
                    ? const OrtizSuccessMark()
                    : Icon(icon, size: OrtizIconSize.sm, color: t.muted),
              ),
              const SizedBox(width: OrtizSpace.sm),
              Flexible(
                child: Text(
                  headline,
                  style: OrtizType.body.copyWith(
                    color: t.fg,
                    fontWeight: undone ? null : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: OrtizSpace.sm),
      // Registro: línea vertical del color de la app (no es una tarjeta).
      Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: undone ? t.line : (app?.color ?? t.accent),
              width: OrtizStroke.focus,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: OrtizSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OrtizType.titleSm.copyWith(
                color: undone ? t.muted : t.fg,
                decoration: undone ? TextDecoration.lineThrough : null,
              ),
            ),
            if (parts.isNotEmpty) _summaryDetail(context, parts, struck: undone),
          ],
        ),
      ),
      const SizedBox(height: OrtizSpace.md),
      Wrap(
        spacing: OrtizSpace.sm,
        runSpacing: OrtizSpace.sm,
        children: [
          if (!alreadyMarked)
            Semantics(
              button: true,
              enabled: undoPressed != null,
              label: 'Deshacer: $title',
              hint: reloadHelp,
              onTap: undoPressed,
              excludeSemantics: true,
              child: OutlinedButton.icon(
                onPressed: undoPressed,
                focusNode: _undoFocus,
                style: buttonStyle,
                icon: _undoing
                    ? const SizedBox(
                        width: OrtizIconSize.sm,
                        height: OrtizIconSize.sm,
                        child: CircularProgressIndicator(strokeWidth: OrtizStroke.focus),
                      )
                    : const Icon(Icons.undo_rounded, size: OrtizIconSize.sm),
                label: Text(_undoing ? 'Deshaciendo…' : 'Deshacer'),
              ),
            ),
          if (route != null && !undone)
            Semantics(
              button: true,
              enabled: viewPressed != null,
              label: 'Ver $title en ${app?.label ?? 'la app'}',
              onTap: viewPressed,
              excludeSemantics: true,
              child: OutlinedButton.icon(
                onPressed: viewPressed,
                style: buttonStyle,
                icon: const Icon(Icons.arrow_forward_rounded, size: OrtizIconSize.sm),
                label: const Text('Ver'),
              ),
            ),
        ],
      ),
      if (reloadHelp != null || _note != null)
        Padding(
          padding: const EdgeInsets.only(top: OrtizSpace.sm),
          child: Text(
            _note ?? reloadHelp!,
            style: OrtizType.bodySm.copyWith(
              color: _note != null && !_noteIsNotice ? t.bad : t.muted,
            ),
          ),
        ),
    ];
  }
}
