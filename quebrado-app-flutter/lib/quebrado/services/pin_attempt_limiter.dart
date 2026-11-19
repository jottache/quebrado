/// Límite de intentos del PIN (auditoría spec 02, A6; decisión de la persona
/// del 2026-11-18): tras [maxAttempts] fallos seguidos hay que esperar
/// [lockout] antes de volver a intentarlo.
///
/// Vive en memoria y es compartido por todos los diálogos del PIN
/// ([instance]), así que cerrar y abrir el diálogo no reinicia la cuenta.
/// Recargar la pestaña sí la reinicia: es una barrera de interfaz (P-01).
class PinAttemptLimiter {
  PinAttemptLimiter({
    this.maxAttempts = 5,
    this.lockout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final PinAttemptLimiter instance = PinAttemptLimiter();

  final int maxAttempts;
  final Duration lockout;
  final DateTime Function() _clock;

  int _failures = 0;
  DateTime? _lockedUntil;

  /// Tiempo que falta para poder volver a intentarlo (cero si no hay espera).
  Duration get remainingLockout {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_clock());
    if (left <= Duration.zero) {
      _lockedUntil = null;
      return Duration.zero;
    }
    return left;
  }

  bool get isLockedOut => remainingLockout > Duration.zero;

  /// Intentos que quedan antes de la espera.
  int get attemptsLeft => maxAttempts - _failures;

  /// Anota un PIN incorrecto. Al llegar a [maxAttempts] empieza la espera.
  void registerFailure() {
    if (isLockedOut) return;
    _failures++;
    if (_failures >= maxAttempts) {
      _failures = 0;
      _lockedUntil = _clock().add(lockout);
    }
  }

  /// Un PIN correcto reinicia la cuenta.
  void registerSuccess() {
    _failures = 0;
    _lockedUntil = null;
  }
}
