import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/undo_result.dart';

void main() {
  group('UndoResult', () {
    test('done es correcto y dice «Deshecho»', () {
      const r = UndoResult.done();
      expect(r.ok, isTrue);
      expect(r.message, 'Deshecho');
      expect(r.message, UndoResult.doneMessage);
    });

    test('failed no es correcto y conserva el motivo', () {
      const r = UndoResult.failed('Cambia al libro Casa para deshacerlo.');
      expect(r.ok, isFalse);
      expect(r.message, 'Cambia al libro Casa para deshacerlo.');
    });

    test('un fallo con el texto «Deshecho» no cuenta como deshecho', () {
      const r = UndoResult.failed('Deshecho');
      expect(r.ok, isFalse);
      expect(r, isNot(const UndoResult.done()));
    });

    test('notice no se deshizo pero es un aviso, no un fallo', () {
      const r = UndoResult.notice('Cambia al libro Casa para deshacerlo.');
      expect(r.ok, isFalse);
      expect(r.isNotice, isTrue);
      expect(const UndoResult.failed('x').isNotice, isFalse);
      expect(r, isNot(const UndoResult.failed('Cambia al libro Casa para deshacerlo.')));
    });

    test('compara por valor', () {
      expect(const UndoResult.failed('x'), const UndoResult.failed('x'));
      expect(const UndoResult.failed('x').hashCode, const UndoResult.failed('x').hashCode);
      expect(const UndoResult.failed('x'), isNot(const UndoResult.failed('y')));
    });
  });
}
