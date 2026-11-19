// Resumen del día (spec 04): filas del resumen en el chat y en el panel de
// hoy, y la fila «Revisando tus apps».
//
// Diseño: docs/design/resumen-del-dia.md U2 (bloque, filas, estados), U3
// (escaneo), U6 (acciones), U8 (accesibilidad) y U10 (textos). Solo pinta el
// `DailyBriefing` y emite `BriefingAction`: las reglas viven en
// `DailyBriefingService` y en `AgenteState`.
import 'package:flutter/material.dart';

import '../../quebrado/models/currency_type.dart';
import '../../quebrado/widgets/helpers.dart';
import '../../theme/ortiz_motion.dart';
import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';
import '../../theme/suite_apps.dart';
import '../../widgets/ortiz/ortiz.dart';
import '../models/daily_briefing.dart';

// ---------------------------------------------------------------------------
// Acciones
// ---------------------------------------------------------------------------

/// Lo que pide una fila del resumen. Quien monta el bloque decide cómo
/// atenderla (formulario de la app, navegación…).
sealed class BriefingAction {
  const BriefingAction();
}

/// «Escribir» (fila Diario).
final class BriefingWriteDiary extends BriefingAction {
  const BriefingWriteDiary();
}

/// «Registrar» (fila Ánimo).
final class BriefingLogMood extends BriefingAction {
  const BriefingLogMood();
}

/// «Pagar todo» ([partial] false) o «Abonar una parte» ([partial] true) sobre
/// la ocurrencia más antigua sin pagar del pago (Q8).
final class BriefingPay extends BriefingAction {
  const BriefingPay({required this.paymentId, required this.oldestOccurrenceDate, required this.partial});
  final String paymentId;
  final DateTime oldestOccurrenceDate;
  final bool partial;
}

/// «Ver» (fila Cumpleaños).
final class BriefingViewContact extends BriefingAction {
  const BriefingViewContact(this.contactId);
  final String contactId;
}

/// «Marcar» (fila Hábitos).
final class BriefingMarkHabits extends BriefingAction {
  const BriefingMarkHabits();
}

/// Opciones del menú «Posponer» (decisión Q7/U2: solo dos).
enum BriefingSnoozeOption {
  /// Ahora + 1 h.
  oneHour('1 hora', Duration(hours: 1)),

  /// Mañana a la misma hora de reloj (no ahora + 24 h: con un cambio de hora
  /// no son lo mismo).
  tomorrowSameTime('Mañana a esta hora', Duration(days: 1));

  const BriefingSnoozeOption(this.label, this.delay);
  final String label;

  /// Aproximación en duración. Para la hora objetivo usa [untilFrom]: para
  /// [tomorrowSameTime] no equivale a sumar este valor.
  final Duration delay;

  /// Hora a la que queda pospuesto si se elige en [now].
  DateTime untilFrom(DateTime now) => switch (this) {
        oneHour => now.add(const Duration(hours: 1)),
        tomorrowSameTime => DateTime(now.year, now.month, now.day + 1, now.hour, now.minute),
      };
}

/// «Posponer» un recordatorio con la opción elegida en el menú.
final class BriefingSnooze extends BriefingAction {
  const BriefingSnooze({required this.reminderId, required this.option});
  final String reminderId;
  final BriefingSnoozeOption option;

  /// Aproximación en duración; para la hora objetivo usa [untilFrom].
  Duration get delay => option.delay;

  /// Hora a la que queda pospuesto si se elige en [now].
  DateTime untilFrom(DateTime now) => option.untilFrom(now);
}

/// «Ver» (fila Tasas).
final class BriefingViewRates extends BriefingAction {
  const BriefingViewRates();
}

enum BriefingViewAllTarget { payments, reminders }

/// «Ver todos» de la fila «Y {n} más» (solo en el chat).
final class BriefingViewAll extends BriefingAction {
  const BriefingViewAll(this.target);
  final BriefingViewAllTarget target;
}

// ---------------------------------------------------------------------------
// Textos y formato (U10)
// ---------------------------------------------------------------------------

enum BriefingBlockVariant { chat, panel }

/// Tope de filas por categoría (pagos y recordatorios) en el chat. Constante
/// del widget, no token (U9).
const int kBriefingChatMaxRows = 3;

const List<String> _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// «lun 16»: el formato de las filas y del menú «Pagar».
String _shortDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}';

/// «a», «a y b», «a, b y c».
String _joinEs(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
}

