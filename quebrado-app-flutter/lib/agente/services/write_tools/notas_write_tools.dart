/// Ejecutor de `createNote` (spec 03, `docs/design/ortiz-registra.md` §2.2 y
/// U2.1): crea una nota o un acuerdo en Notas a través de [NotasState].
library;

import 'package:uuid/uuid.dart';

import '../../../notas/models/note_block.dart';
import '../../../notas/models/note_category.dart';
import '../../../notas/services/note_document_converter.dart';
import '../../../notas/viewmodels/notas_state.dart';
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'ortiz_resolver.dart';
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

class NotasWriteTools implements WriteToolHandler {
  final NotasState _notas;
  final Uuid _uuid = const Uuid();

  NotasWriteTools(this._notas);

  /// Categoría que se busca (por nombre normalizado) para `kind = acuerdo`.
  static const String agreementsCategoryName = 'Acuerdos';

  /// Largo máximo del título sacado de la primera línea del texto.
  static const int _maxDerivedTitle = 60;

  @override
  Set<String> get toolNames => const {WriteToolNames.createNote};

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.createNote;
    if (toolName != action) {
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: _errorText('no sé hacer «$toolName» en Notas'),
      ));
    }
    try {
      return await _createNote(args, ctx);
    } catch (_) {
      return WriteOutcome(WriteToolResult.error(
        action: action,
        message: _errorText('falló el guardado'),
      ));
    }
  }

  Future<WriteOutcome> _createNote(
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.createNote;
    final text = _string(args['text']);
    if (text == null) {
      return WriteOutcome(
        WriteToolResult.missing(action: action, missing: const ['text']),
      );
    }
    final title = _string(args['title']) ?? _titleFrom(text);
    final isAgreement = norm(_string(args['kind']) ?? '') == 'acuerdo';
    final requestedCategory = _string(args['categoryName']) ??
        (isAgreement ? agreementsCategoryName : null);

    if (_notas.categories.isEmpty) await _notas.loadAll();
    final categories = List<NoteCategory>.of(_notas.categories);

    final reasons = <String>[];
    final options = <String, List<String>>{};
    NoteCategory? category;
    if (requestedCategory == null) {
      category = _notas.defaultCategory;
    } else {
      final items = [
        for (final c in categories) ResolverItem(id: c.id, name: c.name),
      ];
      final res = resolveByName(requestedCategory, items);
      if (res.isResolved) {
        category = categories.firstWhere((c) => c.id == res.value!.id);
      } else {
        final ambiguous = res.status == ResolutionStatus.missing;
        final candidates = ambiguous
            ? res.candidates
            : mostSimilar(requestedCategory, items);
        options['categoryName'] = candidates.isNotEmpty
            ? [for (final c in candidates) c.displayName]
            : [for (final i in items) i.displayName];
        if (ctx.confirmedByUser) {
          return WriteOutcome(WriteToolResult.missing(
            action: action,
            missing: const ['categoryName'],
            options: options,
          ));
        }
        reasons.add(ambiguous
            ? ResolverReason.categoryAmbiguous
            : ResolverReason.categoryNotFound);
      }
    }
    reasons.addAll(ctx.forcedProposalReasons);

    final kindLabel = isAgreement ? 'Acuerdo' : 'Nota';
    final parts = <SummaryPart>[
      SummaryPart(kindLabel),
      if (category != null) SummaryPart(category.name),
    ];
    final resolved = <String, dynamic>{'categoryName': ?category?.name};

    if (!ctx.confirmedByUser && reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: _joinSummary(title, parts),
          resolved: resolved,
          options: options,
        ),
        summaryTitle: title,
        summaryParts: parts,
        commitArgs: {
          'text': text,
          'title': title,
          'kind': isAgreement ? 'acuerdo' : 'nota',
          'categoryName': category?.name ?? requestedCategory,
        },
      );
    }

    final blocks = [
      for (final line in text.split('\n'))
        NoteBlock(type: BlockType.paragraph, content: line.trimRight()),
    ];
    final note = await _notas.createNote(
      title: title,
      categoryId: category!.id,
      blocks: blocks,
      document: NoteDocumentConverter.toDocument(blocks).toJson(),
      contentText: text,
    );

    return WriteOutcome(
      WriteToolResult.saved(
        action: action,
        recordId: note.id,
        summary: _joinSummary(note.title, parts),
        route: SuiteRoutes.nota(note.id),
        undoId: _uuid.v4(),
      ),
      summaryTitle: note.title,
      summaryParts: parts,
      undoPayload: {'noteId': note.id},
    );
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    final noteId = undoPayload['noteId'];
    if (noteId is! String || noteId.isEmpty) {
      throw StateError('Falta la nota que deshacer.');
    }
    await _notas.deleteNote(noteId);
  }
}

String _errorText(String motivo) =>
    'No pude registrarlo: $motivo. No se guardó nada.';

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

/// Primera línea no vacía del texto, recortada a [_maxDerivedTitle].
String _titleFrom(String text) {
  final first = text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => text.trim());
  if (first.length <= NotasWriteTools._maxDerivedTitle) return first;
  return '${first.substring(0, NotasWriteTools._maxDerivedTitle).trimRight()}…';
}

String _joinSummary(String title, List<SummaryPart> parts) =>
    [title, ...parts.map((p) => p.text)].join(' · ');
