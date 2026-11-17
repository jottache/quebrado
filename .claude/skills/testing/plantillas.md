# Plantillas copiables

Todas se comprobaron ejecutándolas contra el código real (2026-11-17). Cópialas, cambia los nombres y borra lo que no aplique. Ruta del test nuevo: espejo de `lib/` (`lib/diario/models/diario_contact.dart` → `test/diario/models/diario_contact_test.dart`). Imports de helpers relativos a la ubicación del test (desde `test/a/b/` son `../../helpers/…`).

## A. Modelo (fromMap / toMap / cálculos)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';

import '../../helpers/rows/diario_contact_row.dart';

void main() {
  group('DiarioContact.fromMap', () {
    test('lee una fila real de PostgREST', () {
      final c = DiarioContact.fromMap(diarioContactRow(id: 'c7', isFavorite: true));

      expect(c.id, 'c7');
      expect(c.isFavorite, isTrue);
      expect(c.birthdate, DateTime(1990, 5, 14));
    });

    test('acepta is_favorite como 1 (SQLite) además de true (Postgres)', () {
      final row = diarioContactRow()..['is_favorite'] = 1;
      expect(DiarioContact.fromMap(row).isFavorite, isTrue);
    });

    test('una fecha de nacimiento inválida queda en null sin lanzar', () {
      final row = diarioContactRow(birthdate: 'no-es-fecha');
      expect(DiarioContact.fromMap(row).birthdate, isNull);
    });
  });

  test('toMap y fromMap conservan los datos (ida y vuelta)', () {
    final original = DiarioContact.fromMap(diarioContactRow());
    final copia = DiarioContact.fromMap(original.toMap());

    expect(copia.toMap(), original.toMap());
    expect(original.toMap()['birthdate'], '1990-05-14', reason: 'DATE de Postgres, sin hora');
  });
}
```

## B. ViewModel (ChangeNotifier) con servicio fake

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_category.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/models/diario_template.dart';
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';

/// Sobrescribe todo lo que llama la ruta probada (aquí: loadAll).
class _FakeDiarioService extends DiarioSupabaseService {
  _FakeDiarioService() : super.forTesting();

  bool fallarContactos = false;
  final guardados = <DiarioContact>[];

  @override
  bool get isReady => true;
  @override
  Future<List<DiarioContact>> getContacts() async {
    if (fallarContactos) throw Exception('sin red');
    return [DiarioContact(id: 'c1', name: 'Ana'), DiarioContact(id: 'c2', name: 'Beto')];
  }
  @override
  Future<List<DiarioCategory>> getCategories() async => [];
  @override
  Future<List<DiarioTemplate>> getTemplates() async => [];
  @override
  Future<List<DiarioEntry>> getEntries() async => [];
  @override
  Future<Map<String, String>> getRemoteAvatarUrls() async => {};
  @override
  Future<List<String>> getInlineAvatarContactIds() async => [];
  @override
  Future<void> saveCategory(DiarioCategory category) async {}
  @override
  Future<void> saveContact(DiarioContact contact, {bool includeAvatar = true}) async =>
      guardados.add(contact);
}

/// Espera a que se cumpla una condición (p. ej. que termine la carga del constructor).
Future<void> esperarHasta(bool Function() listo, {int intentos = 100}) async {
  for (var i = 0; i < intentos && !listo(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(listo(), isTrue, reason: 'la condición no se cumplió a tiempo');
}

void main() {
  test('al cargar expone los contactos del servicio y deja de cargar', () async {
    final state = DiarioState(service: _FakeDiarioService());
    await esperarHasta(() => !state.isLoading);

    expect(state.contacts.map((c) => c.id), ['c1', 'c2']);
    expect(state.errorMessage, isNull);
  });

  test('si fallan los contactos, el resto de Diario igual carga', () async {
    final state = DiarioState(service: _FakeDiarioService()..fallarContactos = true);
    await esperarHasta(() => !state.isLoading);

    expect(state.contacts, isEmpty);
    expect(state.categories.map((c) => c.id), contains('cat_notas_personales'));
  });

  test('seleccionar un contacto notifica una vez a los oyentes', () async {
    final state = DiarioState(service: _FakeDiarioService());
    await esperarHasta(() => !state.isLoading);
    var notificaciones = 0;
    state.addListener(() => notificaciones++);

    state.selectContact('c2');

    expect(state.selectedContactId, 'c2');
    expect(notificaciones, 1);
  });
}
```

