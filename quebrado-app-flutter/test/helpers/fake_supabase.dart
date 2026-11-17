// FakeSupabase: un SupabaseClient REAL con la red sustituida.
//
// - El cliente construye las peticiones igual que en producción (PostgREST, RPC),
//   así que el test comprueba la petición real: tabla, filtros, columnas y cuerpo.
// - Cada respuesta la decide el test con [stubRest] / [stubRpc].
// - Una petición sin stub responde 500 y QUEDA REGISTRADA: al terminar el test
//   (addTearDown) se hace fallar aunque el código se haya tragado el error.
//
// Uso:
//   final fake = FakeSupabase.create();          // registra verificación y dispose
//   fake.stubRest('GET', 'diario_contacts', body: [diarioContactRow()]);
//   final svc = DiarioServiceConFake(fake.client);
//   ...
//   final req = fake.single('GET', 'diario_contacts');
//   expect(req.query['order'], 'name.asc.nullslast');
//
// En testWidgets: crea el fake Y haz las llamadas dentro de tester.runAsync(...);
// el cliente arranca un isolate para JSON y en la zona de reloj falso se cuelga.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Petición capturada por [FakeSupabase].
class RecordedRequest {
  RecordedRequest(this.request)
      : uri = request.url,
        method = request.method.toUpperCase();

  final http.Request request;
  final Uri uri;
  final String method;

  /// 'rest' (tabla), 'rpc' o 'other' (auth, storage, functions…).
  String get kind {
    final segs = uri.pathSegments;
    if (segs.length >= 3 && segs[0] == 'rest' && segs[1] == 'v1') {
      return segs[2] == 'rpc' ? 'rpc' : 'rest';
    }
    return 'other';
  }

  /// Nombre de la tabla (kind == 'rest') o de la función (kind == 'rpc').
  String get target {
    final segs = uri.pathSegments;
    if (kind == 'rest') return segs[2];
    if (kind == 'rpc') return segs.length > 3 ? segs[3] : '';
    return uri.path;
  }

  /// Query params (si una clave se repite, gana el último; ver [queryAll]).
  Map<String, String> get query => uri.queryParameters;

  /// Query params con claves repetidas (p. ej. dos filtros sobre la misma columna).
  Map<String, List<String>> get queryAll => uri.queryParametersAll;

  Map<String, String> get headers => request.headers;

  /// Cuerpo JSON decodificado (null si no hay cuerpo).
  Object? get body => request.body.isEmpty ? null : jsonDecode(request.body);

  @override
  String toString() => '$method ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'
      '${request.body.isEmpty ? '' : ' body=${request.body}'}';
}

class _Stub {
  _Stub({
    required this.method,
    required this.kind,
    required this.target,
    required this.where,
    required this.status,
    required this.body,
    required this.headers,
  });

  final String method;
  final String kind;
  final String target;
  final bool Function(RecordedRequest)? where;
  final int status;
  final Object? body;
  final Map<String, String> headers;
  int calls = 0;

  bool matches(RecordedRequest r) =>
      r.method == method && r.kind == kind && r.target == target && (where?.call(r) ?? true);
}

class FakeSupabase {
  FakeSupabase() {
    client = SupabaseClient(
      'https://fake.supabase.co',
      'anon-key-de-prueba',
      httpClient: MockClient(_handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  /// Crea el fake y registra en addTearDown: verificación de peticiones sin
  /// stub (falla el test) y dispose del cliente. Úsalo dentro de un test o setUp.
  static FakeSupabase create({bool verifyOnTearDown = true}) {
    final fake = FakeSupabase();
    addTearDown(() async {
      // Verificar antes del dispose: si dispose() lanzara, la verificación no se perdería.
      try {
        if (verifyOnTearDown) fake.verifyNoUnstubbed();
      } finally {
        await fake.client.dispose();
      }
    });
    return fake;
  }

  late final SupabaseClient client;

  /// Todas las peticiones, en orden.
  final List<RecordedRequest> requests = [];

  /// Peticiones que no encontraron stub.
  final List<RecordedRequest> unstubbed = [];

  final List<_Stub> _stubs = [];

  /// Cuerpo de error con el formato de PostgREST (lo que lee PostgrestException).
  static Map<String, dynamic> pgError({
    String code = 'PGRST000',
    String message = 'error de prueba',
    String? details,
    String? hint,
  }) =>
      {'code': code, 'message': message, 'details': details, 'hint': hint};

  /// Respuesta para una tabla. [method]: GET, POST (insert/upsert), PATCH (update), DELETE.
  /// [where] permite responder distinto según filtros: `where: (r) => r.query['id'] == 'eq.c1'`.
  /// Si hay varios stubs que coinciden, gana el último registrado.
  /// [body] null = respuesta vacía (lo normal en insert/update sin `.select()`).
  void stubRest(
    String method,
    String table, {
    Object? body = const [],
    int status = 200,
    bool Function(RecordedRequest)? where,
    Map<String, String> headers = const {},
  }) {
    _stubs.add(_Stub(
      method: method.toUpperCase(),
      kind: 'rest',
      target: table,
      where: where,
      status: status,
      body: body,
      headers: headers,
    ));
  }

  /// Respuesta para `client.rpc(name, params: …)` (siempre POST).
  void stubRpc(
    String name, {
    Object? body,
    int status = 200,
    bool Function(RecordedRequest)? where,
  }) {
    _stubs.add(_Stub(
      method: 'POST',
      kind: 'rpc',
      target: name,
      where: where,
      status: status,
      body: body,
      headers: const {},
    ));
  }

  /// Peticiones a una tabla o RPC, opcionalmente filtradas por método.
  List<RecordedRequest> requestsTo(String target, {String? method}) => requests
      .where((r) => r.target == target && (method == null || r.method == method.toUpperCase()))
      .toList();

  /// Exactamente una petición [method] a [target]; si no, falla con el detalle.
  RecordedRequest single(String method, String target) {
    final found = requestsTo(target, method: method);
    if (found.length != 1) {
      fail('Se esperaba 1 petición $method a "$target" y hubo ${found.length}.\n'
          'Peticiones: ${requests.join('\n  ')}');
    }
    return found.single;
  }

  /// Falla si hubo peticiones sin stub (se llama sola en el tearDown de [create]).
  void verifyNoUnstubbed() {
    if (unstubbed.isEmpty) return;
    final detail = unstubbed.map((r) => '  $r').join('\n');
    unstubbed.clear();
    fail('Peticiones sin stub (regístralas con stubRest/stubRpc):\n$detail');
  }

  Future<http.Response> _handle(http.Request request) async {
    final rec = RecordedRequest(request);
    requests.add(rec);
    _Stub? stub;
    for (final s in _stubs.reversed) {
      if (s.matches(rec)) {
        stub = s;
        break;
      }
    }
    if (stub == null) {
      unstubbed.add(rec);
      return http.Response(
        jsonEncode(pgError(code: 'FAKE_NO_STUB', message: 'Sin stub: $rec')),
        500,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    stub.calls++;
    // `request:` es obligatorio: postgrest lee response.request! al parsear.
    return http.Response(
      stub.body == null ? '' : jsonEncode(stub.body),
      stub.status,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8', ...stub.headers},
    );
  }
}
