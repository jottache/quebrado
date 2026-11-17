import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';
import 'package:quebrado_app_flutter/diario/dialogs/quick_note_dialog.dart';
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart';
import 'package:quebrado_app_flutter/notas/services/note_document_converter.dart';
import 'package:quebrado_app_flutter/notas/notas.dart';
import 'package:quebrado_app_flutter/rich_editor/block_menu.dart';
import 'package:quebrado_app_flutter/rich_editor/dictation.dart';
import 'package:quebrado_app_flutter/rich_editor/draft_store.dart';
import 'package:quebrado_app_flutter/rich_editor/mentions.dart';

class MemoryDraftBackend implements DraftBackend {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// El editor carga sus textos y el borrador de forma asíncrona (real).
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

EditorState editorOf(WidgetTester tester) => tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// Escribe al final del primer bloque de texto y espera el autoguardado del borrador.
Future<void> typeInEditor(WidgetTester tester, String text) async {
  final editorState = editorOf(tester);
  final node = editorState.document.root.children.firstWhere((n) => n.delta != null);
  final transaction = editorState.transaction..insertText(node, node.delta!.length, text);
  await editorState.apply(transaction);
  await tester.pump(const Duration(seconds: 1)); // retraso del autoguardado
  await tester.pump();
}

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryDraftBackend drafts;

  setUp(() {
    drafts = MemoryDraftBackend();
    DraftStore.instance = DraftStore(backend: drafts);
  });

