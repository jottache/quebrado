/// Dónde recuerda `SuiteLock` el último desbloqueo y si la seguridad estaba
/// activada. En web usa `localStorage`; en las demás plataformas (y en los
/// tests) vive en memoria.
///
/// (package:web 1.x no compila fuera de la web, por eso va con import condicional.)
library;

export 'suite_lock_store_stub.dart' if (dart.library.js_interop) 'suite_lock_store_web.dart';
