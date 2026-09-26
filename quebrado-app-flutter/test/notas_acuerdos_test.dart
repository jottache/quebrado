import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';
import 'package:quebrado_app_flutter/notas/notas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notas & Acuerdos Models & State Tests', () {
    test('NoteCategory serializes and deserializes properly', () {
      final cat = NoteCategory(
        id: 'cat_test_1',
        name: 'Acuerdos de Pareja',
        icon: '💍',
        colorHex: '#EC4899',
        sortOrder: 1,
        isSystem: false,
      );

      final map = cat.toMap();
      expect(map['name'], equals('Acuerdos de Pareja'));
      expect(map['icon'], equals('💍'));
      expect(map['color_hex'], equals('#EC4899'));

      final fromMap = NoteCategory.fromMap(map);
      expect(fromMap.id, equals('cat_test_1'));
      expect(fromMap.name, equals('Acuerdos de Pareja'));
      expect(fromMap.icon, equals('💍'));
      expect(fromMap.isSystem, isFalse);
    });

    test('NoteBlock generates clean Markdown across types', () {
      final h1 = NoteBlock(type: BlockType.heading1, content: 'Reglas de Convivencia');
      expect(h1.toMarkdown(), equals('# Reglas de Convivencia\n'));

      final todo = NoteBlock(type: BlockType.todo, content: 'Comprar víveres juntos', isChecked: true);
      expect(todo.toMarkdown(), equals('- [x] Comprar víveres juntos\n'));

      final callout = NoteBlock(type: BlockType.callout, content: 'Importante hablar con calma', calloutIcon: '❤️');
      expect(callout.toMarkdown(), equals('> ❤️ Importante hablar con calma\n'));

      final toggle = NoteBlock(
        type: BlockType.toggle,
        content: 'Detalles de finanzas',
        children: [
          NoteBlock(type: BlockType.bulletList, content: 'Dividir servicios 50/50'),
        ],
      );
      expect(toggle.toMarkdown(), contains('<details><summary>Detalles de finanzas</summary>'));
      expect(toggle.toMarkdown(), contains('- Dividir servicios 50/50'));
    });

    test('NoteItem computes todoProgress accurately', () {
      final note = NoteItem(
        id: 'note_1',
        title: 'Acuerdo de Limpieza',
        icon: '🧹',
        blocks: [
          NoteBlock(type: BlockType.heading2, content: 'Tareas'),
          NoteBlock(type: BlockType.todo, content: 'Barrer sala', isChecked: true),
          NoteBlock(type: BlockType.todo, content: 'Lavar platos', isChecked: false),
          NoteBlock(type: BlockType.todo, content: 'Sacar basura', isChecked: true),
        ],
      );

      expect(note.hasTodos, isTrue);
      expect(note.todoProgress.total, equals(3));
      expect(note.todoProgress.completed, equals(2));
    });

    test('NotasState manages categories, reassigns notes on category deletion, and toggles todos', () async {
      final state = NotasState();
      await state.loadAll();

      // Debe cargar las categorías por defecto
      expect(state.categories.length, greaterThanOrEqualTo(4));
      final generalCat = state.defaultCategory;
      expect(generalCat, isNotNull);
      expect(generalCat!.isSystem, isTrue);

      // Crear una categoría personalizada
      final customCat = await state.addCategory(
        name: 'Proyectos 2027',
        icon: '🚀',
        colorHex: '#3B82F6',
      );
      expect(state.categories.any((c) => c.id == customCat.id), isTrue);

      // Crear una nota en esa categoría personalizada
      final note = await state.createNote(
        title: 'Lanzamiento SaaS',
        categoryId: customCat.id,
        blocks: [
          NoteBlock(id: 'block_todo_1', type: BlockType.todo, content: 'Comprar dominio', isChecked: false),
        ],
      );

      expect(note.categoryId, equals(customCat.id));
      expect(state.countNotesInCategory(customCat.id), equals(1));

      // Alternar el checkbox del todo
      await state.toggleTodoBlock(note.id, 'block_todo_1');
      final updatedNote = state.getNoteById(note.id);
      expect(updatedNote?.blocks.first.isChecked, isTrue);

      // Eliminar la categoría personalizada:
      // LA NOTA NO SE PIERDE, se reasigna automáticamente a la categoría por defecto 'General'
      await state.deleteCategory(customCat.id);

      expect(state.categories.any((c) => c.id == customCat.id), isFalse);
      final rescuedNote = state.getNoteById(note.id);
      expect(rescuedNote, isNotNull);
      expect(rescuedNote!.categoryId, equals(generalCat.id));
      expect(state.countNotesInCategory(generalCat.id), greaterThanOrEqualTo(1));
    });

    test('Diario cross-mentions: extractMentionedNoteIds and MentionTextSpanHelper buildSpans for #Notas', () {
      final note1 = NoteItem(
        id: 'note_acuerdo_1',
        title: 'Acuerdo de Convivencia',
        categoryId: 'cat_acuerdos',
        blocks: [NoteBlock(type: BlockType.heading1, content: 'Reglas')],
      );
      final note2 = NoteItem(
        id: 'note_idea_2',
        title: 'App de Mascotas',
        categoryId: 'cat_ideas',
        blocks: [],
      );
      final notes = [note1, note2];

      // 1. Detección con DiarioState
      final text = 'Hoy acordamos seguir el #Acuerdo de Convivencia y además evaluar la #App de Mascotas con el equipo.';
      final mentionedIds = DiarioState.parseMentionedNoteIds(text, notes);
      expect(mentionedIds, contains('note_acuerdo_1'));
      expect(mentionedIds, contains('note_idea_2'));
      expect(mentionedIds.length, equals(2));

      expect(DiarioState.checkNoteMentionedInText(note1, text), isTrue);
      expect(DiarioState.checkNoteMentionedInText(note2, text), isTrue);

      final otherNote = NoteItem(id: 'note_other', title: 'Viaje a Roma', categoryId: 'cat_ideas', blocks: []);
      expect(DiarioState.checkNoteMentionedInText(otherNote, text), isFalse);

      // 2. Construcción de Spans interactivos
      NoteItem? tappedNote;
      final spans = MentionTextSpanHelper.buildSpans(
        text: text,
        contacts: [],
        notes: notes,
        baseStyle: const TextStyle(fontSize: 14),
        onNoteTap: (note) {
          tappedNote = note;
        },
      );

      expect(spans.length, greaterThan(1));
      // Buscar el span que contiene '#Acuerdo de Convivencia'
      final noteSpan = spans.firstWhere(
        (s) => s is TextSpan && s.text == '#Acuerdo de Convivencia',
      ) as TextSpan;

      expect(noteSpan.style?.color, equals(NotasColors.primary));
      expect(noteSpan.recognizer, isNotNull);

      // Simular tap en el span de la nota
      (noteSpan.recognizer as TapGestureRecognizer).onTap?.call();
      expect(tappedNote, isNotNull);
      expect(tappedNote!.id, equals('note_acuerdo_1'));
    });

    testWidgets('Desktop modal opens as dialog with 90% width and 90% height', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notasState = NotasState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notasState,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      NoteEditorScreen.open(context);
                    },
                    child: const Text('Crear Nota'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Abrir el editor en desktop
      await tester.tap(find.text('Crear Nota'));
      await tester.pumpAndSettle();

      // Debe abrir un Dialog
      expect(find.byType(Dialog), findsOneWidget);

      // Verificar que el contenedor del modal tiene un tamaño del 90% (1080 x 720)
      final containerFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      // NoteEditorScreen debe estar renderizado dentro del Dialog con isModalDialog = true
      final editor = tester.widget<NoteEditorScreen>(find.byType(NoteEditorScreen));
      expect(editor.isModalDialog, isTrue);

      // El botón de cerrar (leading) debe ser close_rounded en el modal
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('NoteBlockWidget renders plus button to add component below', (tester) async {
      bool addBelowCalled = false;
      BlockType? addedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteBlockWidget(
              block: NoteBlock(
                id: 'b1',
                type: BlockType.heading1,
                content: 'Título de prueba',
              ),
              isEditable: true,
              onAddBlockBelowWithType: (type) {
                addBelowCalled = true;
                addedType = type;
              },
            ),
          ),
        ),
      );

      // Debe tener el botón (+) redondo y sutil para agregar abajo
      expect(find.byTooltip('Agregar bloque abajo'), findsOneWidget);

      // Abrir el popup de agregar abajo
      await tester.tap(find.byTooltip('Agregar bloque abajo'));
      await tester.pumpAndSettle();

      // Debe mostrar las opciones de componentes
      expect(find.text('Párrafo de texto'), findsOneWidget);
      expect(find.text('Tarea checklist'), findsOneWidget);
      expect(find.text('Desplegable'), findsOneWidget);

      // Seleccionar Tarea checklist
      await tester.tap(find.text('Tarea checklist'));
      await tester.pumpAndSettle();

      expect(addBelowCalled, isTrue);
      expect(addedType, equals(BlockType.todo));
    });

    testWidgets('Pressing enter in H1 block creates a paragraph below', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notasState = NotasState();
      final initialNote = NoteItem(
        id: 'test_note_enter',
        title: 'Mi Acuerdo',
        blocks: [
          NoteBlock(id: 'h1_block', type: BlockType.heading1, content: 'Regla 1'),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notasState,
          child: MaterialApp(
            home: NoteEditorScreen(note: initialNote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe haber inicialmente 1 bloque (el H1)
      expect(find.text('Regla 1'), findsOneWidget);

      // Enfocar el campo de texto del H1
      await tester.tap(find.text('Regla 1'));
      await tester.pumpAndSettle();

      // Simular submit / enter en el TextFormField del H1
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Debe haberse agregado un nuevo bloque de tipo párrafo (con hintText 'Escribe algo...')
      expect(find.text('Escribe algo...'), findsOneWidget);
    });

    testWidgets('Pressing enter in todo block creates another todo block below', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notasState = NotasState();
      final initialNote = NoteItem(
        id: 'test_note_enter_todo',
        title: 'Checklist',
        blocks: [
          NoteBlock(id: 'todo_1', type: BlockType.todo, content: 'Pagar arriendo'),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notasState,
          child: MaterialApp(
            home: NoteEditorScreen(note: initialNote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pagar arriendo'), findsOneWidget);

      // Simular Enter en el todo
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Debe haber ahora 2 tareas (la primera con texto y la segunda vacía con hintText 'Tarea pendiente...')
      expect(find.text('Tarea pendiente...'), findsOneWidget);
    });

    testWidgets('Toggle supports children of all types and enter continues inside toggle', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notasState = NotasState();
      final initialNote = NoteItem(
        id: 'test_note_toggle',
        title: 'Acuerdo con Desplegable',
        blocks: [
          NoteBlock(
            id: 'toggle_block_1',
            type: BlockType.toggle,
            content: 'Sección Desplegable',
            children: [
              NoteBlock(
                id: 'toggle_child_1',
                type: BlockType.bulletList,
                content: 'Primer punto dentro del desplegable',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notasState,
          child: MaterialApp(
            home: NoteEditorScreen(note: initialNote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el título del desplegable y su hijo
      expect(find.text('Sección Desplegable'), findsOneWidget);
      expect(find.text('Primer punto dentro del desplegable'), findsOneWidget);

      // Debe mostrar el botón para agregar elemento dentro del desplegable
      expect(find.text('Agregar dentro'), findsOneWidget);

      // Enfocar el hijo bullet list y presionar enter
      await tester.tap(find.text('Primer punto dentro del desplegable'));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Debe haber creado otro elemento de lista con viñetas dentro del desplegable
      expect(find.text('Elemento de lista...'), findsWidgets);
    });
  });
}

