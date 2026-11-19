// Resumen del día (spec 04). Modelo inmutable, solo en memoria y en la
// metadata del artefacto del chat. Sin Flutter ni ViewModels.
//
// Diseño: docs/design/resumen-del-dia.md §1 (modelo), §2.3 (JSON para Gemini),
// §4 (montos), §5.5 (isAllClear), U4 (franja de hoy) y la tabla «Decisiones de
// la persona» (Q3, Q5b, Q8). No guarda ningún texto del diario (CA-08).

import '../../quebrado/models/currency_type.dart';

enum BriefingPeriod { morning, night }

/// Estado de carga por sección (R-01).
enum BriefingStatus { loading, ready, unavailable }

/// Estado de una fila de pago tras actuar sobre ella (CA-10).
enum BriefingPaymentState { pending, paid, dismissed }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

double _toDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
double? _toDoubleOrNull(Object? v) => v is num ? v.toDouble() : null;
int _toInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String _toStr(Object? v) => v is String ? v : '';
DateTime _toDate(Object? v, DateTime fallback) =>
    v is String ? (DateTime.tryParse(v) ?? fallback) : fallback;
DateTime? _toDateOrNull(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic> _toMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _toMapList(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
double? _round2(double? v) => v == null ? null : (v * 100).roundToDouble() / 100;

String _plural(int n, String singular, String plural) => n == 1 ? '1 $singular' : '$n $plural';

const List<String> _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// Nombres de hábitos pendientes que se muestran antes de «y n más».
const int kBriefingMaxHabitNames = 3;

/// Largo máximo de un texto libre en el JSON para Gemini (S4-05), el mismo
/// que `SuiteRagService.contextNameMaxLength`.
const int kBriefingGeminiTextMaxLength = 60;

/// Días de calendario de [from] a [to] (negativo si [to] es anterior), sin
/// mirar la hora. Se calcula sobre fechas UTC construidas con año, mes y día,
/// así que un cambio de horario (días de 23 o 25 horas) no lo altera.
int briefingCalendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Texto libre para Gemini (S4-05): una sola línea, sin caracteres de
/// control, espacios colapsados y como mucho [kBriefingGeminiTextMaxLength]
/// caracteres (con «…» si se corta). Replica `SuiteRagService.contextLine`,
/// que no se importa para no traer Flutter ni ViewModels al modelo.
String _geminiLine(String text) {
  final flat = text
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F  ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final chars = flat.runes.toList();
  if (chars.length <= kBriefingGeminiTextMaxLength) return flat;
  return '${String.fromCharCodes(chars.take(kBriefingGeminiTextMaxLength - 1)).trimRight()}…';
}

/// Ordena sin perder el orden original entre empates.
List<T> _stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

// ---------------------------------------------------------------------------
// Montos (§4)
// ---------------------------------------------------------------------------

/// Una pieza de un monto para formatear con `formatCurrency` de
/// `quebrado/widgets/helpers.dart` y unir con « · ».
typedef BriefingAmountPart = ({double amount, CurrencyType currency});

class BriefingAmount {
  const BriefingAmount({required this.original, required this.originalAmount, this.usd, this.ves});

  /// Convierte [amount] (en [currency]) con las tasas del estado (§4):
  /// usd → (a, a×bcv); Bs → (a/bcv, a); € → (a×eur/bcv, a×eur), con `euro`
  /// en Bs por €. Sin tasa (bcv ≤ 0, o euro ≤ 0 en €): usd = ves = null.
  factory BriefingAmount.convert(double amount, CurrencyType currency, {required double bcv, required double euro}) {
    double? usd;
    double? ves;
    if (bcv > 0) {
      switch (currency) {
        case CurrencyType.usd:
          usd = amount;
          ves = amount * bcv;
        case CurrencyType.bsBCV:
          usd = amount / bcv;
          ves = amount;
        case CurrencyType.eur:
          if (euro > 0) {
            ves = amount * euro;
            usd = ves / bcv;
          }
      }
    }
    return BriefingAmount(original: currency, originalAmount: amount, usd: usd, ves: ves);
  }

  final CurrencyType original;
  final double originalAmount;
  final double? usd;
  final double? ves;

  bool get rateMissing => usd == null || ves == null;

  /// Piezas en el orden de pantalla: «$ · Bs» y, si el pago es en €, además
  /// el monto en € (Q5b). Sin tasa: solo el monto en su moneda.
  List<BriefingAmountPart> get displayParts {
    if (rateMissing) return [(amount: originalAmount, currency: original)];
    return [
      (amount: usd!, currency: CurrencyType.usd),
      (amount: ves!, currency: CurrencyType.bsBCV),
      if (original == CurrencyType.eur) (amount: originalAmount, currency: CurrencyType.eur),
    ];
  }

  Map<String, dynamic> toMap() => {'currency': original.name, 'amount': originalAmount, 'usd': usd, 'ves': ves};

  factory BriefingAmount.fromMap(Map<String, dynamic> m) => BriefingAmount(
        original: _enumByName(CurrencyType.values, m['currency'], CurrencyType.usd),
        originalAmount: _toDouble(m['amount']),
        usd: _toDoubleOrNull(m['usd']),
        ves: _toDoubleOrNull(m['ves']),
      );
}

String _geminiCurrency(CurrencyType c) => switch (c) {
      CurrencyType.usd => 'usd',
      CurrencyType.bsBCV => 'ves',
      CurrencyType.eur => 'eur',
    };

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

class BriefingDiario {
  const BriefingDiario({this.status = BriefingStatus.loading, this.entriesToday = 0});
  final BriefingStatus status;
  final int entriesToday;

  Map<String, dynamic> toMap() => {'status': status.name, 'entriesToday': entriesToday};
  factory BriefingDiario.fromMap(Map<String, dynamic> m) => BriefingDiario(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        entriesToday: _toInt(m['entriesToday']),
      );
}

class BriefingMood {
  const BriefingMood({this.status = BriefingStatus.loading, this.loggedToday = false});
  final BriefingStatus status;
  final bool loggedToday;

  Map<String, dynamic> toMap() => {'status': status.name, 'loggedToday': loggedToday};
  factory BriefingMood.fromMap(Map<String, dynamic> m) => BriefingMood(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        loggedToday: m['loggedToday'] == true,
      );
}

/// Una fila por pago (Q8): agrupa todas sus ocurrencias pendientes de la
/// ventana (vencidas + próximos 7 días).
class BriefingPayment {
  const BriefingPayment({
    required this.paymentId,
    required this.name,
    required this.oldestOccurrenceDate,
    required this.remaining,
    this.oldestRemaining,
    this.occurrenceCount = 1,
    this.overdueCount = 0,
    this.partialPaid = 0,
    this.state = BriefingPaymentState.pending,
  });

  final String paymentId;
  final String name;

  /// Ocurrencia más antigua sin pagar: la que abre «Pagar».
  final DateTime oldestOccurrenceDate;

  /// Ocurrencias agrupadas en la fila (vencidas incluidas).
  final int occurrenceCount;

  /// Cuántas de ellas tienen fecha anterior a hoy.
  final int overdueCount;

  /// Lo que falta en total, con los abonos ya descontados.
  final BriefingAmount remaining;

  /// Lo que falta de la ocurrencia más antigua (abonos descontados): lo que
  /// paga «Pagar». Lo calcula siempre el servicio; null solo en metadata
  /// guardada antes de existir el campo. Para mostrar, usa [payNowAmount].
  final BriefingAmount? oldestRemaining;

  /// Monto de «Pagar todo»: [oldestRemaining] o, si falta y la fila tiene una
  /// sola ocurrencia, [remaining] (son lo mismo). Null si no se puede saber.
  BriefingAmount? get payNowAmount => oldestRemaining ?? (occurrenceCount == 1 ? remaining : null);

  /// Suma de abonos de las ocurrencias agrupadas, en la moneda del pago.
  final double partialPaid;

  final BriefingPaymentState state;

  bool get isOverdue => overdueCount > 0;
  bool get hasPartial => partialPaid > 0;
  bool get isPending => state == BriefingPaymentState.pending;

  BriefingPayment copyWith({
    DateTime? oldestOccurrenceDate,
    int? occurrenceCount,
    int? overdueCount,
    BriefingAmount? remaining,
    BriefingAmount? oldestRemaining,
    double? partialPaid,
    BriefingPaymentState? state,
  }) =>
      BriefingPayment(
        paymentId: paymentId,
        name: name,
        oldestOccurrenceDate: oldestOccurrenceDate ?? this.oldestOccurrenceDate,
        occurrenceCount: occurrenceCount ?? this.occurrenceCount,
        overdueCount: overdueCount ?? this.overdueCount,
        remaining: remaining ?? this.remaining,
        oldestRemaining: oldestRemaining ?? this.oldestRemaining,
        partialPaid: partialPaid ?? this.partialPaid,
        state: state ?? this.state,
      );

  Map<String, dynamic> toMap() => {
        'paymentId': paymentId,
        'name': name,
        'oldestOccurrenceDate': oldestOccurrenceDate.toIso8601String(),
        'occurrenceCount': occurrenceCount,
        'overdueCount': overdueCount,
        'remaining': remaining.toMap(),
        'oldestRemaining': oldestRemaining?.toMap(),
        'partialPaid': partialPaid,
        'state': state.name,
      };

  factory BriefingPayment.fromMap(Map<String, dynamic> m, DateTime fallbackDate) {
    final rawOldest = m['oldestRemaining'];
    return BriefingPayment(
      paymentId: _toStr(m['paymentId']),
      name: _toStr(m['name']),
      oldestOccurrenceDate: _toDate(m['oldestOccurrenceDate'], fallbackDate),
      occurrenceCount: _toInt(m['occurrenceCount'], 1),
      overdueCount: _toInt(m['overdueCount']),
      remaining: BriefingAmount.fromMap(_toMap(m['remaining'])),
      oldestRemaining: rawOldest is Map ? BriefingAmount.fromMap(Map<String, dynamic>.from(rawOldest)) : null,
      partialPaid: _toDouble(m['partialPaid']),
      state: _enumByName(BriefingPaymentState.values, m['state'], BriefingPaymentState.pending),
    );
  }
}

class BriefingPayments {
  const BriefingPayments({this.status = BriefingStatus.loading, this.items = const []});
  final BriefingStatus status;
  final List<BriefingPayment> items;

  /// Orden de pantalla: vencidos primero y luego por la ocurrencia más
  /// antigua. El servicio desempata por nombre.
  static int compareByUrgency(BriefingPayment a, BriefingPayment b) {
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    return a.oldestOccurrenceDate.compareTo(b.oldestOccurrenceDate);
  }

  List<BriefingPayment> get pendingItems => items.where((p) => p.isPending).toList();

  /// [items] en el orden de pantalla ([compareByUrgency]); los empates
  /// conservan el orden recibido.
  List<BriefingPayment> get sortedItems => _stableSorted(items, compareByUrgency);

  /// Total en $ de lo que falta en las filas pendientes que quedan ocultas al
  /// mostrar las primeras [shown] de [sortedItems] («Y n más · $x»). Null si
  /// no hay ninguna pendiente oculta o si alguna no tiene tasa (no se muestra
  /// un total incompleto).
  double? hiddenRemainingUsd(int shown) {
    final hidden = sortedItems.skip(shown < 0 ? 0 : shown).where((p) => p.isPending).toList();
    if (hidden.isEmpty) return null;
    var total = 0.0;
    for (final p in hidden) {
      final usd = p.remaining.usd;
      if (usd == null) return null;
      total += usd;
    }
    return total;
  }

  /// Total en $ de lo que falta en las filas pendientes; null si la sección no
  /// está lista o algún pago no tiene tasa (no se suma un total incompleto).
  double? get totalUsd {
    if (status != BriefingStatus.ready) return null;
    var total = 0.0;
    for (final p in pendingItems) {
      final usd = p.remaining.usd;
      if (usd == null) return null;
      total += usd;
    }
    return total;
  }

  BriefingPayments copyWith({BriefingStatus? status, List<BriefingPayment>? items}) =>
      BriefingPayments(status: status ?? this.status, items: items ?? this.items);

  Map<String, dynamic> toMap() => {'status': status.name, 'items': items.map((p) => p.toMap()).toList()};
  factory BriefingPayments.fromMap(Map<String, dynamic> m, DateTime fallbackDate) => BriefingPayments(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        items: _toMapList(m['items']).map((e) => BriefingPayment.fromMap(e, fallbackDate)).toList(),
      );
}

class BriefingBirthday {
  const BriefingBirthday({required this.contactId, required this.name, required this.date, required this.inDays});
  final String contactId;
  final String name;
  final DateTime date;
  final int inDays;

  Map<String, dynamic> toMap() =>
      {'contactId': contactId, 'name': name, 'date': date.toIso8601String(), 'inDays': inDays};
  factory BriefingBirthday.fromMap(Map<String, dynamic> m, DateTime fallbackDate) => BriefingBirthday(
        contactId: _toStr(m['contactId']),
        name: _toStr(m['name']),
        date: _toDate(m['date'], fallbackDate),
        inDays: _toInt(m['inDays']),
      );
}

class BriefingBirthdays {
  const BriefingBirthdays({this.status = BriefingStatus.loading, this.items = const []});
  final BriefingStatus status;
  final List<BriefingBirthday> items;

  /// Más cercano primero (`inDays`) y, a igualdad, por nombre.
  static int compareByProximity(BriefingBirthday a, BriefingBirthday b) =>
      a.inDays != b.inDays ? a.inDays.compareTo(b.inDays) : a.name.compareTo(b.name);

  /// [items] ordenados con [compareByProximity] (la metadata puede traerlos
  /// en cualquier orden).
  List<BriefingBirthday> get sortedItems => _stableSorted(items, compareByProximity);

  Map<String, dynamic> toMap() => {'status': status.name, 'items': items.map((b) => b.toMap()).toList()};
  factory BriefingBirthdays.fromMap(Map<String, dynamic> m, DateTime fallbackDate) => BriefingBirthdays(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        items: _toMapList(m['items']).map((e) => BriefingBirthday.fromMap(e, fallbackDate)).toList(),
      );
}

class BriefingHabitRef {
  const BriefingHabitRef({required this.id, required this.title});
  final String id;
  final String title;

  Map<String, dynamic> toMap() => {'id': id, 'title': title};
  factory BriefingHabitRef.fromMap(Map<String, dynamic> m) =>
      BriefingHabitRef(id: _toStr(m['id']), title: _toStr(m['title']));
}

/// Hábito que la persona está dejando, solo como racha (Q3). El título es para
/// la pantalla («Llevas 12 días sin…»); a Gemini solo van los días.
class BriefingNegativeStreak {
  const BriefingNegativeStreak({required this.id, required this.title, required this.cleanDays});
  final String id;
  final String title;
  final int cleanDays;

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'cleanDays': cleanDays};
  factory BriefingNegativeStreak.fromMap(Map<String, dynamic> m) => BriefingNegativeStreak(
        id: _toStr(m['id']),
        title: _toStr(m['title']),
        cleanDays: _toInt(m['cleanDays']),
      );
}

class BriefingHabits {
  const BriefingHabits({
    this.status = BriefingStatus.loading,
    this.scheduled = 0,
    this.done = 0,
    this.pending = const [],
    this.negativeStreaks = const [],
  });
  final BriefingStatus status;
  final int scheduled;
  final int done;

  /// Programados hoy y sin hacer.
  final List<BriefingHabitRef> pending;
  final List<BriefingNegativeStreak> negativeStreaks;

  bool get hasPending => scheduled > 0 && done < scheduled;

  /// Todos los programados de hoy están hechos (y había alguno).
  bool get isComplete => scheduled > 0 && done >= scheduled;

  /// Hasta [kBriefingMaxHabitNames] nombres de pendientes, en orden.
  List<String> get pendingNamesShown => [for (final h in pending.take(kBriefingMaxHabitNames)) h.title];

  /// Pendientes que no caben en [pendingNamesShown] («y n más»).
  int get pendingNamesHidden => pending.length - pendingNamesShown.length;

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'scheduled': scheduled,
        'done': done,
        'pending': pending.map((h) => h.toMap()).toList(),
        'negativeStreaks': negativeStreaks.map((s) => s.toMap()).toList(),
      };
  factory BriefingHabits.fromMap(Map<String, dynamic> m) => BriefingHabits(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        scheduled: _toInt(m['scheduled']),
        done: _toInt(m['done']),
        pending: _toMapList(m['pending']).map(BriefingHabitRef.fromMap).toList(),
        negativeStreaks: _toMapList(m['negativeStreaks']).map(BriefingNegativeStreak.fromMap).toList(),
      );
}