  group('Editor de Notas', () {
    Widget host(NotasState notasState, {NoteItem? note}) => ChangeNotifierProvider.value(
          value: notasState,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NoteEditorScreen.open(context, note: note),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

    testWidgets('en escritorio abre como modal del 90 % con el editor enriquecido', (tester) async {
      setSize(tester, const Size(1200, 800));
      await tester.pumpWidget(host(NotasState()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.getSize(find.byType(NoteEditorScreen)), const Size(1080, 720));
      expect(find.byType(AppFlowyEditor), findsOneWidget);
      expect(find.byType(FloatingToolbar), findsOneWidget, reason: 'barra de formato estilo Notion');
      expect(tester.takeException(), isNull);
    });

    testWidgets('una nota del formato anterior se abre con todos sus bloques', (tester) async {
      setSize(tester, const Size(1200, 800));
      final note = NoteItem(
        id: 'legacy',
        title: 'Mi Acuerdo',
        blocks: [
          NoteBlock(type: BlockType.heading1, content: 'Regla 1'),
          NoteBlock(type: BlockType.todo, content: 'Pagar arriendo'),
          NoteBlock(type: BlockType.toggle, content: 'Sección Desplegable', children: [
            NoteBlock(type: BlockType.bulletList, content: 'Primer punto dentro'),
          ]),
        ],
      );
      await tester.pumpWidget(host(NotasState(), note: note));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      for (final text in ['Regla 1', 'Pagar arriendo', 'Sección Desplegable', 'Primer punto dentro']) {
        expect(find.textContaining(text, findRichText: true), findsWidgets, reason: text);
      }
      final root = editorOf(tester).document.root;
      expect(root.children.map((n) => n.type).toList(), ['heading', 'todo_list', 'toggle_list']);
      expect(root.children.last.children.single.type, 'bulleted_list');
    });

    testWidgets('guardar persiste el documento, los bloques derivados y el texto; y borra el borrador',
        (tester) async {
      setSize(tester, const Size(1200, 800));
      final notasState = NotasState();
      await tester.pumpWidget(host(notasState));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('note_title_field')), 'Plan semanal');
      await typeInEditor(tester, 'Llamar al banco');
      expect(drafts.values.keys, contains('draft:nota:new'));

      await tester.tap(find.text('Guardar'));
      await settle(tester);

      final saved = notasState.notes.single;
      expect(saved.title, 'Plan semanal');
      expect(saved.hasRichDocument, isTrue);
      expect(saved.blocks.map((b) => b.content), contains('Llamar al banco'));
      expect(saved.contentText, contains('Llamar al banco'));
      expect(drafts.values, isEmpty, reason: 'al guardar se descarta el borrador');
      expect(find.byType(NoteEditorScreen), findsNothing);
    });

    testWidgets('si se cierra sin guardar, al volver a abrir recupera el borrador y se puede descartar',
        (tester) async {
      setSize(tester, const Size(1200, 800));
      final notasState = NotasState();
      await tester.pumpWidget(host(notasState));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('note_title_field')), 'Ideas');
      await typeInEditor(tester, 'Texto que no quiero perder');

      await tester.tap(find.byTooltip('Cerrar modal'));
      await settle(tester);
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(find.textContaining('Borrador guardado'), findsOneWidget);
      expect(notasState.notes, isEmpty, reason: 'no se creó la nota');

      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ideas'), findsOneWidget);
      expect(find.textContaining('Texto que no quiero perder', findRichText: true), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('draft_discard_button')));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsNothing);
      expect(find.textContaining('Texto que no quiero perder', findRichText: true), findsNothing);
      expect(drafts.values, isEmpty);
    });

    testWidgets('Escape cierra el modal desde el título, desde el editor y sin foco, y conserva el borrador',
        (tester) async {
      setSize(tester, const Size(1200, 800));
      await tester.pumpWidget(host(NotasState()));

      // 1) Foco en el título
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('note_title_field')), 'Con Escape');
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(find.textContaining('Borrador guardado'), findsOneWidget);
      expect(drafts.values.keys, contains('draft:nota:new'));

      // 2) Cursor dentro del editor (AppFlowy usa Escape para quitar la selección)
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      await typeInEditor(tester, 'texto');
      final editorState = editorOf(tester);
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 1));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(NoteEditorScreen), findsNothing);

      // 3) Sin foco en ningún campo
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escape con el menú "/" abierto cierra solo el menú', (tester) async {
      setSize(tester, const Size(1200, 800));
      await tester.pumpWidget(host(NotasState()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      final editorState = editorOf(tester);
      editorState.selection = Selection.collapsed(Position(path: [0]));
      await tester.pump();
      // Igual que escribir "/" en el editor
      await customSlashCommand(slashMenuItems).handler(editorState);
      await settle(tester);
      expect(find.text('Título 2'), findsWidgets, reason: 'menú de bloques abierto');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Título 2'), findsNothing);
      expect(find.byType(NoteEditorScreen), findsOneWidget, reason: 'el modal sigue abierto');
    });

    testWidgets('Cancelar cierra y borra el borrador; "Deshacer" lo recupera', (tester) async {
      setSize(tester, const Size(1200, 800));
      await tester.pumpWidget(host(NotasState()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('note_title_field')), 'Descartable');
      await typeInEditor(tester, 'no lo quiero');
      expect(drafts.values, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('note_editor_cancel')));
      await settle(tester);
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(drafts.values, isEmpty, reason: 'Cancelar descarta el borrador');
      expect(find.textContaining('Borrador descartado'), findsOneWidget);
      expect(find.textContaining('Borrador guardado'), findsNothing);

      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect(drafts.values.keys, contains('draft:nota:new'));

      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Descartable'), findsOneWidget);
    });

    testWidgets('el aviso "Borrador descartado" se cierra solo', (tester) async {
      setSize(tester, const Size(1200, 800));
      await tester.pumpWidget(host(NotasState()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      await typeInEditor(tester, 'algo');
      await tester.tap(find.byKey(const ValueKey('note_editor_cancel')));
      await settle(tester);
      expect(find.textContaining('Borrador descartado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.textContaining('Borrador descartado'), findsNothing);
    });

    testWidgets('un borrador más viejo que la nota guardada se ignora', (tester) async {
      setSize(tester, const Size(1200, 800));
      final note = NoteItem(
        id: 'n1',
        title: 'Guardada',
        blocks: [NoteBlock(type: BlockType.paragraph, content: 'versión guardada')],
        updatedAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      await DraftStore.instance.save('nota:n1', {
        'title': 'Vieja',
        'document': NoteDocumentConverter.toDocument([NoteBlock(type: BlockType.paragraph, content: 'borrador viejo')]).toJson(),
      });

      await tester.pumpWidget(host(NotasState(), note: note));
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsNothing);
      expect(find.textContaining('versión guardada', findRichText: true), findsWidgets);
      expect(drafts.values, isEmpty);
    });

    testWidgets('el lector muestra el documento y permite marcar tareas', (tester) async {
      setSize(tester, const Size(1200, 900));
      final notasState = NotasState();
      final document = Document(root: pageNode(children: [
        paragraphNode(delta: Delta()..insert('Lista ')..insert('importante', attributes: {'bold': true})),
        todoListNode(checked: false, text: 'Pagar luz'),
      ])).toJson();
      final note = await notasState.createNote(title: 'Pendientes', document: document);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notasState),
          ChangeNotifierProvider(create: (_) => DiarioState()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => NoteReaderDialog.show(context, note: note),
                child: const Text('Leer'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Leer'));
      await settle(tester);

      expect(find.textContaining('importante', findRichText: true), findsWidgets);
      await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
      await settle(tester);

      final updated = notasState.notes.single;
      final todo = Document.fromJson(updated.document!).root.children.last;
      expect(todo.attributes['checked'], isTrue);
      expect(updated.blocks.last.isChecked, isTrue, reason: 'los bloques derivados también se actualizan');
      expect(tester.takeException(), isNull);
    });
  });

  group('Editores de Diario', () {
    late DiarioState diarioState;
    late NotasState notasState;

    Widget host(Widget Function() dialog) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: diarioState),
            ChangeNotifierProvider.value(value: notasState),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showDialog(context: context, builder: (_) => dialog()),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

    setUp(() {
      diarioState = DiarioState();
      notasState = NotasState();
    });

    testWidgets('el registro ocupa el 90 % en escritorio y guarda documento + texto plano', (tester) async {
      setSize(tester, const Size(1400, 900));
      await tester.pumpWidget(host(() => const EntryEditorDialog(contactId: 'c1', categoryId: 'cat_gustos')));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      final dialogBox = find.descendant(of: find.byType(Dialog), matching: find.byType(SizedBox)).first;
      expect(tester.getSize(dialogBox), const Size(1260, 810));
      expect(find.byType(AppFlowyEditor), findsOneWidget);
      expect(find.text('Modelo / Plantilla'), findsOneWidget, reason: 'panel de detalles a la derecha');
      expect(find.byKey(const ValueKey('diario_dictation_button')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('diario_entry_title')), 'Cena');
      await typeInEditor(tester, 'Le encanta la pasta');
      await tester.tap(find.byKey(const ValueKey('diario_entry_save')));
      await settle(tester);

      final entry = diarioState.entries.firstWhere((e) => e.title == 'Cena');
      expect(entry.contactId, 'c1');
      expect(entry.contentText, 'Le encanta la pasta');
      expect(entry.hasRichDocument, isTrue);
      expect(entry.contentData.containsKey('rich_document'), isFalse);
      expect(drafts.values, isEmpty);
      expect(find.byType(EntryEditorDialog), findsNothing);
    });

    testWidgets('al cerrar sin guardar queda el borrador del mismo contacto y sección', (tester) async {
      setSize(tester, const Size(1400, 900));
      var contactId = 'c1';
      await tester.pumpWidget(host(() => EntryEditorDialog(contactId: contactId, categoryId: 'cat_gustos')));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('diario_entry_title')), 'Regalo');
      await typeInEditor(tester, 'Un libro de cocina');
      await tester.tap(find.byTooltip('Cerrar (se guarda como borrador)'));
      await settle(tester);
      expect(find.textContaining('Borrador guardado'), findsOneWidget);
      expect(diarioState.entries.where((e) => e.title == 'Regalo'), isEmpty);

      // Otro contacto: empieza en blanco
      contactId = 'c2';
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsNothing);
      await tester.tap(find.byTooltip('Cerrar (se guarda como borrador)'));
      await settle(tester);

      // El mismo contacto: recupera lo escrito
      contactId = 'c1';
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Regalo'), findsOneWidget);
      expect(find.textContaining('Un libro de cocina', findRichText: true), findsWidgets);
    });

    testWidgets('Escape cierra la entrada conservando el borrador y Cancelar lo borra', (tester) async {
      setSize(tester, const Size(1400, 900));
      await tester.pumpWidget(host(() => const EntryEditorDialog(contactId: 'c1', categoryId: 'cat_gustos')));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await typeInEditor(tester, 'Le gusta el té');
      final editorState = editorOf(tester);
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 2));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(EntryEditorDialog), findsNothing);
      expect(drafts.values.keys, contains('draft:diario:new:c1:cat_gustos'));

      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('diario_entry_cancel')));
      await settle(tester);
      expect(find.byType(EntryEditorDialog), findsNothing);
      expect(drafts.values, isEmpty);
      expect(find.textContaining('Borrador descartado'), findsOneWidget);
    });

    testWidgets('la nota rápida se cierra con Escape y Cancelar borra su borrador', (tester) async {
      setSize(tester, const Size(1400, 900));
      await tester.pumpWidget(host(() => const QuickNoteDialog()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);
      await typeInEditor(tester, 'pensamiento');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(QuickNoteDialog), findsNothing);
      expect(drafts.values.keys, contains('draft:diario:quick'));

      await tester.tap(find.text('Abrir'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('quick_note_cancel')));
      await settle(tester);
      expect(find.byType(QuickNoteDialog), findsNothing);
      expect(drafts.values, isEmpty);
    });

    testWidgets('editar una entrada antigua de solo texto la abre en el editor', (tester) async {
      setSize(tester, const Size(1400, 900));
      final entry = DiarioEntry(
        id: 'old',
        contactId: 'c1',
        categoryId: 'cat_gustos',
        title: 'Antigua',
        contentText: 'Primera línea\nSegunda línea',
      );
      await tester.pumpWidget(host(() => EntryEditorDialog(entry: entry)));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(editorOf(tester).document.root.children.length, 2);
      expect(find.textContaining('Segunda línea', findRichText: true), findsWidgets);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsNothing);
    });

    testWidgets('en móvil ocupa toda la pantalla y los detalles van plegados', (tester) async {
      setSize(tester, const Size(400, 850));
      await tester.pumpWidget(host(() => const EntryEditorDialog(contactId: 'c1', categoryId: 'cat_gustos')));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(tester.getSize(find.byType(EntryEditorDialog)), const Size(400, 850));
      expect(find.byType(AppFlowyEditor), findsOneWidget);
      expect(find.text('Modelo / Plantilla'), findsNothing);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      expect(find.text('Modelo / Plantilla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la nota rápida es grande, guarda el documento y también tiene borrador', (tester) async {
      setSize(tester, const Size(1400, 900));
      await tester.pumpWidget(host(() => const QuickNoteDialog()));
      await tester.tap(find.text('Abrir'));
      await settle(tester);

      final dialogBox = find.descendant(of: find.byType(Dialog), matching: find.byType(SizedBox)).first;
      expect(tester.getSize(dialogBox), const Size(1260, 810));

      await typeInEditor(tester, 'Idea para el fin de semana');
      expect(drafts.values.keys, contains('draft:diario:quick'));
      await tester.tap(find.byTooltip('Cerrar (se guarda como borrador)'));
      await settle(tester);

      await tester.tap(find.text('Abrir'));
      await settle(tester);
      expect(find.byKey(const ValueKey('draft_restored_banner')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quick_note_save')));
      await settle(tester);
      final entry = diarioState.entries.firstWhere((e) => e.contentText == 'Idea para el fin de semana');
      expect(entry.contactId, 'personal');
      expect(entry.hasRichDocument, isTrue);
      expect(drafts.values, isEmpty);
    });
  });

  group('Menciones y dictado', () {
    test('elegir una mención reemplaza lo escrito desde @ y la resalta', () async {
      final editorState = EditorState(document: Document(root: pageNode(children: [paragraphNode(text: 'Cena con @An')])));
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 12));

      await insertMention(editorState, '@', const MentionOption(id: 'c1', label: 'Ana López'));

      final delta = editorState.getNodeAtPath([0])!.delta!;
      expect(delta.toPlainText(), 'Cena con @Ana López ');
      final mention = delta.toList().cast<TextInsert>().firstWhere((op) => op.text == '@Ana López');
      expect(mention.attributes?['bold'], isTrue);
      expect(delta.toList().cast<TextInsert>().last.attributes, anyOf(isNull, isEmpty),
          reason: 'lo que se escribe después ya no sale resaltado');
    });

    test('el dictado reemplaza los resultados parciales en vez de duplicarlos', () async {
      final editorState = EditorState(document: Document(root: pageNode(children: [paragraphNode(text: 'Hoy')])));
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 3));
      final session = EditorDictationSession(editorState);

      await session.update('fui');
      await session.update('fui al');
      await session.update('fui al parque');
      expect(editorState.getNodeAtPath([0])!.delta!.toPlainText(), 'Hoy fui al parque');
    });
  });
}
