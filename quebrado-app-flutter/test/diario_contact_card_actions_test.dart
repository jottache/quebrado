import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/screens/diario_home_screen.dart';
import 'package:quebrado_app_flutter/diario/screens/contact_detail_screen.dart';
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

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

      if (find.text('Contactos').evaluate().isNotEmpty) {
        await tester.tap(find.text('Contactos'));
        await tester.pumpAndSettle();
      }

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

      if (find.text('Contactos').evaluate().isNotEmpty) {
        await tester.tap(find.text('Contactos'));
        await tester.pumpAndSettle();
      }

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

    testWidgets('Notes without title render contentText directly without generic titles in ContactDetailScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = DiarioState();
      await state.loadAll();

      final targetContact = state.contacts.first;

      // Add an entry with empty title
      await state.addEntry(
        contactId: targetContact.id,
        categoryId: 'cat_salud',
        title: '',
        contentText: 'Esta es una nota rápida sobre café y postres sin título',
      );

      expect(state.entries.first.hasTitle, isFalse);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DiarioState>.value(value: state),
            ChangeNotifierProvider<HabitosState>.value(value: HabitosState()),
          ],
          child: MaterialApp(
            home: ContactDetailScreen(contactId: targetContact.id),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the content text is rendered directly
      expect(find.text('Esta es una nota rápida sobre café y postres sin título'), findsOneWidget);

      // Verify NO generic title like "Sin título" or "Nueva entrada" is shown
      expect(find.text('Sin título'), findsNothing);
      expect(find.text('Nueva entrada'), findsNothing);
    });
  });
}
