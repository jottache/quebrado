import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/notas_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/notas/models/note_category.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sin Supabase, NotasState usa las categorías por defecto en memoria.
  Future<(NotasState, NotasWriteTools)> preparar() async {
    final notas = NotasState();
    await notas.loadAll();
    return (notas, NotasWriteTools(notas));
  }

  const tool = WriteToolNames.createNote;

  test('CA-09: un acuerdo se guarda en la categoría de acuerdos con su texto y se deshace', () async {
    final (notas, tools) = await preparar();
    const texto = 'Los domingos cocinamos juntos\nY lavamos los platos por turnos';

    final out = await tools.execute(tool, {'text': texto, 'kind': 'acuerdo'}, WriteContext(userText: 'anota un acuerdo: $texto'));

    expect(out.result.isSaved, isTrue, reason: out.result.toString());
    final note = notas.notes.singleWhere((n) => n.id == out.result.recordId);
    expect(note.categoryId, NoteCategory.acuerdosCategoryId);
    expect(note.contentText, texto);
    expect(note.blocks.map((b) => b.content), ['Los domingos cocinamos juntos', 'Y lavamos los platos por turnos']);
    expect(note.title, 'Los domingos cocinamos juntos');
    expect(out.result.route, SuiteRoutes.nota(note.id));
    expect(out.result.undoId, isNotNull);
    expect(out.summaryParts.map((p) => p.text), ['Acuerdo', 'Acuerdos de Pareja']);
    expect(out.result.summary, 'Los domingos cocinamos juntos · Acuerdo · Acuerdos de Pareja');

    await tools.undo(tool, out.undoPayload!);
    expect(notas.notes.any((n) => n.id == note.id), isFalse);
  });

  test('una nota sin categoría va a la categoría predeterminada con el título dado', () async {
    final (notas, tools) = await preparar();

    final out = await tools.execute(tool, {'text': 'Comprar bombillos', 'title': 'Casa'}, WriteContext());

    expect(out.result.isSaved, isTrue);
    final note = notas.notes.singleWhere((n) => n.id == out.result.recordId);
    expect(note.categoryId, NoteCategory.generalCategoryId);
    expect(note.title, 'Casa');
    expect(out.summaryParts.first.text, 'Nota');
  });

  test('sin texto devuelve missing [text] y no guarda nada', () async {
    final (notas, tools) = await preparar();

    final out = await tools.execute(tool, {'title': 'Algo'}, WriteContext());

    expect(out.result.isMissing, isTrue);
    expect(out.result.missing, ['text']);
    expect(notas.notes, isEmpty);
  });

  test('categoría inexistente: tarjeta con opciones; al confirmar sin elegir sigue faltando y eligiendo se guarda', () async {
    final (notas, tools) = await preparar();

    final out = await tools.execute(tool, {'text': 'Arepas con queso', 'categoryName': 'Recetas'}, WriteContext());

    expect(out.result.isProposal, isTrue);
    expect(out.result.reasons, ['category_not_found']);
    expect(out.result.options['categoryName'], hasLength(3));
    expect(notas.notes, isEmpty);

    final confirmed = WriteContext().copyWith(confirmedByUser: true);
    final sinElegir = await tools.execute(tool, out.commitArgs!, confirmed);
    expect(sinElegir.result.isMissing, isTrue);
    expect(sinElegir.result.missing, ['categoryName']);
    expect(notas.notes, isEmpty);

    final eligiendo = await tools.execute(tool, {...out.commitArgs!, 'categoryName': 'Ideas & Proyectos'}, confirmed);
    expect(eligiendo.result.isSaved, isTrue);
    expect(notas.notes.single.categoryId, NoteCategory.ideasCategoryId);
  });

  test('si en el turno se leyó texto libre, sale como tarjeta aunque todo esté claro', () async {
    final (notas, tools) = await preparar();

    final out = await tools.execute(tool, {'text': 'Algo', 'kind': 'acuerdo'}, WriteContext(untrustedRead: true));

    expect(out.result.isProposal, isTrue);
    expect(out.result.reasons, ['read_untrusted_text']);
    expect(notas.notes, isEmpty);
  });

  test('deshacer sin id de nota lanza', () async {
    final (_, tools) = await preparar();
    await expectLater(tools.undo(tool, {}), throwsStateError);
  });
}
