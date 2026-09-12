import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diario Contact Update & Sorting Tests', () {
    test('DiarioState.updateContact preserves updated contact and does not confuse indices on sort', () async {
      final state = DiarioState();
      // Wait for initial loadAll to finish
      await Future.delayed(const Duration(milliseconds: 100));

      // Seed initial contacts
      final contactCarlos = DiarioContact(id: 'c1', name: 'Carlos Mendoza', nickname: 'Carlitos');
      final contactZack = DiarioContact(id: 'c2', name: 'Zack Taylor', nickname: 'Zack');

      state.contacts.clear();
      state.contacts.addAll([contactCarlos, contactZack]);

      // Update Zack to Aaron so its position in the sorted list moves from index 1 to index 0
      final updatedZack = contactZack.copyWith(
        name: 'Aaron Taylor',
        phone: '+58 414-9999999',
      );

      await state.updateContact(updatedZack);

      // Verify the list is properly sorted
      expect(state.contacts.first.id, equals('c2'));
      expect(state.contacts.first.name, equals('Aaron Taylor'));
      expect(state.contacts.first.phone, equals('+58 414-9999999'));

      // Verify Carlos is still untouched
      expect(state.contacts[1].id, equals('c1'));
      expect(state.contacts[1].name, equals('Carlos Mendoza'));
    });

    test('DiarioState.updateContact handles updating contact not initially present', () async {
      final state = DiarioState();
      await Future.delayed(const Duration(milliseconds: 100));

      state.contacts.clear();

      final newContact = DiarioContact(id: 'c3', name: 'Daniel Ortiz');
      await state.updateContact(newContact);

      expect(state.contacts.length, equals(1));
      expect(state.contacts.first.id, equals('c3'));
      expect(state.contacts.first.name, equals('Daniel Ortiz'));
    });

    test('DiarioContact.copyWith clear flags correctly clear nullable properties', () {
      final contact = DiarioContact(
        id: 'c1',
        name: 'Papa',
        nickname: 'papa',
        relationship: 'Papá',
        phone: '04141234567',
        notes: 'Nota importante',
        birthdate: DateTime(1952, 1, 16),
      );

      final cleared = contact.copyWith(
        nickname: null,
        clearNickname: true,
        phone: null,
        clearPhone: true,
        notes: null,
        clearNotes: true,
        birthdate: null,
        clearBirthdate: true,
      );

      expect(cleared.nickname, isNull);
      expect(cleared.phone, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.birthdate, isNull);
      expect(cleared.name, equals('Papa'));
      expect(cleared.relationship, equals('Papá'));
    });
  });
}
