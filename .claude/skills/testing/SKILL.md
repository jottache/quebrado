---
name: testing
description: Cómo escribir y depurar tests en quebrado-app (Flutter + Provider + sqflite + Supabase). Úsala al crear o cambiar código en quebrado-app-flutter/lib, al escribir tests nuevos, al investigar un test en rojo o al medir cobertura. Cubre qué tipo de test usar, cómo simular Supabase (FakeSupabase), SQLite, ViewModels ChangeNotifier y widgets por clase de ventana, con plantillas copiables y una lista de control.
---

# Testing en quebrado-app

Archivos de esta skill:
- `SKILL.md` (este): reglas, qué test escribir, cómo correrlos.
- `mocking.md`: cómo simular Supabase, servicios, SQLite, reloj y plugins.
- `plantillas.md`: plantillas copiables (modelo, ViewModel, servicio, widget, SQLite).
- `checklist.md`: lista de control antes de dar un test por terminado.

Todo se ejecuta desde `quebrado-app-flutter/` (el paquete es `quebrado_app_flutter`).

## 1. Reglas (no negociables)

1. **Si un test falla, el sospechoso es el código nuevo**, no el test. Un test existente solo se cambia si se demuestra que estaba mal, y con confirmación de la persona.
2. **Prohibido**: `skip:`, aserciones vacías (`expect(true, isTrue)`), tests sin `expect`, bajar `.claude/coverage-threshold`, borrar tests, añadir líneas a `.claude/known-failures`.
3. **`.claude/known-failures` solo baja.** Son 5 tests que ya fallaban al implantar el sistema. Si arreglas uno, quítalo de la lista (la puerta falla si un test de la lista pasa). No se arreglan "de paso": están en `docs/pendientes.md`.
4. **Cada test debe poder fallar.** Comprueba rompiendo a propósito el código que prueba (invertir una condición, devolver otro valor), ejecuta el test, ve el rojo y **restaura con Edit (deshaciendo tu cambio) o desde una copia en el scratchpad. Nunca con `git checkout`/`git restore`**: borraría también los cambios sin commitear de la persona.
5. **No fijes en un test una regla inventada ni un bug conocido.** Si la regla no está en `docs/reglas-de-negocio.md`, en una spec aprobada o en el código actual de forma inequívoca, es una pregunta, no un test. Un bug listado en `docs/pendientes.md` no se "congela" con un test que lo dé por bueno.
6. **Tests espejo para lo nuevo**: `lib/a/b.dart` → `test/a/b_test.dart`. Los tests legados planos (`test/*_test.dart`) se quedan donde están; no se mueven ni se renombran.
7. **Nombres en español y en presente**, describiendo el comportamiento: `'devuelve la lista por defecto cuando Supabase falla'`, no `'test 1'` ni `'should work'`.
8. **Nada de red real, ni Supabase real, ni Gemini real** en tests. Sin `.env`, `SupabaseConfig.isConfigured` es false y los servicios caen a su modo local; para probar la ruta Supabase usa `FakeSupabase`.

## 2. Qué test escribir

| Cambiaste…                                   | Test                                                           | Plantilla |
| -------------------------------------------- | -------------------------------------------------------------- | --------- |
| `models/` (fromMap/toMap, cálculos)          | `test()` puro con filas realistas (`test/helpers/rows/`)       | A         |
| `viewmodels/` (ChangeNotifier)               | `test()` con servicio fake inyectado; afirma estado y `notifyListeners` | B |
| `services/*_supabase_service.dart`           | `test()` con `FakeSupabase`: afirma la petición y decide la respuesta | C / C2 |
| `services/` sin Supabase (parser, cálculo)   | `test()` puro                                                  | A         |
| `screens/`, `widgets/`, `dialogs/`           | `testWidgets` con `pumpApp` en las clases de ventana que apliquen | D      |
| SQL local (sqflite) en código nuevo          | SQLite en memoria con `sqflite_common_ffi`                      | E         |
| Migración `supabase/NNN_*.sql`               | No hay Postgres en tests: revisión manual + `test/contract/supabase_contract_test.dart` | — |

## 3. Infraestructura en `quebrado-app-flutter/test/`

