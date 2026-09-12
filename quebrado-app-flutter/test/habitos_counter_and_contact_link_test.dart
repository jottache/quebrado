import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HabitModel & HabitType Counter Tests', () {
    test('HabitType.counter serializes and parses properly', () {
      expect(HabitType.counter.rawValue, equals('counter'));
      expect(HabitType.counter.label, equals('CONTADOR INFINITO'));
      expect(HabitTypeExtension.fromString('counter'), equals(HabitType.counter));
    });

    test('HabitModel supports counter type and contactId with copyWith', () {
      final habit = HabitModel(
        id: 'h1',
        title: 'Decir groserías',
        type: HabitType.counter,
        unit: 'groserías',
        contactId: 'c1',
      );

      expect(habit.type, equals(HabitType.counter));
      expect(habit.unit, equals('groserías'));
      expect(habit.contactId, equals('c1'));

      final map = habit.toMap();
      expect(map['type'], equals('counter'));
      expect(map['unit'], equals('groserías'));
      expect(map['contact_id'], equals('c1'));

      final restored = HabitModel.fromMap(map);
      expect(restored.type, equals(HabitType.counter));
      expect(restored.unit, equals('groserías'));
      expect(restored.contactId, equals('c1'));

      // Test clearing contactId
      final cleared = habit.copyWith(contactId: null, clearContactId: true);
      expect(cleared.contactId, isNull);
    });
  });

  group('HabitosState Counter & Contact Linking Tests', () {
    test('incrementCounter and updateHabitValue for counter habits increment freely and do not drop below zero', () async {
      final state = HabitosState();
      await Future.delayed(const Duration(milliseconds: 100));

      final counterHabit = HabitModel(
        id: 'habit_counter_1',
        title: 'Decir groserías',
        type: HabitType.counter,
        unit: 'groserías',
      );

      state.habits.add(counterHabit);

      // Verify initial value is 0
      expect(state.getValue(counterHabit.id), equals(0.0));
      expect(state.isCompleted(counterHabit.id), isFalse);

      // Increment +1
      await state.incrementCounter(counterHabit.id);
      expect(state.getValue(counterHabit.id), equals(1.0));
      expect(state.isCompleted(counterHabit.id), isTrue);

      // Increment +4 more
      await state.incrementCounter(counterHabit.id, delta: 4.0);
      expect(state.getValue(counterHabit.id), equals(5.0));

      // Decrement -2
      await state.updateHabitValue(counterHabit.id, -2.0);
      expect(state.getValue(counterHabit.id), equals(3.0));

      // Decrement by 10 (should clamp at 0.0, not negative)
      await state.updateHabitValue(counterHabit.id, -10.0);
      expect(state.getValue(counterHabit.id), equals(0.0));
      expect(state.isCompleted(counterHabit.id), isFalse);
    });

    test('toggleHabitCompletion increments counter habit by 1', () async {
      final state = HabitosState();
      await Future.delayed(const Duration(milliseconds: 100));

      final counterHabit = HabitModel(
        id: 'habit_counter_2',
        title: 'Vasos de agua extra',
        type: HabitType.counter,
        unit: 'vasos',
      );
      state.habits.add(counterHabit);

      await state.toggleHabitCompletion(counterHabit.id);
      expect(state.getValue(counterHabit.id), equals(1.0));

      await state.toggleHabitCompletion(counterHabit.id);
      expect(state.getValue(counterHabit.id), equals(2.0));
    });

    test('getHabitsForContact and linkHabitToContact link and filter properly', () async {
      final state = HabitosState();
      await Future.delayed(const Duration(milliseconds: 100));

      final habit1 = HabitModel(
        id: 'h_contact_1',
        title: 'Llamar a mamá',
        contactId: 'contact_mama',
      );
      final habit2 = HabitModel(
        id: 'h_contact_2',
        title: 'Pagar almuerzo a Carlos',
        contactId: 'contact_carlos',
      );
      final habit3 = HabitModel(
        id: 'h_contact_3',
        title: 'Rutina gym personal',
        contactId: null,
      );

      state.habits.addAll([habit1, habit2, habit3]);

      final mamaHabits = state.getHabitsForContact('contact_mama');
      expect(mamaHabits.length, equals(1));
      expect(mamaHabits.first.id, equals('h_contact_1'));

      final carlosHabits = state.getHabitsForContact('contact_carlos');
      expect(carlosHabits.length, equals(1));
      expect(carlosHabits.first.id, equals('h_contact_2'));

      // Link habit3 to Carlos
      await state.linkHabitToContact('h_contact_3', 'contact_carlos');
      final updatedCarlosHabits = state.getHabitsForContact('contact_carlos');
      expect(updatedCarlosHabits.length, equals(2));

      // Unlink habit2 from Carlos
      await state.linkHabitToContact('h_contact_2', null);
      final finalCarlosHabits = state.getHabitsForContact('contact_carlos');
      expect(finalCarlosHabits.length, equals(1));
      expect(finalCarlosHabits.first.id, equals('h_contact_3'));
    });

    test('setContactFilter filters filteredHabits correctly and toggles off', () async {
      final state = HabitosState();
      await Future.delayed(const Duration(milliseconds: 100));

      final habit1 = HabitModel(id: 'h_1', title: 'H1', contactId: 'c_1');
      final habit2 = HabitModel(id: 'h_2', title: 'H2', contactId: 'c_2');
      final habit3 = HabitModel(id: 'h_3', title: 'H3', contactId: null);

      state.habits.addAll([habit1, habit2, habit3]);

      // Filter by c_1
      state.setContactFilter('c_1');
      expect(state.selectedContactId, equals('c_1'));
      expect(state.filteredHabits.any((h) => h.id == 'h_1'), isTrue);
      expect(state.filteredHabits.any((h) => h.id == 'h_2'), isFalse);
      expect(state.filteredHabits.any((h) => h.id == 'h_3'), isFalse);

      // Filter by unlinked (__none__)
      state.setContactFilter('__none__');
      expect(state.selectedContactId, equals('__none__'));
      expect(state.filteredHabits.any((h) => h.id == 'h_3'), isTrue);
      expect(state.filteredHabits.any((h) => h.id == 'h_1'), isFalse);

      // Toggle off
      state.setContactFilter('__none__');
      expect(state.selectedContactId, isNull);
      expect(state.filteredHabits.any((h) => h.id == 'h_1'), isTrue);
      expect(state.filteredHabits.any((h) => h.id == 'h_2'), isTrue);
      expect(state.filteredHabits.any((h) => h.id == 'h_3'), isTrue);
    });
  });
}
