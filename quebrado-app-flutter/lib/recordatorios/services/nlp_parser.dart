import '../models/reminder_model.dart';

class NlpParseResult {
  final String rawInput;
  final String cleanTitle;
  final DateTime? dueAt;
  final ReminderPriority priority;
  final ReminderRecurrence recurrence;
  final List<String> tags;
  final String? matchedDateText;
  final String? matchedPriorityText;
  final String? matchedRecurrenceText;

  NlpParseResult({
    required this.rawInput,
    required this.cleanTitle,
    this.dueAt,
    this.priority = ReminderPriority.p3Medium,
    this.recurrence = ReminderRecurrence.none,
    this.tags = const [],
    this.matchedDateText,
    this.matchedPriorityText,
    this.matchedRecurrenceText,
  });

  bool get hasParsedDue => dueAt != null;
  bool get isRecurring => recurrence != ReminderRecurrence.none;
}

/// Parser de Lenguaje Natural en Español/Inglés para Captura Rápida de Recordatorios.
class NlpParser {
  static NlpParseResult parse(String input) {
    if (input.trim().isEmpty) {
      return NlpParseResult(rawInput: input, cleanTitle: '');
    }

    String working = input;
    final List<String> tags = [];
    ReminderPriority priority = ReminderPriority.p3Medium;
    ReminderRecurrence recurrence = ReminderRecurrence.none;
    String? matchedPriorityText;
    String? matchedRecurrenceText;
    String? matchedDateText;
    DateTime? resolvedDate;

    final now = DateTime.now();

    // 1. Extraer Tags (#tag)
    final tagRegex = RegExp(r'#([a-zA-Z0-9_\-]+)');
    final tagMatches = tagRegex.allMatches(working);
    for (final m in tagMatches) {
      final tag = m.group(1);
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag.toLowerCase());
      }
    }
    working = working.replaceAll(tagRegex, ' ');

    // 2. Extraer Prioridad (!p1, !urgente, !alta, etc.)
    final priorityRegex = RegExp(r'!(p1|p2|p3|p4|urgente|alta|media|baja|urgent|high|medium|low)\b', caseSensitive: false);
    final prioMatch = priorityRegex.firstMatch(working);
    if (prioMatch != null) {
      matchedPriorityText = prioMatch.group(0);
      final pVal = prioMatch.group(1)?.toLowerCase();
      priority = ReminderPriority.fromString(pVal);
      working = working.replaceFirst(priorityRegex, ' ');
    }

    // 3. Extraer Recurrencia (semanal, quincenal, mensual, diario)
    final recurrenceRegex = RegExp(
      r'\b(quincenalmente|cada\s+quincena|cada\s+15\s+d[ií]as|quincenal|biweekly|semanalmente|cada\s+semana|semanal|weekly|mensualmente|cada\s+mes|mensual|monthly|diariamente|cada\s+d[ií]a|diario|daily|anualmente|cada\s+a[ñn]o|anual|yearly)\b',
      caseSensitive: false,
    );
    final recMatch = recurrenceRegex.firstMatch(working);
    if (recMatch != null) {
      final matchStr = recMatch.group(1)!.toLowerCase();
      if (matchStr.contains('quince') || matchStr.contains('15') || matchStr.contains('biweekly')) {
        recurrence = ReminderRecurrence.biweekly;
        matchedRecurrenceText = 'Quincenal';
      } else if (matchStr.contains('seman') || matchStr.contains('weekly')) {
        recurrence = ReminderRecurrence.weekly;
        matchedRecurrenceText = 'Semanal';
      } else if (matchStr.contains('mensua') || matchStr.contains('mes') || matchStr.contains('monthly')) {
        recurrence = ReminderRecurrence.monthly;
        matchedRecurrenceText = 'Mensual';
      } else if (matchStr.contains('diar') || matchStr.contains('dia') || matchStr.contains('día') || matchStr.contains('daily')) {
        recurrence = ReminderRecurrence.daily;
        matchedRecurrenceText = 'Diario';
      } else if (matchStr.contains('anua') || matchStr.contains('ano') || matchStr.contains('año') || matchStr.contains('yearly')) {
        recurrence = ReminderRecurrence.yearly;
        matchedRecurrenceText = 'Anual';
      }
      working = working.replaceFirst(recurrenceRegex, ' ');
    }

    if (recurrence == ReminderRecurrence.none) {
      if (tags.contains('semanal')) {
        recurrence = ReminderRecurrence.weekly;
        matchedRecurrenceText = 'Semanal';
      } else if (tags.contains('quincenal')) {
        recurrence = ReminderRecurrence.biweekly;
        matchedRecurrenceText = 'Quincenal';
      } else if (tags.contains('mensual')) {
        recurrence = ReminderRecurrence.monthly;
        matchedRecurrenceText = 'Mensual';
      } else if (tags.contains('diario')) {
        recurrence = ReminderRecurrence.daily;
        matchedRecurrenceText = 'Diario';
      }
    }

    // 3. Extraer Duraciones Relativas inmediatas ("en 15 minutos", "en 2 horas", "en 3 dias")
    final relativeOffsetRegex = RegExp(
      r'\ben\s+(\d+)\s*(minutos?|mins?|m|horas?|hrs?|h|d[ií]as?|d)\b',
      caseSensitive: false,
    );
    final offsetMatch = relativeOffsetRegex.firstMatch(working);
    if (offsetMatch != null) {
      final amount = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
      final unit = offsetMatch.group(2)!.toLowerCase();
      matchedDateText = offsetMatch.group(0);

      if (unit.startsWith('m') && !unit.startsWith('mes')) {
        resolvedDate = now.add(Duration(minutes: amount));
      } else if (unit.startsWith('h')) {
        resolvedDate = now.add(Duration(hours: amount));
      } else if (unit.startsWith('d')) {
        resolvedDate = now.add(Duration(days: amount));
      }

      working = working.replaceFirst(relativeOffsetRegex, ' ');
    }

    // 4. Si no se resolvió con offset relativo, buscar combinaciones de Fecha y Hora
    if (resolvedDate == null) {
      DateTime baseDate = DateTime(now.year, now.month, now.day);
      bool dateFound = false;

      // A. Fechas relativas
      final todayRegex = RegExp(r'\b(hoy|today)\b', caseSensitive: false);
      final tomorrowRegex = RegExp(r'\b(mañana|manana|tomorrow)\b', caseSensitive: false);
      final dayAfterTomorrowRegex = RegExp(r'\b(pasado\s+mañana|pasado\s+manana)\b', caseSensitive: false);

      if (dayAfterTomorrowRegex.hasMatch(working)) {
        baseDate = baseDate.add(const Duration(days: 2));
        matchedDateText = 'Pasado mañana';
        dateFound = true;
        working = working.replaceFirst(dayAfterTomorrowRegex, ' ');
      } else if (tomorrowRegex.hasMatch(working)) {
        baseDate = baseDate.add(const Duration(days: 1));
        matchedDateText = 'Mañana';
        dateFound = true;
        working = working.replaceFirst(tomorrowRegex, ' ');
      } else if (todayRegex.hasMatch(working)) {
        dateFound = true;
        matchedDateText = 'Hoy';
        working = working.replaceFirst(todayRegex, ' ');
      }

      // B. Días de la semana ("el lunes", "el viernes")
      final weekdayRegex = RegExp(
        r'\b(?:el\s+)?(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b',
        caseSensitive: false,
      );
      final weekdayMatch = weekdayRegex.firstMatch(working);
      if (!dateFound && weekdayMatch != null) {
        final dayName = weekdayMatch.group(1)!.toLowerCase();
        int targetWeekday = 1;
        if (dayName.startsWith('lun')) targetWeekday = DateTime.monday;
        if (dayName.startsWith('mar')) targetWeekday = DateTime.tuesday;
        if (dayName.startsWith('mi')) targetWeekday = DateTime.wednesday;
        if (dayName.startsWith('jue')) targetWeekday = DateTime.thursday;
        if (dayName.startsWith('vie')) targetWeekday = DateTime.friday;
        if (dayName.startsWith('s')) targetWeekday = DateTime.saturday;
        if (dayName.startsWith('dom')) targetWeekday = DateTime.sunday;

        int daysToAdd = (targetWeekday - now.weekday) % 7;
        if (daysToAdd <= 0) daysToAdd += 7; // Próxima ocurrencia
        baseDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
        dateFound = true;
        matchedDateText = 'El ${dayName[0].toUpperCase()}${dayName.substring(1)}';
        working = working.replaceFirst(weekdayRegex, ' ');
      }

      // C. Extracción de Horas ("a las 3pm", "15:30", "a las 9:00", "en la noche")
      int hour = 9; // Hora predeterminada 9:00 AM
      int minute = 0;
      bool timeFound = false;

      // C1. Modificadores de momento del día
      final nightRegex = RegExp(r'\b(esta\s+noche|en\s+la\s+noche|por\s+la\s+noche|tonight)\b', caseSensitive: false);
      final afternoonRegex = RegExp(r'\b(en\s+la\s+tarde|por\s+la\s+tarde)\b', caseSensitive: false);
      final morningRegex = RegExp(r'\b(en\s+la\s+mañana|por\s+la\s+mañana)\b', caseSensitive: false);
      final noonRegex = RegExp(r'\b(al?\s+mediod[ií]a|noon)\b', caseSensitive: false);

      if (nightRegex.hasMatch(working)) {
        hour = 20;
        minute = 0;
        timeFound = true;
        working = working.replaceFirst(nightRegex, ' ');
      } else if (afternoonRegex.hasMatch(working)) {
        hour = 15;
        minute = 0;
        timeFound = true;
        working = working.replaceFirst(afternoonRegex, ' ');
      } else if (morningRegex.hasMatch(working)) {
        hour = 9;
        minute = 0;
        timeFound = true;
        working = working.replaceFirst(morningRegex, ' ');
      } else if (noonRegex.hasMatch(working)) {
        hour = 12;
        minute = 0;
        timeFound = true;
        working = working.replaceFirst(noonRegex, ' ');
      }

      // C2. Horas numéricas explícitas: "a las 3pm", "a las 15:30", "10:30am", "4pm"
      final timeRegex = RegExp(
        r'\b(?:a\s+las?\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
        caseSensitive: false,
      );

      final timeMatches = timeRegex.allMatches(working);
      for (final tm in timeMatches) {
        final hStr = tm.group(1);
        final mStr = tm.group(2);
        final meridian = tm.group(3)?.toLowerCase();

        if (hStr != null) {
          int parsedH = int.tryParse(hStr) ?? hour;
          int parsedM = mStr != null ? (int.tryParse(mStr) ?? 0) : 0;

          if (meridian == 'pm' && parsedH < 12) parsedH += 12;
          if (meridian == 'am' && parsedH == 12) parsedH = 0;

          if (parsedH >= 0 && parsedH <= 23 && parsedM >= 0 && parsedM <= 59) {
            // Solo considerar si es hora válida o si vino precedido por "a las" o meridian
            final full = tm.group(0)!.toLowerCase();
            if (full.contains('a las') || full.contains('a la') || meridian != null || mStr != null) {
              hour = parsedH;
              minute = parsedM;
              timeFound = true;
              working = working.replaceFirst(tm.group(0)!, ' ');
              break;
            }
          }
        }
      }

      if (dateFound || timeFound) {
        resolvedDate = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);

        // Si fue para "hoy" pero la hora ya pasó, posponer para mañana a esa misma hora
        if (!dateFound && timeFound && resolvedDate.isBefore(now)) {
          resolvedDate = resolvedDate.add(const Duration(days: 1));
          matchedDateText = 'Mañana';
        }
      }
    }

    // 5. Limpieza de Título final
    String clean = working
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\s*[-–—:]\s*'), '')
        .trim();

    // Si todo fue parseado y quedó vacío, mantener un título descriptivo
    if (clean.isEmpty) {
      clean = input.trim();
    }

    return NlpParseResult(
      rawInput: input,
      cleanTitle: clean,
      dueAt: resolvedDate,
      priority: priority,
      recurrence: recurrence,
      tags: tags,
      matchedDateText: matchedDateText,
      matchedPriorityText: matchedPriorityText,
      matchedRecurrenceText: matchedRecurrenceText,
    );
  }
}
