import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/notas/services/note_document_converter.dart';
import 'package:quebrado_app_flutter/rich_editor/custom_blocks.dart';
import 'package:quebrado_app_flutter/notas/models/note_block.dart';

/// Nota de ejemplo con todos los tipos de bloque del formato anterior.
List<NoteBlock> sampleBlocks() => [
      NoteBlock(type: BlockType.heading1, content: 'Acuerdos del hogar'),
      NoteBlock(type: BlockType.paragraph, content: 'Lo que hablamos el domingo.'),
      NoteBlock(type: BlockType.heading2, content: 'Tareas'),
      NoteBlock(type: BlockType.todo, content: 'Pagar arriendo', isChecked: true),
      NoteBlock(type: BlockType.todo, content: 'Comprar mercado'),
      NoteBlock(type: BlockType.bulletList, content: 'Punto uno'),
      NoteBlock(type: BlockType.numberedList, content: 'Paso uno'),
      NoteBlock(type: BlockType.heading3, content: 'Detalle'),
      NoteBlock(type: BlockType.toggle, content: 'Ver más', children: [
        NoteBlock(type: BlockType.paragraph, content: 'Este texto está dentro del desplegable.'),
        NoteBlock(type: BlockType.bulletList, content: 'En escritorio, Tab mete un bloque dentro del desplegable de arriba.'),
      ]),
      NoteBlock(type: BlockType.callout, content: 'Revisar cada mes', calloutIcon: '💡'),
      NoteBlock(type: BlockType.divider),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Conversión NoteBlock ↔ AppFlowy', () {
    test('ida y vuelta conserva tipos, textos, tareas, destacados y el contenido de los desplegables', () {
      final original = sampleBlocks();
      final document = NoteDocumentConverter.toDocument(original);
      final back = NoteDocumentConverter.fromDocument(document);

      expect(back.map((b) => b.type).toList(), original.map((b) => b.type).toList());
      expect(back.map((b) => b.content).toList(), original.map((b) => b.content).toList());
      expect(back.map((b) => b.isChecked).toList(), original.map((b) => b.isChecked).toList());

      final toggle = back.firstWhere((b) => b.type == BlockType.toggle);
      expect(toggle.children.map((c) => c.content), [
        'Este texto está dentro del desplegable.',
        'En escritorio, Tab mete un bloque dentro del desplegable de arriba.',
      ]);
      expect(back.firstWhere((b) => b.type == BlockType.callout).calloutIcon, '💡');
    });

    test('una nota vacía abre con un párrafo para empezar a escribir', () {
      final document = NoteDocumentConverter.toDocument([]);
      expect(document.root.children.single.type, ParagraphBlockKeys.type);
    });

    test('el Markdown incluye desplegables, destacados y código', () {
      final document = Document(root: pageNode(children: [
        toggleNode(text: 'Detalles', children: [paragraphNode(text: 'adentro')]),
        calloutNode(text: 'Importante', icon: '⚠️'),
        codeNode(text: 'print("hola")'),
      ]));
      final md = NoteDocumentConverter.toMarkdown(document);

      expect(md, contains('<details><summary>Detalles</summary>'));
      expect(md, contains('adentro'));
      expect(md, contains('> ⚠️ Importante'));
      expect(md, contains('```\nprint("hola")\n```'));
    });

    test('bloques sin equivalente actual no pierden su texto (código y cita)', () {
      final document = Document(root: pageNode(children: [
        codeNode(text: 'SELECT 1;'),
        Node(type: 'quote', attributes: {'delta': (Delta()..insert('una cita')).toJson()}),
      ]));
      final back = NoteDocumentConverter.fromDocument(document);
      expect(back.map((b) => b.content), ['SELECT 1;', 'una cita']);
    });
  });

  group('Enter en bloques propios', () {
    EditorState stateWith(Node node, int offset) {
      final editorState = EditorState(document: Document(root: pageNode(children: [node])));
      editorState.selection = Selection.collapsed(Position(path: [0], offset: offset));
      return editorState;
    }

    test('en código, Enter agrega un salto de línea y Enter en línea vacía final sale del bloque', () async {
      final editorState = stateWith(codeNode(text: 'a'), 1);

      expect(await codeBlockEnter.handler(editorState), isTrue);
      expect(editorState.getNodeAtPath([0])!.delta!.toPlainText(), 'a\n');

      expect(await codeBlockEnter.handler(editorState), isTrue);
      expect(editorState.getNodeAtPath([0])!.delta!.toPlainText(), 'a');
      expect(editorState.getNodeAtPath([1])!.type, ParagraphBlockKeys.type);
      expect(editorState.selection!.end.path, [1]);
    });

    test('en un desplegable abierto, Enter al final crea un bloque dentro', () async {
      final editorState = stateWith(toggleNode(text: 'Título'), 6);
      expect(await toggleBlockEnter.handler(editorState), isTrue);
      expect(editorState.getNodeAtPath([0, 0])!.type, ParagraphBlockKeys.type);
      expect(editorState.selection!.end.path, [0, 0]);
    });

    test('en un desplegable cerrado, Enter crea otro desplegable debajo', () async {
      final editorState = stateWith(toggleNode(text: 'Título', collapsed: true), 6);
      expect(await toggleBlockEnter.handler(editorState), isTrue);
      expect(editorState.getNodeAtPath([1])!.type, ToggleBlockKeys.type);
    });

    test('Enter en un desplegable vacío lo convierte en párrafo', () async {
      final editorState = stateWith(toggleNode(), 0);
      expect(await toggleBlockEnter.handler(editorState), isTrue);
      expect(editorState.getNodeAtPath([0])!.type, ParagraphBlockKeys.type);
    });

    test('el Enter propio no interfiere con otros bloques', () async {
      final editorState = stateWith(paragraphNode(text: 'hola'), 4);
      expect(await toggleBlockEnter.handler(editorState), isFalse);
      expect(await codeBlockEnter.handler(editorState), isFalse);
    });
  });
}