| Pieza | Qué es |
| ----- | ------ |
| `helpers/pump_app.dart` | `pumpApp(tester, widget, providers: [...], window: WindowClass.compact)`: MaterialApp con el tema de la app (sin GoogleFonts) y MultiProvider. `WindowClass`: `compact` 390×844, `medium` 720×1024, `desktop` 1000×800, `expanded` 1280×800 (breakpoints 600/840/1200 de `lib/widgets/responsive_breakpoints.dart`). El tamaño se restaura solo. |
| `helpers/fake_supabase.dart` | `SupabaseClient` real con la red sustituida. `stubRest` / `stubRpc` deciden la respuesta; `single()` / `requestsTo()` devuelven la petición para afirmar tabla, filtros (`query`), cuerpo (`body`). **Una petición sin stub hace fallar el test al terminar, aunque el código se trague el error.** |
| `helpers/rows/` | Una factory por tabla con filas realistas de PostgREST: `diarioContactRow()`. Añade la tuya al necesitarla (`<tabla_singular>_row.dart`). |
| `contract/supabase_contract_test.dart` | Falla si `lib/` usa una tabla sin `CREATE TABLE` en `supabase/*.sql` o sin documentar en `DATABASE_MODELS.md`, o una RPC sin `CREATE FUNCTION`. Tiene listas de deuda que **no se amplían** y que fallan si un elemento ya se resolvió. |
| `all_imports_test.dart` | Generado por `tool/generate_all_imports_test.sh`; importa todo `lib/` (salvo archivos solo-web) para que la cobertura sea real. Si añades o borras archivos en `lib/`, falla con "Lista desactualizada": ejecuta `./tool/generate_all_imports_test.sh`. |

## 4. Cómo correr

```bash
cd quebrado-app-flutter
flutter test test/ruta/archivo_test.dart              # un archivo
flutter test test/ruta/archivo_test.dart --plain-name 'nombre del test'
flutter analyze --no-fatal-infos                      # 0 errores y 0 warnings
```

Puerta completa (analyze + suite comparada con known-failures + cobertura):
`.claude/hooks/suite-run.sh` desde la raíz del repo. O a mano:
`cd quebrado-app-flutter && flutter test --coverage && ../.claude/hooks/check-coverage.sh`.

Cobertura: umbral en `.claude/coverage-threshold` (31.3 % al implantar, medido sobre `SF:lib/` de `coverage/lcov.info`). **Solo sube**, y lo suben personas por hitos. Cada cambio trae sus tests.

## 5. Particularidades de este proyecto (leer antes de escribir tests)

- **Estado**: Provider + `ChangeNotifier` (no Riverpod). Los ViewModels nuevos reciben dependencias por constructor con valor por defecto al singleton: `XState({XService? service, DateTime Function()? clock})` (patrón de `AnimoState` y `DiarioState`).
- **Servicios Supabase existentes** son singletons con `SupabaseClient? get client => Supabase.instance.client`. Solo `DiarioSupabaseService`, `AnimoSupabaseService` y `MediaStorageService` tienen constructor `forTesting()`; el resto (notas, hábitos, recordatorios, agente, `SupabaseService` de finanzas) no se puede probar con `FakeSupabase` sin añadírselo (pendiente P-11). Para probar los que sí lo tienen: subclase con `super.forTesting()` que sobrescribe `client` (devuelve `fake.client`) o los métodos (fake de servicio). No se refactorizan solo para testear.
- **Servicios nuevos**: aceptan `SupabaseClient? client` inyectable (ver `mocking.md` §2).
- **SQLite de la app** (`DatabaseHelper.instance`, finanzas): en tests usa `sqflite_common_ffi` sobre un **archivo compartido y persistente** (`.dart_tool/sqflite_common_ffi/databases/quebrado.db`, más `quebrado_profiles.json` en la raíz del paquete). Persiste entre ejecuciones y lo usan a la vez varios archivos de test (la suite corre archivos en paralelo). Por eso: **no borres ni reinicies esa base en un test**, usa ids únicos y afirma cambios relativos, o mejor prueba la lógica sin `DatabaseHelper` (ver `mocking.md` §4).
- `AppState` tiene ganchos de test: `AppState.debugLocalDbIsSourceOfTruth` (restaurar a `null` en `tearDown`) y `debugSetRates(bcv:, euro:, parallel:)`.
- **Plugins nativos** (path_provider, pasteboard, local_auth, notificaciones, speech_to_text) no existen en la VM de tests: `MissingPluginException`. Simula el canal o aísla la lógica (ver `mocking.md` §5).
- **GoogleFonts** pide fuentes por red: no montes `MyApp` completo; usa `pumpApp`, que usa el tema sin GoogleFonts.
- **Fechas**: inyecta un reloj (`clock: () => DateTime(2026, 9, 28, 12)`) en lugar de `DateTime.now()`. Si tocas fechas, ejecuta también con otra zona: `TZ=America/Caracas flutter test …` y `TZ=UTC flutter test …`.
