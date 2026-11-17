import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/rich_editor/custom_blocks.dart';
import 'package:quebrado_app_flutter/rich_editor/format_toolbar.dart';
import 'package:quebrado_app_flutter/rich_editor/rich_document_editor.dart';

EditorState _stateWithText(String text, {int start = 0, int? end}) {
  final editorState = EditorState(document: Document(root: pageNode(children: [paragraphNode(text: text)])));
  editorState.selection = Selection(
    start: Position(path: [0], offset: start),
    end: Position(path: [0], offset: end ?? text.length),
  );
  return editorState;
}

Map<String, dynamic>? _attrsOfFirstInsert(EditorState s) =>
    (s.getNodeAtPath([0])!.delta!.first as TextInsert).attributes;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Acciones de formato', () {
    test('negrita se activa y se desactiva sobre la selección', () async {
      final s = _stateWithText('hola mundo');
      expect(NoteFormatActions.isMarkActive(s, AppFlowyRichTextKeys.bold), isFalse);

      await NoteFormatActions.toggleMark(s, AppFlowyRichTextKeys.bold);
      expect(_attrsOfFirstInsert(s)?['bold'], isTrue);
      expect(NoteFormatActions.isMarkActive(s, AppFlowyRichTextKeys.bold), isTrue);

      await NoteFormatActions.toggleMark(s, AppFlowyRichTextKeys.bold);
      expect(NoteFormatActions.isMarkActive(s, AppFlowyRichTextKeys.bold), isFalse);
    });

    test('colores de texto y fondo se guardan y se leen', () async {
      final s = _stateWithText('importante');
      final rojo = noteTextColors.firstWhere((c) => c.label == 'Rojo');
      final amarillo = noteBackgroundColors.firstWhere((c) => c.label == 'Amarillo');

      await NoteFormatActions.setColor(s, s.selection!, text: rojo.hex);
      await NoteFormatActions.setColor(s, s.selection!, background: amarillo.hex);

      expect(NoteFormatActions.sharedValue(s, AppFlowyRichTextKeys.textColor), rojo.hex);
      expect(NoteFormatActions.sharedValue(s, AppFlowyRichTextKeys.backgroundColor), amarillo.hex);
      expect(rojo.hex.tryToColor(), rojo.color, reason: 'el editor debe poder pintar el color guardado');
    });

    test('quitar formato limpia marcas, colores y enlaces', () async {
      final s = _stateWithText('texto');
      await NoteFormatActions.toggleMark(s, AppFlowyRichTextKeys.bold);
      await NoteFormatActions.toggleMark(s, AppFlowyRichTextKeys.italic);
      await NoteFormatActions.setColor(s, s.selection!, text: noteTextColors.first.hex);
      await s.formatDelta(s.selection, {AppFlowyRichTextKeys.href: 'https://ejemplo.com'});
      expect(NoteFormatButton.link.isActive(s), isTrue);

      await NoteFormatActions.clearFormatting(s);
      final attrs = _attrsOfFirstInsert(s) ?? {};
      expect(attrs.values.where((v) => v != null), isEmpty);
      expect(NoteFormatButton.link.isActive(s), isFalse);
    });

    test('sin texto seleccionado no hace nada', () async {
      final s = _stateWithText('hola');
      s.selection = Selection.collapsed(Position(path: [0], offset: 2));
      await NoteFormatActions.toggleMark(s, AppFlowyRichTextKeys.bold);
      expect(_attrsOfFirstInsert(s)?['bold'], isNull);
    });

    test('se puede dar formato dentro de desplegables y destacados', () {
      registerFormatToolbarBlocks();
      expect(toolbarItemWhiteList, containsAll([ToggleBlockKeys.type, CalloutBlockKeys.type]));
      expect(toolbarItemWhiteList.contains(CodeBlockKeys.type), isFalse);
    });

    test('la barra de escritorio tiene los botones estilo Notion en orden', () {
      expect(notionToolbarItems().map((i) => i.id).toList(), [
        'note_format.color',
        'note_format.bold',
        'note_format.italic',
        'note_format.underline',
        'note_format.clear',
        'note_format.link',
        'note_format.strikethrough',
        'note_format.code',
        'note_format.more',
      ]);
    });
  });

  group('Barra móvil', () {
    testWidgets('muestra los 9 botones y marca negrita al tocarla', (tester) async {
      final s = _stateWithText('hola mundo');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: NoteFormatBar(editorState: s)))));

      for (final b in NoteFormatButton.values) {
        expect(find.byKey(ValueKey('note_format_${b.name}')), findsOneWidget, reason: b.name);
      }

      await tester.tap(find.byKey(const ValueKey('note_format_bold')));
      await tester.pumpAndSettle();
      expect(NoteFormatActions.isMarkActive(s, AppFlowyRichTextKeys.bold), isTrue);

      final boldMaterial = tester.widget<Material>(
        find.ancestor(of: find.byKey(const ValueKey('note_format_bold')), matching: find.byType(Material)).first,
      );
      expect(boldMaterial.color, isNot(Colors.transparent), reason: 'el botón activo se resalta');
    });
  });

  group('Barra flotante de escritorio', () {
    testWidgets('aparece al seleccionar texto con los botones nuevos', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final host = EditorState(
        document: Document(root: pageNode(children: [
          headingNode(level: 1, text: 'Prueba'),
          paragraphNode(text: 'Bienvenido al editor enriquecido'),
          toggleNode(text: 'Desplegable', children: [paragraphNode(text: 'dentro')]),
          calloutNode(text: 'Destacado'),
        ])),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RichDocumentEditor(editorState: host))));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Seleccionar el párrafo de bienvenida (bloque [1])
      final editorState = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;
      editorState.selection = Selection(
        start: Position(path: [1], offset: 0),
        end: Position(path: [1], offset: 10),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const ValueKey('note_format_bold')), findsOneWidget);
      expect(find.byKey(const ValueKey('note_format_color')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('note_format_italic')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(NoteFormatActions.isMarkActive(editorState, AppFlowyRichTextKeys.italic), isTrue);
    });
  });
}
