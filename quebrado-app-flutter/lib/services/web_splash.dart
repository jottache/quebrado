/// Quita el splash HTML de la versión web. En otras plataformas no hace nada.
/// (package:web 1.x no compila fuera de la web, por eso va con import condicional.)
export 'web_splash_stub.dart' if (dart.library.js_interop) 'web_splash_web.dart';
