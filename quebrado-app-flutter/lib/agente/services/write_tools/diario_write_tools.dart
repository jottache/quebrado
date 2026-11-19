/// Ejecutores de escritura del Diario: `registerDiarioEntry` y
/// `createContact` (spec 03, `docs/design/ortiz-registra.md` §2.2 y §3).
///
/// - Nunca crea contactos al registrar una entrada: un contacto inexistente
///   sale como tarjeta (`contact_not_found`) con hasta 3 parecidos más
///   «Sin contacto» (entrada personal).
/// - `createContact` no inventa la fecha de nacimiento: solo la guarda si
///   llega completa (`YYYY-MM-DD`).
library;

import 'package:uuid/uuid.dart';

import '../../../diario/models/diario_contact.dart';
import '../../../diario/models/diario_entry.dart';
import '../../../diario/models/diario_template.dart';
import '../../../diario/viewmodels/diario_state.dart';
import '../../../quebrado/widgets/helpers.dart' show formatDate;
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'ortiz_resolver.dart';
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

/// Motivos (`reasons`) propios del Diario.
abstract final class DiarioWriteReason {
  static const contactNotFound = 'contact_not_found';
  static const duplicateName = 'duplicate_name';

  /// S3-02: el contacto no salió de lo que escribió la persona.
  static const nameNotInUserText = 'name_not_in_user_text';
}

class DiarioWriteTools implements WriteToolHandler {
  final DiarioState _diario;
  final Uuid _uuid;

  DiarioWriteTools(this._diario, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Opción de la tarjeta `contact_not_found` que guarda la entrada como
  /// personal. Solo se acepta con la tarjeta confirmada.
  static const String noContactOption = 'Sin contacto';

  /// Título del resumen cuando la entrada no tiene título (se recorta).
  static const int _excerptLength = 60;

  @override
  Set<String> get toolNames => const {
        WriteToolNames.registerDiarioEntry,
        WriteToolNames.createContact,
      };

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    switch (toolName) {
      case WriteToolNames.registerDiarioEntry:
        return _registerEntry(args, ctx);
      case WriteToolNames.createContact:
        return _createContact(args, ctx);
      default:
        return WriteOutcome(WriteToolResult.error(
          action: toolName,
          message: 'No pude registrarlo: el Diario no conoce la acción «$toolName». No se guardó nada.',
        ));
    }
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    switch (toolName) {
      case WriteToolNames.registerDiarioEntry:
        final id = undoPayload['entryId'] as String?;
        if (id == null || id.isEmpty) {
          throw StateError('No sé qué entrada deshacer.');
        }
        await _diario.deleteEntry(id);
      case WriteToolNames.createContact:
        final id = undoPayload['contactId'] as String?;
        if (id == null || id.isEmpty) {
          throw StateError('No sé qué contacto deshacer.');
        }
        await _diario.deleteContact(id);
      default:
        throw StateError('El Diario no puede deshacer «$toolName».');
    }
  }

  // ---------------------------------------------------------------------------
  // registerDiarioEntry
  // ---------------------------------------------------------------------------