class BriefingReminder {
  const BriefingReminder({
    required this.id,
    required this.title,
    required this.dueAt,
    this.isOverdue = false,
    this.isTomorrow = false,
    this.snoozedUntil,
  });
  final String id;
  final String title;
  final DateTime dueAt;
  final bool isOverdue;
  final bool isTomorrow;

  /// Se rellena al posponer desde la fila («Pospuesto a {cuándo}»).
  final DateTime? snoozedUntil;

  bool get isSnoozed => snoozedUntil != null;

  BriefingReminder copyWith({DateTime? snoozedUntil}) => BriefingReminder(
        id: id,
        title: title,
        dueAt: dueAt,
        isOverdue: isOverdue,
        isTomorrow: isTomorrow,
        snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dueAt': dueAt.toIso8601String(),
        'isOverdue': isOverdue,
        'isTomorrow': isTomorrow,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };
  factory BriefingReminder.fromMap(Map<String, dynamic> m, DateTime fallbackDate) => BriefingReminder(
        id: _toStr(m['id']),
        title: _toStr(m['title']),
        dueAt: _toDate(m['dueAt'], fallbackDate),
        isOverdue: m['isOverdue'] == true,
        isTomorrow: m['isTomorrow'] == true,
        snoozedUntil: _toDateOrNull(m['snoozedUntil']),
      );
}

