import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/notas/models/note_block.dart';
import 'package:quebrado_app_flutter/notas/models/note_item.dart';
import 'package:quebrado_app_flutter/rich_editor/custom_blocks.dart';
import 'package:quebrado_app_flutter/rich_editor/draft_banner.dart';
import 'package:quebrado_app_flutter/rich_editor/draft_store.dart';
import 'package:quebrado_app_flutter/rich_editor/plain_text.dart';

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

void main() {
  group('DraftStore', () {
    test('guarda, recupera desde la base (sin caché) y borra', () async {
      final backend = MemoryDraftBackend();
      await DraftStore(backend: backend).save('nota:1', {'title': 'Hola', 'n': 2});
      expect(backend.values.keys, ['draft:nota:1']);

      // Otro DraftStore = como reabrir la app: lee de la base
      final reopened = await DraftStore(backend: backend).load('nota:1');
      expect(reopened, isNotNull);
      expect(reopened!.data, {'title': 'Hola', 'n': 2});
      expect(DateTime.now().difference(reopened.savedAt).inSeconds, lessThan(5));

      final store = DraftStore(backend: backend);
      await store.clear('nota:1');
      expect(await store.load('nota:1'), isNull);
      expect(backend.values, isEmpty);
    });

    test('un borrador ilegible se ignora', () async {
      final backend = MemoryDraftBackend()..values['draft:x'] = '{no es json';
      expect(await DraftStore(backend: backend).load('x'), isNull);
    });

    test('el autoguardado espera, no guarda si no hay nada y deja de guardar tras descartar', () async {
      final backend = MemoryDraftBackend();
      final store = DraftStore(backend: backend);
      Map<String, dynamic>? payload;
      final saver = DraftAutosaver(
        scope: 's',
        store: store,
        collect: () => payload,
        delay: const Duration(milliseconds: 20),
      );

      saver.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(backend.values, isEmpty, reason: 'collect() devolvió null');

      payload = {'texto': 'uno'};
      saver.schedule();
      expect(backend.values, isEmpty, reason: 'todavía no pasó el retraso');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(jsonDecode(backend.values['draft:s']!)['data'], {'texto': 'uno'});

      payload = {'texto': 'dos'};
      await saver.flush();
      expect((await store.load('s'))!.data, {'texto': 'dos'});

      await saver.discard();
      expect(backend.values, isEmpty);
      payload = {'texto': 'tres'};
      saver.schedule();
      await saver.flush();
      expect(backend.values, isEmpty, reason: 'tras guardar de verdad ya no hay borrador');
      saver.dispose();
    });

    test('el aviso describe la antigüedad del borrador', () {
      final now = DateTime(2026, 11, 16, 12);
      expect(DraftRestoredBanner.describeAge(now.subtract(const Duration(seconds: 20)), now: now), 'hace un momento');
      expect(DraftRestoredBanner.describeAge(now.subtract(const Duration(minutes: 7)), now: now), 'hace 7 min');
      expect(DraftRestoredBanner.describeAge(now.subtract(const Duration(hours: 3)), now: now), 'hace 3 h');
      expect(DraftRestoredBanner.describeAge(now.subtract(const Duration(days: 2)), now: now), 'hace 2 días');
    });
  });

  group('NoteItem con documento enriquecido', () {
    final document = Document(root: pageNode(children: [
      headingNode(level: 2, text: 'Plan'),
      paragraphNode(delta: Delta()
        ..insert('texto ')
        ..insert('negrita', attributes: {AppFlowyRichTextKeys.bold: true})),
      codeNode(text: 'print(1)'),
    ])).toJson();

    test('toMap / fromMap (base local) y toSupabaseMap conservan el documento', () {
      final note = NoteItem(id: 'n1', title: 'Plan', document: document);
      expect(note.hasRichDocument, isTrue);

      final local = note.toMap();
      expect(local['document'], isA<String>(), reason: 'en SQLite va como JSON');
      final fromLocal = NoteItem.fromMap(local);
      expect(fromLocal.document, document);

      final remote = note.toSupabaseMap();
      expect(remote['document'], document, reason: 'en Supabase va como JSONB');
      expect(NoteItem.fromMap(Map<String, dynamic>.from(remote)).document, document);
    });

    test('las notas sin documento no envían la columna (compatibles sin el SQL 016)', () {
      final legacy = NoteItem(id: 'n2', title: 'Vieja', blocks: [NoteBlock(type: BlockType.paragraph, content: 'hola')]);
      expect(legacy.hasRichDocument, isFalse);
      expect(legacy.toSupabaseMap().containsKey('document'), isFalse);
      expect(legacy.toMap().containsKey('document'), isFalse);
      expect(legacy.toMarkdown(), contains('hola'));
    });

    test('el Markdown sale del documento cuando existe (incluye formato y código)', () {
      final note = NoteItem(id: 'n1', title: 'Plan', icon: '📝', document: document);
      final md = note.toMarkdown();
      expect(md, startsWith('# 📝 Plan'));
      expect(md, contains('## Plan'));
      expect(md, contains('**negrita**'));
      expect(md, contains('print(1)'));
    });

    test('copyWith puede quitar el documento', () {
      final note = NoteItem(id: 'n1', title: 'Plan', document: document);
      expect(note.copyWith(title: 'Otro').document, document);
      expect(note.copyWith(clearDocument: true).document, isNull);
    });
  });

  group('DiarioEntry con documento enriquecido', () {
    final document = Document(root: pageNode(children: [paragraphNode(text: 'Hablé con @Ana')])).toJson();

    test('el documento viaja dentro de content_data pero no aparece en los campos del modelo', () {
      final entry = DiarioEntry(
        id: 'e1',
        contactId: 'personal',
        categoryId: 'cat',
        title: '',
        contentText: 'Hablé con @Ana',
        contentData: {'lugar': 'Café'},
        richDocument: document,
      );
      final map = entry.toMap();
      final data = map['content_data'] as Map<String, dynamic>;
      expect(data['lugar'], 'Café');
      expect(data[DiarioEntry.richDocumentKey], document);
      expect(map['content_text'], 'Hablé con @Ana', reason: 'el texto plano se sigue guardando');

      final back = DiarioEntry.fromMap(map);
      expect(back.richDocument, document);
      expect(back.contentData, {'lugar': 'Café'}, reason: 'búsqueda, lector y agente recorren contentData');
      expect(back.hasRichDocument, isTrue);
    });

    test('acepta el documento como texto JSON y las entradas antiguas no cambian', () {
      final fromString = DiarioEntry.fromMap({
        'id': 'e2',
        'contact_id': 'personal',
        'category_id': 'cat',
        'title': '',
        'content_data': {DiarioEntry.richDocumentKey: jsonEncode(document)},
      });
      expect(fromString.richDocument, document);
      expect(fromString.contentData, isEmpty);

      final legacy = DiarioEntry(id: 'e3', contactId: 'c', categoryId: 'cat', title: 'x', contentText: 'hola');
      expect(legacy.hasRichDocument, isFalse);
      expect((legacy.toMap()['content_data'] as Map).containsKey(DiarioEntry.richDocumentKey), isFalse);
    });

    test('copyWith conserva o quita el documento', () {
      final entry = DiarioEntry(id: 'e1', contactId: 'c', categoryId: 'cat', title: '', richDocument: document);
      expect(entry.copyWith(isPinned: true).richDocument, document);
      expect(entry.copyWith(clearRichDocument: true).richDocument, isNull);
    });
  });

  group('Texto plano del documento', () {
    test('listas, tareas, destacados y desplegables quedan legibles', () {
      final document = Document(root: pageNode(children: [
        headingNode(level: 1, text: 'Viaje'),
        bulletedListNode(text: 'pasaporte'),
        numberedListNode(delta: Delta()..insert('reservar')),
        numberedListNode(delta: Delta()..insert('pagar')),
        todoListNode(checked: true, text: 'maleta'),
        todoListNode(checked: false, text: 'taxi'),
        calloutNode(text: 'ojo con el clima', icon: '⚠️'),
        toggleNode(text: 'Detalles', children: [paragraphNode(text: 'hotel @Ana')]),
        dividerNode(),
        paragraphNode(),
      ]));
      expect(
        documentToPlainText(document),
        'Viaje\n• pasaporte\n1. reservar\n2. pagar\n☑ maleta\n☐ taxi\n⚠️ ojo con el clima\nDetalles\n  hotel @Ana\n———',
      );
    });

    test('el texto antiguo se abre como párrafos y resalta las menciones conocidas', () {
      final document = documentFromPlainText('Cena con @Ana López\nver #Acuerdos', mentions: ['@Ana López', '@Ana', '#Acuerdos']);
      expect(document.root.children.length, 2);

      final first = document.root.children.first.delta!.toList().cast<TextInsert>();
      expect(first.map((op) => op.text).toList(), ['Cena con ', '@Ana López']);
      expect(first.last.attributes?[AppFlowyRichTextKeys.bold], isTrue, reason: 'gana la mención más larga');

      final second = document.root.children.last.delta!.toList().cast<TextInsert>();
      expect(second.last.text, '#Acuerdos');
      expect(documentToPlainText(document), 'Cena con @Ana López\nver #Acuerdos');
    });

    test('un texto vacío abre con un párrafo listo para escribir', () {
      final document = documentFromPlainText('');
      expect(document.root.children.single.type, ParagraphBlockKeys.type);
    });
  });

  testWidgets('el aviso de borrador permite descartarlo u ocultarlo', (tester) async {
    var discarded = false;
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DraftRestoredBanner(
          savedAt: DateTime.now().subtract(const Duration(minutes: 3)),
          accent: Colors.indigo,
          onDiscard: () => discarded = true,
          onDismiss: () => dismissed = true,
        ),
      ),
    ));
    expect(find.textContaining('hace 3 min'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draft_discard_button')));
    await tester.tap(find.byTooltip('Ocultar aviso'));
    expect(discarded, isTrue);
    expect(dismissed, isTrue);
  });
}
