/// Almacén clave-valor mínimo para `SuiteLock`. No guarda el PIN ni datos
/// personales: solo la fecha del último desbloqueo y si la seguridad estaba
/// activada.
abstract class SuiteLockStore {
  String? read(String key);
  void write(String key, String value);
}

/// Almacén en memoria: se pierde al cerrar la app (y es el de los tests).
class MemorySuiteLockStore implements SuiteLockStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;
}