class BriefingReminders {
  const BriefingReminders({this.status = BriefingStatus.loading, this.items = const []});
  final BriefingStatus status;
  final List<BriefingReminder> items;

  /// Orden de pantalla y del servicio: vencidos primero y luego por hora.
  static int compareByUrgency(BriefingReminder a, BriefingReminder b) {
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    return a.dueAt.compareTo(b.dueAt);
  }

  /// [items] en el orden de [compareByUrgency]; los empates conservan el
  /// orden recibido.
  List<BriefingReminder> get sortedItems => _stableSorted(items, compareByUrgency);

  /// Vencidos y de hoy (sin los de mañana), ordenados.
  List<BriefingReminder> get sortedTodayItems => sortedItems.where((r) => !r.isTomorrow).toList();

  /// Los de mañana (solo de noche, Q4), ordenados.
  List<BriefingReminder> get sortedTomorrowItems => sortedItems.where((r) => r.isTomorrow).toList();

  BriefingReminders copyWith({BriefingStatus? status, List<BriefingReminder>? items}) =>
      BriefingReminders(status: status ?? this.status, items: items ?? this.items);

  Map<String, dynamic> toMap() => {'status': status.name, 'items': items.map((r) => r.toMap()).toList()};
  factory BriefingReminders.fromMap(Map<String, dynamic> m, DateTime fallbackDate) => BriefingReminders(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        items: _toMapList(m['items']).map((e) => BriefingReminder.fromMap(e, fallbackDate)).toList(),
      );
}

