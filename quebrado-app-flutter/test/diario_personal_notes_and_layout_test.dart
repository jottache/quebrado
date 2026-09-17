import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/screens/diario_home_screen.dart';
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart';
import 'package:quebrado_app_flutter/diario/widgets/personal_notes_view.dart';
import 'package:quebrado_app_flutter/diario/dialogs/entry_reader_dialog.dart';
import 'package:quebrado_app_flutter/diario/screens/diario_search_screen.dart';
import 'package:quebrado_app_flutter/diario/screens/template_manager_screen.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diario Personal Notes and Responsive Layout Tests', () {
    testWidgets('DiarioState creates and filters personal entries properly', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      final initialPersonalCount = state.personalEntries.length;

      // Add a new personal note
      final newNote = await state.addPersonalEntry(
        title: 'Mi diario íntimo de prueba',
        contentText: 'Hoy fue un día excelente logrando nuevos objetivos.',
        isPinned: true,
      );

      expect(newNote.contactId, equals('personal'));
      expect(newNote.categoryId, equals('cat_notas_personales'));
      expect(newNote.title, equals('Mi diario íntimo de prueba'));
      expect(newNote.isPinned, isTrue);

      expect(state.personalEntries.length, equals(initialPersonalCount + 1));
      expect(state.personalEntries.any((e) => e.title == 'Mi diario íntimo de prueba'), isTrue);
    });

    testWidgets('Mobile view displays tabs with "Mis Notas" as the default active tab', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Verify TabBar with "Mis Notas" and "Contactos" is displayed on mobile
      expect(find.text('Mis Notas'), findsOneWidget);
      expect(find.text('Contactos'), findsOneWidget);

      // Verify PersonalNotesView is rendered as the primary/default view
      expect(find.byType(PersonalNotesView), findsOneWidget);

      // Verify mobile floating action button for Nueva Nota
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text('Nueva Nota'),
        ),
        findsOneWidget,
      );

      // Switch to Contactos tab
      await tester.tap(find.text('Contactos'));
      await tester.pumpAndSettle();

      // Now Directory of Contacts is visible and FAB is 'Nuevo Contacto'
      expect(find.text('Directorio de Personas'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text('Nuevo Contacto'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Desktop view displays 2-column layout simultaneously', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // In desktop, tabs at the top are not displayed because both columns are visible side-by-side
      expect(find.byType(TabBar), findsNothing);

      // Verify PersonalNotesView is rendered (Column 1)
      expect(find.byType(PersonalNotesView), findsOneWidget);

      // Verify Directorio de Personas is also visible at the same time (Column 2)
      expect(find.text('Directorio de Personas'), findsOneWidget);
    });

    testWidgets('EntryEditorDialog renders voice dictation action bar', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: EntryEditorDialog(
                contactId: 'personal',
                categoryId: 'cat_notas_personales',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header indicates personal note
      expect(find.text('Nueva Nota Personal'), findsOneWidget);

      // Voice dictation bar is present
      expect(find.text('Dictar por voz'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('PersonalNotesView header has separate "Nota Rápida" and "Nota Completa" buttons, opening QuickNoteDialog on quick note tap', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: PersonalNotesView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check both buttons exist
      expect(find.text('Nota Rápida'), findsOneWidget);
      expect(find.text('Nota Completa'), findsOneWidget);

      // Tap 'Nota Rápida'
      await tester.tap(find.text('Nota Rápida'));
      await tester.pumpAndSettle();

      // Quick note dialog is shown
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Registrar Nota'), findsOneWidget);
      expect(find.text('Grabar por voz mientras hablas'), findsOneWidget);
    });

    testWidgets('Tapping a contact in Desktop column renders ContactDetailScreen embedded and returns to directory on back', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DiarioState>.value(value: state),
            ChangeNotifierProvider<HabitosState>.value(value: HabitosState()),
          ],
          child: const MaterialApp(
            home: DiarioHomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Directorio de Personas'), findsOneWidget);
      final contactToTap = state.contacts.first;

      // Scroll into view if needed and tap the contact card
      final contactFinder = find.text(contactToTap.name).last;
      await tester.ensureVisible(contactFinder);
      await tester.tap(contactFinder);
      await tester.pumpAndSettle();

      // Now ContactDetailScreen is rendered embedded in the same column
      expect(find.byTooltip('Volver a contactos'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Volver a contactos'));
      await tester.pumpAndSettle();

      // We are back at the directory list
      expect(find.text('Directorio de Personas'), findsOneWidget);
    });

    test('DiarioContact calculates currentAge and ageOnUpcomingBirthday correctly', () {
      final now = DateTime.now();
      // Contact born 25 years ago whose birthday already passed this year
      final bdayPast = DateTime(now.year - 25, now.month - 1 > 0 ? now.month - 1 : 1, 15);
      final c1 = DiarioContact(id: 'c1', name: 'Test 1', birthdate: bdayPast);
      expect(c1.currentAge, equals(25));
      expect(c1.ageOnUpcomingBirthday, equals(26));

      // Contact born today 30 years ago
      final bdayToday = DateTime(now.year - 30, now.month, now.day);
      final c2 = DiarioContact(id: 'c2', name: 'Test 2', birthdate: bdayToday);
      expect(c2.currentAge, equals(30));
      expect(c2.daysUntilBirthday, equals(0));
      expect(c2.ageOnUpcomingBirthday, equals(30));
    });

    testWidgets('Tapping a personal note card opens EntryReaderDialog in reading mode', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      await state.addPersonalEntry(
        title: 'Nota de Prueba Lectura',
        contentText: 'Este es el contenido completo para verificar el modo lectura.',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: PersonalNotesView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on note
      await tester.tap(find.text('Nota de Prueba Lectura'));
      await tester.pumpAndSettle();

      // Check EntryReaderDialog opened with reading view elements
      expect(find.byType(EntryReaderDialog), findsOneWidget);
      expect(find.text('Personal'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(EntryReaderDialog),
          matching: find.text('Nota de Prueba Lectura'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EntryReaderDialog),
          matching: find.text('Este es el contenido completo para verificar el modo lectura.'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Editar esta nota'), findsOneWidget);
    });

    testWidgets('DiarioSearchScreen displays "Nota Personal" badge for personal entries and opens reader on tap', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      await state.addPersonalEntry(
        title: 'Nota Secreta Personal',
        contentText: 'Comprar frutas frescas hoy por la tarde',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: DiarioSearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Type query in search
      await tester.enterText(find.byType(TextField), 'frutas frescas');
      await tester.pumpAndSettle();

      // Check search result displays "Nota Personal"
      expect(find.text('Nota Personal'), findsWidgets);

      // Tap the result item
      await tester.tap(find.text('Nota Secreta Personal'));
      await tester.pumpAndSettle();

      // Check reader is opened
      expect(find.byType(EntryReaderDialog), findsOneWidget);
    });

    testWidgets('Desktop view opens endDrawer for search and templates', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DiarioState>.value(value: state),
            ChangeNotifierProvider<HabitosState>.value(value: HabitosState()),
          ],
          child: const MaterialApp(
            home: DiarioHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap search icon in AppBar
      await tester.tap(find.byTooltip('Búsqueda Global'));
      await tester.pumpAndSettle();

      // Drawer is open with DiarioSearchScreen
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(DiarioSearchScreen), findsOneWidget);

      // Close drawer
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);

      // Tap templates icon in AppBar
      await tester.tap(find.byTooltip('Modelos Reutilizables'));
      await tester.pumpAndSettle();

      // Drawer is open with TemplateManagerScreen
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Modelos Reutilizables'), findsWidgets);
    });
  });
}
