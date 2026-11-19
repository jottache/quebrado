/// Ejecutor de escritura de Hábitos: `markHabitDone` y `createHabit`
/// (spec 03, `docs/design/ortiz-registra.md` §2.2 y §3).
library;

import 'package:uuid/uuid.dart';

import '../../../diario/models/diario_contact.dart';
import '../../../diario/viewmodels/diario_state.dart';
import '../../../habitos/models/habit_model.dart';
import '../../../habitos/viewmodels/habitos_state.dart';
import '../../../quebrado/widgets/helpers.dart' show formatDate;
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'diario_write_tools.dart' show DiarioWriteTools;
import 'ortiz_resolver.dart';
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

/// Motivos de `proposal` propios de Hábitos (U2.4).
abstract final class HabitosWriteReason {
  static const futureDate = 'future_date';
  static const duplicateName = 'duplicate_name';

  /// S3-02: el hábito no salió de lo que escribió la persona.
  static const nameNotInUserText = 'name_not_in_user_text';

  /// S3-02: el contacto del hábito no salió de lo que escribió la persona.
  static const contactNotInUserText = 'contact_not_in_user_text';

  /// El contacto pedido no existe: la tarjeta deja elegir uno parecido o
  /// «Sin contacto» (igual que en el Diario).
  static const contactNotFound = 'contact_not_found';
}

class HabitosWriteTools implements WriteToolHandler {
  final HabitosState habitos;

  /// Contactos para vincular un hábito nuevo (`contactName`). Sin él, todo
  /// contacto pedido sale como tarjeta `contact_not_found` con la opción
  /// «Sin contacto».
  final DiarioState? diario;

  HabitosWriteTools(this.habitos, {this.diario});

  /// Color con el que la app ya crea los malos hábitos (semillas y tarjeta).
  static const String _negativeColorHex = '#FF3B30';

  /// Unidad por defecto de los contadores (la del editor de hábitos).
  static const String _defaultCounterUnit = 'veces';