class BriefingRate {
  const BriefingRate({this.value = 0, this.deltaVsPrevious});
  final double value;
  final double? deltaVsPrevious;

  /// value ≤ 0 → «sin tasa».
  bool get hasValue => value > 0;

  Map<String, dynamic> toMap() => {'value': value, 'delta': deltaVsPrevious};
  factory BriefingRate.fromMap(Map<String, dynamic> m) =>
      BriefingRate(value: _toDouble(m['value']), deltaVsPrevious: _toDoubleOrNull(m['delta']));
}

class BriefingRates {
  const BriefingRates({
    this.status = BriefingStatus.loading,
    this.bcv = const BriefingRate(),
    this.parallel = const BriefingRate(),
    this.euro = const BriefingRate(),
  });
  final BriefingStatus status;
  final BriefingRate bcv;
  final BriefingRate parallel;
  final BriefingRate euro;

  Map<String, dynamic> toMap() =>
      {'status': status.name, 'bcv': bcv.toMap(), 'parallel': parallel.toMap(), 'euro': euro.toMap()};
  factory BriefingRates.fromMap(Map<String, dynamic> m) => BriefingRates(
        status: _enumByName(BriefingStatus.values, m['status'], BriefingStatus.unavailable),
        bcv: BriefingRate.fromMap(_toMap(m['bcv'])),
        parallel: BriefingRate.fromMap(_toMap(m['parallel'])),
        euro: BriefingRate.fromMap(_toMap(m['euro'])),
      );
}

