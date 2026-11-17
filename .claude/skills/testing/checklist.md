# Lista de control de tests

Recórrela antes de dar por terminado un cambio con tests. Si un punto no aplica, sáltalo a conciencia, no por olvido.

## Antes de escribir
- [ ] Sé qué comportamiento pruebo y de dónde sale la regla (código actual, spec aprobada, `docs/reglas-de-negocio.md`). Si la regla no está definida → pregunta, no test.
- [ ] El comportamiento no es un bug listado en `docs/pendientes.md` (no se congela un bug con un test).
- [ ] Elegí el tipo de test de la tabla de `SKILL.md` §2 y la plantilla correspondiente.

## Al escribir
- [ ] Ruta espejo para tests nuevos: `lib/a/b.dart` → `test/a/b_test.dart`.
- [ ] Nombres en español, en presente, describiendo el comportamiento.
- [ ] Datos realistas: filas de `test/helpers/rows/` (o una factory nueva ahí), montos y fechas creíbles (Bs, USD, EUR; tasas BCV plausibles).
- [ ] Nada de red real: Supabase con `FakeSupabase`, servicios con fakes (`forTesting()`), Gemini nunca.
- [ ] Sin dependencia del reloj real: `clock` inyectado o fechas fijas; si hay fechas, probado también con `TZ=UTC` y `TZ=America/Caracas`.
- [ ] Sin dependencia de la SQLite compartida de `DatabaseHelper` (o, si es inevitable, ids únicos y aserciones relativas; nunca borrar/cerrar esa base).
- [ ] Casos borde: lista vacía, null, error de Supabase (`pgError`), fallo de red tragado por el servicio, montos 0 / negativos, cambio de moneda.
- [ ] En servicios Supabase: afirmo la **petición** (tabla, filtros, columnas, cuerpo, `on_conflict`), no solo el resultado.
- [ ] En ViewModels: afirmo estado expuesto y `notifyListeners` (cuántas veces, si importa).
- [ ] En widgets: `pumpApp` en las clases de ventana del diseño (mínimo `compact` y `expanded` si es responsivo); búsqueda por texto visible, `Key` o `Semantics`; `tester.takeException()` es null.
- [ ] Cada `expect` aporta: sin `expect(true, isTrue)`, sin tests sin aserciones, sin `skip`.

## Al terminar
- [ ] **Mutación**: rompí a propósito el código probado, vi el test en rojo y lo restauré con Edit o desde una copia (nunca `git checkout`/`git restore`).
- [ ] `flutter test <mi_test>` en verde y `flutter analyze --no-fatal-infos` sin errores ni warnings.
- [ ] Si añadí o borré archivos en `lib/`: `./tool/generate_all_imports_test.sh`.
- [ ] Si usé una tabla o RPC nueva: migración en `supabase/NNN_*.sql` y entrada en `DATABASE_MODELS.md` (el test de contrato lo exige). No amplié las listas de deuda del contrato.
- [ ] No toqué `.claude/coverage-threshold` hacia abajo ni añadí líneas a `.claude/known-failures`. Si un test de known-failures pasa ahora, quité su línea.
- [ ] La puerta completa (`.claude/hooks/suite-run.sh`) pasa, o el hook de fin de turno lo hará.
- [ ] En el informe: salida real de los tests (no "deberían pasar"), cobertura si cambió, y qué mutaciones comprobé.
