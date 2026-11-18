import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/services/pin_attempt_limiter.dart';

void main() {
  late DateTime now;
  late PinAttemptLimiter limiter;

  setUp(() {
    now = DateTime(2026, 11, 18, 10);
    limiter = PinAttemptLimiter(clock: () => now);
  });

  test('por defecto: 5 intentos y 30 s de espera', () {
    final porDefecto = PinAttemptLimiter();

    expect(porDefecto.maxAttempts, 5);
    expect(porDefecto.lockout, const Duration(seconds: 30));
  });

  test('cuatro fallos todavía permiten intentarlo', () {
    for (var i = 0; i < 4; i++) {
      limiter.registerFailure();
    }

    expect(limiter.isLockedOut, isFalse);
    expect(limiter.attemptsLeft, 1);
  });

  test('el quinto fallo obliga a esperar 30 s', () {
    for (var i = 0; i < 5; i++) {
      limiter.registerFailure();
    }

    expect(limiter.isLockedOut, isTrue);
    expect(limiter.remainingLockout, const Duration(seconds: 30));

    now = now.add(const Duration(seconds: 29));
    expect(limiter.isLockedOut, isTrue);

    now = now.add(const Duration(seconds: 1));
    expect(limiter.isLockedOut, isFalse);
    expect(limiter.attemptsLeft, 5, reason: 'tras la espera vuelven los 5 intentos');
  });

  test('los fallos durante la espera no la alargan', () {
    for (var i = 0; i < 5; i++) {
      limiter.registerFailure();
    }
    now = now.add(const Duration(seconds: 10));

    limiter.registerFailure();

    expect(limiter.remainingLockout, const Duration(seconds: 20));
  });

  test('un acierto reinicia la cuenta', () {
    for (var i = 0; i < 4; i++) {
      limiter.registerFailure();
    }

    limiter.registerSuccess();

    expect(limiter.attemptsLeft, 5);
    expect(limiter.isLockedOut, isFalse);
  });
}