// ---------------------------------------------------------------------------
// Franja de hoy (U4)
// ---------------------------------------------------------------------------

/// Categoría de una etiqueta: la franja toma una como máximo por categoría.
/// El widget la traduce al color de su app (pagos → finanzas; diario/ánimo y
/// cumpleaños → diario; hábitos → habitos; recordatorios → recordatorios).
enum BriefingHighlightCategory { payments, reminders, birthdays, journal, habits, allClear }

enum BriefingHighlightKind {
  overduePayments(BriefingHighlightCategory.payments),
  weekPayments(BriefingHighlightCategory.payments),
  tomorrowPayments(BriefingHighlightCategory.payments),
  overdueReminders(BriefingHighlightCategory.reminders),
  todayReminders(BriefingHighlightCategory.reminders),
  tomorrowReminders(BriefingHighlightCategory.reminders),
  birthdayToday(BriefingHighlightCategory.birthdays),
  birthdayTomorrow(BriefingHighlightCategory.birthdays),
  upcomingBirthdays(BriefingHighlightCategory.birthdays),
  missingJournal(BriefingHighlightCategory.journal),
  pendingHabits(BriefingHighlightCategory.habits),
  allClear(BriefingHighlightCategory.allClear);

  const BriefingHighlightKind(this.category);
  final BriefingHighlightCategory category;
}

/// Etiqueta de la franja: sin nombres ni montos (U4).
class BriefingHighlight {
  const BriefingHighlight(this.kind, this.label);
  final BriefingHighlightKind kind;
  final String label;

  BriefingHighlightCategory get category => kind.category;

  @override
  String toString() => 'BriefingHighlight(${kind.name}, $label)';
}

// ---------------------------------------------------------------------------
// Resumen
// ---------------------------------------------------------------------------

/// Secciones que pueden ir en «Al día: diario, ánimo y hábitos.», en ese
/// orden; [label] es el texto de la línea.
enum BriefingUpToDateSection {
  diario('diario'),
  mood('ánimo'),
  habits('hábitos');

  const BriefingUpToDateSection(this.label);
  final String label;
}

class DailyBriefing {
  const DailyBriefing({
    required this.generatedAt,
    required this.period,
    required this.bookName,
    this.bookId = '',
    this.diario = const BriefingDiario(),
    this.mood = const BriefingMood(),
    this.payments = const BriefingPayments(),
    this.birthdays = const BriefingBirthdays(),
    this.habits = const BriefingHabits(),
    this.reminders = const BriefingReminders(),
    this.rates = const BriefingRates(),
    this.rowsOmitted = false,
  });

  static const int metadataVersion = 1;

  /// Claves de las secciones (filas) dentro de la metadata del artefacto.
  static const List<String> _sectionKeys = [
    'diario',
    'mood',
    'payments',
    'birthdays',
    'habits',
    'reminders',
    'rates',
  ];
  static const int maxHighlights = 3;
  static const String allClearLabel = 'Todo al día';

  final DateTime generatedAt;
  final BriefingPeriod period;
  final String bookName;

  /// Id del libro activo al generar (`AppState.activeDbName`). Solo para la
  /// app (comparar con el libro activo); nunca va a Gemini.
  final String bookId;
  final BriefingDiario diario;
  final BriefingMood mood;
  final BriefingPayments payments;
  final BriefingBirthdays birthdays;
  final BriefingHabits habits;
  final BriefingReminders reminders;
  final BriefingRates rates;

