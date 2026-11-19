import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/widgets/helpers.dart' show formatCurrency;

// Datos inventados. 2026-11-18 es miércoles.
final _now = DateTime(2026, 11, 18, 9, 30);
final _night = DateTime(2026, 11, 18, 20, 15);

String _fmt(BriefingAmount a) => a.displayParts.map((p) => formatCurrency(p.amount, p.currency)).join(' · ');

BriefingPayment _payment(
  String id, {
  DateTime? date,
  int occurrences = 1,
  int overdue = 0,
  double amount = 10,
  CurrencyType currency = CurrencyType.usd,
  double bcv = 250,
  double partialPaid = 0,
  BriefingPaymentState state = BriefingPaymentState.pending,
}) =>
    BriefingPayment(
      paymentId: id,
      name: 'Pago $id',
      oldestOccurrenceDate: date ?? DateTime(2026, 11, 20),
      occurrenceCount: occurrences,
      overdueCount: overdue,
      remaining: BriefingAmount.convert(amount, currency, bcv: bcv, euro: 270),
      partialPaid: partialPaid,
      state: state,
    );

/// Resumen con todo listo y al día; cada test cambia lo que necesita.
DailyBriefing _clear({DateTime? at, BriefingPeriod period = BriefingPeriod.morning}) => DailyBriefing(
      generatedAt: at ?? _now,
      period: period,
      bookName: 'Libro de prueba',
      diario: const BriefingDiario(status: BriefingStatus.ready, entriesToday: 1),
      mood: const BriefingMood(status: BriefingStatus.ready, loggedToday: true),
      payments: const BriefingPayments(status: BriefingStatus.ready),
      birthdays: const BriefingBirthdays(status: BriefingStatus.ready),
      habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 2, done: 2),
      reminders: const BriefingReminders(status: BriefingStatus.ready),
      rates: const BriefingRates(
        status: BriefingStatus.ready,
        bcv: BriefingRate(value: 250, deltaVsPrevious: 1.5),
        parallel: BriefingRate(value: 300),
        euro: BriefingRate(value: 270),
      ),
    );

/// Resumen con todas las secciones llenas (para JSON y metadata).
DailyBriefing _full() => _clear().copyWith(
      diario: const BriefingDiario(status: BriefingStatus.ready, entriesToday: 0),
      mood: const BriefingMood(status: BriefingStatus.ready, loggedToday: false),
      payments: BriefingPayments(status: BriefingStatus.ready, items: [
        _payment('p1', amount: 25, partialPaid: 15, date: DateTime(2026, 11, 20)),
        _payment('p2', amount: 75, overdue: 3, occurrences: 3, date: DateTime(2026, 9, 10)),
        _payment('p3', amount: 10, currency: CurrencyType.eur, state: BriefingPaymentState.paid),
      ]),
      birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
        BriefingBirthday(contactId: 'c-1', name: 'Contacto Uno', date: DateTime(2026, 11, 20), inDays: 2),
      ]),
      habits: const BriefingHabits(
        status: BriefingStatus.ready,
        scheduled: 3,
        done: 1,
        pending: [BriefingHabitRef(id: 'h-1', title: 'HabitoSecretoA'), BriefingHabitRef(id: 'h-2', title: 'HabitoSecretoB')],
        negativeStreaks: [BriefingNegativeStreak(id: 'n-1', title: 'RachaSecreta', cleanDays: 12)],
      ),
      reminders: BriefingReminders(status: BriefingStatus.ready, items: [
        BriefingReminder(id: 'r-1', title: 'Recordatorio inventado', dueAt: DateTime(2026, 11, 17, 10), isOverdue: true),
        BriefingReminder(
            id: 'r-2', title: 'Otro', dueAt: DateTime(2026, 11, 18, 15), snoozedUntil: DateTime(2026, 11, 18, 16)),
      ]),
    );

List<String> _labels(DailyBriefing b) => b.highlights.map((h) => h.label).toList();

