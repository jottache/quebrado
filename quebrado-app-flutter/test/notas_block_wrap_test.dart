import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/notas/models/note_block.dart';
import 'package:quebrado_app_flutter/notas/widgets/note_block_widget.dart';

void main() {
  const longText =
      'Cuando viene Anabella a visitarnos nos quedamos hablando hasta muy tarde y luego nadie quiere recoger la cocina';

  Future<double> pumpBlockHeight(WidgetTester tester, BlockType type, String text) async {
    final controller = TextEditingController(text: text);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360, // ancho de celular
            child: NoteBlockWidget(
              key: ValueKey('$type-$text'),
              block: NoteBlock(type: type, content: text),
              isEditable: true,
              controller: controller,
              onDelete: () {},
              onAddBlockBelow: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.getSize(find.byType(EditableText)).height;
  }

  for (final type in [
    BlockType.heading1,
    BlockType.heading3,
    BlockType.todo,
    BlockType.bulletList,
    BlockType.numberedList,
    BlockType.toggle,
  ]) {
    testWidgets('el bloque ${type.name} con texto largo baja de línea en móvil', (tester) async {
      final oneLine = await pumpBlockHeight(tester, type, 'Corto');
      final wrapped = await pumpBlockHeight(tester, type, longText);

      expect(wrapped, greaterThan(oneLine * 1.8), reason: 'debe ocupar varias líneas en vez de desplazarse a la derecha');
      expect(tester.takeException(), isNull, reason: 'sin desbordes de layout');
    });
  }

  testWidgets('Enter en una viñeta sigue creando un bloque nuevo y no guarda el salto de línea', (tester) async {
    final controller = TextEditingController();
    var enterCount = 0;
    String? lastContent;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: NoteBlockWidget(
            block: NoteBlock(type: BlockType.bulletList, content: ''),
            isEditable: true,
            controller: controller,
            onContentChanged: (c) => lastContent = c,
            onEnterPressed: () => enterCount++,
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextFormField), '$longText\n');
    await tester.pump();

    expect(enterCount, 1);
    expect(lastContent, longText);
    expect(controller.text.contains('\n'), isFalse);
  });

  testWidgets('la acción "siguiente" del teclado del celular crea un bloque nuevo', (tester) async {
    var enterCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: NoteBlockWidget(
            block: NoteBlock(type: BlockType.todo, content: ''),
            isEditable: true,
            controller: TextEditingController(text: 'Comprar pan'),
            onEnterPressed: () => enterCount++,
          ),
        ),
      ),
    ));

    await tester.showKeyboard(find.byType(TextFormField));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(enterCount, 1);
  });
}