/// Monto con el formato de la app, piezas unidas con « · »:
/// «$25.00 · Bs. 6250.00» (U1, CA-03/CA-04).
String briefingAmountText(BriefingAmount amount) =>
    amount.displayParts.map((p) => formatCurrency(p.amount, p.currency)).join(' · ');

String _rateNumber(double v) => v.toStringAsFixed(2);

/// «(+0.8 %)» a partir de la variación absoluta en Bs; null si no hay
/// registro de ayer (R-02).
String? _ratePercent(BriefingRate rate) {
  final delta = rate.deltaVsPrevious;
  if (delta == null || !rate.hasValue) return null;
  final previous = rate.value - delta;
  if (previous <= 0) return null;
  final pct = delta / previous * 100;
  final sign = pct >= 0 ? '+' : '-';
  return '($sign${pct.abs().toStringAsFixed(1)} %)';
}

// ---------------------------------------------------------------------------
// Bloque
// ---------------------------------------------------------------------------

/// Filas del resumen del día. [BriefingBlockVariant.chat] va dentro del
/// mensaje de Ortiz (con tope de [kBriefingChatMaxRows] por categoría y
/// entrada escalonada); [BriefingBlockVariant.panel] es el panel de hoy
/// (todas las filas).
///
/// Con [actionsEnabled] false (resumen viejo) no hay botones y abajo se lee
/// «Resumen del {fecha} a las {hora}. Pide uno nuevo para actuar.».
/// Si [activeBookId] no es el libro del resumen (`DailyBriefing.bookId`),
/// «Pagar» queda desactivado; [activeBookName] no decide nada (el texto
/// «Cambia al libro …» usa el nombre guardado en el resumen).
///
/// Un resumen recargado del historial no trae filas (solo `generatedAt` y
/// `period`; todas las secciones `unavailable`): se pinta solo la línea
/// «Resumen del {fecha} a las {hora}. Pide uno nuevo para actuar.».
class BriefingBlock extends StatelessWidget {
  const BriefingBlock({
    super.key,
    required this.briefing,
    this.variant = BriefingBlockVariant.chat,
    this.actionsEnabled = true,
    this.onAction,
    this.activeBookId,
    this.activeBookName,
  });

  final DailyBriefing briefing;
  final BriefingBlockVariant variant;
  final bool actionsEnabled;
  final void Function(BriefingAction action)? onAction;

  /// `AppState.activeDbName` del libro activo; null = no se compara.
  final String? activeBookId;
  final String? activeBookName;

  bool get _night => briefing.period == BriefingPeriod.night;
  bool get _isChat => variant == BriefingBlockVariant.chat;
  bool get _bookChanged => activeBookId != null && briefing.bookId.isNotEmpty && activeBookId != briefing.bookId;

  /// Resumen recargado sin filas (`DailyBriefing.rowsOmitted`). Un resumen
  /// vivo con todo `unavailable` sí pinta sus filas «No pude leer…».
  bool get _withoutData => briefing.rowsOmitted;

  void _emit(BriefingAction action) => onAction?.call(action);

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    if (_withoutData) {
      return Semantics(
        container: true,
        label: 'Resumen del día',
        child: _staleLine(t),
      );
    }
    final allClear = briefing.isAllClear;

    final diario = _diarioCategory();
    final mood = _moodCategory();
    final payments = _paymentsCategory();
    final birthdays = _birthdaysCategory();
    final habits = _habitsCategory();
    final rates = _ratesCategory();
    final doneRow = allClear ? _allClearCategory() : _upToDateCategory();
    // «Todo al día» abre el grupo, salvo que quede algo por hacer (el ánimo
    // no cuenta para estar al día): entonces va al final, como «Al día».
    final doneFirst = allClear && mood == null;

    final groups = <(String?, List<_Category?>)>[];
    if (_night) {
      groups.add((
        'Lo que faltó hoy',
        [
          if (doneFirst) doneRow,
          diario,
          mood,
          habits,
          _remindersCategory(tomorrow: false),
          if (!doneFirst) doneRow,
        ]
      ));
      groups.add(('Lo que viene', [payments, birthdays, _remindersCategory(tomorrow: true)]));
      groups.add((null, [rates]));
    } else {
      groups.add((
        'Lo que viene hoy',
        [
          if (doneFirst) doneRow,
          diario,
          mood,
          payments,
          birthdays,
          habits,
          _remindersCategory(tomorrow: false),
          if (!doneFirst) doneRow,
          rates,
        ]
      ));
    }