  Future<WriteOutcome> _registerEntry(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.registerDiarioEntry;
    final contentText = _str(args, 'contentText');
    final title = _str(args, 'title') ?? '';
    final contactName = _str(args, 'contactName');
    final templateName = _str(args, 'templateName');

    final missing = <String>[];
    final options = <String, List<String>>{};
    final resolved = <String, dynamic>{};
    final reasons = <String>[...ctx.forcedProposalReasons];

    if (contentText == null) missing.add('contentText');

    final date = resolveDate(_str(args, 'date'), now: ctx.now);
    if (date.isInvalid) {
      missing.add('date');
    } else {
      resolved['date'] = _isoDate(date.date!);
    }

    DiarioTemplate? template;
    if (templateName != null) {
      final res = resolveByName(templateName, [
        for (final t in _diario.templates) ResolverItem(id: t.id, name: t.name),
      ]);
      if (res.isResolved) {
        template = _diario.templates.firstWhere((t) => t.id == res.value!.id);
        resolved['templateName'] = template.name;
      } else {
        missing.add('templateName');
        options['templateName'] = res.options;
      }
    }

    DiarioContact? contact;
    var contactNotFound = false;
    final wantsPersonal = contactName == null ||
        (ctx.confirmedByUser && norm(contactName) == norm(noContactOption));
    if (!wantsPersonal) {
      final res = _resolveContact(contactName);
      switch (res.status) {
        case ResolutionStatus.resolved:
          contact = _diario.contacts.firstWhere((c) => c.id == res.value!.id);
          resolved['contactName'] = contact.name;
          // S3-02: solo directo si la persona nombró al contacto (nombre o
          // apodo resueltos; nunca el término del modelo, S3-09).
          final names = [contact.name, contact.nickname];
          if (!ctx.confirmedByUser &&
              !names.any((n) =>
                  ctx.termInUserText(n) || nameWordInText(n, ctx.userText))) {
            reasons.add(DiarioWriteReason.nameNotInUserText);
          }
        case ResolutionStatus.missing:
        case ResolutionStatus.proposal:
          missing.add('contactName');
          options['contactName'] = res.options;
        case ResolutionStatus.notFound:
          final similar = [
            ...mostSimilar(contactName, _contactItems()).map((c) => c.name),
            noContactOption,
          ];
          options['contactName'] = similar;
          resolved['requestedContactName'] = contactName;
          if (ctx.confirmedByUser) {
            // Confirmó la tarjeta sin elegir a nadie: hay que elegir.
            missing.add('contactName');
          } else {
            contactNotFound = true;
            reasons.add(DiarioWriteReason.contactNotFound);
          }
      }
    }

    if (missing.isNotEmpty) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
        options: options,
      ));
    }

    final day = date.date!;
    final summaryTitle = title.isNotEmpty ? title : _excerpt(contentText!);
    final parts = [
      SummaryPart(contact?.name ?? (contactNotFound ? contactName! : 'Personal')),
      SummaryPart(_dayLabel(day, ctx.now())),
    ];

    if (reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: _joinSummary(summaryTitle, parts),
          resolved: resolved,
          options: options,
        ),
        summaryTitle: summaryTitle,
        summaryParts: parts,
        // S3-07: solo los campos que usa `execute`, nunca `args` crudo.
        commitArgs: {
          'contentText': contentText,
          if (title.isNotEmpty) 'title': title,
          'contactName': ?(contact?.name ?? contactName),
          if (template != null) 'templateName': template.name,
          'date': _isoDate(day),
        },
      );
    }

    final createdAt = date.usedToday ? ctx.now() : _atTimeOf(day, ctx.now());
    final String entryId;
    try {
      if (contact != null) {
        final categoryId =
            _diario.getRootCategories(contact.id).firstOrNull?.id;
        if (categoryId == null) {
          return _saveError(action, 'el Diario no tiene categorías para ${contact.name}');
        }
        final reservedId = _diario.newEntryId();
        try {
          final DiarioEntry entry = await _diario.addEntry(
            id: reservedId,
            contactId: contact.id,
            categoryId: categoryId,
            templateId: template?.id,
            entryType: template != null ? 'template_instance' : 'simple_text',
            title: title,
            contentText: contentText,
            createdAt: createdAt,
          );
          entryId = entry.id;
        } catch (_) {
          await _quietly(() => _diario.deleteEntry(reservedId));
          rethrow;
        }
      } else {
        final entry = await _diario.addPersonalEntry(
          title: title,
          contentText: contentText,
          templateId: template?.id,
          entryType: template != null ? 'template_instance' : 'simple_text',
          createdAt: createdAt,
        );
        entryId = entry.id;
      }
    } catch (_) {
      return _saveError(action, 'falló el guardado en el Diario');
    }

    final summaryParts = [
      SummaryPart(contact?.name ?? 'Personal'),
      SummaryPart(_dayLabel(day, ctx.now())),
    ];
    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: entryId,
        summary: _joinSummary(summaryTitle, summaryParts),
        route: SuiteRoutes.entrada(entryId),
        undoId: _uuid.v4(),
      ),
      summaryTitle: summaryTitle,
      summaryParts: summaryParts,
      undoPayload: {'entryId': entryId},
    );
  }

  /// Contacto por nombre o apodo (§3.5): exactas por nombre o apodo primero;
  /// si no hay, coincidencia parcial por nombre y luego por apodo.
  Resolution<ResolverItem> _resolveContact(String term) {
    final t = norm(term);
    final exactIds = <String>{
      for (final c in _diario.contacts)
        if (norm(c.name) == t || (c.nickname != null && norm(c.nickname!) == t))
          c.id,
    };
    final byName = _contactItems();
    if (exactIds.isNotEmpty) {
      return resolveByName(
        term,
        [
          for (final c in _diario.contacts)
            if (exactIds.contains(c.id)) ResolverItem(id: c.id, name: term, label: c.name),
        ],
      );
    }
    final res = resolveByName(term, byName);
    if (res.status != ResolutionStatus.notFound) return res;
    final byNickname = [
      for (final c in _diario.contacts)
        if (c.nickname != null && c.nickname!.trim().isNotEmpty)
          ResolverItem(id: c.id, name: c.nickname!, label: c.name),
    ];
    final nick = resolveByName(term, byNickname);
    if (nick.status != ResolutionStatus.notFound) return nick;
    return res;
  }

  List<ResolverItem> _contactItems() => [
        for (final c in _diario.contacts) ResolverItem(id: c.id, name: c.name),
      ];

  // ---------------------------------------------------------------------------
  // createContact
  // ---------------------------------------------------------------------------

  Future<WriteOutcome> _createContact(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.createContact;
    final name = _str(args, 'name');
    final nickname = _str(args, 'nickname');
    final relationship = _str(args, 'relationship');
    final phone = _str(args, 'phone');
    final notes = _str(args, 'notes');
    final birthdateRaw = _str(args, 'birthdate');

    final missing = <String>[];
    final resolved = <String, dynamic>{};
    if (name == null) {
      missing.add('name');
    } else {
      resolved['name'] = name;
    }

    DateTime? birthdate;
    if (birthdateRaw != null) {
      final res = resolveDate(birthdateRaw, now: ctx.now);
      if (res.isInvalid) {
        missing.add('birthdate');
      } else {
        birthdate = res.date;
        resolved['birthdate'] = _isoDate(birthdate!);
      }
    }

    if (missing.isNotEmpty) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: missing,
        resolved: resolved,
      ));
    }

    final reasons = <String>[...ctx.forcedProposalReasons];
    if (!ctx.confirmedByUser &&
        _diario.contacts.any((c) => norm(c.name) == norm(name!))) {
      reasons.add(DiarioWriteReason.duplicateName);
    }

    final summaryTitle = name!;
    final parts = [
      const SummaryPart('Contacto nuevo'),
      if (relationship != null) SummaryPart(relationship),
    ];

    if (reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: _joinSummary(summaryTitle, parts),
          resolved: resolved,
        ),
        summaryTitle: summaryTitle,
        summaryParts: parts,
        commitArgs: {
          'name': name,
          'nickname': ?nickname,
          'relationship': ?relationship,
          'phone': ?phone,
          if (birthdate != null) 'birthdate': _isoDate(birthdate),
          'notes': ?notes,
        },
      );
    }

    final DiarioContact contact;
    try {
      contact = await _diario.addContact(
        name: name,
        nickname: nickname,
        relationship: relationship,
        phone: phone,
        birthdate: birthdate,
        notes: notes,
      );
    } catch (_) {
      return _saveError(action, 'falló el guardado del contacto en el Diario');
    }

    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: contact.id,
        summary: _joinSummary(summaryTitle, parts),
        route: SuiteRoutes.contacto(contact.id),
        undoId: _uuid.v4(),
      ),
      summaryTitle: summaryTitle,
      summaryParts: parts,
      undoPayload: {'contactId': contact.id},
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  static String? _str(Map<String, dynamic> args, String key) {
    final value = args[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _excerpt(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= _excerptLength) return firstLine;
    return '${firstLine.substring(0, _excerptLength).trimRight()}…';
  }

  static WriteOutcome _saveError(String action, String reason) =>
      WriteOutcome(WriteToolResult.error(
        action: action,
        message: 'No pude registrarlo: $reason. No se guardó nada.',
      ));

  static Future<void> _quietly(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {}
  }
}

/// «hoy», «ayer» o dd/MM/yyyy (U2.1).
String _dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return 'hoy';
  if (d == DateTime(today.year, today.month, today.day - 1)) return 'ayer';
  return formatDate(d);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// La fecha [day] con la hora de [now] (para no fijar medianoche).
DateTime _atTimeOf(DateTime day, DateTime now) =>
    DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second);

String _joinSummary(String title, List<SummaryPart> parts) =>
    [title, ...parts.map((p) => p.text)].join(' · ');
