import 'package:flutter/foundation.dart';

import 'suite_lock_store.dart';

/// Bloqueo de toda la suite con PIN o biometría, **una vez al día**
/// (`docs/design/rutas.md` §10, P-04 revisada el 2026-11-18).
///
/// - Si la seguridad está activada, al entrar a la app se pide el PIN; tras
///   desbloquear se puede hacer todo (Finanzas, acciones rápidas, Ortiz) sin
///   volver a pedirlo hasta el día siguiente.
/// - La fecha del último desbloqueo se recuerda en [SuiteLockStore]
///   (`localStorage` en web), así que recargar la pestaña el mismo día no
///   vuelve a pedirlo.
/// - Cierra ante la duda (A1): recuerda si la seguridad estaba activada y, si
///   los ajustes aún no se leyeron o no se pudieron leer, usa ese valor.
/// - El router lo usa como `refreshListenable`.
///
/// Es una barrera de interfaz, no de datos (ver la deuda de RLS en
/// `docs/pendientes.md`, P-01): quien borra el almacenamiento del navegador o
/// lee la base con la anon key se la salta.
class SuiteLock extends ChangeNotifier {
  SuiteLock({SuiteLockStore? store, DateTime Function()? clock})
      : _store = store ?? createSuiteLockStore(),
        _clock = clock ?? DateTime.now {
    final cached = _store.read(securityEnabledKey);
    _securityKnown = cached != null;
    _securityEnabled = cached == 'true';
  }

  /// Clave con la fecha (`AAAA-MM-DD`) del último desbloqueo.
  static const String unlockedOnKey = 'ortiz.lock.unlockedOn';

  /// Clave con el último valor conocido de «seguridad activada».
  static const String securityEnabledKey = 'ortiz.lock.securityEnabled';

  final SuiteLockStore _store;
  final DateTime Function() _clock;
  late bool _securityEnabled;
  late bool _securityKnown;

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// True si ya se desbloqueó hoy (según el reloj local).
  bool get isUnlocked => _store.read(unlockedOnKey) == _dayKey(_clock());

  /// True si el PIN o la biometría están activados (o lo estaban la última vez
  /// que se pudieron leer los ajustes).
  bool get securityEnabled => _securityEnabled;

  /// True si ya se sabe si la seguridad está activada: se leyó en esta carga
  /// o se recordó de una anterior. La primera vez en un navegador es false y
  /// el router espera a los ajustes antes de abrir la app.
  bool get securityKnown => _securityKnown;

  /// True si hay que pedir el PIN antes de mostrar la app.
  bool get requiresUnlock => _securityEnabled && !isUnlocked;

  /// Lo llama `main.dart` cada vez que cambian los ajustes de `AppState`.
  ///
  /// [confirmed] indica que los ajustes se leyeron de verdad (o los cambió la
  /// persona). Si no, se mantiene el último valor conocido cuando era «activada»
  /// para no abrir la app por un fallo de lectura.
  void updateSecurity({required bool enabled, required bool confirmed}) {
    final before = requiresUnlock;
    if (confirmed) {
      _securityKnown = true;
      _securityEnabled = enabled;
      _store.write(securityEnabledKey, enabled.toString());
    } else {
      _securityEnabled = enabled || _securityEnabled;
    }
    if (requiresUnlock != before) notifyListeners();
  }

  /// Marca el día de hoy como desbloqueado.
  void unlock() {
    if (isUnlocked) return;
    _store.write(unlockedOnKey, _dayKey(_clock()));
    notifyListeners();
  }
}
