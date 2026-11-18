import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/services/suite_lock_store.dart';

void main() {
  test('fuera de la web el almacén vive en memoria', () {
    final store = createSuiteLockStore();

    expect(store, isA<MemorySuiteLockStore>());
    expect(store.read('x'), isNull);
    store.write('x', '1');
    expect(store.read('x'), '1');
  });

  test('cada almacén en memoria es independiente', () {
    createSuiteLockStore().write('x', '1');

    expect(createSuiteLockStore().read('x'), isNull);
  });
}