ViewModel nuevo: recibe `service` (y `clock` si usa fechas) por constructor; no dispares cargas en el constructor si puedes evitarlo (un `loadAll()` explícito es más fácil de probar).

## C. Servicio Supabase existente con FakeSupabase

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_supabase.dart';
import '../../helpers/rows/diario_contact_row.dart';

class _ServicioConFake extends DiarioSupabaseService {
  _ServicioConFake(this._client) : super.forTesting();
  final SupabaseClient _client;
  @override
  SupabaseClient? get client => _client;
}

void main() {
  late FakeSupabase fake;
  late DiarioSupabaseService servicio;

  setUp(() {
    fake = FakeSupabase.create();
    servicio = _ServicioConFake(fake.client);
  });

  test('getContacts pide las columnas sin avatar ordenadas por nombre', () async {
    fake.stubRest('GET', 'diario_contacts', body: [diarioContactRow(id: 'c1')]);

    final contactos = await servicio.getContacts();

    expect(contactos.single.id, 'c1');
    final req = fake.single('GET', 'diario_contacts');
    expect(req.query['select'], isNot(contains('avatar_url')));
    expect(req.query['order'], 'name.asc.nullslast');
  });

  test('saveContact hace upsert por id sin avatar cuando se pide', () async {
    fake.stubRest('POST', 'diario_contacts', body: null, status: 201);
    final contacto = DiarioContact.fromMap(diarioContactRow(avatarUrl: 'https://x/a.jpg'));

    await servicio.saveContact(contacto, includeAvatar: false);

    final req = fake.single('POST', 'diario_contacts');
    expect(req.query['on_conflict'], 'id');
    expect(req.headers['Prefer'], contains('merge-duplicates'));
    expect((req.body as Map).containsKey('avatar_url'), isFalse);
  });

  test('ante un error de permisos devuelve la reserva local', () async {
    fake.stubRest('GET', 'diario_contacts', status: 401,
        body: FakeSupabase.pgError(code: '42501', message: 'permission denied'));

    final contactos = await servicio.getContacts();

    expect(contactos, isNotEmpty, reason: 'getContacts cae en los contactos por defecto');
  });
}
```

## C2. Servicio nuevo con cliente inyectable

```dart
// lib/<modulo>/services/<x>_supabase_service.dart
class XSupabaseService {
  XSupabaseService({SupabaseClient? client}) : _client = client;
  static final XSupabaseService instance = XSupabaseService();
  final SupabaseClient? _client;

  SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

// test/<modulo>/services/<x>_supabase_service_test.dart
final fake = FakeSupabase.create();
final servicio = XSupabaseService(client: fake.client);
```

## D. Widget por clase de ventana

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/<modulo>/screens/<pantalla>.dart';
import 'package:quebrado_app_flutter/<modulo>/viewmodels/<x>_state.dart';

import '../../helpers/pump_app.dart';

void main() {
  late XState state;
  setUp(() => state = XState(service: FakeXService()));

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    testWidgets('muestra la lista y el botón de crear en ${window.name}', (tester) async {
      await pumpApp(
        tester,
        const MiPantalla(),
        providers: [ChangeNotifierProvider<XState>.value(value: state)],
        window: window,
      );

      expect(find.text('Mis notas'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sin overflow ni errores de layout');
    });
  }

  testWidgets('en compact el detalle se abre en otra pantalla; en expanded, al lado', (tester) async {
    // …afirma la diferencia de layout que define el diseño (docs/design/<feature>.md)
  });
}
```

- Prueba las clases de ventana que el diseño distingue (mínimo `compact` y `expanded` si la vista es responsiva).
- Busca por texto visible, `Key` o `Semantics`, no por tipo de widget interno.
- `pumpApp(..., settle: false)` si la pantalla tiene animaciones infinitas (indicadores de carga).
- Si la pantalla usa `context.read<OtroState>()`, añade su provider aunque el test no lo mire (si no: `ProviderNotFoundException`).

## E. SQLite en memoria (código que recibe un `Database`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false), // base nueva por test
    );
    await db.execute('CREATE TABLE cuentas (id TEXT PRIMARY KEY, saldo REAL NOT NULL)');
  });
  tearDown(() => db.close());

  test('insertar una cuenta la deja disponible para consulta', () async {
    await db.insert('cuentas', {'id': 'a1', 'saldo': 10.5});

    final filas = await db.query('cuentas');

    expect(filas, [{'id': 'a1', 'saldo': 10.5}]);
  });

  test('cada test empieza con la base vacía', () async {
    expect(await db.query('cuentas'), isEmpty);
  });
}
```
