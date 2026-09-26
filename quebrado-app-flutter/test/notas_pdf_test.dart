import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/notas/models/note_item.dart';
import 'package:quebrado_app_flutter/notas/models/note_category.dart';
import 'package:quebrado_app_flutter/notas/models/note_block.dart';
import 'package:quebrado_app_flutter/notas/services/note_pdf_service.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/notas/dialogs/note_reader_dialog.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotePdfService Tests', () {
    test('generateNotePdf generates valid PDF bytes with all block types', () async {
      final category = NoteCategory(
        id: 'cat_test_1',
        name: 'Acuerdos de Pareja',
        icon: '💍',
        colorHex: '#EC4899',
      );

      final blocks = [
        NoteBlock(type: BlockType.heading1, content: 'Acuerdo de Convivencia'),
        NoteBlock(type: BlockType.paragraph, content: 'Este documento resume nuestros acuerdos principales.'),
        NoteBlock(type: BlockType.heading2, content: '1. Compromisos Semanales'),
        NoteBlock(type: BlockType.todo, content: 'Cita romántica los viernes', isChecked: true),
        NoteBlock(type: BlockType.todo, content: 'Organizar las compras del súper los domingos', isChecked: false),
        NoteBlock(type: BlockType.heading3, content: 'Detalles y Reglas'),
        NoteBlock(type: BlockType.bulletList, content: 'Respetar los tiempos de trabajo'),
        NoteBlock(type: BlockType.numberedList, content: 'Primer punto clave'),
        NoteBlock(type: BlockType.numberedList, content: 'Segundo punto clave'),
        NoteBlock(
          type: BlockType.toggle,
          content: 'Planes para vacaciones',
          children: [
            NoteBlock(type: BlockType.paragraph, content: 'Destino preferido: Playa'),
            NoteBlock(type: BlockType.todo, content: 'Averiguar pasajes', isChecked: false),
          ],
        ),
        NoteBlock(type: BlockType.callout, content: 'Nota importante: La comunicación es la base.'),
        NoteBlock(type: BlockType.divider),
      ];

      final note = NoteItem(
        id: 'note_test_1',
        title: 'Nuestros Acuerdos 2026',
        icon: '💍',
        colorHex: '#EC4899',
        blocks: blocks,
        sharedTag: 'pareja',
        isPinned: true,
      );

      final pdfBytes = await NotePdfService.instance.generateNotePdf(
        note: note,
        category: category,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Validar encabezado mágico del formato PDF: "%PDF"
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('sanitizeFilename removes illegal characters and trims correctly', () {
      expect(
        NotePdfService.sanitizeFilename('Acuerdo de Pareja #1 (Importante!)'),
        equals('acuerdo_de_pareja_1_importante'),
      );
      expect(
        NotePdfService.sanitizeFilename('  Espacios   múltiples  '),
        equals('espacios_mltiples'),
      );
    });

    test('parseHexColor parses valid hex and falls back on error', () {
      final color = NotePdfService.parseHexColor('#EC4899');
      expect(color, isNotNull);

      final fallback = NotePdfService.parseHexColor('invalid_hex');
      expect(fallback, isNotNull);
    });

    testWidgets('NoteReaderDialog renders PDF download and share action buttons', (tester) async {
      final note = NoteItem(
        id: 'test_reader_pdf',
        title: 'Nota para exportar PDF',
        blocks: [NoteBlock(type: BlockType.paragraph, content: 'Texto de prueba')],
      );

      final notasState = NotasState();
      final diarioState = DiarioState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotasState>.value(value: notasState),
            ChangeNotifierProvider<DiarioState>.value(value: diarioState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NoteReaderDialog(initialNote: note),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que los botones de PDF y Compartir existen en el lector
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });
  });
}