    final children = <Widget>[];
    var staggerIndex = 0;
    for (final (header, rawCategories) in groups) {
      final categories = rawCategories.whereType<_Category>().toList();
      if (categories.isEmpty) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: OrtizSpace.lg));
      if (header != null) {
        children.add(Semantics(
          header: true,
          child: Text(header, style: OrtizType.caption.copyWith(color: t.muted)),
        ));
        children.add(const SizedBox(height: OrtizSpace.sm));
      }
      for (var i = 0; i < categories.length; i++) {
        if (i > 0) children.add(const Divider());
        final category = categories[i];
        Widget view = _CategoryView(category: category);
        if (_isChat) view = ortizStaggered(context, staggerIndex++, view);
        // Clave estable por categoría: si otra aparece o desaparece, esta
        // conserva su entrada (no se repite la animación ni se cruza).
        children.add(KeyedSubtree(key: ValueKey('briefing-${category.id}'), child: view));
      }
    }

    if (!actionsEnabled) {
      children.add(const SizedBox(height: OrtizSpace.sm));
      children.add(_staleLine(t));
    }

    return Semantics(
      container: true,
      label: 'Resumen del día',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// «Resumen del {fecha} a las {hora}. Pide uno nuevo para actuar.»
  Widget _staleLine(OrtizTokens t) {
    final at = briefing.generatedAt;
    return Text(
      'Resumen del ${formatDate(at)} a las ${_hm(at)}. Pide uno nuevo para actuar.',
      style: OrtizType.bodySm.copyWith(color: t.muted),
    );
  }

  // -------------------------------------------------------------------------
  // Categorías
  // -------------------------------------------------------------------------

  _Category? _statusCategory(String id, SuiteApp app, String label, BriefingStatus status, String unavailable) {
    switch (status) {
      case BriefingStatus.loading:
        return _Category(id: id, app: app, key: '$label-loading', rows: [
          _RowData(dotColor: app.color, label: label, title: 'Cargando…', titleMuted: true),
        ]);
      case BriefingStatus.unavailable:
        return _Category(id: id, app: app, key: '$label-unavailable', rows: [
          _RowData(dotColor: app.color, label: label, title: 'No pude leer $unavailable.', titleMuted: true),
        ]);
      case BriefingStatus.ready:
        return null;
    }
  }

  _Category? _diarioCategory() {
    const label = 'Diario';
    final s = briefing.diario;
    if (s.status != BriefingStatus.ready) {
      return _statusCategory('diario', SuiteApp.diario, label, s.status, 'tu diario');
    }
    if (s.entriesToday > 0) return null;
    return _Category(id: 'diario', app: SuiteApp.diario, key: '$label-ready', rows: [
      _RowData(
        dotColor: SuiteApp.diario.color,
        label: label,
        title: _night ? 'Hoy no escribiste en el diario.' : 'Aún no escribes hoy.',
        trailing: actionsEnabled
            ? _ActionButton(
                label: 'Escribir',
                semanticLabel: 'Escribir en el diario',
                onPressed: () => _emit(const BriefingWriteDiary()),
              )
            : null,
      ),
    ]);
  }

  _Category? _moodCategory() {
    const label = 'Ánimo';
    final s = briefing.mood;
    if (s.status != BriefingStatus.ready) return _statusCategory('mood', SuiteApp.diario, label, s.status, 'tu ánimo');
    if (s.loggedToday) return null;
    return _Category(id: 'mood', app: SuiteApp.diario, key: '$label-ready', rows: [
      _RowData(
        dotColor: SuiteApp.diario.color,
        label: label,
        title: _night ? 'No registraste tu ánimo hoy.' : 'Aún no registras tu ánimo.',
        trailing: actionsEnabled
            ? _ActionButton(
                label: 'Registrar',
                semanticLabel: 'Registrar tu ánimo',
                onPressed: () => _emit(const BriefingLogMood()),
              )
            : null,
      ),
    ]);
  }

  _Category? _paymentsCategory() {
    final label = briefing.bookName.isEmpty ? 'Pagos pendientes' : 'Pagos pendientes · ${briefing.bookName}';
    final s = briefing.payments;
    if (s.status != BriefingStatus.ready) {
      return _statusCategory('payments', SuiteApp.finanzas, label, s.status, 'tus pagos');
    }
    if (s.items.isEmpty) return null;

    final sorted = s.sortedItems;
    final visible = _isChat ? sorted.take(kBriefingChatMaxRows).toList() : sorted;
    final hidden = sorted.length - visible.length;

    final rows = <_RowData>[
      for (final (i, p) in visible.indexed) _paymentRow(p, label: i == 0 ? label : null),
    ];
    if (hidden > 0) {
      final total = s.hiddenRemainingUsd(visible.length);
      rows.add(_RowData(
        title: total != null ? 'Y $hidden más · ${formatUSD(total)}' : 'Y $hidden más',
        trailing: actionsEnabled
            ? _ActionButton(
                label: 'Ver todos',
                semanticLabel: 'Ver todos los pagos',
                onPressed: () => _emit(const BriefingViewAll(BriefingViewAllTarget.payments)),
              )
            : null,
      ));
    }
    return _Category(id: 'payments', app: SuiteApp.finanzas, key: 'payments-ready', rows: rows);
  }

  /// Opción completa del menú «Pagar»: con varias ocurrencias, «Pagar el del
  /// {lun 16} · {monto}» (solo la más antigua, con la fecha como en la fila);
  /// con una, «Pagar todo · {monto}». Sin monto si no se sabe lo que falta de
  /// esa ocurrencia.
  String _payNowLabel(BriefingPayment p) {
    final base = p.occurrenceCount > 1 ? 'Pagar el del ${_shortDate(p.oldestOccurrenceDate)}' : 'Pagar todo';
    final amount = p.payNowAmount;
    if (amount == null) return base;
    final primary = amount.displayParts.first;
    return '$base · ${formatCurrency(primary.amount, primary.currency)}';
  }

  /// «Abonar al del {lun 16}» con varias ocurrencias; «Abonar una parte» con una.
  String _payPartLabel(BriefingPayment p) =>
      p.occurrenceCount > 1 ? 'Abonar al del ${_shortDate(p.oldestOccurrenceDate)}' : 'Abonar una parte';

  _RowData _paymentRow(BriefingPayment p, {String? label}) {
    final done = !p.isPending;
    final title = p.overdueCount > 1 ? '${p.name} · ${p.overdueCount} vencidos' : p.name;
    final days = briefingCalendarDaysBetween(briefing.generatedAt, p.oldestOccurrenceDate);
    final when = p.isOverdue || days < 0
        ? 'venció el ${_shortDate(p.oldestOccurrenceDate)}'
        : days == 0
            ? 'vence hoy'
            : days == 1
                ? 'vence mañana'
                : 'vence ${_shortDate(p.oldestOccurrenceDate)}';
    final detail = p.hasPartial
        ? '$when · abonaste ${formatCurrency(p.partialPaid, p.remaining.original)}'
        : when;

    Widget? trailing;
    Object trailingKey = 'none';
    switch (p.state) {
      case BriefingPaymentState.paid:
        trailing = const _PaidStatus();
        trailingKey = 'paid';
      case BriefingPaymentState.dismissed:
        trailing = const _MutedStatus('Omitido');
        trailingKey = 'dismissed';
      case BriefingPaymentState.pending:
        if (actionsEnabled) {
          trailingKey = 'pay';
          trailing = _MenuButton<bool>(
            label: 'Pagar',
            semanticLabel: 'Pagar ${p.name}',
            enabled: !_bookChanged,
            options: [
              (false, _payNowLabel(p)),
              (true, _payPartLabel(p)),
            ],
            onSelected: (partial) => _emit(BriefingPay(
              paymentId: p.paymentId,
              oldestOccurrenceDate: p.oldestOccurrenceDate,
              partial: partial,
            )),
          );
        }
    }

    return _RowData(
      dotColor: SuiteApp.finanzas.color,
      label: label,
      title: title,
      titleMuted: done,
      pills: [
        if (p.isOverdue && !done) _Pill.overdue,
        if (p.hasPartial && !done) _Pill.partial,
      ],
      detail: detail,
      amount: p.remaining,
      amountMuted: done,
      note: p.remaining.rateMissing ? 'sin tasa de hoy' : null,
      trailing: trailing,
      trailingKey: trailingKey,
      footnote: p.isPending && actionsEnabled && _bookChanged
          ? 'Cambia al libro ${briefing.bookName} para pagarlo.'
          : null,
    );
  }

  _Category? _birthdaysCategory() {
    const label = 'Cumpleaños';
    final s = briefing.birthdays;
    if (s.status != BriefingStatus.ready) {
      return _statusCategory('birthdays', SuiteApp.diario, label, s.status, 'tus cumpleaños');
    }
    if (s.items.isEmpty) return null;
    return _Category(id: 'birthdays', app: SuiteApp.diario, key: '$label-ready', rows: [
      for (final (i, b) in s.sortedItems.indexed)
        _RowData(
          dotColor: SuiteApp.diario.color,
          label: i == 0 ? label : null,
          title: b.inDays <= 0
              ? '${b.name} cumple hoy'
              : b.inDays == 1
                  ? '${b.name} cumple mañana'
                  : '${b.name} cumple el ${_shortDate(b.date)}',
          detail: b.inDays >= 2 ? 'en ${b.inDays} días' : null,
          trailing: actionsEnabled
              ? _ActionButton(
                  label: 'Ver',
                  semanticLabel: 'Ver contacto de ${b.name}',
                  onPressed: () => _emit(BriefingViewContact(b.contactId)),
                )
              : null,
        ),
    ]);
  }

  _Category? _habitsCategory() {
    const label = 'Hábitos';
    final s = briefing.habits;
    if (s.status != BriefingStatus.ready) {
      return _statusCategory('habits', SuiteApp.habitos, label, s.status, 'tus hábitos');
    }
    final rows = <_RowData>[];
    if (s.hasPending) {
      final shown = s.pendingNamesShown;
      final rest = s.pendingNamesHidden;
      final missing = shown.isEmpty
          ? ''
          : rest > 0
              ? ' Te faltan ${shown.join(', ')} y $rest más.'
              : ' Te faltan ${_joinEs(shown)}.';
      rows.add(_RowData(
        dotColor: SuiteApp.habitos.color,
        label: label,
        title: '${s.done} de ${s.scheduled} hechos.$missing',
        trailing: actionsEnabled
            ? _ActionButton(
                label: 'Marcar',
                semanticLabel: 'Marcar hábitos de hoy',
                onPressed: () => _emit(const BriefingMarkHabits()),
              )
            : null,
      ));
    }
    for (final streak in s.negativeStreaks) {
      rows.add(_RowData(
        dotColor: SuiteApp.habitos.color,
        label: rows.isEmpty ? label : null,
        title: streak.cleanDays == 1
            ? 'Llevas 1 día sin ${streak.title}'
            : 'Llevas ${streak.cleanDays} días sin ${streak.title}',
      ));
    }
    if (rows.isEmpty) return null;
    return _Category(id: 'habits', app: SuiteApp.habitos, key: '$label-ready', rows: rows);
  }

  _Category? _remindersCategory({required bool tomorrow}) {
    const label = 'Recordatorios';
    final s = briefing.reminders;
    if (s.status != BriefingStatus.ready) {
      // El estado de la sección sale una sola vez, en su primer lugar.
      if (tomorrow) return null;
      return _statusCategory('reminders-today', SuiteApp.recordatorios, label, s.status, 'tus recordatorios');
    }
    // De mañana no salen los de mañana (Q4); de noche van en «Lo que viene».
    if (tomorrow && !_night) return null;
    final sorted = tomorrow ? s.sortedTomorrowItems : s.sortedTodayItems;
    if (sorted.isEmpty) return null;
    final visible = _isChat ? sorted.take(kBriefingChatMaxRows).toList() : sorted;
    final hidden = sorted.length - visible.length;

    final rows = <_RowData>[
      for (final (i, r) in visible.indexed) _reminderRow(r, label: i == 0 ? label : null),
      if (hidden > 0)
        _RowData(
          title: 'Y $hidden más',
          trailing: actionsEnabled
              ? _ActionButton(
                  label: 'Ver todos',
                  semanticLabel: 'Ver todos los recordatorios',
                  onPressed: () => _emit(const BriefingViewAll(BriefingViewAllTarget.reminders)),
                )
              : null,
        ),
    ];
    return _Category(
      id: tomorrow ? 'reminders-tomorrow' : 'reminders-today',
      app: SuiteApp.recordatorios,
      key: '$label-$tomorrow-ready',
      rows: rows,
    );
  }

  String _reminderWhen(DateTime at) {
    final days = briefingCalendarDaysBetween(briefing.generatedAt, at);
    return switch (days) {
      -1 => 'ayer ${_hm(at)}',
      0 => 'hoy ${_hm(at)}',
      1 => 'mañana ${_hm(at)}',
      _ => formatDate(at),
    };
  }

  String _snoozedWhen(DateTime at) {
    final days = briefingCalendarDaysBetween(briefing.generatedAt, at);
    return switch (days) {
      0 => 'las ${_hm(at)}',
      1 => 'mañana ${_hm(at)}',
      _ => '${formatDate(at)} ${_hm(at)}',
    };
  }

  _RowData _reminderRow(BriefingReminder r, {String? label}) {
    final snoozed = r.snoozedUntil;
    Widget? trailing;
    Object trailingKey = 'none';
    if (snoozed != null) {
      trailing = _SnoozedStatus('Pospuesto a ${_snoozedWhen(snoozed)}');
      trailingKey = 'snoozed';
    } else if (actionsEnabled) {
      trailingKey = 'snooze';
      trailing = _MenuButton<BriefingSnoozeOption>(
        label: 'Posponer',
        semanticLabel: 'Posponer ${r.title}',
        options: [for (final o in BriefingSnoozeOption.values) (o, o.label)],
        onSelected: (option) => _emit(BriefingSnooze(reminderId: r.id, option: option)),
      );
    }
    return _RowData(
      dotColor: SuiteApp.recordatorios.color,
      label: label,
      title: r.title,
      pills: [if (r.isOverdue && snoozed == null) _Pill.overdue],
      detail: _reminderWhen(r.dueAt),
      trailing: trailing,
      trailingKey: trailingKey,
    );
  }

  _Category _ratesCategory() {
    const label = 'Tasas';
    final s = briefing.rates;
    if (s.status != BriefingStatus.ready) {
      return _statusCategory('rates', SuiteApp.finanzas, label, s.status, 'las tasas')!;
    }
    final parts = <(String, String?)>[
      if (s.bcv.hasValue) ('BCV ${_rateNumber(s.bcv.value)}', _ratePercent(s.bcv)),
      if (s.parallel.hasValue) ('Paralelo ${_rateNumber(s.parallel.value)}', null),
      if (s.euro.hasValue) ('€ ${_rateNumber(s.euro.value)}', _ratePercent(s.euro)),
    ];
    return _Category(id: 'rates', app: SuiteApp.finanzas, key: '$label-ready', rows: [
      _RowData(
        dotColor: SuiteApp.finanzas.color,
        label: label,
        title: parts.isEmpty ? 'Aún no tengo las tasas de hoy' : null,
        rates: parts.isEmpty ? null : parts,
        trailing: actionsEnabled
            ? _ActionButton(
                label: 'Ver',
                semanticLabel: 'Ver tasas en Finanzas',
                onPressed: () => _emit(const BriefingViewRates()),
              )
            : null,
      ),
    ]);
  }

  /// «Al día: diario, ánimo y hábitos.» con lo que esté completo.
  _Category? _upToDateCategory() {
    final done = [for (final s in briefing.upToDateSections) s.label];
    if (done.isEmpty) return null;
    return _Category(id: 'done', app: SuiteApp.habitos, key: 'up-to-date', rows: [
      _RowData(successMark: true, title: 'Al día: ${_joinEs(done)}.'),
    ]);
  }

  /// «Todo al día: escribiste en el diario, …» (U2.4).
  _Category _allClearCategory() {
    final clauses = <String>[
      'escribiste en el diario',
      'no tienes pagos esta semana',
      if (briefing.habits.scheduled > 0) 'tus hábitos están completos',
    ];
    return _Category(id: 'done', app: SuiteApp.habitos, key: 'all-clear', rows: [
      _RowData(successMark: true, title: 'Todo al día: ${_joinEs(clauses)}'),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Filas
// ---------------------------------------------------------------------------

enum _Pill {
  overdue('Vencido'),
  partial('Parcial');

  const _Pill(this.label);
  final String label;
}

class _Category {
  const _Category({required this.id, required this.app, required this.key, required this.rows});

  /// Identidad estable de la categoría (no cambia con su estado).
  final String id;
  final SuiteApp app;

  /// Cambia con el estado (cargando → listo) y dispara el fundido.
  final String key;
  final List<_RowData> rows;
}

class _RowData {
  const _RowData({
    this.dotColor,
    this.successMark = false,
    this.label,
    this.title,
    this.titleMuted = false,
    this.rates,
    this.pills = const [],
    this.detail,
    this.amount,
    this.amountMuted = false,
    this.note,
    this.trailing,
    this.trailingKey = 'none',
    this.footnote,
  });

  /// Punto de la app; null sin punto (fila «Y {n} más»).
  final Color? dotColor;

  /// `OrtizSuccessMark` en lugar del punto (filas «Al día»).
  final bool successMark;

  /// Etiqueta de la categoría (solo en su primera fila).
  final String? label;
  final String? title;
  final bool titleMuted;

  /// Línea de tasas en mono: (valor, variación en `muted`).
  final List<(String, String?)>? rates;
  final List<_Pill> pills;
  final String? detail;
  final BriefingAmount? amount;
  final bool amountMuted;
  final String? note;
  final Widget? trailing;
  final Object trailingKey;
  final String? footnote;
}

/// Una categoría: sus filas con `Divider` entre ellas. Al cambiar de estado
/// (cargando → listo) se sustituye con un fundido (U2.4).
class _CategoryView extends StatelessWidget {
  const _CategoryView({required this.category});
  final _Category category;

  @override
  Widget build(BuildContext context) {
    final rows = category.rows;
    return AnimatedSwitcher(
      duration: OrtizMotion.of(context, OrtizMotion.base),
      switchInCurve: OrtizMotion.ease,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(category.key),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            _BriefingRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

/// Fila sin tarjeta (U2.2): punto alineado con la primera línea, textos que
/// se ajustan sin elipsis, montos en mono y acción arriba a la derecha (o
/// debajo con texto grande).
class _BriefingRow extends StatelessWidget {
  const _BriefingRow({required this.data});
  final _RowData data;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final large = OrtizType.isLargeText(context);
    final d = data;
    final titleColor = d.titleMuted ? t.muted : t.fg;

    final lines = <Widget>[
      if (d.label != null) Text(d.label!, style: OrtizType.caption.copyWith(color: t.muted)),
      if (d.title != null) Text(d.title!, style: OrtizType.body.copyWith(color: titleColor)),
      if (d.rates != null)
        Text.rich(
          TextSpan(children: [
            for (final (i, (value, delta)) in d.rates!.indexed) ...[
              if (i > 0) TextSpan(text: ' · ', style: TextStyle(color: t.muted)),
              TextSpan(text: value),
              if (delta != null) TextSpan(text: ' $delta', style: TextStyle(color: t.muted)),
            ],
          ]),
          style: OrtizType.amount.copyWith(color: t.fg),
        ),
      if (d.pills.isNotEmpty || d.detail != null)
        Wrap(
          spacing: OrtizSpace.xs,
          runSpacing: OrtizSpace.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in d.pills) OrtizPill(label: p.label, color: p == _Pill.overdue ? t.bad : t.warn),
            if (d.detail != null) Text(d.detail!, style: OrtizType.bodySm.copyWith(color: t.muted)),
          ],
        ),
      if (d.amount != null) _AmountLine(amount: d.amount!, muted: d.amountMuted),
      if (d.note != null) Text(d.note!, style: OrtizType.bodySm.copyWith(color: t.muted)),
      if (d.footnote != null) Text(d.footnote!, style: OrtizType.bodySm.copyWith(color: t.muted)),
    ];

    final text = MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: OrtizSpace.xxs),
            lines[i],
          ],
        ],
      ),
    );

    final Widget leading = ExcludeSemantics(
      child: d.successMark
          ? const OrtizSuccessMark()
          : Padding(
              padding: const EdgeInsets.only(top: OrtizSpace.xs),
              child: SizedBox.square(
                dimension: OrtizSize.dot,
                child: d.dotColor == null
                    ? null
                    : DecoratedBox(decoration: BoxDecoration(color: d.dotColor, shape: BoxShape.circle)),
              ),
            ),
    );

    final Widget? trailing = d.trailing == null
        ? null
        : AnimatedSwitcher(
            duration: OrtizMotion.of(context, OrtizMotion.fast),
            switchInCurve: OrtizMotion.ease,
            child: KeyedSubtree(key: ValueKey(d.trailingKey), child: d.trailing!),
          );

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: OrtizSpace.md),
        Expanded(child: text),
        if (trailing != null && !large) ...[
          const SizedBox(width: OrtizSpace.sm),
          trailing,
        ],
      ],
    );
    if (trailing != null && large) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: OrtizSpace.sm),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: OrtizSize.dot + OrtizSpace.md),
            child: trailing,
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
        child: content,
      ),
    );
  }
}

