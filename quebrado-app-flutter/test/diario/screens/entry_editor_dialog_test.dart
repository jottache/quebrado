import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';
import 'package:quebrado_app_flutter/diario/screens/entry_editor_dialog.dart';
import 'package:quebrado_app_flutter/notas/notas.dart';
import 'package:quebrado_app_flutter/rich_editor/draft_store.dart';

import '../../helpers/pump_app.dart';

/// Borradores en memoria (sin SharedPreferences).
class _MemoryDraftBackend implements DraftBackend {
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

/// Servicio sin red.
class _OfflineDiarioService extends DiarioSupabaseService {
  _OfflineDiarioService() : super.forTesting();

  @override
  bool get isReady => false;
}

/// DiarioState que registra cada `addEntry` y deja al test decidir cuándo
/// termina ([gate]) y si falla ([failNext], como si la subida de la foto lanzara).
class _RecordingDiarioState extends DiarioState {
  _RecordingDiarioState() : super(service: _OfflineDiarioService());

  final List<String?> addIds = [];
  Completer<void>? gate;
  Object? failNext;

  @override
  Future<DiarioEntry> addEntry({
    String? id,
    required String contactId,
    required String categoryId,
    String? templateId,
    String entryType = 'simple_text',
    required String title,
    String? contentText,
    String? photoUrl,
    Map<String, dynamic>? contentData,
    Map<String, dynamic>? richDocument,
    List<String>? mentionedContactIds,
    List<String>? mentionedNoteIds,
    bool isPinned = false,
    DateTime? createdAt,
  }) async {
    addIds.add(id);
    final wait = gate;
    if (wait != null) await wait.future;
    final error = failNext;
    failNext = null;
    if (error != null) throw error;
    return DiarioEntry(
      id: id ?? 'sin-id',
      contactId: contactId,
      categoryId: categoryId,
      title: title,
    );
  }
}

/// El editor carga sus textos y el borrador de forma asíncrona (real).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _save = find.byKey(const ValueKey('diario_entry_save'));

void main() {
  late _RecordingDiarioState diario;
  late NotasState notas;
  DiarioEntry? result;

  TestWidgetsFlutterBinding.ensureInitialized();
  // En móvil el editor escucha la altura del teclado (plugin nativo).
  const keyboardHeight = EventChannel('keyboardHeightEventChannel');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(keyboardHeight, MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(keyboardHeight, null));
    DraftStore.instance = DraftStore(backend: _MemoryDraftBackend());
    diario = _RecordingDiarioState();
    notas = NotasState();
    result = null;
  });

  tearDown(() {
    diario.dispose();
    notas.dispose();
  });

  Future<void> openEditor(WidgetTester tester, WindowClass window) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<DiarioEntry>(
              context: context,
              builder: (_) => const EntryEditorDialog(contactId: 'c1', categoryId: 'cat_gustos'),
            );
          },
          child: const Text('Abrir'),
        ),
      ),
      providers: [
        ChangeNotifierProvider<DiarioState>.value(value: diario),
        ChangeNotifierProvider<NotasState>.value(value: notas),
      ],
      window: window,
    );
    await tester.tap(find.text('Abrir'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('diario_entry_title')), 'Cena');
    await tester.pump();
  }

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('un doble toque en Guardar crea una sola entrada (${window.name})', (tester) async {
      await openEditor(tester, window);
      diario.gate = Completer<void>();

      // Dos toques seguidos, sin frame entre medias (el botón sigue activo).
      await tester.tap(_save);
      await tester.tap(_save);
      await tester.pump();

      expect(diario.addIds, hasLength(1));
      expect(find.byKey(const ValueKey('diario_entry_saving')), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(_save).onPressed, isNull,
          reason: 'Guardar queda deshabilitado mientras guarda');

      diario.gate!.complete();
      await _settle(tester);

      expect(diario.addIds, hasLength(1));
      expect(find.byType(EntryEditorDialog), findsNothing);
      expect(result?.id, diario.addIds.single);
    });
  }

  testWidgets('si guardar falla, avisa en español, sigue abierto y el reintento usa el mismo id',
      (tester) async {
    await openEditor(tester, WindowClass.expanded);
    diario.failNext = Exception('storage caído');

    await tester.tap(_save);
    await _settle(tester);

    // El messenger lo pinta en el Scaffold de debajo y en el del editor.
    expect(find.text(EntryEditorDialog.saveErrorNotice), findsWidgets);
    expect(find.textContaining('storage caído'), findsNothing, reason: 'sin el error crudo');
    expect(find.byType(EntryEditorDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('diario_entry_saving')), findsNothing, reason: 'Guardar vuelve a estar activo');

    await tester.tap(_save);
    await _settle(tester);

    expect(diario.addIds, hasLength(2));
    expect(diario.addIds.first, isNotNull);
    expect(diario.addIds.last, diario.addIds.first, reason: 'el reintento no duplica la entrada');
    expect(find.byType(EntryEditorDialog), findsNothing);
    expect(result?.id, diario.addIds.first);

    // Deja expirar el aviso para no dejar timers vivos.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
  });
}
