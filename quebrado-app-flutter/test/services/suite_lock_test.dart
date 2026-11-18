import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/services/suite_lock.dart';
import 'package:quebrado_app_flutter/services/suite_lock_store_base.dart';

// rutas.md §10, P-04 (revisada 2026-11-18): el PIN se pide una vez al día al
// entrar a la app; después se permite todo.
void main() {
  late MemorySuiteLockStore store;
  late DateTime now;

  SuiteLock newLock() => SuiteLock(store: store, clock: () => now);

  setUp(() {
    store = MemorySuiteLockStore();
    now = DateTime(2026, 11, 18, 9, 30);
  });

  test('sin seguridad activada no pide desbloqueo', () {
    final lock = newLock()..updateSecurity(enabled: false, confirmed: true);

    expect(lock.requiresUnlock, isFalse);
  });

  test('con seguridad activada pide desbloqueo hasta que se desbloquea', () {
    final lock = newLock()..updateSecurity(enabled: true, confirmed: true);
    expect(lock.requiresUnlock, isTrue);

    lock.unlock();

    expect(lock.isUnlocked, isTrue);
    expect(lock.requiresUnlock, isFalse);
  });

  test('unlock avisa una sola vez', () {
    final lock = newLock()..updateSecurity(enabled: true, confirmed: true);
    var avisos = 0;
    lock.addListener(() => avisos++);

    lock.unlock();
    lock.unlock();

    expect(avisos, 1);
  });

  test('recargar la app el mismo día no vuelve a pedirlo', () {
    newLock()
      ..updateSecurity(enabled: true, confirmed: true)
      ..unlock();
    now = DateTime(2026, 11, 18, 23, 59);

    final recargada = newLock()..updateSecurity(enabled: true, confirmed: true);

    expect(recargada.requiresUnlock, isFalse);
  });

  test('al día siguiente se vuelve a pedir', () {
    final lock = newLock()
      ..updateSecurity(enabled: true, confirmed: true)
      ..unlock();

    now = DateTime(2026, 11, 19, 0, 1);

    expect(lock.isUnlocked, isFalse);
    expect(lock.requiresUnlock, isTrue);
    expect(newLock().requiresUnlock, isTrue);
  });

  group('cierra ante la duda (A1)', () {
    test('antes de leer los ajustes usa el último valor conocido', () {
      newLock().updateSecurity(enabled: true, confirmed: true);

      final recargada = newLock();

      expect(recargada.requiresUnlock, isTrue);
    });

    test('ajustes sin confirmar en «desactivada» no abren si estaba activada', () {
      newLock().updateSecurity(enabled: true, confirmed: true);
      final lock = newLock()..updateSecurity(enabled: false, confirmed: false);

      expect(lock.requiresUnlock, isTrue);
    });

    test('desactivarla de verdad sí se respeta y se recuerda', () {
      newLock().updateSecurity(enabled: true, confirmed: true);
      newLock().updateSecurity(enabled: false, confirmed: true);

      expect(newLock().requiresUnlock, isFalse);
    });

    test('ajustes sin confirmar en «activada» bloquean igual', () {
      final lock = newLock()..updateSecurity(enabled: true, confirmed: false);

      expect(lock.requiresUnlock, isTrue);
    });
  });

  test('securityKnown: falso la primera vez; cierto tras confirmar o en recargas', () {
    final primera = newLock();
    expect(primera.securityKnown, isFalse);

    primera.updateSecurity(enabled: false, confirmed: false);
    expect(primera.securityKnown, isFalse);

    primera.updateSecurity(enabled: false, confirmed: true);
    expect(primera.securityKnown, isTrue);
    expect(newLock().securityKnown, isTrue);
  });

  test('activar la seguridad tras desbloquear el día no vuelve a bloquear ni avisa', () {
    final lock = newLock()..updateSecurity(enabled: false, confirmed: true);
    var avisos = 0;
    lock.unlock(); // lo que hace AppState.setUsePinSecurity(true) vía onSecurityVerified
    lock.addListener(() => avisos++);

    lock.updateSecurity(enabled: true, confirmed: true);

    expect(lock.requiresUnlock, isFalse);
    expect(avisos, 0, reason: 'sin aviso, el router no redirige a /desbloquear');
  });

  test('updateSecurity avisa solo si cambia si hay que desbloquear', () {
    final lock = newLock();
    var avisos = 0;
    lock.addListener(() => avisos++);

    lock.updateSecurity(enabled: false, confirmed: true);
    expect(avisos, 0);
    lock.updateSecurity(enabled: true, confirmed: true);
    expect(avisos, 1);
    lock.updateSecurity(enabled: true, confirmed: true);
    expect(avisos, 1);
  });

  test('no guarda nada más que la fecha y el indicador', () {
    newLock()
      ..updateSecurity(enabled: true, confirmed: true)
      ..unlock();

    expect(store.read(SuiteLock.unlockedOnKey), '2026-11-18');
    expect(store.read(SuiteLock.securityEnabledKey), 'true');
  });
}