/// «$25.00 · Bs. 6250.00» en dos piezas (o tres con €) dentro de un `Wrap`:
/// si no caben, el equivalente baja de línea; nunca se corta. El lector oye
/// el monto completo una vez.
class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.amount, required this.muted});
  final BriefingAmount amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final parts = amount.displayParts;
    return Semantics(
      label: briefingAmountText(amount),
      excludeSemantics: true,
      child: Wrap(
        spacing: OrtizSpace.xs,
        runSpacing: OrtizSpace.xxs,
        children: [
          for (final (i, part) in parts.indexed)
            OrtizAmount(
              value: part.amount,
              currencySymbol: '',
              color: i == 0 && !muted ? t.fg : t.muted,
              format: (v) => _piece(v, part.currency, first: i == 0),
            ),
        ],
      ),
    );
  }

  static String _piece(double v, CurrencyType currency, {required bool first}) =>
      first ? formatCurrency(v, currency) : '· ${formatCurrency(v, currency)}';
}

/// `OutlinedButton` del tema, objetivo de 48 y etiqueta semántica completa
/// («Ver» en pantalla, «Ver contacto de Andrea» para el lector).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.semanticLabel, required this.onPressed});
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
        onPressed: onPressed,
        child: Semantics(label: semanticLabel, child: ExcludeSemantics(child: Text(label))),
      );
}

