import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('readImageFromClipboard works without exceptions', () async {
      final result = await readImageFromClipboard();
      // On macOS environment with an active clipboard image, result is a non-empty string path
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });
  });
}
