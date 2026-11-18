import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/animo_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';

/// Servicio sin red: guarda en memoria lo que recibe.
class _FakeAnimoService extends AnimoSupabaseService {
  _FakeAnimoService() : super.forTesting();

  final Map<String, MoodLog> remote = {};

  @override
  bool get isReady => true;

  @override
  Future<List<MoodLog>> getLogs({DateTime? since}) async => remote.values.toList();

  @override
  Future<void> saveLog(MoodLog log) async => remote[log.id] = log;

  @override
  Future<void> deleteLog(String id) async => remote.remove(id);
}

/// Cola pendiente en memoria (sin SQLite).
class _MemoryPendingStore implements MoodPendingStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _ThrowingAnimoState extends AnimoState {
  _ThrowingAnimoState({super.service, super.pendingStore, super.clock});

  @override
  Future<MoodLog> addLog({
    required int valence,
    String? contactId,
    MoodPerspective? perspective,
    MoodKind kind = MoodKind.momentary,
    int? energy,
    List<String> emotions = const [],
    List<String> tagIds = const [],
    List<String> roleIds = const [],
    List<String> mentionedContactIds = const [],
    String? note,
    String? diarioEntryId,
    MoodSource source = MoodSource.manual,
    DateTime? loggedAt,
  }) =>
      throw StateError('fallo inventado');
}

void main() {
  final now = DateTime(2026, 11, 18, 9, 30);
  late _FakeAnimoService service;
  late AnimoState animo;
  late AnimoWriteTools tools;

  WriteContext ctx({bool untrusted = false, bool confirmed = false}) => WriteContext(
        userText: 'hoy me siento bien',
        untrustedRead: untrusted,
        confirmedByUser: confirmed,
        now: () => now,
      );

  setUp(() {
    service = _FakeAnimoService();
    animo = AnimoState(service: service, pendingStore: _MemoryPendingStore(), clock: () => now);
    tools = AnimoWriteTools(animo);
  });

  test('atiende solo logMood', () {
    expect(tools.toolNames, {WriteToolNames.logMood});
  });

  test('traduce los 5 niveles a la valencia −2…2', () {
    expect(
      [for (final l in moodLevels) AnimoWriteTools.valenceForLevel(l)],
      [-2, -1, 0, 1, 2],
    );
    expect(AnimoWriteTools.valenceForLevel(' Muy mal '), -2);
    expect(AnimoWriteTools.valenceForLevel('raro'), isNull);
    expect(AnimoWriteTools.valenceForLevel(null), isNull);
  });

  test('CA-07: «bien» guarda el balance de hoy con valencia 1 y source agent', () async {
    final out = await tools.execute(WriteToolNames.logMood, {'level': 'bien', 'note': 'Día tranquilo'}, ctx());

    expect(out.result.isSaved, isTrue);
    final log = animo.dailyLogFor(now)!;
    expect(log.valence, 1);
    expect(log.kind, MoodKind.daily);
    expect(log.source, MoodSource.agent);
    expect(log.note, 'Día tranquilo');
    expect(log.logDateKey, '2026-11-18');
    expect(service.remote.containsKey(log.id), isTrue);

    expect(out.result.recordId, log.id);
    expect(out.result.route, '/diario/animo');
    expect(out.summaryTitle, 'Ánimo de hoy');
    expect(out.summaryParts.map((p) => p.text), ['Bien', 'balance del día']);
    expect(out.result.summary, 'Ánimo de hoy · Bien · balance del día');
    expect(out.undoPayload, {'logId': log.id});
  });

  test('nivel ausente o desconocido pide el nivel con las 5 opciones', () async {
    for (final args in [
      <String, dynamic>{},
      <String, dynamic>{'level': 'raro', 'note': 'me siento raro'},
    ]) {
      final out = await tools.execute(WriteToolNames.logMood, args, ctx());
      expect(out.result.isMissing, isTrue);
      expect(out.result.missing, ['level']);
      expect(out.result.options['level'], moodLevels);
      expect(out.undoPayload, isNull);
    }
    expect(animo.logs, isEmpty);
  });

  test('deshacer sin balance previo borra el registro', () async {
    final out = await tools.execute(WriteToolNames.logMood, {'level': 'mal'}, ctx());
    expect(animo.logs, hasLength(1));

    await tools.undo(WriteToolNames.logMood, out.undoPayload!);

    expect(animo.logs, isEmpty);
    expect(service.remote, isEmpty);
  });

  test('reemplaza el balance de hoy y deshacer restaura el anterior', () async {
    final previous = await animo.addLog(
      valence: -1,
      kind: MoodKind.daily,
      note: 'Nota previa',
      loggedAt: DateTime(2026, 11, 18, 8),
    );

    final out = await tools.execute(WriteToolNames.logMood, {'level': 'excelente'}, ctx());

    expect(out.result.isSaved, isTrue);
    expect(out.summaryParts.map((p) => p.text), ['Excelente', 'balance del día', 'reemplaza el de hoy']);
    expect(animo.logs, hasLength(1));
    expect(animo.dailyLogFor(now)!.valence, 2);
    expect(animo.dailyLogFor(now)!.source, MoodSource.agent);

    await tools.undo(WriteToolNames.logMood, out.undoPayload!);

    final restored = animo.dailyLogFor(now)!;
    expect(animo.logs, hasLength(1));
    expect(restored.id, previous.id);
    expect(restored.valence, -1);
    expect(restored.note, 'Nota previa');
    expect(restored.source, MoodSource.manual);
    expect(service.remote[previous.id]!.valence, -1);
  });

  test('texto leído en el turno obliga a tarjeta y no guarda', () async {
    final out = await tools.execute(WriteToolNames.logMood, {'level': 'bien'}, ctx(untrusted: true));

    expect(out.result.isProposal, isTrue);
    expect(out.result.reasons, ['read_untrusted_text']);
    expect(out.commitArgs, {'level': 'bien'});
    expect(out.undoPayload, isNull);
    expect(animo.logs, isEmpty);
  });

  test('confirmada por la persona guarda aunque el turno leyera texto', () async {
    final out = await tools.execute(
      WriteToolNames.logMood,
      {'level': 'bien'},
      ctx(untrusted: true, confirmed: true),
    );

    expect(out.result.isSaved, isTrue);
    expect(animo.dailyLogFor(now)!.valence, 1);
  });

  test('si el guardado lanza devuelve error sin nada que deshacer', () async {
    final failing = AnimoWriteTools(
      _ThrowingAnimoState(service: service, pendingStore: _MemoryPendingStore(), clock: () => now),
    );

    final out = await failing.execute(WriteToolNames.logMood, {'level': 'bien'}, ctx());

    expect(out.result.isError, isTrue);
    expect(out.result.message, startsWith('No pude registrarlo: '));
    expect(out.result.message, endsWith('No se guardó nada.'));
    expect(out.undoPayload, isNull);
  });
}
