import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../quebrado/services/db_helper.dart';

/// Borradores automáticos de los editores (Notas y Diario).
///
/// Se guardan en este dispositivo (tabla `settings` de la base local, que también
/// funciona en la web) unos segundos después de cada cambio, y se borran al guardar.
/// Así, si el modal se cierra por error, al volver a abrirlo se recupera lo escrito.
abstract class DraftBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class _SettingsDraftBackend implements DraftBackend {
  @override
  Future<String?> read(String key) async {
    try {
      final value = await DatabaseHelper.instance.getSetting(key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (e) {
      debugPrint('Borradores: no se pudo leer $key ($e)');
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      await DatabaseHelper.instance.setSetting(key, value ?? '');
    } catch (e) {
      debugPrint('Borradores: no se pudo guardar $key ($e)');
    }
  }
}

class EditorDraft {
  final Map<String, dynamic> data;
  final DateTime savedAt;

  const EditorDraft(this.data, this.savedAt);
}

class DraftStore {
  DraftStore({DraftBackend? backend}) : _backend = backend ?? _SettingsDraftBackend();

  static DraftStore instance = DraftStore();

  final DraftBackend _backend;

  /// Copia en memoria: en la misma sesión se recupera al instante aunque la
  /// escritura en la base local todavía no haya terminado.
  final Map<String, EditorDraft> _memory = {};

  static String _key(String scope) => 'draft:$scope';

  Future<EditorDraft?> load(String scope) async {
    final cached = _memory[scope];
    if (cached != null) return cached;
    // Si la base local no responde, el editor abre igual (sin borrador)
    final raw = await _backend.read(_key(scope)).timeout(const Duration(seconds: 3), onTimeout: () {
      debugPrint('Borradores: la lectura de $scope tardó demasiado, se abre sin borrador');
      return null;
    });
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final draft = EditorDraft(
        Map<String, dynamic>.from(decoded['data'] as Map),
        DateTime.tryParse(decoded['saved_at']?.toString() ?? '') ?? DateTime.now(),
      );
      _memory[scope] = draft;
      return draft;
    } catch (e) {
      debugPrint('Borradores: borrador ilegible en $scope ($e)');
      return null;
    }
  }

  Future<void> save(String scope, Map<String, dynamic> data) async {
    final draft = EditorDraft(data, DateTime.now());
    _memory[scope] = draft;
    await _backend.write(_key(scope), jsonEncode({'saved_at': draft.savedAt.toIso8601String(), 'data': data}));
  }

  Future<void> clear(String scope) async {
    _memory.remove(scope);
    await _backend.write(_key(scope), null);
  }
}

/// Guarda borradores con un pequeño retraso para no escribir en cada tecla.
class DraftAutosaver {
  DraftAutosaver({required this.scope, required this.collect, DraftStore? store, this.delay = const Duration(milliseconds: 800)})
      : _store = store ?? DraftStore.instance;

  final String scope;
  final Map<String, dynamic>? Function() collect;
  final Duration delay;
  final DraftStore _store;
  Timer? _timer;
  bool _disabled = false;

  /// Programa un guardado. [collect] devuelve null si no hay nada que guardar.
  void schedule() {
    if (_disabled) return;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Guarda ya (por ejemplo, al cerrar el modal).
  Future<void> flush() async {
    _timer?.cancel();
    if (_disabled) return;
    final data = collect();
    if (data == null) return;
    await _store.save(scope, data);
  }

  /// Tras guardar de verdad: borra el borrador y deja de autoguardar.
  Future<void> discard() async {
    _disabled = true;
    _timer?.cancel();
    await _store.clear(scope);
  }

  void dispose() => _timer?.cancel();
}