  /// Resumen leído de una metadata guardada sin filas (S4-02: solo `version`,
  /// `generatedAt` y `period`). Sus secciones quedan `unavailable`, pero no
  /// porque fallaran: la vista muestra «Resumen del … Pide uno nuevo para
  /// actuar.» en lugar de filas «No disponible».
  final bool rowsOmitted;

  List<BriefingStatus> get _statuses => [
        diario.status,
        mood.status,
        payments.status,
        birthdays.status,
        habits.status,
        reminders.status,
        rates.status,
      ];

  /// Ninguna sección sigue cargando.
  bool get isFullyLoaded => !_statuses.contains(BriefingStatus.loading);

  /// §5.5: todas las secciones listas, escribió en el diario, sin pagos
  /// pendientes, hábitos completos y sin recordatorios vencidos o de hoy. El
  /// ánimo no cuenta (la frase de la spec no lo nombra).
  bool get isAllClear {
    if (_statuses.any((s) => s != BriefingStatus.ready)) return false;
    if (diario.entriesToday < 1) return false;
    if (payments.pendingItems.isNotEmpty) return false;
    if (habits.done < habits.scheduled) return false;
    return !reminders.items.any((r) => !r.isTomorrow && !r.isSnoozed);
  }

  /// Lo que está completo hoy, para «Al día: …»: diario con alguna entrada,
  /// ánimo registrado y hábitos programados todos hechos (solo secciones
  /// listas).
  List<BriefingUpToDateSection> get upToDateSections => [
        if (_ready(diario.status) && diario.entriesToday > 0) BriefingUpToDateSection.diario,
        if (_ready(mood.status) && mood.loggedToday) BriefingUpToDateSection.mood,
        if (_ready(habits.status) && habits.isComplete) BriefingUpToDateSection.habits,
      ];

  /// Cosas para hoy del anuncio «Resumen listo: n cosas para hoy» (U8):
  /// diario sin escribir, ánimo sin registrar, una por pago pendiente, una por
  /// cumpleaños, una si faltan hábitos y una por recordatorio de hoy o
  /// vencido sin posponer. No mira [isAllClear] (eso decide el anuncio).
  int get itemCount {
    var n = 0;
    if (_ready(diario.status) && diario.entriesToday == 0) n++;
    if (_ready(mood.status) && !mood.loggedToday) n++;
    if (_ready(payments.status)) n += payments.pendingItems.length;
    if (_ready(birthdays.status)) n += birthdays.items.length;
    if (_ready(habits.status) && habits.hasPending) n++;
    if (_ready(reminders.status)) n += reminders.items.where((r) => !r.isTomorrow && !r.isSnoozed).length;
    return n;
  }

  /// El {n} de «Resumen listo: {n} cosas para hoy» (U8): [itemCount], o 0
  /// cuando [isAllClear] (entonces el anuncio es «Todo al día»).
  int get announcementCount => isAllClear ? 0 : itemCount;

  /// Hasta 3 etiquetas para la franja de hoy (U4), una por categoría, en el
  /// orden de prioridad de mañana o de noche. Las secciones que no están
  /// listas no compiten; las tasas nunca entran. Sin nada relevante y con todo
  /// cargado: una sola etiqueta «Todo al día».
  List<BriefingHighlight> get highlights {
    final candidates = period == BriefingPeriod.night
        ? [
            _overduePayments(),
            _overdueReminders(),
            _missingJournal(),
            _pendingHabits(),
            _tomorrowPayments(),
            _nightBirthdays(),
            _tomorrowReminders(),
          ]
        : [
            _overduePayments(),
            _overdueReminders(),
            _birthdayToday(),
            _weekPayments(),
            _todayReminders(),
            _upcomingBirthdays(),
            _pendingHabits(),
            _missingJournal(),
          ];
    final result = <BriefingHighlight>[];
    final used = <BriefingHighlightCategory>{};
    for (final c in candidates) {
      if (c == null || used.contains(c.category)) continue;
      result.add(c);
      used.add(c.category);
      if (result.length == maxHighlights) break;
    }
    if (result.isEmpty && isFullyLoaded) {
      return const [BriefingHighlight(BriefingHighlightKind.allClear, allClearLabel)];
    }
    return result;
  }

  bool _ready(BriefingStatus s) => s == BriefingStatus.ready;
  // Por calendario, no sumando 24 h (con cambio de hora caería el mismo día).
  DateTime get _tomorrow => DateTime(generatedAt.year, generatedAt.month, generatedAt.day + 1);
  List<BriefingReminder> get _activeReminders =>
      _ready(reminders.status) ? reminders.items.where((r) => !r.isSnoozed).toList() : const [];

  BriefingHighlight? _overduePayments() {
    if (!_ready(payments.status)) return null;
    final n = payments.pendingItems.fold<int>(0, (sum, p) => sum + p.overdueCount);
    if (n == 0) return null;
    return BriefingHighlight(BriefingHighlightKind.overduePayments, _plural(n, 'pago vencido', 'pagos vencidos'));
  }

