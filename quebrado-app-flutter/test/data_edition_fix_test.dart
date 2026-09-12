import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';

void main() {
  group('Hábitos Data Edition Tests', () {
    test('HabitModel can clear description, unit, and stackGroupId without being blocked by null-coalescing', () {
      final habit = HabitModel(
        id: 'h1',
        title: 'Leer libro',
        description: 'Capítulo diario',
        type: HabitType.quantitative,
        targetValue: 20,
        unit: 'págs',
        stackGroupId: 'stack_night',
      );

      // Edit habit: update title, clear description, switch to binary type, clear unit & stack
      final edited = habit.copyWith(
        title: 'Leer 30 min',
        description: null,
        clearDescription: true,
        type: HabitType.binary,
        unit: null,
        clearUnit: true,
        stackGroupId: null,
        clearStackGroupId: true,
      );

      expect(edited.title, equals('Leer 30 min'));
      expect(edited.description, isNull);
      expect(edited.unit, isNull);
      expect(edited.stackGroupId, isNull);
      expect(edited.type, equals(HabitType.binary));
    });
  });

  group('Diario Data Edition Tests', () {
    test('DiarioEntry.toMap does NOT have root photo_url column (prevents PGRST204) and stores photo in content_data', () {
      final entry = DiarioEntry(
        id: 'e1',
        contactId: 'c1',
        categoryId: 'cat_alimentos',
        title: 'Pasta favorita',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      );

      final map = entry.toMap();

      // Ensure root map does NOT contain photo_url so Supabase does not fail with PGRST204
      expect(map.containsKey('photo_url'), isFalse);

      // Ensure content_data contains photo_url
      final contentData = map['content_data'] as Map<String, dynamic>;
      expect(contentData['photo_url'], equals('https://cdn.example.com/photo.jpg'));

      // Ensure deserialization restores photoUrl correctly
      final restored = DiarioEntry.fromMap(map);
      expect(restored.photoUrl, equals('https://cdn.example.com/photo.jpg'));
    });

    test('DiarioEntry.copyWith can clear contentText and templateId', () {
      final entry = DiarioEntry(
        id: 'e1',
        contactId: 'c1',
        categoryId: 'cat_1',
        templateId: 'tpl_1',
        title: 'Entrada con modelo',
        contentText: 'Texto largo explicativo',
      );

      final edited = entry.copyWith(
        title: 'Nuevo Título',
        contentText: null,
        clearContentText: true,
        templateId: null,
        clearTemplate: true,
      );

      expect(edited.title, equals('Nuevo Título'));
      expect(edited.contentText, isNull);
      expect(edited.templateId, isNull);
    });

    test('DiarioContact.copyWith can clear nickname, relationship, phone, notes, and birthdate', () {
      final contact = DiarioContact(
        id: 'c1',
        name: 'Carlos Mendoza',
        nickname: 'Carlitos',
        relationship: 'Amigo',
        phone: '+58 412-1234567',
        notes: 'Le gustan los autos',
        birthdate: DateTime(1990, 5, 20),
      );

      final edited = contact.copyWith(
        name: 'Carlos A. Mendoza',
        nickname: null,
        clearNickname: true,
        relationship: null,
        clearRelationship: true,
        phone: null,
        clearPhone: true,
        notes: null,
        clearNotes: true,
        birthdate: null,
        clearBirthdate: true,
      );

      expect(edited.name, equals('Carlos A. Mendoza'));
      expect(edited.nickname, isNull);
      expect(edited.relationship, isNull);
      expect(edited.phone, isNull);
      expect(edited.notes, isNull);
      expect(edited.birthdate, isNull);
    });
  });

  group('Recordatorios Data Edition Tests', () {
    test('ReminderModel copyWith can update and clear nullable fields properly', () {
      final reminder = ReminderModel(
        id: 'r1',
        title: 'Comprar repuesto',
        notes: 'En la tienda central',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        rrule: 'FREQ=DAILY',
      );

      final edited = reminder.copyWith(
        title: 'Comprar repuesto urgente',
        notes: null,
        clearNotes: true,
        dueAt: null,
        clearDueAt: true,
        rrule: null,
        clearRrule: true,
      );

      expect(edited.title, equals('Comprar repuesto urgente'));
      expect(edited.notes, isNull);
      expect(edited.dueAt, isNull);
      expect(edited.rrule, isNull);
    });
  });
}
