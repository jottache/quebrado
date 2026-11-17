// Contrato app ↔ Supabase.
//
// Escanea lib/ y comprueba que:
//  1. toda tabla usada con `.from('x')` (PostgREST, no `.storage.from`) tiene su
//     CREATE TABLE en alguna migración de supabase/*.sql;
//  2. toda tabla usada está documentada en DATABASE_MODELS.md (nombre entre comillas
//     invertidas, p. ej. "Tabla: `accounts`");
//  3. toda RPC usada con `.rpc('y')` se crea con CREATE [OR REPLACE] FUNCTION.
//
// También cuenta los envoltorios con nombre de tabla literal: `_batchUpsert('x', …)`
// y `fetchTable('x', …)` de lib/services/supabase_service.dart.
// Límite conocido: un nombre de tabla que llega en una variable no literal no se ve.
//
// Las listas de deuda recogen incumplimientos que ya existían al crear el test.
// NO SE AMPLÍAN: una tabla nueva se documenta y se migra antes de usarla.
// Si arreglas un elemento, el test falla hasta que lo quites de la deuda (solo baja).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tablas usadas por la app sin documentar en DATABASE_MODELS.md. NO SE AMPLÍA.
const deudaSinDocumentar = <String>{
  'chat_artifacts',
  'chat_messages',
  'chat_prompts',
  'chat_sessions',
  'market_shopping_list_items',
  'mood_logs',
  'mood_tags',
  // DATABASE_MODELS.md la llama `user_life_roles`, pero la migración 011 y la app usan `roles`.
  'roles',
};

/// Tablas usadas por la app sin CREATE TABLE en supabase/*.sql. NO SE AMPLÍA.
const deudaSinMigracion = <String>{};

/// RPCs usadas por la app sin CREATE FUNCTION en supabase/*.sql. NO SE AMPLÍA.
const deudaRpcSinMigracion = <String>{};

final _tablaLiteral = RegExp(r'''(?<!storage)\s*\.from\(\s*['"]([A-Za-z0-9_]+)['"]\s*\)''');
final _envoltorio = RegExp(r'''\b(?:_batchUpsert|fetchTable)\(\s*['"]([A-Za-z0-9_]+)['"]''');
final _rpcLiteral = RegExp(r'''\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]''');
final _createTable = RegExp(
  r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?"?([a-z0-9_]+)',
  caseSensitive: false,
);
final _createFunction = RegExp(
  r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?"?([a-z0-9_]+)',
  caseSensitive: false,
);
final _nombreDocumentado = RegExp(r'`([a-z0-9_]+)`');

String _codigoLib() {
  final buffer = StringBuffer();
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    // Quita comentarios de línea para no contar ejemplos en la documentación.
    final sinComentarios = f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    buffer.writeln(sinComentarios);
  }
  return buffer.toString();
}

String _sqlMigraciones() {
  final dir = Directory('../supabase');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.sql')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map((f) => f.readAsStringSync()).join('\n');
}

Set<String> _grupos(RegExp re, String texto) =>
    re.allMatches(texto).map((m) => m.group(1)!.toLowerCase()).toSet();

void main() {
  late Set<String> tablasUsadas;
  late Set<String> rpcsUsadas;
  late Set<String> tablasCreadas;
  late Set<String> funcionesCreadas;
  late Set<String> documentadas;

  setUpAll(() {
    final codigo = _codigoLib();
    tablasUsadas = {..._grupos(_tablaLiteral, codigo), ..._grupos(_envoltorio, codigo)};
    rpcsUsadas = _grupos(_rpcLiteral, codigo);
    final sql = _sqlMigraciones();
    tablasCreadas = _grupos(_createTable, sql);
    funcionesCreadas = _grupos(_createFunction, sql);
    documentadas = _grupos(_nombreDocumentado, File('../DATABASE_MODELS.md').readAsStringSync());
  });

  test('el escáner encuentra las tablas y RPCs conocidas (si no, se rompió la expresión)', () {
    expect(tablasUsadas, containsAll(['transactions', 'diario_contacts', 'reminders', 'notas']));
    expect(tablasUsadas.length, greaterThan(20));
    expect(rpcsUsadas, contains('import_quebrado_backup'));
    expect(tablasCreadas, contains('transactions'));
    expect(funcionesCreadas, contains('import_quebrado_backup'));
  });

  test('toda tabla que usa la app tiene CREATE TABLE en supabase/*.sql', () {
    final faltan = tablasUsadas.difference(tablasCreadas).difference(deudaSinMigracion);
    expect(faltan, isEmpty,
        reason: 'Tablas usadas en lib/ sin migración. Crea la migración supabase/NNN_*.sql antes de usarlas.');
  });

  test('toda tabla que usa la app está documentada en DATABASE_MODELS.md', () {
    final faltan = tablasUsadas.difference(documentadas).difference(deudaSinDocumentar);
    expect(faltan, isEmpty,
        reason: 'Documenta la tabla en DATABASE_MODELS.md (p. ej. "Tabla: `nombre`").');
  });

  test('toda RPC que usa la app se crea en alguna migración', () {
    final faltan = rpcsUsadas.difference(funcionesCreadas).difference(deudaRpcSinMigracion);
    expect(faltan, isEmpty, reason: 'RPC sin CREATE FUNCTION en supabase/*.sql.');
  });

  test('la deuda solo baja: ningún elemento de la deuda está ya resuelto', () {
    final resueltasDoc = deudaSinDocumentar.where((t) => documentadas.contains(t) || !tablasUsadas.contains(t));
    final resueltasMig = deudaSinMigracion.where((t) => tablasCreadas.contains(t) || !tablasUsadas.contains(t));
    final resueltasRpc = deudaRpcSinMigracion.where((r) => funcionesCreadas.contains(r) || !rpcsUsadas.contains(r));
    expect([...resueltasDoc, ...resueltasMig, ...resueltasRpc], isEmpty,
        reason: 'Ya están resueltas (o ya no se usan): quítalas de la lista de deuda.');
  });
}