void main() {
  group('BriefingAmount.convert (§4)', () {
    test('CA-03: \$40 con \$15 abonados → usd 25 y ves 25 × BCV, con el formato de la app', () {
      final a = BriefingAmount.convert(40 - 15, CurrencyType.usd, bcv: 250, euro: 270);
      expect(a.usd, 25);
      expect(a.ves, 25 * 250);
      expect(a.rateMissing, isFalse);
      expect(_fmt(a), r'$25.00 · Bs. 6250.00');
    });

    test('CA-04: Bs 1000 con BCV 250 → usd 4 y ves 1000', () {
      final a = BriefingAmount.convert(1000, CurrencyType.bsBCV, bcv: 250, euro: 270);
      expect(a.usd, 4);
      expect(a.ves, 1000);
      expect(_fmt(a), r'$4.00 · Bs. 1000.00');
    });

    test('pago en € usa la tasa euro (usd = a × eur / bcv) y conserva el monto en € (Q5b)', () {
      final a = BriefingAmount.convert(10, CurrencyType.eur, bcv: 250, euro: 270);
      expect(a.ves, closeTo(2700, 1e-9));
      expect(a.usd, closeTo(10 * 270 / 250, 1e-9));
      expect(a.displayParts.last, (amount: 10.0, currency: CurrencyType.eur));
      expect(_fmt(a), r'$10.80 · Bs. 2700.00 · €10.00');
    });

    test('sin tasa BCV: usd y ves son null y solo se muestra el monto original', () {
      final a = BriefingAmount.convert(1000, CurrencyType.bsBCV, bcv: 0, euro: 270);
      expect(a.usd, isNull);
      expect(a.ves, isNull);
      expect(a.rateMissing, isTrue);
      expect(_fmt(a), 'Bs. 1000.00');
    });

    test('pago en € sin tasa euro: usd y ves son null', () {
      final a = BriefingAmount.convert(10, CurrencyType.eur, bcv: 250, euro: 0);
      expect(a.usd, isNull);
      expect(a.ves, isNull);
      expect(_fmt(a), '€10.00');
    });
  });

  group('BriefingPayments.totalUsd', () {
    test('suma lo que falta de las filas pendientes y omite las pagadas', () {
      final p = BriefingPayments(status: BriefingStatus.ready, items: [
        _payment('a', amount: 25),
        _payment('b', amount: 1000, currency: CurrencyType.bsBCV),
        _payment('c', amount: 99, state: BriefingPaymentState.paid),
      ]);
      expect(p.totalUsd, 29);
    });

    test('es null si algún pago pendiente no tiene tasa', () {
      final p = BriefingPayments(status: BriefingStatus.ready, items: [
        _payment('a', amount: 25),
        _payment('b', amount: 1000, currency: CurrencyType.bsBCV, bcv: 0),
      ]);
      expect(p.totalUsd, isNull);
    });

    test('es null mientras la sección carga', () {
      expect(const BriefingPayments().totalUsd, isNull);
    });
  });

  group('BriefingPayment (Q8)', () {
    test('una fila agrupa vencidos: isOverdue y hasPartial salen de los conteos', () {
      final p = _payment('x', overdue: 3, occurrences: 3, partialPaid: 5);
      expect(p.isOverdue, isTrue);
      expect(p.hasPartial, isTrue);
      final paid = p.copyWith(state: BriefingPaymentState.paid);
      expect(paid.isPending, isFalse);
      expect(paid.overdueCount, 3);
      expect(_payment('y').isOverdue, isFalse);
    });
  });

  group('toGeminiJson (§2.3)', () {
    test('usa exactamente las claves de la lista blanca', () {
      final json = _full().toGeminiJson();
      expect(json.keys.toSet(), {
        'fecha', 'hora', 'periodo', 'libro', 'diario', 'animo', 'pagos', //
        'cumpleanos', 'habitos', 'recordatorios', 'tasas',
      });
      expect(json['fecha'], '2026-11-18');
      expect(json['hora'], '09:30');
      expect(json['periodo'], 'morning');
      expect((json['diario'] as Map).keys.toSet(), {'estado', 'entradas_hoy'});
      expect((json['animo'] as Map).keys.toSet(), {'estado', 'registrado_hoy'});
      final pagos = json['pagos'] as Map;
      expect(pagos.keys.toSet(), {'estado', 'total_usd', 'items'});
      expect((pagos['items'] as List).first.keys.toSet(),
          {'nombre', 'vence', 'vencido', 'vencidos', 'falta_usd', 'falta_bs', 'moneda', 'monto_moneda', 'parcial'});
      final cumple = json['cumpleanos'] as Map;
      expect(cumple.keys.toSet(), {'estado', 'items'});
      expect((cumple['items'] as List).first.keys.toSet(), {'nombre', 'fecha', 'en_dias'});
      expect((json['habitos'] as Map).keys.toSet(),
          {'estado', 'programados', 'hechos', 'pendientes', 'rachas_dejando'});
      final rec = json['recordatorios'] as Map;
      expect(rec.keys.toSet(), {'estado', 'items'});
      expect((rec['items'] as List).first.keys.toSet(), {'titulo', 'vence', 'vencido', 'manana'});
      expect((json['tasas'] as Map).keys.toSet(), {'estado', 'bcv', 'paralelo', 'euro', 'var_bcv', 'var_euro'});
    });

    test('pagos: solo las filas pendientes, agrupadas, con montos y moneda', () {
      final pagos = _full().toGeminiJson()['pagos'] as Map;
      final items = (pagos['items'] as List).cast<Map>();
      expect(items, hasLength(2));
      expect(items[0], {
        'nombre': 'Pago p1', 'vence': '2026-11-20', 'vencido': false, 'vencidos': 0, 'falta_usd': 25.0, //
        'falta_bs': 6250.0, 'moneda': 'usd', 'monto_moneda': 25.0, 'parcial': true,
      });
      expect(items[1]['vencido'], isTrue);
      expect(items[1]['vencidos'], 3);
      expect(items[1]['vence'], '2026-09-10');
      expect(pagos['total_usd'], 100.0);
    });

    test('las rachas van sin nombre (solo días) y no salen títulos de hábitos ni ids', () {
      final json = _full().toGeminiJson();
      expect((json['habitos'] as Map)['rachas_dejando'], [12]);
      expect((json['habitos'] as Map)['pendientes'], 2);
      final text = jsonEncode(json);
      for (final secret in ['HabitoSecretoA', 'HabitoSecretoB', 'RachaSecreta', 'h-1', 'n-1', 'c-1', 'r-1']) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('una sección que no está lista solo lleva su estado', () {
      final json = _full().copyWith(payments: const BriefingPayments(status: BriefingStatus.unavailable)).toGeminiJson();
      expect(json['pagos'], {'estado': 'unavailable'});
      expect(DailyBriefing(generatedAt: _now, period: BriefingPeriod.night, bookName: 'L').toGeminiJson()['diario'],
          {'estado': 'loading'});
    });

    test('pago sin tasa manda falta_usd y falta_bs en null y total_usd null', () {
      final b = _clear().copyWith(
        payments: BriefingPayments(status: BriefingStatus.ready, items: [
          _payment('z', amount: 1000, currency: CurrencyType.bsBCV, bcv: 0),
        ]),
      );
      final pagos = b.toGeminiJson()['pagos'] as Map;
      final item = (pagos['items'] as List).first as Map;
      expect(item['falta_usd'], isNull);
      expect(item['falta_bs'], isNull);
      expect(item['moneda'], 'ves');
      expect(pagos['total_usd'], isNull);
    });
  });

  group('metadata del artefacto', () {
    test('ida y vuelta por JSON conserva todo', () {
      final original = _full();
      final meta = jsonDecode(jsonEncode(original.toArtifactMetadata())) as Map<String, dynamic>;
      final back = DailyBriefing.fromArtifactMetadata(meta);
      expect(back.toArtifactMetadata(), original.toArtifactMetadata());
      expect(back.generatedAt, _now);
      expect(back.payments.items[1].overdueCount, 3);
      expect(back.payments.items[2].state, BriefingPaymentState.paid);
      expect(back.payments.items[2].remaining.original, CurrencyType.eur);
      expect(back.reminders.items[1].snoozedUntil, DateTime(2026, 11, 18, 16));
      expect(back.habits.negativeStreaks.single.title, 'RachaSecreta');
    });

    test('una sección ausente queda como no disponible', () {
      final meta = _full().toArtifactMetadata()..remove('habits');
      final back = DailyBriefing.fromArtifactMetadata(meta);
      expect(back.habits.status, BriefingStatus.unavailable);
      expect(back.diario.status, BriefingStatus.ready);
    });
  });

  group('isFullyLoaded e isAllClear (§5.5)', () {
    test('todo listo, escribió, sin pagos, hábitos completos y sin recordatorios de hoy → al día', () {
      expect(_clear().isFullyLoaded, isTrue);
      expect(_clear().isAllClear, isTrue);
    });

    test('el ánimo sin registrar no impide estar al día', () {
      expect(_clear().copyWith(mood: const BriefingMood(status: BriefingStatus.ready)).isAllClear, isTrue);
    });

    test('cualquier condición incumplida lo impide', () {
      final b = _clear();
      expect(b.copyWith(diario: const BriefingDiario(status: BriefingStatus.ready)).isAllClear, isFalse);
      expect(b.copyWith(rates: const BriefingRates()).isAllClear, isFalse);
      expect(b.copyWith(rates: const BriefingRates()).isFullyLoaded, isFalse);
      expect(
          b.copyWith(payments: BriefingPayments(status: BriefingStatus.ready, items: [_payment('a')])).isAllClear, isFalse);
      expect(b.copyWith(habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 2, done: 1)).isAllClear,
          isFalse);
      expect(
          b
              .copyWith(
                  reminders: BriefingReminders(
                      status: BriefingStatus.ready,
                      items: [BriefingReminder(id: 'r', title: 't', dueAt: DateTime(2026, 11, 18, 15))]))
              .isAllClear,
          isFalse);
    });

    test('pagos ya pagados o recordatorios de mañana no impiden estar al día', () {
      final b = _clear().copyWith(
        payments: BriefingPayments(
            status: BriefingStatus.ready, items: [_payment('a', state: BriefingPaymentState.paid)]),
        reminders: BriefingReminders(
            status: BriefingStatus.ready,
            items: [BriefingReminder(id: 'r', title: 't', dueAt: DateTime(2026, 11, 19, 9), isTomorrow: true)]),
      );
      expect(b.isAllClear, isTrue);
    });
  });

  group('highlights (U4)', () {
    test('sin nada relevante y todo cargado: una sola etiqueta «Todo al día»', () {
      final h = _clear().highlights;
      expect(h, hasLength(1));
      expect(h.single.kind, BriefingHighlightKind.allClear);
      expect(h.single.label, 'Todo al día');
    });

    test('mientras algo carga y no hay nada que mostrar, la franja queda vacía', () {
      expect(_clear().copyWith(diario: const BriefingDiario()).highlights, isEmpty);
    });

    test('de mañana: vencidos > recordatorios vencidos > cumpleaños hoy, máximo 3', () {
      final b = _clear().copyWith(
        payments: BriefingPayments(status: BriefingStatus.ready, items: [
          _payment('a', overdue: 2, occurrences: 3),
          _payment('b', overdue: 1),
        ]),
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'r', title: 't', dueAt: DateTime(2026, 11, 17), isOverdue: true),
        ]),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 18), inDays: 0),
        ]),
        habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 5, done: 3),
      );
      expect(_labels(b), ['3 pagos vencidos', '1 recordatorio vencido', 'Cumpleaños hoy']);
    });

    test('de mañana sin vencidos: semana, hoy, próximos cumpleaños (una por categoría)', () {
      final b = _clear().copyWith(
        payments: BriefingPayments(status: BriefingStatus.ready, items: [_payment('a'), _payment('b')]),
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'r', title: 't', dueAt: DateTime(2026, 11, 18, 15)),
        ]),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 20), inDays: 2),
        ]),
      );
      expect(_labels(b), ['2 pagos esta semana', '1 recordatorio hoy', 'Cumpleaños el viernes']);
    });

    test('de mañana, hábitos y luego diario/ánimo cuando no hay más', () {
      final b = _clear().copyWith(
        habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 5, done: 3),
        diario: const BriefingDiario(status: BriefingStatus.ready),
        mood: const BriefingMood(status: BriefingStatus.ready),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 20), inDays: 2),
          BriefingBirthday(contactId: 'd', name: 'M', date: DateTime(2026, 11, 22), inDays: 4),
        ]),
      );
      expect(_labels(b), ['2 cumpleaños esta semana', '3/5 hábitos', 'Sin diario ni ánimo']);
    });

    test('de noche sube lo que faltó: diario/ánimo y hábitos antes que lo que viene', () {
      final b = _clear(at: _night, period: BriefingPeriod.night).copyWith(
        mood: const BriefingMood(status: BriefingStatus.ready),
        habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 4, done: 1),
        payments: BriefingPayments(status: BriefingStatus.ready, items: [_payment('a', date: DateTime(2026, 11, 19))]),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 19), inDays: 1),
        ]),
      );
      expect(_labels(b), ['Sin ánimo hoy', '1/4 hábitos', '1 pago mañana']);
    });

    test('de noche sin lo que faltó: pagos y cumpleaños de mañana y recordatorios de mañana', () {
      final b = _clear(at: _night, period: BriefingPeriod.night).copyWith(
        payments: BriefingPayments(status: BriefingStatus.ready, items: [
          _payment('a', date: DateTime(2026, 11, 19)),
          _payment('b', date: DateTime(2026, 11, 22)),
        ]),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 19), inDays: 1),
        ]),
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'r', title: 't', dueAt: DateTime(2026, 11, 19, 8), isTomorrow: true),
          BriefingReminder(id: 's', title: 'u', dueAt: DateTime(2026, 11, 19, 9), isTomorrow: true),
        ]),
      );
      expect(_labels(b), ['1 pago mañana', 'Cumpleaños mañana', '2 recordatorios mañana']);
    });

    test('las secciones que cargan, los pagos ya pagados y los recordatorios pospuestos no compiten', () {
      final b = _clear().copyWith(
        diario: const BriefingDiario(),
        payments: BriefingPayments(
            status: BriefingStatus.ready, items: [_payment('a', overdue: 1, state: BriefingPaymentState.paid)]),
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(
              id: 'r', title: 't', dueAt: DateTime(2026, 11, 17), isOverdue: true, snoozedUntil: DateTime(2026, 11, 19)),
        ]),
        habits: const BriefingHabits(scheduled: 3, done: 0),
      );
      expect(b.highlights, isEmpty);
    });

    test('las etiquetas no llevan nombres ni montos', () {
      final labels = _labels(_full()).join(' ');
      expect(labels, isNot(contains('Pago p')));
      expect(labels, isNot(contains('Contacto')));
      expect(labels, isNot(contains(r'$')));
      expect(labels, isNot(contains('Bs')));
    });
  });

  // Fechas locales con DateTime(y, m, d). En una zona sin cambio de horario
  // (UTC, America/Caracas) estos casos pasan con cualquier cálculo; son
  // significativos con una zona con DST, p. ej.:
  //   TZ=America/New_York flutter test test/agente/models/daily_briefing_test.dart
  // (en 2026 la hora cambia el 8 de marzo y el 1 de noviembre).
  group('briefingCalendarDaysBetween', () {
    test('cuenta días de calendario sin mirar la hora, también hacia atrás y entre años', () {
      expect(briefingCalendarDaysBetween(DateTime(2026, 11, 18, 23, 59), DateTime(2026, 11, 19, 0, 1)), 1);
      expect(briefingCalendarDaysBetween(DateTime(2026, 11, 18, 0, 1), DateTime(2026, 11, 18, 23, 59)), 0);
      expect(briefingCalendarDaysBetween(DateTime(2026, 11, 18), DateTime(2026, 11, 17, 8)), -1);
      expect(briefingCalendarDaysBetween(DateTime(2026, 12, 31, 20), DateTime(2027, 1, 1)), 1);
    });

    test('no se altera en los días de cambio de horario (día de 23 y de 25 horas)', () {
      expect(briefingCalendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
      expect(briefingCalendarDaysBetween(DateTime(2026, 3, 7, 12), DateTime(2026, 3, 9)), 2);
      expect(briefingCalendarDaysBetween(DateTime(2026, 3, 9), DateTime(2026, 3, 8)), -1);
      expect(briefingCalendarDaysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
      expect(briefingCalendarDaysBetween(DateTime(2026, 10, 31, 22), DateTime(2026, 11, 2)), 2);
      expect(briefingCalendarDaysBetween(DateTime(2026, 11, 2), DateTime(2026, 11, 1)), -1);
    });
  });

  group('orden de pagos y recordatorios', () {
    test('pagos: vencidos primero, luego por fecha; los empates conservan el orden recibido', () {
      final p = BriefingPayments(status: BriefingStatus.ready, items: [
        _payment('semana', date: DateTime(2026, 11, 20)),
        _payment('vencido-reciente', overdue: 1, date: DateTime(2026, 11, 10)),
        _payment('empate', date: DateTime(2026, 11, 20)),
        _payment('vencido-viejo', overdue: 2, occurrences: 2, date: DateTime(2026, 9, 10)),
        _payment('hoy', date: DateTime(2026, 11, 18)),
      ]);
      expect(p.sortedItems.map((x) => x.paymentId), ['vencido-viejo', 'vencido-reciente', 'hoy', 'semana', 'empate']);
      expect(p.items.first.paymentId, 'semana', reason: 'no cambia la lista original');
    });

    test('recordatorios: vencidos primero y luego por hora; separados en hoy y mañana', () {
      final r = BriefingReminders(status: BriefingStatus.ready, items: [
        BriefingReminder(id: 'manana', title: 'm', dueAt: DateTime(2026, 11, 19, 8), isTomorrow: true),
        BriefingReminder(id: 'hoy-tarde', title: 't', dueAt: DateTime(2026, 11, 18, 21)),
        BriefingReminder(id: 'vencido', title: 'v', dueAt: DateTime(2026, 11, 18, 22), isOverdue: true),
        BriefingReminder(id: 'hoy-temprano', title: 'e', dueAt: DateTime(2026, 11, 18, 11)),
      ]);
      expect(r.sortedItems.map((x) => x.id), ['vencido', 'hoy-temprano', 'hoy-tarde', 'manana']);
      expect(r.sortedTodayItems.map((x) => x.id), ['vencido', 'hoy-temprano', 'hoy-tarde']);
      expect(r.sortedTomorrowItems.map((x) => x.id), ['manana']);
    });
  });

  group('BriefingPayments.hiddenRemainingUsd', () {
    BriefingPayments payments(List<BriefingPayment> items) =>
        BriefingPayments(status: BriefingStatus.ready, items: items);

    test('suma en \$ lo que falta de las filas pendientes a partir de las primeras N', () {
      final p = payments([
        _payment('d', amount: 4, date: DateTime(2026, 11, 23)),
        _payment('a', amount: 1, date: DateTime(2026, 11, 19)),
        _payment('c', amount: 1000, currency: CurrencyType.bsBCV, date: DateTime(2026, 11, 22)),
        _payment('b', amount: 2, date: DateTime(2026, 11, 20)),
      ]);
      expect(p.hiddenRemainingUsd(3), 4);
      expect(p.hiddenRemainingUsd(2), 4 + 1000 / 250);
      expect(p.hiddenRemainingUsd(4), isNull, reason: 'no queda nada oculto');
    });

    test('omite las ocultas ya pagadas u omitidas; null si ninguna oculta está pendiente', () {
      final p = payments([
        _payment('a', amount: 1, date: DateTime(2026, 11, 19)),
        _payment('b', amount: 2, date: DateTime(2026, 11, 20), state: BriefingPaymentState.paid),
        _payment('c', amount: 3, date: DateTime(2026, 11, 21)),
        _payment('d', amount: 4, date: DateTime(2026, 11, 22), state: BriefingPaymentState.dismissed),
      ]);
      expect(p.hiddenRemainingUsd(1), 3);
      expect(p.hiddenRemainingUsd(3), isNull);
    });

    test('es null si alguna oculta pendiente no tiene tasa', () {
      final p = payments([
        _payment('a', amount: 1, date: DateTime(2026, 11, 19)),
        _payment('b', amount: 2, date: DateTime(2026, 11, 20)),
        _payment('c', amount: 1000, currency: CurrencyType.bsBCV, bcv: 0, date: DateTime(2026, 11, 21)),
      ]);
      expect(p.hiddenRemainingUsd(1), isNull);
      expect(p.hiddenRemainingUsd(0), isNull);
    });
  });

  group('«Al día», anuncio y nombres de hábitos', () {
    test('upToDateSections: diario, ánimo y hábitos completos, en ese orden', () {
      expect(_clear().upToDateSections, [
        BriefingUpToDateSection.diario,
        BriefingUpToDateSection.mood,
        BriefingUpToDateSection.habits,
      ]);
      expect(BriefingUpToDateSection.values.map((s) => s.label), ['diario', 'ánimo', 'hábitos']);
    });

    test('upToDateSections deja fuera lo incompleto, lo que no está listo y los hábitos sin programar', () {
      expect(_full().upToDateSections, isEmpty);
      final b = _clear().copyWith(
        diario: const BriefingDiario(status: BriefingStatus.loading, entriesToday: 1),
        habits: const BriefingHabits(status: BriefingStatus.ready),
      );
      expect(b.upToDateSections, [BriefingUpToDateSection.mood]);
    });

    test('itemCount cuenta diario, ánimo, pagos pendientes, cumpleaños, hábitos y recordatorios de hoy', () {
      // _full: sin diario (1) + sin ánimo (1) + 2 pagos pendientes + 1
      // cumpleaños + hábitos pendientes (1) + 1 recordatorio vencido (el
      // pospuesto no cuenta).
      expect(_full().itemCount, 7);
      expect(_clear().itemCount, 0);
    });

    test('itemCount no cuenta los recordatorios de mañana ni los pospuestos', () {
      final b = _clear().copyWith(
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'm', title: 'm', dueAt: DateTime(2026, 11, 19, 8), isTomorrow: true),
          BriefingReminder(
              id: 'p', title: 'p', dueAt: DateTime(2026, 11, 18, 15), snoozedUntil: DateTime(2026, 11, 18, 16)),
          BriefingReminder(id: 'h', title: 'h', dueAt: DateTime(2026, 11, 18, 15)),
        ]),
      );
      expect(b.itemCount, 1);
    });

    test('pendingNamesShown muestra hasta kBriefingMaxHabitNames y cuenta el resto', () {
      expect(kBriefingMaxHabitNames, 3);
      final h = BriefingHabits(
        status: BriefingStatus.ready,
        scheduled: 5,
        pending: [for (final id in ['a', 'b', 'c', 'd', 'e']) BriefingHabitRef(id: id, title: 'Hábito $id')],
      );
      expect(h.pendingNamesShown, ['Hábito a', 'Hábito b', 'Hábito c']);
      expect(h.pendingNamesHidden, 2);
      expect(_full().habits.pendingNamesShown, ['HabitoSecretoA', 'HabitoSecretoB']);
      expect(_full().habits.pendingNamesHidden, 0);
    });
  });

  group('bookId y oldestRemaining', () {
    final oldest = BriefingAmount.convert(25, CurrencyType.usd, bcv: 250, euro: 270);

    test('la metadata conserva bookId y oldestRemaining; bookId no va a Gemini', () {
      final b = DailyBriefing(
        generatedAt: _now,
        period: BriefingPeriod.morning,
        bookName: 'Libro de prueba',
        bookId: 'libro-id-prueba.db',
        payments: BriefingPayments(status: BriefingStatus.ready, items: [
          _payment('x', amount: 75, occurrences: 3, overdue: 2).copyWith(oldestRemaining: oldest),
        ]),
      );
      final meta = jsonDecode(jsonEncode(b.toArtifactMetadata())) as Map<String, dynamic>;
      final back = DailyBriefing.fromArtifactMetadata(meta);
      expect(back.bookId, 'libro-id-prueba.db');
      expect(back.payments.items.single.oldestRemaining?.usd, 25);
      expect(back.payments.items.single.oldestRemaining?.ves, 25 * 250);
      expect(back.copyWith().bookId, 'libro-id-prueba.db');
      expect(jsonEncode(b.toGeminiJson()), isNot(contains('libro-id-prueba')));
    });

    test('metadata sin bookId ni oldestRemaining: vacío y null', () {
      final meta = _full().toArtifactMetadata()..remove('bookId');
      final back = DailyBriefing.fromArtifactMetadata(meta);
      expect(back.bookId, '');
      expect(back.payments.items.first.oldestRemaining, isNull);
    });

    test('payNowAmount: oldestRemaining o, con una sola ocurrencia, lo que falta', () {
      expect(_payment('a', amount: 75, occurrences: 3).copyWith(oldestRemaining: oldest).payNowAmount?.usd, 25);
      expect(_payment('b', amount: 40).payNowAmount?.usd, 40);
      expect(_payment('c', amount: 75, occurrences: 3).payNowAmount, isNull);
    });
  });

  group('S4-05: textos libres a Gemini en una línea y 60 caracteres', () {
    final largo = 'Línea uno\nlínea\tdos ${'x' * 80}';

    test('recorta nombres de pagos, contactos, títulos de recordatorios y el libro', () {
      final b = DailyBriefing(
        generatedAt: _now,
        period: BriefingPeriod.morning,
        bookName: largo,
        payments: BriefingPayments(status: BriefingStatus.ready, items: [
          BriefingPayment(
            paymentId: 'p',
            name: largo,
            oldestOccurrenceDate: DateTime(2026, 11, 20),
            remaining: BriefingAmount.convert(1, CurrencyType.usd, bcv: 250, euro: 270),
          ),
        ]),
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: largo, date: DateTime(2026, 11, 20), inDays: 2),
        ]),
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'r', title: largo, dueAt: DateTime(2026, 11, 18, 15)),
        ]),
      );
      final json = b.toGeminiJson();
      final textos = [
        json['libro'] as String,
        (json['pagos']['items'] as List).single['nombre'] as String,
        (json['cumpleanos']['items'] as List).single['nombre'] as String,
        (json['recordatorios']['items'] as List).single['titulo'] as String,
      ];
      for (final t in textos) {
        expect(t.runes.length, kBriefingGeminiTextMaxLength);
        expect(t, startsWith('Línea uno línea dos xxx'));
        expect(t, endsWith('…'));
        expect(t, isNot(matches(RegExp(r'[\n\t ]'))));
      }
      expect(kBriefingGeminiTextMaxLength, 60);
    });

    test('los textos cortos van igual y la metadata guarda el texto completo', () {
      final b = _full();
      expect(((b.toGeminiJson()['pagos'] as Map)['items'] as List).first['nombre'], 'Pago p1');
      final conLargo = b.copyWith(
        reminders: BriefingReminders(status: BriefingStatus.ready, items: [
          BriefingReminder(id: 'r', title: largo, dueAt: DateTime(2026, 11, 18, 15)),
        ]),
      );
      final back = DailyBriefing.fromArtifactMetadata(conLargo.toArtifactMetadata());
      expect(back.reminders.items.single.title, largo);
    });
  });

  // Significativo con TZ=America/New_York: el 1 de noviembre de 2026 dura 25 h
  // y sumar 24 h a su medianoche cae todavía el día 1.
  group('cambio de horario (DST)', () {
    test('de noche del día del cambio, un pago del día siguiente es «mañana»', () {
      final b = _clear(at: DateTime(2026, 11, 1, 20), period: BriefingPeriod.night).copyWith(
        payments: BriefingPayments(status: BriefingStatus.ready, items: [_payment('a', date: DateTime(2026, 11, 2))]),
      );
      expect(_labels(b), ['1 pago mañana']);
    });
  });

  group('BriefingBirthdays.sortedItems', () {
    test('ordena por días que faltan y luego por nombre, sin tocar la lista original', () {
      final b = BriefingBirthdays(status: BriefingStatus.ready, items: [
        BriefingBirthday(contactId: 'c', name: 'Zeta', date: DateTime(2026, 11, 20), inDays: 2),
        BriefingBirthday(contactId: 'a', name: 'Beta', date: DateTime(2026, 11, 22), inDays: 4),
        BriefingBirthday(contactId: 'd', name: 'Alfa', date: DateTime(2026, 11, 20), inDays: 2),
        BriefingBirthday(contactId: 'b', name: 'Omega', date: DateTime(2026, 11, 18), inDays: 0),
      ]);
      expect(b.sortedItems.map((x) => x.name), ['Omega', 'Alfa', 'Zeta', 'Beta']);
      expect(b.items.first.name, 'Zeta', reason: 'no cambia la lista original');
    });
  });

  group('rowsOmitted (S4-02)', () {
    test('la metadata guardada sin secciones da un resumen sin filas', () {
      final meta = {
        'version': DailyBriefing.metadataVersion,
        'generatedAt': _now.toIso8601String(),
        'period': BriefingPeriod.night.name,
      };
      final back = DailyBriefing.fromArtifactMetadata(meta);
      expect(back.rowsOmitted, isTrue);
      expect(back.generatedAt, _now);
      expect(back.period, BriefingPeriod.night);
      expect(back.payments.status, BriefingStatus.unavailable);
    });

    test('la metadata completa, aunque todas las secciones estén no disponibles, no omite filas', () {
      expect(DailyBriefing.fromArtifactMetadata(_full().toArtifactMetadata()).rowsOmitted, isFalse);
      final unavailable = DailyBriefing(generatedAt: _now, period: BriefingPeriod.morning, bookName: 'L').copyWith(
        diario: const BriefingDiario(status: BriefingStatus.unavailable),
        mood: const BriefingMood(status: BriefingStatus.unavailable),
        payments: const BriefingPayments(status: BriefingStatus.unavailable),
        birthdays: const BriefingBirthdays(status: BriefingStatus.unavailable),
        habits: const BriefingHabits(status: BriefingStatus.unavailable),
        reminders: const BriefingReminders(status: BriefingStatus.unavailable),
        rates: const BriefingRates(status: BriefingStatus.unavailable),
      );
      expect(DailyBriefing.fromArtifactMetadata(unavailable.toArtifactMetadata()).rowsOmitted, isFalse);
      expect(_full().rowsOmitted, isFalse);
    });
  });

  group('itemCount y announcementCount', () {
    test('itemCount no cuenta lo de secciones que no están listas', () {
      final b = _full().copyWith(
        payments: BriefingPayments(items: [_payment('x')]),
        birthdays: BriefingBirthdays(
          status: BriefingStatus.unavailable,
          items: [BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 20), inDays: 2)],
        ),
        habits: const BriefingHabits(scheduled: 3, done: 1),
        reminders: BriefingReminders(items: [BriefingReminder(id: 'h', title: 'h', dueAt: DateTime(2026, 11, 18, 15))]),
      );
      // Solo diario y ánimo (listos) cuentan.
      expect(b.itemCount, 2);
    });

    test('announcementCount es itemCount salvo con todo al día, que es 0', () {
      expect(_full().announcementCount, 7);
      final allClearWithBirthday = _clear().copyWith(
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c', name: 'N', date: DateTime(2026, 11, 20), inDays: 2),
        ]),
      );
      expect(allClearWithBirthday.isAllClear, isTrue);
      expect(allClearWithBirthday.itemCount, 1);
      expect(allClearWithBirthday.announcementCount, 0);
    });
  });
}
