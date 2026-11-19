// Solo compila en web (usa package:web): `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/services/suite_lock_store_web.dart';
import 'package:web/web.dart' as web;

void main() {
  const key = 'ortiz.lock.test';

  tearDown(() => web.window.localStorage.removeItem(key));

  test('guarda en localStorage y otra instancia lo lee (sobrevive a recargar)', () {
    createSuiteLockStore().write(key, '2026-11-18');

    expect(web.window.localStorage.getItem(key), '2026-11-18');
    expect(createSuiteLockStore().read(key), '2026-11-18');
  });

  test('una clave que no existe da null', () {
    expect(createSuiteLockStore().read(key), isNull);
  });
}
