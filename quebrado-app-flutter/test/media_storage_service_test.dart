import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quebrado_app_flutter/services/media_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaStorageService · clasificación de valores', () {
    test('needsUpload distingue base64, rutas locales y URLs', () {
      expect(MediaStorageService.needsUpload(null), isFalse);
      expect(MediaStorageService.needsUpload(''), isFalse);
      expect(MediaStorageService.needsUpload('https://x.supabase.co/storage/v1/object/public/diario-media/a.jpg'), isFalse);
      expect(MediaStorageService.needsUpload('blob:http://localhost/123'), isFalse);
      expect(MediaStorageService.needsUpload('data:image/png;base64,AAAA'), isTrue);
      expect(MediaStorageService.needsUpload('/Users/me/Documents/diario_images/foto.png'), isTrue);
    });

    test('isManagedUrl solo reconoce archivos del bucket diario-media', () {
      expect(
        MediaStorageService.isManagedUrl('https://x.supabase.co/storage/v1/object/public/diario-media/avatars/a.jpg'),
        isTrue,
      );
      expect(MediaStorageService.isManagedUrl('https://otra-web.com/avatar.jpg'), isFalse);
      expect(MediaStorageService.isManagedUrl('https://x.supabase.co/storage/v1/object/public/otro/a.jpg'), isFalse);
      expect(MediaStorageService.isManagedUrl(null), isFalse);
    });

    test('sin Supabase configurado ensureRemote devuelve el valor original', () async {
      final service = MediaStorageService.forTesting();
      const value = 'data:image/png;base64,AAAA';
      expect(await service.ensureRemote(value, MediaImagePreset.avatar), value);
    });
  });

  group('MediaStorageService · compresión', () {
    testWidgets('reduce el lado mayor, mantiene la proporción y codifica JPEG', (tester) async {
      await tester.runAsync(() async {
        final big = img.Image(width: 2000, height: 1000);
        img.fill(big, color: img.ColorRgb8(30, 120, 90));
        final png = Uint8List.fromList(img.encodePng(big));

        final jpeg = await MediaStorageService.compressToJpeg(png, maxSide: 512, quality: 82);
        expect(jpeg[0], 0xFF);
        expect(jpeg[1], 0xD8);
        final decoded = img.decodeJpg(jpeg)!;
        expect(decoded.width, 512);
        expect(decoded.height, 256);
        expect(jpeg.length, lessThan(png.length));
      });
    });

    testWidgets('la transparencia queda sobre fondo blanco', (tester) async {
      await tester.runAsync(() async {
        final transparent = img.Image(width: 40, height: 40, numChannels: 4);
        img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));
        final png = Uint8List.fromList(img.encodePng(transparent));

        final jpeg = await MediaStorageService.compressToJpeg(png, maxSide: 512, quality: 90);
        final pixel = img.decodeJpg(jpeg)!.getPixel(20, 20);
        expect(pixel.r, greaterThan(245));
        expect(pixel.g, greaterThan(245));
        expect(pixel.b, greaterThan(245));
      });
    });

    testWidgets('un JPEG que ya cabe se devuelve sin recomprimir', (tester) async {
      await tester.runAsync(() async {
        final small = img.Image(width: 300, height: 200);
        img.fill(small, color: img.ColorRgb8(200, 50, 50));
        final original = Uint8List.fromList(img.encodeJpg(small, quality: 70));

        final result = await MediaStorageService.compressToJpeg(original, maxSide: 512, quality: 82);
        expect(base64Encode(result), base64Encode(original));
      });
    });
  });
}
