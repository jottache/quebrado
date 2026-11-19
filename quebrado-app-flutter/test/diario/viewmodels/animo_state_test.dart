import 'package:flutter_test/flutter_test.dart';
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
}

void main() {
  // Spec 02, paso 6: el formulario de ánimo devuelve el registro guardado.
  test('updateLog devuelve el registro guardado, normalizado y con el mismo id', () async {
    final now = DateTime(2026, 9, 28, 12);
    final service = _FakeAnimoService();
    final state = AnimoState(service: service, clock: () => now);
    final log = await state.addLog(valence: 1, loggedAt: DateTime(2026, 9, 28, 9));

    final updated = await state.updateLog(log.copyWith(
      valence: -1,
      emotions: ['a', 'b', 'c', 'd'],
      loggedAt: DateTime(2026, 10, 5), // futuro: se recorta a ahora
    ));

    expect(updated.id, log.id);
    expect(updated.valence, -1);
    expect(updated.emotions.length, 3, reason: 'máximo 3 emociones');
    expect(updated.loggedAt, now);
    expect(updated.updatedAt, now);
    expect(service.remote[log.id]?.valence, -1);
  });
}