  BriefingHighlight? _weekPayments() {
    if (!_ready(payments.status)) return null;
    final n = payments.pendingItems.fold<int>(0, (sum, p) => sum + (p.occurrenceCount - p.overdueCount));
    if (n <= 0) return null;
    return BriefingHighlight(BriefingHighlightKind.weekPayments, _plural(n, 'pago esta semana', 'pagos esta semana'));
  }

  BriefingHighlight? _tomorrowPayments() {
    if (!_ready(payments.status)) return null;
    final n = payments.pendingItems
        .where((p) => p.overdueCount == 0 && _sameDay(p.oldestOccurrenceDate, _tomorrow))
        .length;
    if (n == 0) return null;
    return BriefingHighlight(BriefingHighlightKind.tomorrowPayments, _plural(n, 'pago mañana', 'pagos mañana'));
  }

  BriefingHighlight? _overdueReminders() {
    final n = _activeReminders.where((r) => r.isOverdue).length;
    if (n == 0) return null;
    return BriefingHighlight(
        BriefingHighlightKind.overdueReminders, _plural(n, 'recordatorio vencido', 'recordatorios vencidos'));
  }

  BriefingHighlight? _todayReminders() {
    final n = _activeReminders.where((r) => !r.isOverdue && !r.isTomorrow).length;
    if (n == 0) return null;
    return BriefingHighlight(BriefingHighlightKind.todayReminders, _plural(n, 'recordatorio hoy', 'recordatorios hoy'));
  }

  BriefingHighlight? _tomorrowReminders() {
    final n = _activeReminders.where((r) => r.isTomorrow).length;
    if (n == 0) return null;
    return BriefingHighlight(
        BriefingHighlightKind.tomorrowReminders, _plural(n, 'recordatorio mañana', 'recordatorios mañana'));
  }

  BriefingHighlight? _birthdayToday() {
    if (!_ready(birthdays.status)) return null;
    if (!birthdays.items.any((b) => b.inDays == 0)) return null;
    return const BriefingHighlight(BriefingHighlightKind.birthdayToday, 'Cumpleaños hoy');
  }

  BriefingHighlight? _upcomingBirthdays({int fromDays = 1}) {
    if (!_ready(birthdays.status)) return null;
    final upcoming = birthdays.items.where((b) => b.inDays >= fromDays && b.inDays <= 7).toList();
    if (upcoming.isEmpty) return null;
    if (upcoming.length == 1) {
      final weekday = _weekdays[upcoming.first.date.weekday - 1];
      return BriefingHighlight(BriefingHighlightKind.upcomingBirthdays, 'Cumpleaños el $weekday');
    }
    return BriefingHighlight(BriefingHighlightKind.upcomingBirthdays, '${upcoming.length} cumpleaños esta semana');
  }

  BriefingHighlight? _nightBirthdays() {
    if (!_ready(birthdays.status)) return null;
    if (birthdays.items.any((b) => b.inDays == 1)) {
      return const BriefingHighlight(BriefingHighlightKind.birthdayTomorrow, 'Cumpleaños mañana');
    }
    return _upcomingBirthdays(fromDays: 2);
  }

  BriefingHighlight? _pendingHabits() {
    if (!_ready(habits.status) || !habits.hasPending) return null;
    return BriefingHighlight(BriefingHighlightKind.pendingHabits, '${habits.done}/${habits.scheduled} hábitos');
  }

  BriefingHighlight? _missingJournal() {
    final noDiary = _ready(diario.status) && diario.entriesToday == 0;
    final noMood = _ready(mood.status) && !mood.loggedToday;
    if (!noDiary && !noMood) return null;
    final label = noDiary && noMood
        ? 'Sin diario ni ánimo'
        : noDiary
            ? 'Sin diario hoy'
            : 'Sin ánimo hoy';
    return BriefingHighlight(BriefingHighlightKind.missingJournal, label);
  }

  // -------------------------------------------------------------------------
  // JSON para Gemini (§2.3): lista blanca exacta. Nunca texto del diario,
  // notas de ánimo, nombres de hábitos, ids, ni datos de contacto salvo el
  // nombre del cumpleañero.
  // -------------------------------------------------------------------------

