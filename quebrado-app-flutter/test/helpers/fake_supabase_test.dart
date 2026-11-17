import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase.dart';
import 'rows/diario_contact_row.dart';

/// Servicio existente (singleton con `Supabase.instance.client`) conectado al fake
/// sin tocar producción: el constructor `forTesting()` + override del getter `client`.
class _DiarioServiceConFake extends DiarioSupabaseService {
  _DiarioServiceConFake(this._fake) : super.forTesting();
  final SupabaseClient _fake;

  @override
  SupabaseClient? get client => _fake;
}

void main() {
  group('FakeSupabase · PostgREST', () {
    test('devuelve las filas del stub y registra tabla, columnas y orden', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('GET', 'diario_contacts', body: [
        diarioContactRow(id: 'c1', name: 'Ana'),
        diarioContactRow(id: 'c2', name: 'Beto', isFavorite: true),
      ]);

      final contacts = await _DiarioServiceConFake(fake.client).getContacts();

      expect(contacts.map((c) => c.id), ['c1', 'c2']);
      expect(contacts.last.isFavorite, isTrue);
      final req = fake.single('GET', 'diario_contacts');
      expect(req.query['select'], DiarioSupabaseService.contactColumnsWithoutAvatar);
      expect(req.query['select'], isNot(contains('avatar_url')));
      expect(req.query['order'], startsWith('name.asc'));
    });

    test('registra filtros y cuerpo de un update', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('PATCH', 'diario_contacts', body: null, status: 204);

      final ok = await _DiarioServiceConFake(fake.client)
          .updateContactAvatar('c9', 'https://x/avatar.jpg');

      expect(ok, isTrue);
      final req = fake.single('PATCH', 'diario_contacts');
      expect(req.query['id'], 'eq.c9');
      expect(req.body, {'avatar_url': 'https://x/avatar.jpg'});
    });

    test('where permite responder distinto según el filtro', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('GET', 'diario_contacts', body: [], where: (_) => true);
      fake.stubRest(
        'GET',
        'diario_contacts',
        body: {'avatar_url': 'data:image/png;base64,AAAA'},
        where: (r) => r.query['id'] == 'eq.c2',
      );

      final svc = _DiarioServiceConFake(fake.client);
      expect(await svc.getContactAvatar('c2'), 'data:image/png;base64,AAAA');
    });

    test('un error de PostgREST llega como PostgrestException con su código', () async {
      final fake = FakeSupabase.create();
      fake.stubRest(
        'GET',
        'accounts',
        status: 401,
        body: FakeSupabase.pgError(code: '42501', message: 'permission denied for table accounts'),
      );

      await expectLater(
        fake.client.from('accounts').select(),
        throwsA(isA<PostgrestException>()
            .having((e) => e.code, 'code', '42501')
            .having((e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('el servicio que se traga el error devuelve su reserva ante un 500', () async {
      final fake = FakeSupabase.create();
      fake.stubRest('GET', 'diario_contacts', status: 500, body: FakeSupabase.pgError());

      final contacts = await _DiarioServiceConFake(fake.client).getContacts();

      // getContacts cae en la lista por defecto cuando Supabase falla.
      expect(contacts, isNotEmpty);
      expect(contacts.map((c) => c.id), isNot(contains('c1')));
    });
  });

  group('FakeSupabase · RPC', () {
    test('stubRpc responde y registra los parámetros', () async {
      final fake = FakeSupabase.create();
      fake.stubRpc('import_quebrado_backup', body: {'ok': true, 'rows': 3});

      final res = await fake.client.rpc('import_quebrado_backup', params: {'p_backup': {'a': 1}});

      expect(res, {'ok': true, 'rows': 3});
      final req = fake.single('POST', 'import_quebrado_backup');
      expect(req.kind, 'rpc');
      expect(req.body, {'p_backup': {'a': 1}});
    });
  });

  group('FakeSupabase · peticiones sin stub', () {
    test('se detectan aunque el código se trague el error', () async {
      final fake = FakeSupabase.create(verifyOnTearDown: false);

      // getContacts captura la excepción y devuelve la reserva: sin el fake,
      // este test pasaría en silencio con una petición que nadie previó.
      await _DiarioServiceConFake(fake.client).getContacts();

      expect(fake.unstubbed.single.target, 'diario_contacts');
      expect(
        fake.verifyNoUnstubbed,
        throwsA(isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('GET /rest/v1/diario_contacts'),
        )),
      );
      // verifyNoUnstubbed vacía la lista: llamarla de nuevo ya no falla.
      expect(fake.verifyNoUnstubbed, returnsNormally);
    });

    test('un stub de otro método no cubre la petición', () async {
      final fake = FakeSupabase.create(verifyOnTearDown: false);
      fake.stubRest('POST', 'diario_contacts', body: null, status: 201);

      await _DiarioServiceConFake(fake.client).deleteContact('c1');

      expect(fake.unstubbed.single.method, 'DELETE');
      fake.unstubbed.clear();
    });
  });
}