  @override
  Set<String> get toolNames => const {
        WriteToolNames.markHabitDone,
        WriteToolNames.createHabit,
      };

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    switch (toolName) {
      case WriteToolNames.markHabitDone:
        return _markHabitDone(args, ctx);
      case WriteToolNames.createHabit:
        return _createHabit(args, ctx);
      default:
        return WriteOutcome(WriteToolResult.error(
          action: toolName,
          message: 'No pude registrarlo: la herramienta $toolName no es de Hábitos. No se guardó nada.',
        ));
    }
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    final habitId = undoPayload['habitId'];
    if (habitId is! String || habitId.isEmpty) {
      throw ArgumentError.value(undoPayload, 'undoPayload', 'Falta habitId');
    }
    switch (toolName) {
      case WriteToolNames.createHabit:
        await habitos.deleteHabit(habitId);
      case WriteToolNames.markHabitDone:
        final dateKey = undoPayload['dateKey'];
        if (dateKey is! String || dateKey.isEmpty) {
          throw ArgumentError.value(undoPayload, 'undoPayload', 'Falta dateKey');
        }
        if (!habitos.habits.any((h) => h.id == habitId)) {
          throw StateError('el hábito ya no existe');
        }
        await _revertMark(
          habitId,
          dateKey,
          counter: undoPayload['counter'] == true,
          previousValue: (undoPayload['previousValue'] as num?)?.toDouble() ?? 0,
        );
      default:
        throw ArgumentError.value(toolName, 'toolName', 'No es una herramienta de Hábitos');
    }
  }

  // ---------------------------------------------------------------------------
  // markHabitDone
  // ---------------------------------------------------------------------------

  Future<WriteOutcome> _markHabitDone(Map<String, dynamic> args, WriteContext ctx) async {
    const action = WriteToolNames.markHabitDone;
    final active = habitos.allHabits;
    if (active.isEmpty) {
      return _error(action, 'aún no tienes hábitos activos');
    }

    final missing = <String>[];
    final options = <String, List<String>>{};
    final resolved = <String, dynamic>{};

    HabitModel? habit;
    final habitId = _text(args['habitId']);
    if (habitId != null) {
      for (final h in active) {
        if (h.id == habitId) habit = h;
      }
    }
    if (habit == null) {
      final name = _text(args['habitName']) ?? '';
      final resolution = resolveByName(
        name,
        [for (final h in active) ResolverItem(id: h.id, name: h.title)],
      );
      switch (resolution.status) {
        case ResolutionStatus.resolved:
          habit = active.firstWhere((h) => h.id == resolution.value!.id);
        case ResolutionStatus.notFound:
          return _error(
            action,
            'no encontré el hábito «$name»; tus hábitos son: ${resolution.options.join(', ')}',
          );
        case ResolutionStatus.missing:
        case ResolutionStatus.proposal:
          missing.add('habit');
          options['habit'] = resolution.options;
      }
    }

    if (habit != null) {
      if (habit.isNegative || habit.type == HabitType.negative) {
        return _error(
          action,
          '«${habit.title}» es un hábito que quieres dejar y no se marca como hecho',
        );
      }
      resolved['habit'] = habit.title;
    }

    final date = resolveDate(_text(args['date']), now: ctx.now);
    if (date.isInvalid) {
      missing.add('date');
    } else {
      resolved['date'] = habitos.dateKeyOf(date.date!);
    }

    if (missing.isNotEmpty || habit == null) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
        options: options,
      ));
    }

    final day = date.date!;
    final dateKey = habitos.dateKeyOf(day);
    final dayLabel = _dayLabel(day, ctx.now());
    final isCounter = habit.type == HabitType.counter;
    final route = SuiteRoutes.habito(habit.id);

    if (!isCounter && habitos.isCompleted(habit.id, dateKey)) {
      final parts = [SummaryPart('Hecho $dayLabel')];
      return WriteOutcome(
        WriteToolResult.saved(
          action: action,
          recordId: habit.id,
          summary: 'Ya estaba marcado: ${_join(habit.title, parts)}',
          route: route,
        ),
        summaryTitle: habit.title,
        summaryParts: parts,
      );
    }

    final previousValue = habitos.getValue(habit.id, dateKey);
    final unit = _unitOf(habit);
    List<SummaryPart> partsFor(double counterValue) => [
          if (isCounter)
            SummaryPart('${_formatCount(counterValue)} $unit $dayLabel')
          else
            SummaryPart('Hecho $dayLabel'),
        ];

    // S3-02: solo directo si la persona nombró el hábito: el nombre
    // resuelto, completo, por palabra de 4+ letras o conjugado («Leer» en
    // «ya leí»: ver [nameWordInText]). Nunca el término del modelo (S3-09):
    // «Alquiler hola» resolvería a «Alquiler» y anclaría con «hola».
    final named = ctx.termInUserText(habit.title) ||
        nameWordInText(habit.title, ctx.userText, verbForms: true);
    final reasons = [
      if (date.isFuture && !ctx.confirmedByUser) HabitosWriteReason.futureDate,
      if (!named && !ctx.confirmedByUser) HabitosWriteReason.nameNotInUserText,
      ...ctx.forcedProposalReasons,
    ];
    if (reasons.isNotEmpty) {
      final parts = partsFor(previousValue + 1);
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: _join(habit.title, parts),
          resolved: resolved,
        ),
        summaryTitle: habit.title,
        summaryParts: parts,
        commitArgs: {'habitId': habit.id, 'habitName': habit.title, 'date': dateKey},
      );
    }

    try {
      await habitos.toggleHabitCompletion(habit.id, dateKey: dateKey);
    } catch (_) {
      try {
        if (isCounter
            ? habitos.getValue(habit.id, dateKey) > previousValue
            : habitos.isCompleted(habit.id, dateKey)) {
          await _revertMark(habit.id, dateKey, counter: isCounter, previousValue: previousValue);
        }
      } catch (_) {}
      return _error(action, 'falló el guardado del hábito');
    }

    final parts = partsFor(habitos.getValue(habit.id, dateKey));
    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: habit.id,
        summary: _join(habit.title, parts),
        route: route,
      ),
      summaryTitle: habit.title,
      summaryParts: parts,
      undoPayload: {
        'habitId': habit.id,
        'dateKey': dateKey,
        'counter': isCounter,
        'previousValue': previousValue,
      },
    );
  }

  /// Deshace un «hecho» de Ortiz solo si sigue como lo dejó: en un contador
  /// resta 1; en el resto vuelve a alternar (si sigue hecho) y recupera el
  /// valor parcial que hubiera antes.
  Future<void> _revertMark(
    String habitId,
    String dateKey, {
    required bool counter,
    required double previousValue,
  }) async {
    if (counter) {
      if (habitos.getValue(habitId, dateKey) > 0) {
        await habitos.incrementCounter(habitId, delta: -1, dateStr: dateKey);
      }
      return;
    }
    if (!habitos.isCompleted(habitId, dateKey)) return;
    await habitos.toggleHabitCompletion(habitId, dateKey: dateKey);
    if (previousValue > 0) {
      await habitos.updateHabitValue(habitId, previousValue, dateKey);
    }
  }

  // ---------------------------------------------------------------------------
  // createHabit
  // ---------------------------------------------------------------------------

  Future<WriteOutcome> _createHabit(Map<String, dynamic> args, WriteContext ctx) async {
    const action = WriteToolNames.createHabit;
    final title = _text(args['title']);
    final isNegative = _bool(args['isNegative']);
    final kind = isNegative ? null : _habitKind(_text(args['habitType']));
    final type = isNegative ? HabitType.negative : (kind?.type ?? HabitType.binary);
    final target = _number(args['target']);
    final unit = _text(args['unit']) ??
        (type == HabitType.timer ? 'min' : null);
    final contactName = _text(args['contactName']);

    final missing = <String>[];
    final options = <String, List<String>>{};
    final resolved = <String, dynamic>{'isNegative': isNegative};
    if (title == null) missing.add('title');
    if (kind != null) resolved['habitType'] = kind.code;
    // Cantidad y tiempo necesitan una meta: no se inventa (como los montos).
    final needsTarget = type == HabitType.quantitative || type == HabitType.timer;
    if (needsTarget) {
      if (target == null || target <= 0) {
        missing.add('target');
      } else {
        resolved['target'] = target;
      }
    }
    if (unit != null && type != HabitType.binary && type != HabitType.negative) {
      resolved['unit'] = unit;
    }

    DiarioContact? contact;
    final reasons = <String>[];
    // «Sin contacto» (de la tarjeta o dicho por la persona) = sin vincular.
    final wantsContact = contactName != null &&
        norm(contactName) != norm(DiarioWriteTools.noContactOption);
    var contactNotFound = false;
    if (wantsContact) {
      final contacts = diario?.contacts ?? const <DiarioContact>[];
      final res = DiarioWriteTools.resolveContact(contactName, contacts);
      switch (res.status) {
        case ResolutionStatus.resolved:
          contact = contacts.firstWhere((c) => c.id == res.value!.id);
          resolved['contactName'] = contact.name;
          // S3-02: solo directo si la persona nombró al contacto.
          final names = [contact.name, contact.nickname];
          if (!ctx.confirmedByUser &&
              !names.any((n) => ctx.termInUserText(n) || nameWordInText(n, ctx.userText))) {
            reasons.add(HabitosWriteReason.contactNotInUserText);
          }
        case ResolutionStatus.missing:
        case ResolutionStatus.proposal:
          missing.add('contactName');
          options['contactName'] = res.options;
        case ResolutionStatus.notFound:
          // Como en el Diario: tarjeta con los parecidos y «Sin contacto»
          // (un `missing` aquí volvería al modelo y podría repetirse).
          options['contactName'] = [
            ...mostSimilar(contactName, DiarioWriteTools.contactItems(contacts)).map((c) => c.name),
            DiarioWriteTools.noContactOption,
          ];
          resolved['requestedContactName'] = contactName;
          if (ctx.confirmedByUser) {
            missing.add('contactName');
          } else {
            contactNotFound = true;
            reasons.add(HabitosWriteReason.contactNotFound);
          }
      }
    }

    if (missing.isNotEmpty || title == null) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: {...resolved, 'title': ?title},
        options: options,
      ));
    }

    final parts = [
      SummaryPart(isNegative ? 'Hábito por dejar' : 'Hábito por construir'),
      if (kind != null && kind != _HabitKind.check) SummaryPart(_kindLabel(type, target, unit)),
      if (contact != null) SummaryPart(contact.name),
      if (contactNotFound) SummaryPart(contactName!),
    ];
    final summary = _join(title, parts);
    final isDuplicate = habitos.allHabits.any((h) => norm(h.title) == norm(title));
    reasons.insertAll(0, [
      if (isDuplicate && !ctx.confirmedByUser) HabitosWriteReason.duplicateName,
    ]);
    reasons.addAll(ctx.forcedProposalReasons);
    resolved['title'] = title;
    if (reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: summary,
          resolved: resolved,
          options: options,
        ),
        summaryTitle: title,
        summaryParts: parts,
        // S3-07: solo los campos que usa `execute`, nunca `args` crudo.
        commitArgs: {
          'title': title,
          'isNegative': isNegative,
          if (kind != null && kind != _HabitKind.check) 'habitType': kind.code,
          if (resolved.containsKey('target')) 'target': target,
          if (resolved.containsKey('unit')) 'unit': unit,
          if (contact != null) 'contactName': contact.name,
          if (contactNotFound) 'contactName': contactName,
        },
      );
    }

    final id = const Uuid().v4();
    try {
      if (isNegative) {
        await habitos.addHabit(
          id: id,
          title: title,
          isNegative: true,
          type: HabitType.negative,
          colorHex: _negativeColorHex,
          contactId: contact?.id,
        );
      } else {
        await habitos.addHabit(
          id: id,
          title: title,
          type: type,
          targetValue: needsTarget ? target! : 1.0,
          unit: resolved['unit'] as String?,
          contactId: contact?.id,
        );
      }
    } catch (_) {
      try {
        if (habitos.habits.any((h) => h.id == id)) await habitos.deleteHabit(id);
      } catch (_) {}
      return _error(action, 'falló el guardado del hábito');
    }

    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: id,
        summary: summary,
        route: SuiteRoutes.habito(id),
      ),
      summaryTitle: title,
      summaryParts: parts,
      undoPayload: {'habitId': id},
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  WriteOutcome _error(String action, String reason) => WriteOutcome(
        WriteToolResult.error(
          action: action,
          message: 'No pude registrarlo: $reason. No se guardó nada.',
        ),
      );

  static String _join(String title, List<SummaryPart> parts) =>
      [title, ...parts.map((p) => p.text)].join(' · ');

  static String _unitOf(HabitModel habit) {
    final unit = habit.unit?.trim();
    return (unit == null || unit.isEmpty) ? _defaultCounterUnit : unit;
  }

  static String _formatCount(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  /// «hoy», «ayer» o dd/MM/yyyy (U2.1).
  static String _dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    if (target == today) return 'hoy';
    if (target == DateTime(today.year, today.month, today.day - 1)) return 'ayer';
    return formatDate(target);
  }
}

/// Tipo de hábito que puede pedir Ortiz (`habitType` de `createHabit`).
enum _HabitKind {
  check('check', HabitType.binary),
  counter('counter', HabitType.counter),
  quantity('quantity', HabitType.quantitative),
  timer('timer', HabitType.timer);

  const _HabitKind(this.code, this.type);
  final String code;
  final HabitType type;
}

_HabitKind? _habitKind(String? code) {
  if (code == null) return null;
  final c = code.trim().toLowerCase();
  for (final k in _HabitKind.values) {
    if (k.code == c) return k;
  }
  return null;
}

/// «Contador», «Meta: 20 páginas» o «Meta: 15 min».
String _kindLabel(HabitType type, double? target, String? unit) {
  switch (type) {
    case HabitType.counter:
      return 'Contador';
    case HabitType.quantitative:
    case HabitType.timer:
      final n = target == null
          ? ''
          : (target == target.roundToDouble() ? target.toInt().toString() : target.toString());
      return ['Meta:', n, ?unit].where((s) => s.isNotEmpty).join(' ');
    case HabitType.binary:
    case HabitType.negative:
      return 'Check';
  }
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim().replaceAll(',', '.'));
  return null;
}

String? _text(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return false;
}
