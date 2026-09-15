import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/screens/diario_home_screen.dart';
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyAvatar =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  group('Diario Contact Card Actions Tests', () {
    testWidgets('Contact card displays quick add note button and opens EntryEditorDialog', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      final targetContact = state.contacts.first.copyWith(
        name: 'Mariana Davila',
        nickname: 'Cotiprin',
        avatarUrl: dummyAvatar,
      );
      await state.updateContact(targetContact);

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: DiarioHomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify contact name and nickname are rendered in list
      expect(find.text('Mariana Davila'), findsWidgets);
      expect(find.text('"Cotiprin"'), findsOneWidget);

      // Verify quick add note button is present with correct icon and tooltip
      final quickAddButtonFinder = find.byTooltip('Agregar nota rápida');
      expect(quickAddButtonFinder, findsWidgets);
      expect(find.byIcon(Icons.note_add_outlined), findsWidgets);

      // Verify edit contact button is NO LONGER present on any card
      expect(find.byTooltip('Editar contacto'), findsNothing);

      // Tap the quick add note button on the target card
      await tester.tap(quickAddButtonFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify EntryEditorDialog is opened
      expect(find.byType(EntryEditorDialog), findsOneWidget);
      expect(find.text('Nuevo Registro'), findsOneWidget);
    });

    testWidgets('Tapping avatar on contact card opens full screen image viewer', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      final targetContact = state.contacts.first.copyWith(
        name: 'Mariana Davila',
        nickname: 'Cotiprin',
        avatarUrl: dummyAvatar,
      );
      await state.updateContact(targetContact);

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: DiarioHomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the avatar ClipOval inside row
      final avatarFinder = find.byType(ClipOval);
      expect(avatarFinder, findsWidgets);

      // Tap on the avatar
      await tester.tap(avatarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify full screen image viewer is opened with InteractiveViewer
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Mariana Davila'), findsWidgets);
    });
  });
}
