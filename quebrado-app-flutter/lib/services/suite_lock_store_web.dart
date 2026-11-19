import 'package:web/web.dart' as web;

import 'suite_lock_store_base.dart';

export 'suite_lock_store_base.dart';

/// En web el desbloqueo se recuerda en `localStorage` para no pedir el PIN
/// más de una vez al día. Si el navegador no deja usarlo (modo privado,
/// datos bloqueados), cae a memoria.
SuiteLockStore createSuiteLockStore() => _LocalStorageSuiteLockStore();

class _LocalStorageSuiteLockStore implements SuiteLockStore {
  final MemorySuiteLockStore _fallback = MemorySuiteLockStore();

  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key) ?? _fallback.read(key);
    } catch (_) {
      return _fallback.read(key);
    }
  }

  @override
  void write(String key, String value) {
    _fallback.write(key, value);
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }
}