/// Botón que abre un menú anclado a él («Pagar», «Posponer»; U6). Flechas,
/// Enter y Esc los da el menú emergente del tema.
class _MenuButton<T> extends StatelessWidget {
  const _MenuButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final String semanticLabel;
  final List<(T, String)> options;
  final void Function(T value) onSelected;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<T>(
      context: context,
      position: position,
      items: [
        for (final (value, text) in options) PopupMenuItem<T>(value: value, child: Text(text)),
      ],
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (buttonContext) => _ActionButton(
          label: label,
          semanticLabel: semanticLabel,
          onPressed: enabled ? () => _open(buttonContext) : null,
        ),
      );
}

/// «Pagado» con la marca de éxito (CA-10).
class _PaidStatus extends StatelessWidget {
  const _PaidStatus();

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: OrtizSpace.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: OrtizSuccessMark()),
          const SizedBox(width: OrtizSpace.xs),
          Text('Pagado', style: OrtizType.bodySm.copyWith(color: t.ok)),
        ],
      ),
    );
  }
}

class _SnoozedStatus extends StatelessWidget {
  const _SnoozedStatus(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: OrtizType.bodySm.copyWith(color: OrtizTokens.of(context).warn));
}

class _MutedStatus extends StatelessWidget {
  const _MutedStatus(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: OrtizType.bodySm.copyWith(color: OrtizTokens.of(context).muted));
}

