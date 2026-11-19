import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/dialogs/contact_editor_dialog.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/widgets/clipboard_image_helper.dart';
import 'package:quebrado_app_flutter/diario/widgets/diario_image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diario Clipboard Image Tests', () {
    test('saveImageBytesPermanently handles binary image data correctly', () async {
      // Mock bytes of a tiny 1x1 png or sample data
      final Uint8List sampleBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final savedPathOrUri = await DiarioImageHelper.saveImageBytesPermanently(sampleBytes);
      expect(savedPathOrUri, isNotEmpty);
    });

    testWidgets('ContactEditorDialog displays quick paste button and Cmd+V shortcut support', (tester) async {
      final state = DiarioState();
      await state.loadAll();

      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ChangeNotifierProvider<DiarioState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: ContactEditorDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the quick paste button under avatar is present
      expect(find.text('Pegar foto copiada (Cmd+V)'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);

      // Tap on the avatar circle to open the source modal
      final avatarPickerFinder = find.byIcon(Icons.add_a_photo_rounded);
      expect(avatarPickerFinder, findsOneWidget);
      await tester.tap(avatarPickerFinder);
      await tester.pumpAndSettle();

      // Verify modal options: Galería, Cámara, and Pegar del Portapapeles
      expect(find.text('Galería'), findsOneWidget);
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Pegar del Portapapeles'), findsOneWidget);
      expect(find.text('Usa una imagen copiada en tu equipo (Cmd+V)'), findsOneWidget);
    });

    group('readImageFromClipboard', () {
      const pasteboardChannel = MethodChannel('pasteboard');
      const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      late Directory docsDir;
      late List<String> pasteboardCalls;
      Object? Function(String method) pasteboardResponse = (_) => null;

      setUp(() {
        docsDir = Directory.systemTemp.createTempSync('diario_clip_test_');
        pasteboardCalls = [];
        messenger.setMockMethodCallHandler(pasteboardChannel, (call) async {
          pasteboardCalls.add(call.method);
          return pasteboardResponse(call.method);
        });
        messenger.setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') return docsDir.path;
          return null;
        });
        // Portapapeles de texto vacío (Clipboard.getData).
        messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return null;
          return null;
        });
      });

      tearDown(() {
        messenger.setMockMethodCallHandler(pasteboardChannel, null);
        messenger.setMockMethodCallHandler(pathProviderChannel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        pasteboardResponse = (_) => null;
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      test('guarda la imagen del portapapeles en diario_images y devuelve su ruta', () async {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
        pasteboardResponse = (method) => method == 'image' ? bytes : null;

        final result = await readImageFromClipboard();

        expect(result, isNotNull);
        expect(p.dirname(result!), p.join(docsDir.path, 'diario_images'));
        expect(p.basename(result), allOf(startsWith('diario_clip_'), endsWith('.png')));
        expect(File(result).readAsBytesSync(), bytes);
        // Con imagen directa no consulta los archivos copiados.
        expect(pasteboardCalls, ['image']);
      });

      // En macOS la implementación prueba además `osascript` contra el
      // portapapeles real; se neutraliza haciendo que ningún archivo exista
      // dentro de la zona, para que el resultado no dependa del equipo.
      Future<String?> leerSinArchivosReales() => IOOverrides.runZoned(
            readImageFromClipboard,
            createFile: _ArchivoInexistente.new,
          );

      test('devuelve null cuando no hay imagen, ni archivos, ni texto en el portapapeles', () async {
        pasteboardResponse = (method) => method == 'files' ? <String>[] : null;

        final result = await leerSinArchivosReales();

        expect(result, isNull);
        expect(pasteboardCalls, ['image', 'files']);
        expect(Directory(p.join(docsDir.path, 'diario_images')).existsSync(), isFalse);
      });

      test('devuelve null sin lanzar cuando el canal del portapapeles falla', () async {
        pasteboardResponse = (method) => throw PlatformException(code: 'ERROR', message: method);

        await expectLater(leerSinArchivosReales(), completion(isNull));
        expect(pasteboardCalls, ['image', 'files']);
      });
    });
  });
}

/// `File` que nunca existe: evita que el fallback de macOS (osascript) lea
/// el portapapeles real del equipo durante el test.
class _ArchivoInexistente implements File {
  _ArchivoInexistente(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
