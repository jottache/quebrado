import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/services/nlp_parser.dart';

void main() {
  group('NlpParser Tests', () {
    test('Extrae prioridad y tags correctamente', () {
      final res = NlpParser.parse('Pagar tarjeta de crédito !p1 #finanzas #banco');

      expect(res.cleanTitle, equals('Pagar tarjeta de crédito'));
      expect(res.priority, equals(ReminderPriority.p1Urgent));
      expect(res.tags, containsAll(['finanzas', 'banco']));
      expect(res.hasParsedDue, isFalse);
    });

    test('Parsea fechas relativas "mañana a las 3pm"', () {
      final res = NlpParser.parse('Llamar al médico mañana a las 3pm !alta');

      expect(res.cleanTitle, equals('Llamar al médico'));
      expect(res.priority, equals(ReminderPriority.p2High));
      expect(res.hasParsedDue, isTrue);

      final due = res.dueAt!;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(due.day, equals(tomorrow.day));
      expect(due.hour, equals(15));
      expect(due.minute, equals(0));
    });

    test('Parsea offset relativo "en 30 minutos"', () {
      final before = DateTime.now();
      final res = NlpParser.parse('Revisar servidor en 30 minutos !urgente');
      final after = DateTime.now();

      expect(res.cleanTitle, equals('Revisar servidor'));
      expect(res.priority, equals(ReminderPriority.p1Urgent));
      expect(res.hasParsedDue, isTrue);

      final diff = res.dueAt!.difference(before).inMinutes;
      expect(diff, inInclusiveRange(29, 31));
    });

    test('Parsea momentos del día "esta noche"', () {
      final res = NlpParser.parse('Comprar cena esta noche #comida');

      expect(res.cleanTitle, equals('Comprar cena'));
      expect(res.tags, contains('comida'));
      expect(res.hasParsedDue, isTrue);
      expect(res.dueAt!.hour, equals(20));
      expect(res.dueAt!.minute, equals(0));
    });
  });

  group('ReminderModel Tests', () {
    test('Serialización toMap y fromMap', () {
      final reminder = ReminderModel(
        id: 'rem-123',
        title: 'Comprar repuesto',
        notes: 'Marca Bosch',
        priority: ReminderPriority.p1Urgent,
        status: ReminderStatus.pending,
        dueAt: DateTime(2026, 9, 15, 14, 0),
        isNagging: true,
        nagIntervalMinutes: 15,
        tags: ['auto', 'taller'],
      );

      final map = reminder.toMap();
      expect(map['id'], equals('rem-123'));
      expect(map['priority'], equals('p1_urgent'));
      expect(map['status'], equals('pending'));
      expect(map['is_nagging'], isTrue);
      expect(map['tags'], equals(['auto', 'taller']));

      final restored = ReminderModel.fromMap(map);
      expect(restored.id, equals(reminder.id));
      expect(restored.title, equals(reminder.title));
      expect(restored.priority, equals(reminder.priority));
      expect(restored.status, equals(reminder.status));
      expect(restored.isNagging, equals(reminder.isNagging));
      expect(restored.tags, equals(reminder.tags));
    });

    test('Detecta vencimiento isOverdue', () {
      final past = ReminderModel(
        id: 'past',
        title: 'Pasado',
        dueAt: DateTime.now().subtract(const Duration(hours: 1)),
        status: ReminderStatus.pending,
      );
      expect(past.isOverdue, isTrue);

      final future = ReminderModel(
        id: 'future',
        title: 'Futuro',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        status: ReminderStatus.pending,
      );
      expect(future.isOverdue, isFalse);

      final completedPast = past.copyWith(status: ReminderStatus.completed);
      expect(completedPast.isOverdue, isFalse);
    });

    test('Mapeo y persistencia de recurrencia en rrule', () {
      final weeklyReminder = ReminderModel(
        id: 'rec-1',
        title: 'Revisión semanal',
        rrule: ReminderRecurrence.weekly.rruleString,
      );
      expect(weeklyReminder.isRecurring, isTrue);
      expect(weeklyReminder.recurrence, equals(ReminderRecurrence.weekly));
      expect(weeklyReminder.rrule, equals('FREQ=WEEKLY'));

      final map = weeklyReminder.toMap();
      expect(map['rrule'], equals('FREQ=WEEKLY'));

      final fromMap = ReminderModel.fromMap(map);
      expect(fromMap.isRecurring, isTrue);
      expect(fromMap.recurrence, equals(ReminderRecurrence.weekly));

      final biweekly = ReminderModel(
        id: 'rec-2',
        title: 'Pago quincenal',
        rrule: ReminderRecurrence.biweekly.rruleString,
      );
      expect(biweekly.recurrence, equals(ReminderRecurrence.biweekly));
      expect(biweekly.rrule, equals('FREQ=WEEKLY;INTERVAL=2'));

      final monthly = ReminderModel(
        id: 'rec-3',
        title: 'Alquiler mensual',
        rrule: ReminderRecurrence.monthly.rruleString,
      );
      expect(monthly.recurrence, equals(ReminderRecurrence.monthly));
      expect(monthly.rrule, equals('FREQ=MONTHLY'));
    });

    test('Cálculo de siguiente ocurrencia calculateNextDueDate', () {
      final base = DateTime(2026, 9, 10, 15, 30);

      // Semanal -> +7 días
      final nextWeekly = ReminderRecurrence.weekly.calculateNextDueDate(base);
      expect(nextWeekly, equals(DateTime(2026, 9, 17, 15, 30)));

      // Quincenal -> +14 días
      final nextBiweekly = ReminderRecurrence.biweekly.calculateNextDueDate(base);
      expect(nextBiweekly, equals(DateTime(2026, 9, 24, 15, 30)));

      // Mensual -> +1 mes (mismo día y hora)
      final nextMonthly = ReminderRecurrence.monthly.calculateNextDueDate(base);
      expect(nextMonthly, equals(DateTime(2026, 10, 10, 15, 30)));

      // Mensual con ajuste de fin de mes (ej. 31 de enero -> 28 o 29 de febrero)
      final jan31 = DateTime(2026, 1, 31, 10, 0);
      final febNext = ReminderRecurrence.monthly.calculateNextDueDate(jan31);
      expect(febNext.month, equals(2));
      expect(febNext.day, equals(28)); // 2026 no es bisiesto
      expect(febNext.hour, equals(10));

      // Diario -> +1 día
      final nextDaily = ReminderRecurrence.daily.calculateNextDueDate(base);
      expect(nextDaily, equals(DateTime(2026, 9, 11, 15, 30)));
    });
  });

  group('NlpParser Recurrence Tests', () {
    test('Extrae recurrencia semanal en lenguaje natural', () {
      final res = NlpParser.parse('Reunión de sprint semanal !alta #trabajo');
      expect(res.cleanTitle, equals('Reunión de sprint'));
      expect(res.recurrence, equals(ReminderRecurrence.weekly));
      expect(res.priority, equals(ReminderPriority.p2High));
      expect(res.tags, contains('trabajo'));
    });

    test('Extrae recurrencia quincenal con variantes ("quincenal", "cada 15 días")', () {
      final res1 = NlpParser.parse('Pago nómina quincenal !urgente');
      expect(res1.cleanTitle, equals('Pago nómina'));
      expect(res1.recurrence, equals(ReminderRecurrence.biweekly));
      expect(res1.priority, equals(ReminderPriority.p1Urgent));

      final res2 = NlpParser.parse('Limpieza profunda cada 15 días #hogar');
      expect(res2.cleanTitle, equals('Limpieza profunda'));
      expect(res2.recurrence, equals(ReminderRecurrence.biweekly));
      expect(res2.tags, contains('hogar'));
    });

    test('Extrae recurrencia mensual ("mensual", "cada mes")', () {
      final res1 = NlpParser.parse('Pagar suscripción mensual #finanzas');
      expect(res1.cleanTitle, equals('Pagar suscripción'));
      expect(res1.recurrence, equals(ReminderRecurrence.monthly));
      expect(res1.tags, contains('finanzas'));

      final res2 = NlpParser.parse('Informe de resultados cada mes');
      expect(res2.cleanTitle, equals('Informe de resultados'));
      expect(res2.recurrence, equals(ReminderRecurrence.monthly));
    });

    test('Extrae recurrencia mediante tags cuando no está en texto plano', () {
      final res = NlpParser.parse('Rutina de ejercicios #semanal');
      expect(res.cleanTitle, equals('Rutina de ejercicios'));
      expect(res.recurrence, equals(ReminderRecurrence.weekly));

      final res2 = NlpParser.parse('Revisar ahorros #quincenal');
      expect(res2.cleanTitle, equals('Revisar ahorros'));
      expect(res2.recurrence, equals(ReminderRecurrence.biweekly));
    });
  });
}