// ---------------------------------------------------------------------------
// «Revisando tus apps» (U3)
// ---------------------------------------------------------------------------

/// Fila de escaneo: «Revisando tus apps» y una píldora por `SuiteApp` que se
/// enciende a `OrtizMotion.fast` de la anterior. Una píldora no se enciende
/// hasta que su app está en [readyApps]. Con reducir movimiento, las listas
/// aparecen encendidas a la vez. El plazo de 1,5 s (`OrtizMotion.scanMax`) lo
/// lleva quien la monta.
class BriefingScanIndicator extends StatefulWidget {
  const BriefingScanIndicator({super.key, this.readyApps});

  /// Apps cuyos datos ya cargaron; null = todas.
  final Set<SuiteApp>? readyApps;

  @override
  State<BriefingScanIndicator> createState() => _BriefingScanIndicatorState();
}

class _BriefingScanIndicatorState extends State<BriefingScanIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OrtizMotion.fast * SuiteApp.values.length,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OrtizMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final ready = widget.readyApps;
    final apps = SuiteApp.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text('Revisando tus apps', style: OrtizType.body.copyWith(color: t.muted)),
        ),
        const SizedBox(height: OrtizSpace.sm),
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Wrap(
              spacing: OrtizSpace.xs,
              runSpacing: OrtizSpace.xs,
              children: [
                for (final (i, app) in apps.indexed)
                  _ScanPill(
                    key: ValueKey(app),
                    app: app,
                    lit: (ready == null || ready.contains(app)) &&
                        (_controller.value >= 1 || _controller.value * apps.length > i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanPill extends StatelessWidget {
  const _ScanPill({super.key, required this.app, required this.lit});
  final SuiteApp app;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    return AnimatedContainer(
      duration: OrtizMotion.of(context, OrtizMotion.fast),
      curve: OrtizMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
      decoration: BoxDecoration(
        color: lit ? app.color : Colors.transparent,
        borderRadius: BorderRadius.circular(OrtizRadius.pill),
        border: Border.all(color: lit ? app.color : t.line, width: OrtizStroke.hairline),
      ),
      child: Text(
        app.label,
        style: OrtizType.caption.copyWith(color: lit ? t.onAccent : t.muted),
      ),
    );
  }
}
