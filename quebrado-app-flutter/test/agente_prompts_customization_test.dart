import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/agente_prompt_model.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/docked_launcher_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentePromptModel Tests', () {
    test('AgentePromptModel serializes and parses properly', () {
      final now = DateTime.now();
      final prompt = AgentePromptModel(
        id: 'p1',
        text: '¿Cuánto dinero tengo en el banco?',
        label: 'Balance',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = prompt.toMap();
      expect(map['id'], equals('p1'));
      expect(map['text'], equals('¿Cuánto dinero tengo en el banco?'));
      expect(map['label'], equals('Balance'));
      expect(map['sort_order'], equals(1));

      final restored = AgentePromptModel.fromMap(map);
      expect(restored.id, equals(prompt.id));
      expect(restored.text, equals(prompt.text));
      expect(restored.label, equals(prompt.label));
      expect(restored.sortOrder, equals(1));
    });

    test('AgentePromptModel copyWith updates fields correctly', () {
      final prompt = AgentePromptModel(
        id: 'p1',
        text: 'Texto inicial',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = prompt.copyWith(text: 'Texto modificado', label: 'Nuevo Alias');
      expect(updated.id, equals('p1'));
      expect(updated.text, equals('Texto modificado'));
      expect(updated.label, equals('Nuevo Alias'));
    });
  });

  group('AgenteState Quick Prompts CRUD Tests', () {
    test('Can save, update, delete, and reorder prompts', () async {
      final state = AgenteState(autoInit: false);

      // Create prompt 1
      final p1 = AgentePromptModel(
        id: 'prompt_1',
        text: '¿Cuáles son mis hábitos de hoy?',
        label: 'Hábitos',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await state.saveQuickPrompt(p1, persist: false);

      expect(state.quickPrompts.any((p) => p.id == 'prompt_1'), isTrue);
      expect(state.quickPrompts.firstWhere((p) => p.id == 'prompt_1').text, equals('¿Cuáles son mis hábitos de hoy?'));

      // Create prompt 2
      final p2 = AgentePromptModel(
        id: 'prompt_2',
        text: 'Ver tipo de cambio BCV',
        label: 'Tasas',
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await state.saveQuickPrompt(p2, persist: false);

      expect(state.quickPrompts.length, equals(2));

      // Update prompt 1
      final p1Updated = p1.copyWith(text: '¿Completé mis hábitos de hoy?');
      await state.saveQuickPrompt(p1Updated, persist: false);

      expect(state.quickPrompts.firstWhere((p) => p.id == 'prompt_1').text, equals('¿Completé mis hábitos de hoy?'));

      // Reorder prompts
      await state.reorderQuickPrompts(1, 0, persist: false);
      expect(state.quickPrompts.first.id, equals('prompt_2'));

      // Delete prompt 2
      await state.deleteQuickPrompt('prompt_2', persist: false);
      expect(state.quickPrompts.any((p) => p.id == 'prompt_2'), isFalse);
      expect(state.quickPrompts.length, equals(1));
    });
  });

  group('DockedLauncherChat Widget Tests', () {
    testWidgets('Renders empty state with customize button when no prompts exist', (tester) async {
      final state = AgenteState(autoInit: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AgenteState>.value(
              value: state,
              child: const DockedLauncherChat(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Does NOT show old hardcoded prompts
      expect(find.text('¿Cuáles son los próximos 3 cumpleaños?'), findsNothing);
      expect(find.text('¿Cuánto dinero tengo en total?'), findsNothing);
      expect(find.text('Calcular 50 USD a Bs'), findsNothing);

      // Shows customize button
      expect(find.text('Personalizar atajos de consulta'), findsOneWidget);
    });

    testWidgets('Renders user custom prompts when available', (tester) async {
      final state = AgenteState(autoInit: false);

      await state.saveQuickPrompt(
        AgentePromptModel(
          id: 'custom_1',
          text: '¿Cuánto gasté hoy en comida?',
          label: 'Gastos',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        persist: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AgenteState>.value(
              value: state,
              child: const DockedLauncherChat(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Shows custom prompt with label
      expect(find.text('Gastos: ¿Cuánto gasté hoy en comida?'), findsOneWidget);
      // Shows "Nuevo" action chip to quickly add more
      expect(find.text('Nuevo'), findsOneWidget);
    });
  });
}
