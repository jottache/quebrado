// Resumen del día (spec 04). Dos capas (docs/design/resumen-del-dia.md §2.1):
// - `DailyBriefingSnapshot.fromStates`: único punto que lee los ViewModels y
//   copia solo lo necesario (nunca el contenido del diario, CA-08).
// - `DailyBriefingService.build`: pura y determinista (`now` inyectado).
//
// Reglas: §2.2, §4 y la tabla «Decisiones de la persona» (Q1, Q3, Q4, Q5a,
// Q6, Q8).

import '../../diario/viewmodels/animo_state.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../quebrado/models/exchange_rate_record.dart';
import '../../quebrado/models/recurring_payment.dart';
import '../../quebrado/models/transaction.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../recordatorios/models/reminder_model.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../models/daily_briefing.dart';

/// Tipo de entrada del diario que no cuenta como «entrada de hoy» (Q6).
const String _listItemEntryType = 'list_item';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Instantánea
// ---------------------------------------------------------------------------

/// Entrada del diario reducida a su fecha y tipo: nunca título ni contenido.
class DiaryEntryStamp {
  const DiaryEntryStamp({required this.createdAt, required this.entryType});
  final DateTime createdAt;
  final String entryType;
}

/// Contacto con fecha de nacimiento.
class ContactBirthday {
  const ContactBirthday({required this.id, required this.name, required this.birthdate});
  final String id;
  final String name;
  final DateTime birthdate;
}

/// Hábito bueno programado hoy.
class HabitStamp {
  const HabitStamp({required this.id, required this.title, required this.doneToday});
  final String id;
  final String title;
  final bool doneToday;
}

/// Hábito que la persona está dejando, con sus días limpios (Q3).
class NegativeHabitStamp {
  const NegativeHabitStamp({required this.id, required this.title, required this.cleanDays});
  final String id;
  final String title;
  final int cleanDays;
}

/// Recordatorio reducido a lo que usa el resumen.
class ReminderStamp {
  const ReminderStamp({required this.id, required this.title, required this.dueAt, required this.status});
  final String id;
  final String title;
  final DateTime? dueAt;
  final ReminderStatus status;
}

/// Instantánea inmutable de lo que necesita el resumen.
class DailyBriefingSnapshot {
  const DailyBriefingSnapshot({
    this.financeLoaded = false,
    this.bookName = '',
    this.bookId = '',
    this.pendingWindow = const [],
    this.bcv = 0,
    this.parallel = 0,
    this.euro = 0,
    this.bcvHistory = const [],
    this.euroHistory = const [],
    this.diarioLoaded = false,
    this.diaryEntries = const [],
    this.contacts = const [],
    this.moodLoaded = false,
    this.moodLoggedToday = false,
    this.habitsLoaded = false,
    this.scheduledGoodHabits = const [],
    this.negativeHabits = const [],
    this.remindersLoaded = false,
    this.reminders = const [],
  });

  /// `AppState.isDataLoaded`: pagos y tasas.
  final bool financeLoaded;

  /// Libro activo (Q2).
  final String bookName;

  /// Id del libro activo (`AppState.activeDbName`).
  final String bookId;

  /// `AppState.pendingPaymentsWithin(now:)`: libro activo, vencidos + 7 días.
  final List<PendingOccurrence> pendingWindow;

  /// Tasas del estado; `euro` en Bs por €.
  final double bcv;
  final double parallel;
  final double euro;
  final List<ExchangeRateRecord> bcvHistory;
  final List<ExchangeRateRecord> euroHistory;

  final bool diarioLoaded;
  final List<DiaryEntryStamp> diaryEntries;
  final List<ContactBirthday> contacts;

  final bool moodLoaded;
  final bool moodLoggedToday;

  final bool habitsLoaded;
  final List<HabitStamp> scheduledGoodHabits;
  final List<NegativeHabitStamp> negativeHabits;

  final bool remindersLoaded;
  final List<ReminderStamp> reminders;

