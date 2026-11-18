import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';

/// SupabaseService con el cliente sustituido (null = Supabase no disponible).
class _ServicioConFake extends SupabaseService {
  _ServicioConFake(this._client) : super.forTesting();
  final SupabaseClient? _client;

  @override
  SupabaseClient? get client => _client;
}

void main() {
  group('saveSettingOrThrow', () {
    test('hace upsert en settings con la clave, el valor y la fecha', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('POST', 'settings', body: null, status: 201);

      await _ServicioConFake(fake.client).saveSettingOrThrow('clave_prueba', 'valor_prueba');

      final req = fake.single('POST', 'settings');
      final body = req.body! as Map<String, dynamic>;
      expect(body['key'], 'clave_prueba');
      expect(body['value'], 'valor_prueba');
      expect(DateTime.tryParse(body['updated_at'] as String), isNotNull);
      expect(req.headers['Prefer'] ?? req.headers['prefer'], contains('resolution=merge-duplicates'));
    });

    test('lanza si Supabase responde con error', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('POST', 'settings', body: FakeSupabase.pgError(), status: 500);

      await expectLater(
        _ServicioConFake(fake.client).saveSettingOrThrow('clave_prueba', 'v'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('lanza si Supabase no está disponible', () async {
      await expectLater(_ServicioConFake(null).saveSettingOrThrow('clave_prueba', 'v'), throwsStateError);
    });
  });

  group('saveSetting', () {
    test('se traga el error de Supabase', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('POST', 'settings', body: FakeSupabase.pgError(), status: 500);

      await _ServicioConFake(fake.client).saveSetting('clave_prueba', 'v');

      expect(fake.requestsTo('settings', method: 'POST'), hasLength(1));
    });

    test('sin Supabase no hace nada ni lanza', () async {
      await expectLater(_ServicioConFake(null).saveSetting('clave_prueba', 'v'), completes);
    });
  });
}
