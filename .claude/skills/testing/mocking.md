# Simular dependencias en quebrado-app

Regla general: **simula en el borde** (red, base de datos, plugin, reloj) y deja real todo lo demás. Cuanto más código real ejecute el test, más bugs atrapa.

## 1. FakeSupabase (`test/helpers/fake_supabase.dart`)

Es un `SupabaseClient` real (supabase 2.x) con un `MockClient` de `package:http/testing.dart`. El cliente arma la petición igual que en producción; el test la inspecciona y decide la respuesta.

```dart
final fake = FakeSupabase.create();   // dentro de test()/setUp: registra verificación y dispose

// Respuestas
fake.stubRest('GET', 'diario_contacts', body: [diarioContactRow()]);         // select
fake.stubRest('POST', 'notas', body: null, status: 201);                      // insert/upsert sin .select()
fake.stubRest('PATCH', 'notas', body: null, status: 204);                     // update
fake.stubRest('DELETE', 'notas', body: null, status: 204);                    // delete
fake.stubRest('GET', 'diario_contacts',                                       // según filtro
    body: {'avatar_url': 'https://…'}, where: (r) => r.query['id'] == 'eq.c2');
fake.stubRpc('import_quebrado_backup', body: {'ok': true});
fake.stubRest('GET', 'accounts', status: 401,                                  // error PostgREST
    body: FakeSupabase.pgError(code: '42501', message: 'permission denied for table accounts'));

// Afirmaciones sobre la petición
final req = fake.single('PATCH', 'notas');     // falla si no hubo exactamente 1
req.query['id'];        // 'eq.n1'   (filtros: eq., neq., like., is., in.(…), not.…)
req.query['select'];    // columnas pedidas
req.query['order'];     // 'name.asc.nullslast'
req.queryAll['avatar_url'];  // filtros repetidos sobre la misma columna
req.body;               // JSON decodificado (insert/update/upsert/rpc)
req.headers['Prefer'];  // p. ej. 'resolution=merge-duplicates' en upsert
fake.requestsTo('notas', method: 'POST');      // todas las de una tabla
```

Detalles comprobados:
- Si varios stubs coinciden, **gana el último registrado** (registra el genérico primero y el específico después).
- `.maybeSingle()` acepta un objeto (`body: {...}`) o una lista de 0–1 elementos; `.single()` exige un objeto (con una lista lanza un `TypeError`).
- Un upsert llega como `POST` con `req.headers['Prefer'] == 'resolution=merge-duplicates'` y `req.query['on_conflict']`.
- Una petición sin stub responde 500 con `code: 'FAKE_NO_STUB'` y queda en `fake.unstubbed`; el `tearDown` de `create()` hace fallar el test con la lista. Así se detecta aunque el servicio haga `catch (e) { debugPrint(...) }`.
- Para afirmar que **sí** hubo una petición no prevista (test del propio helper), usa `FakeSupabase.create(verifyOnTearDown: false)` y vacía `fake.unstubbed` al final.
- Úsalo en `test()`. En `testWidgets`, **crea el fake y haz las llamadas dentro de** `await tester.runAsync(() async { … })`: el cliente arranca un isolate para JSON y, creado en la zona de reloj falso, el test se cuelga (comprobado: timeout). Crearlo fuera y llamar dentro tampoco basta.
- `client.auth.currentUser` es `null` (no hay sesión): los servicios que añaden `user_id` solo si hay usuario no lo añadirán. Si un test necesita usuario, es una señal de que el servicio debería recibir el `userId` por parámetro.

## 2. Conectar un servicio a FakeSupabase

**Servicio existente** (singleton con `forTesting()`): subclase que sobrescribe el getter `client`. No se toca producción.

```dart
class _DiarioServiceConFake extends DiarioSupabaseService {
  _DiarioServiceConFake(this._fake) : super.forTesting();
  final SupabaseClient _fake;
  @override
  SupabaseClient? get client => _fake;
}
```

Si el servicio no tiene `forTesting()` (p. ej. `SupabaseService`, `NotasSupabaseService`), no lo refactorices "de paso": añadir el constructor es un cambio de producción que va en la spec o en un fix propio, con su revisión.

**Servicio nuevo**: cliente inyectable con valor por defecto al singleton.