  Map<String, dynamic> toGeminiJson() {
    Map<String, dynamic> section(BriefingStatus status, Map<String, dynamic> Function() fields) =>
        status == BriefingStatus.ready ? {'estado': status.name, ...fields()} : {'estado': status.name};

    return {
      'fecha': _ymd(generatedAt),
      'hora': _hm(generatedAt),
      'periodo': period.name,
      'libro': _geminiLine(bookName),
      'diario': section(diario.status, () => {'entradas_hoy': diario.entriesToday}),
      'animo': section(mood.status, () => {'registrado_hoy': mood.loggedToday}),
      'pagos': section(
        payments.status,
        () => {
          'total_usd': _round2(payments.totalUsd),
          'items': [
            for (final p in payments.pendingItems)
              {
                'nombre': _geminiLine(p.name),
                'vence': _ymd(p.oldestOccurrenceDate),
                'vencido': p.isOverdue,
                'vencidos': p.overdueCount,
                'falta_usd': _round2(p.remaining.usd),
                'falta_bs': _round2(p.remaining.ves),
                'moneda': _geminiCurrency(p.remaining.original),
                'monto_moneda': _round2(p.remaining.originalAmount),
                'parcial': p.hasPartial,
              },
          ],
        },
      ),
      'cumpleanos': section(
        birthdays.status,
        () => {
          'items': [
            for (final b in birthdays.items) {'nombre': _geminiLine(b.name), 'fecha': _ymd(b.date), 'en_dias': b.inDays},
          ],
        },
      ),
      'habitos': section(
        habits.status,
        () => {
          'programados': habits.scheduled,
          'hechos': habits.done,
          'pendientes': habits.pending.length,
          'rachas_dejando': [for (final s in habits.negativeStreaks) s.cleanDays],
        },
      ),
      'recordatorios': section(
        reminders.status,
        () => {
          'items': [
            for (final r in reminders.items)
              {
                'titulo': _geminiLine(r.title),
                'vence': '${_ymd(r.dueAt)}T${_hm(r.dueAt)}',
                'vencido': r.isOverdue,
                'manana': r.isTomorrow,
              },
          ],
        },
      ),
      'tasas': section(
        rates.status,
        () => {
          'bcv': rates.bcv.hasValue ? rates.bcv.value : null,
          'paralelo': rates.parallel.hasValue ? rates.parallel.value : null,
          'euro': rates.euro.hasValue ? rates.euro.value : null,
          'var_bcv': rates.bcv.deltaVsPrevious,
          'var_euro': rates.euro.deltaVsPrevious,
        },
      ),
    };
  }

  // -------------------------------------------------------------------------
  // Metadata del artefacto del chat (§5): ida y vuelta.
  // -------------------------------------------------------------------------

  Map<String, dynamic> toArtifactMetadata() => {
        'version': metadataVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'period': period.name,
        'bookName': bookName,
        'bookId': bookId,
        'diario': diario.toMap(),
        'mood': mood.toMap(),
        'payments': payments.toMap(),
        'birthdays': birthdays.toMap(),
        'habits': habits.toMap(),
        'reminders': reminders.toMap(),
        'rates': rates.toMap(),
      };

  /// Tolerante: una sección ausente o mal formada queda `unavailable`. Si no
  /// trae ninguna sección (artefacto guardado sin filas, S4-02),
  /// [rowsOmitted] es `true`.
  factory DailyBriefing.fromArtifactMetadata(Map<String, dynamic> m) {
    final generatedAt = _toDate(m['generatedAt'], DateTime.fromMillisecondsSinceEpoch(0));
    T read<T>(Object? raw, T Function(Map<String, dynamic>) parse, T Function(BriefingStatus) empty) =>
        raw is Map ? parse(Map<String, dynamic>.from(raw)) : empty(BriefingStatus.unavailable);
    return DailyBriefing(
      generatedAt: generatedAt,
      period: _enumByName(BriefingPeriod.values, m['period'], BriefingPeriod.morning),
      bookName: _toStr(m['bookName']),
      bookId: _toStr(m['bookId']),
      diario: read(m['diario'], BriefingDiario.fromMap, (s) => BriefingDiario(status: s)),
      mood: read(m['mood'], BriefingMood.fromMap, (s) => BriefingMood(status: s)),
      payments: read(m['payments'], (x) => BriefingPayments.fromMap(x, generatedAt), (s) => BriefingPayments(status: s)),
      birthdays:
          read(m['birthdays'], (x) => BriefingBirthdays.fromMap(x, generatedAt), (s) => BriefingBirthdays(status: s)),
      habits: read(m['habits'], BriefingHabits.fromMap, (s) => BriefingHabits(status: s)),
      reminders:
          read(m['reminders'], (x) => BriefingReminders.fromMap(x, generatedAt), (s) => BriefingReminders(status: s)),
      rates: read(m['rates'], BriefingRates.fromMap, (s) => BriefingRates(status: s)),
      rowsOmitted: !_sectionKeys.any(m.containsKey),
    );
  }

  DailyBriefing copyWith({
    BriefingDiario? diario,
    BriefingMood? mood,
    BriefingPayments? payments,
    BriefingBirthdays? birthdays,
    BriefingHabits? habits,
    BriefingReminders? reminders,
    BriefingRates? rates,
  }) =>
      DailyBriefing(
        generatedAt: generatedAt,
        period: period,
        bookName: bookName,
        bookId: bookId,
        diario: diario ?? this.diario,
        mood: mood ?? this.mood,
        payments: payments ?? this.payments,
        birthdays: birthdays ?? this.birthdays,
        habits: habits ?? this.habits,
        reminders: reminders ?? this.reminders,
        rates: rates ?? this.rates,
        rowsOmitted: rowsOmitted,
      );
}
