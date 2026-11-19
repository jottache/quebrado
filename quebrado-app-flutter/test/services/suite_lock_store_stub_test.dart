import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/services/suite_lock_store_stub.dart';

void main() {
  test('fuera de la web crea un almacén en memoria nuevo cada vez', () {
    final a = createSuiteLockStore();
    final b = createSuiteLockStore();

    expect(a, isA<MemorySuiteLockStore>());
    a.write('ortiz.lock.unlockedOn', '2026-11-18');
    expect(a.read('ortiz.lock.unlockedOn'), '2026-11-18');
    expect(b.read('ortiz.lock.unlockedOn'), isNull);
  });
}