```dart
class MiServicio {
  MiServicio({SupabaseClient? client}) : _client = client;
  static final MiServicio instance = MiServicio();

  final SupabaseClient? _client;
  SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Supabase no inicializado (tests, sin .env)
    }
  }
}
// En el test: MiServicio(client: fake.client)
```

## 3. Fake de servicio para ViewModels

Para probar un `ChangeNotifier`, no hace falta HTTP: sustituye el servicio entero por una subclase con datos en memoria (patrón de `test/animo_state_test.dart` y `test/diario_light_contacts_load_test.dart`).

```dart
class FakeDiarioService extends DiarioSupabaseService {
  FakeDiarioService() : super.forTesting();
  bool failContacts = false;
  final saved = <DiarioContact>[];

  @override
  bool get isReady => true;
  @override
  Future<List<DiarioContact>> getContacts() async {
    if (failContacts) throw Exception('sin red');
    return [DiarioContact(id: 'c1', name: 'Ana')];
  }
  @override
  Future<void> saveContact(DiarioContact c, {bool includeAvatar = true}) async => saved.add(c);
}
// DiarioState(service: FakeDiarioService())
```

Sobrescribe **solo** lo que el test usa; si el ViewModel llama a otro método, el real devuelve su valor local por defecto (sin Supabase, `isReady` sería false, pero aquí lo forzamos a true: revisa qué métodos toca la ruta que pruebas).

Para contar notificaciones: `var n = 0; state.addListener(() => n++);`.

## 4. SQLite (sqflite)

**Código nuevo que recibe un `Database`**: base en memoria, aislada por test.

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;
setUpAll(sqfliteFfiInit);
setUp(() async {
  db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));   // una base nueva por test
  await db.execute('CREATE TABLE …');
});
tearDown(() => db.close());
```

`singleInstance: false` es necesario: con el valor por defecto, todas las aperturas de `inMemoryDatabasePath` comparten la misma base y los datos se cuelan entre tests.

**`DatabaseHelper.instance` (finanzas, `AppState`)**: abre `quebrado.db` en una ruta fija. En tests es un archivo **persistente** en `.dart_tool/sqflite_common_ffi/databases/` (y `quebrado_profiles.json` en la raíz del paquete), compartido por todos los archivos de test que corren en paralelo. Consecuencias:
- No borres, cierres ni cambies de perfil esa base en un test nuevo: rompe a otros archivos que corren a la vez.
- Usa ids únicos (`const Uuid().v4()` o un prefijo por test) y afirma **diferencias** (antes/después), no conteos absolutos. (El test `mobile_payment_recipient_test` está en known-failures justamente por esperar la base vacía.)
- Para lógica de saldos/proyecciones en memoria: `AppState.debugLocalDbIsSourceOfTruth = false` en `setUp` y `= null` en `tearDown`; fija tasas con `debugSetRates`. **Ojo:** con ese modo las cuentas viven solo en memoria, pero las transacciones se siguen insertando en SQLite y la clave foránea falla (es la causa del fallo conocido de `multi_currency_balance_test`). Úsalo solo para lógica que no inserte transacciones; si las inserta, prueba con una función pura o con la base en memoria.
- Mejor aún: saca la lógica nueva a funciones puras o a clases que reciban `Database`, y pruébalas con la base en memoria.

## 5. Plugins nativos (canales de plataforma)

En la VM de tests no hay implementación de plugins → `MissingPluginException`. Simula el canal:

```dart
TestWidgetsFlutterBinding.ensureInitialized();
const channel = MethodChannel('plugins.flutter.io/path_provider');
setUp(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => tempDir.path);
});
tearDown(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
});
```

Nombres de canal: mira el mensaje de la excepción (`… on channel plugins.flutter.io/path_provider`). Para `local_auth`, notificaciones o dictado, prefiere aislar la lógica detrás de una clase pequeña inyectable antes que simular el canal.

## 6. Reloj, aleatoriedad e IA

- Reloj: inyecta `DateTime Function() clock` (ver `AnimoState`). Nunca afirmes contra `DateTime.now()`.
- Ids: si el código usa `Uuid().v4()`, afirma por contenido, no por id.
- Gemini (`lib/agente/services/gemini_service.dart`): no hay llamadas reales en tests. Prueba el armado del prompt, el parseo de la respuesta y el RAG (`suite_rag_service.dart`) con textos fijos.