  /// Lee los ViewModels una sola vez. Los días limpios de los hábitos
  /// negativos salen de `HabitosState.calculateCleanDays`, que usa el reloj
  /// del sistema.
  factory DailyBriefingSnapshot.fromStates({
    required AppState app,
    required DiarioState diario,
    required AnimoState animo,
    required HabitosState habitos,
    required RemindersState reminders,
    required DateTime now,
  }) {
    final today = _day(now);
    final todayKey = habitos.dateKeyOf(today);
    return DailyBriefingSnapshot(
      financeLoaded: app.isDataLoaded,
      bookName: app.activeProfileName,
      bookId: app.activeDbName,
      pendingWindow: List.unmodifiable(app.pendingPaymentsWithin(now: now)),
      bcv: app.bcvRate,
      parallel: app.parallelRate,
      euro: app.euroRate,
      bcvHistory: List.unmodifiable(app.rateHistory),
      euroHistory: List.unmodifiable(app.euroRateHistory),
      diarioLoaded: !diario.isLoading,
      diaryEntries: List.unmodifiable([
        for (final e in diario.allEntries) DiaryEntryStamp(createdAt: e.createdAt.toLocal(), entryType: e.entryType),
      ]),
      contacts: List.unmodifiable([
        for (final c in diario.contacts)
          if (c.birthdate != null) ContactBirthday(id: c.id, name: c.name, birthdate: c.birthdate!),
      ]),
      moodLoaded: animo.hasLoaded,
      moodLoggedToday: animo.logsOnDate(now).isNotEmpty,
      habitsLoaded: !habitos.isLoading,
      scheduledGoodHabits: List.unmodifiable([
        for (final h in habitos.goodHabitsScheduledOn(today))
          HabitStamp(id: h.id, title: h.title, doneToday: habitos.isCompleted(h.id, todayKey)),
      ]),
      negativeHabits: List.unmodifiable([
        for (final h in habitos.allHabits)
          if (h.isNegative) NegativeHabitStamp(id: h.id, title: h.title, cleanDays: habitos.calculateCleanDays(h.id)),
      ]),
      remindersLoaded: !reminders.isLoading,
      reminders: List.unmodifiable([
        for (final r in reminders.allReminders)
          ReminderStamp(id: r.id, title: r.title, dueAt: r.dueAt?.toLocal(), status: r.status),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Servicio
// ---------------------------------------------------------------------------

class DailyBriefingService {
  const DailyBriefingService({this.nightStartHour = defaultNightStartHour});

  /// Hora de corte (Q1): desde las 18:00:00 el resumen es de noche.
  static const int defaultNightStartHour = 18;

  /// Días hacia delante para cumpleaños (C14).
  static const int birthdayWindowDays = 7;

  final int nightStartHour;

  DailyBriefing build(DailyBriefingSnapshot s, {required DateTime now}) {
    final period = now.hour >= nightStartHour ? BriefingPeriod.night : BriefingPeriod.morning;
    return DailyBriefing(
      generatedAt: now,
      period: period,
      bookName: s.bookName,
      bookId: s.bookId,
      diario: _diario(s, now),
      mood: s.moodLoaded
          ? BriefingMood(status: BriefingStatus.ready, loggedToday: s.moodLoggedToday)
          : const BriefingMood(),
      payments: _payments(s, now),
      birthdays: _birthdays(s, now),
      habits: _habits(s),
      reminders: _reminders(s, now, period),
      rates: _rates(s, now),
    );
  }

  /// Entradas creadas hoy, personales y de contactos, sin `list_item` (Q6).
  BriefingDiario _diario(DailyBriefingSnapshot s, DateTime now) {
    if (!s.diarioLoaded) return const BriefingDiario();
    final count = s.diaryEntries.where((e) => e.entryType != _listItemEntryType && _sameDay(e.createdAt, now)).length;
    return BriefingDiario(status: BriefingStatus.ready, entriesToday: count);
  }

  /// Solo gastos (Q5a), una fila por pago (Q8), vencidos primero y luego por
  /// fecha de la ocurrencia más antigua. Montos según §4.
  BriefingPayments _payments(DailyBriefingSnapshot s, DateTime now) {
    if (!s.financeLoaded) return const BriefingPayments();
    final today = _day(now);
    final groups = <String, List<PendingOccurrence>>{};
    for (final o in s.pendingWindow) {
      if (o.payment.type != TransactionType.expense) continue;
      groups.putIfAbsent(o.payment.id, () => []).add(o);
    }
    final items = <BriefingPayment>[];
    for (final occurrences in groups.values) {
      occurrences.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
      final payment = occurrences.first.payment;
      var remaining = 0.0;
      var partial = 0.0;
      var overdue = 0;
      for (final o in occurrences) {
        remaining += o.remainingAmount;
        partial += o.partialAmountPaid;
        if (_day(o.occurrenceDate).isBefore(today)) overdue++;
      }
      items.add(BriefingPayment(
        paymentId: payment.id,
        name: payment.name,
        oldestOccurrenceDate: _day(occurrences.first.occurrenceDate),
        occurrenceCount: occurrences.length,
        overdueCount: overdue,
        remaining: BriefingAmount.convert(remaining, payment.currency, bcv: s.bcv, euro: s.euro),
        oldestRemaining:
            BriefingAmount.convert(occurrences.first.remainingAmount, payment.currency, bcv: s.bcv, euro: s.euro),
        partialPaid: partial,
      ));
    }
    items.sort((a, b) {
      final byUrgency = BriefingPayments.compareByUrgency(a, b);
      return byUrgency != 0 ? byUrgency : a.name.compareTo(b.name);
    });
    return BriefingPayments(status: BriefingStatus.ready, items: items);
  }

  /// Próximo cumpleaños calculado con [now], de hoy a hoy + 7. El 29 de
  /// febrero cae el 1 de marzo en año no bisiesto (como `daysUntilBirthday`).
  BriefingBirthdays _birthdays(DailyBriefingSnapshot s, DateTime now) {
    if (!s.diarioLoaded) return const BriefingBirthdays();
    final today = _day(now);
    final items = <BriefingBirthday>[];
    for (final c in s.contacts) {
      var next = DateTime(today.year, c.birthdate.month, c.birthdate.day);
      if (next.isBefore(today)) next = DateTime(today.year + 1, c.birthdate.month, c.birthdate.day);
      final inDays = briefingCalendarDaysBetween(today, next);
      if (inDays < 0 || inDays > birthdayWindowDays) continue;
      items.add(BriefingBirthday(contactId: c.id, name: c.name, date: next, inDays: inDays));
    }
    items.sort(BriefingBirthdays.compareByProximity);
    return BriefingBirthdays(status: BriefingStatus.ready, items: items);
  }

  /// Buenos programados hoy (hechos/pendientes); negativos solo como racha (Q3).
  BriefingHabits _habits(DailyBriefingSnapshot s) {
    if (!s.habitsLoaded) return const BriefingHabits();
    final good = s.scheduledGoodHabits;
    return BriefingHabits(
      status: BriefingStatus.ready,
      scheduled: good.length,
      done: good.where((h) => h.doneToday).length,
      pending: [
        for (final h in good)
          if (!h.doneToday) BriefingHabitRef(id: h.id, title: h.title),
      ],
      negativeStreaks: [
        for (final h in s.negativeHabits) BriefingNegativeStreak(id: h.id, title: h.title, cleanDays: h.cleanDays),
      ],
    );
  }

  /// Pendientes o pospuestos vencidos y de hoy; los de mañana solo de noche (Q4).
  BriefingReminders _reminders(DailyBriefingSnapshot s, DateTime now, BriefingPeriod period) {
    if (!s.remindersLoaded) return const BriefingReminders();
    // Por calendario, no sumando 24 h: con cambio de hora (DST) `add` cae en
    // el mismo día.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final items = <BriefingReminder>[];
    for (final r in s.reminders) {
      final due = r.dueAt;
      if (due == null) continue;
      if (r.status != ReminderStatus.pending && r.status != ReminderStatus.snoozed) continue;
      final overdue = due.isBefore(now);
      final isToday = _sameDay(due, now);
      final isTomorrow = period == BriefingPeriod.night && _sameDay(due, tomorrow);
      if (!overdue && !isToday && !isTomorrow) continue;
      items.add(BriefingReminder(id: r.id, title: r.title, dueAt: due, isOverdue: overdue, isTomorrow: isTomorrow));
    }
    items.sort((a, b) {
      final byUrgency = BriefingReminders.compareByUrgency(a, b);
      return byUrgency != 0 ? byUrgency : a.title.compareTo(b.title);
    });
    return BriefingReminders(status: BriefingStatus.ready, items: items);
  }

  /// Variación contra el registro más reciente con fecha anterior a hoy; el
  /// paralelo no tiene historial (sin variación).
  BriefingRates _rates(DailyBriefingSnapshot s, DateTime now) {
    if (!s.financeLoaded) return const BriefingRates();
    return BriefingRates(
      status: BriefingStatus.ready,
      bcv: BriefingRate(value: s.bcv, deltaVsPrevious: _delta(s.bcv, s.bcvHistory, now)),
      parallel: BriefingRate(value: s.parallel),
      euro: BriefingRate(value: s.euro, deltaVsPrevious: _delta(s.euro, s.euroHistory, now)),
    );
  }

  double? _delta(double current, List<ExchangeRateRecord> history, DateTime now) {
    if (current <= 0) return null;
    final today = _day(now);
    ExchangeRateRecord? previous;
    for (final r in history) {
      if (!_day(r.date.toLocal()).isBefore(today)) continue;
      if (previous == null || r.date.isAfter(previous.date)) previous = r;
    }
    if (previous == null || previous.rate <= 0) return null;
    return current - previous.rate;
  }
}
