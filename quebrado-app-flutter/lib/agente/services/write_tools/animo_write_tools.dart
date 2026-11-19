/// Ejecutor de escritura de Ánimo: `logMood` (spec 03,
/// `docs/design/ortiz-registra.md` §2.2 y §5).
library;

import '../../../diario/models/mood_catalog.dart';
import '../../../diario/models/mood_log.dart';
import '../../../diario/viewmodels/animo_state.dart';
import '../../../widgets/suite_router.dart' show SuiteRoutes;
import 'ortiz_resolver.dart';
import 'write_tool_contract.dart';
import 'write_tool_result.dart';
import 'write_tool_specs.dart';

/// Registra el balance de ánimo de hoy (`kind: daily`, `source: agent`).
///
/// `AnimoState.addLog` con `daily` sobrescribe el balance del día si ya
/// había uno: la copia previa va en el `undoPayload` para que Deshacer la
/// restaure; si no había, Deshacer borra el registro.
class AnimoWriteTools implements WriteToolHandler {
  final AnimoState animo;

  AnimoWriteTools(this.animo);

  static const String _title = 'Ánimo de hoy';

  @override
  Set<String> get toolNames => const {WriteToolNames.logMood};

  /// Valencia (−2…2) del nivel `muy_mal`…`excelente`, o `null` si no es
  /// uno de los 5 niveles.
  static int? valenceForLevel(String? level) {
    if (level == null) return null;
    final key = norm(level).replaceAll(' ', '_');
    final index = moodLevels.indexOf(key);
    return index == -1 ? null : index + MoodCatalog.minValence;
  }

  @override
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  ) async {
    const action = WriteToolNames.logMood;
    if (toolName != action) {
      return WriteOutcome(WriteToolResult.error(
        action: toolName,
        message: 'No pude registrarlo: la herramienta $toolName no es de Ánimo. No se guardó nada.',
      ));
    }

    final note = _text(args['note']);
    final valence = valenceForLevel(_text(args['level']));
    if (valence == null) {
      return WriteOutcome(WriteToolResult.missing(
        action: action,
        missing: const ['level'],
        resolved: {'note': ?note},
        options: const {'level': moodLevels},
      ));
    }

    final level = moodLevels[valence - MoodCatalog.minValence];
    final today = ctx.now();
    final previous = animo.dailyLogFor(today);
    final parts = <SummaryPart>[
      SummaryPart(MoodCatalog.valenceMeta(valence).label),
      const SummaryPart('balance del día'),
      if (previous != null) const SummaryPart('reemplaza el de hoy'),
    ];
    final summary = _joinSummary(parts);

    final reasons = ctx.forcedProposalReasons;
    if (reasons.isNotEmpty) {
      return WriteOutcome(
        WriteToolResult.proposal(
          action: action,
          reasons: reasons,
          summary: summary,
          resolved: {'level': level, 'note': ?note},
        ),
        summaryTitle: _title,
        summaryParts: parts,
        commitArgs: {'level': level, 'note': ?note},
      );
    }

    try {
      final saved = await animo.addLog(
        valence: valence,
        kind: MoodKind.daily,
        note: note,
        source: MoodSource.agent,
        loggedAt: today,
      );
      return WriteOutcome(
        WriteToolResult.saved(
          action: action,
          recordId: saved.id,
          summary: summary,
          route: SuiteRoutes.animo,
        ),
        summaryTitle: _title,
        summaryParts: parts,
        undoPayload: {
          'logId': saved.id,
          if (previous != null) 'previous': previous.toSupabaseMap(),
        },
      );
    } catch (_) {
      return WriteOutcome(WriteToolResult.error(
        action: action,
        message: 'No pude registrarlo: falló el guardado del ánimo. No se guardó nada.',
      ));
    }
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    final previous = undoPayload['previous'];
    if (previous is Map) {
      await animo.updateLog(MoodLog.fromMap(Map<String, dynamic>.from(previous)));
      return;
    }
    final logId = undoPayload['logId'];
    if (logId is! String || logId.isEmpty) {
      throw ArgumentError.value(undoPayload, 'undoPayload', 'Falta logId');
    }
    await animo.deleteLog(logId);
  }

  String _joinSummary(List<SummaryPart> parts) =>
      [_title, ...parts.map((p) => p.text)].join(' · ');
}

String? _text(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}
