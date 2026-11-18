# Inventario del sistema agéntico — quebrado-app

> Estado técnico exacto de cada pieza. Se actualiza **cada vez** que cambian `CLAUDE.md`, algo de `.claude/` o `.mcp.json` (lo exige `docs-sync.sh`). La explicación para personas está en `guia-sistema-agentico.md`.

**Última actualización:** 2026-11-17 — implantación inicial, adaptada del proyecto hermano (Flutter + Supabase + Odoo). Diferencias: sin `odoo-bridge` ni chequeos de Odoo/Edge Functions; `ui-designer` pasa a ser `ui-ux-designer` (diseño de flujos y experiencia además de lo visual); rama base `feature/new-app`; se añade `.claude/known-failures` porque la suite tenía 5 tests en rojo al empezar.

## Agentes (`.claude/agents/`)

| Agente | tools | skills | maxTurns | Escribe en | Estado |
| --- | --- | --- | --- | --- | --- |
| `architect` | Read, Grep, Glob, Bash, Write, Edit | — | 30 | `docs/design/` (sección Arquitectura), `docs/adr/`, `docs/api-contracts/` | activo |
| `ui-ux-designer` | todas | testing | 35 | `docs/design/` (sección UI/UX), `docs/design-system.md`, `lib/theme/`, `lib/<módulo>/theme/`, `lib/widgets/` + tests | activo (nuevo) |
| `qa-analyst` | Read, Grep, Glob, Bash, Write, Edit | — | 25 | `docs/qa/` | activo |
| `flutter-dev` | todas | testing | 40 | `quebrado-app-flutter/lib/`, `quebrado-app-flutter/test/` | activo |
| `supabase-backend` | todas | testing | 35 | `supabase/`, `DATABASE_MODELS.md`, `docs/api-contracts/`, `lib/*/services/*supabase*` + tests | activo |
| `test-engineer` | todas | testing | 35 | `quebrado-app-flutter/test/` | activo |
| `revisor` | Read, Grep, Glob, Bash | — | 30 | nada (solo lectura) | activo |
| `security-auditor` | Read, Grep, Glob, Bash, Write | — | 30 | `docs/security/` | activo |
| `tech-lead` | Read, Grep, Glob, Bash, Write | — | 20 | scratchpad / `docs/` | activo |

## Skills (`.claude/skills/`)

| Skill | Archivos | Invocación | Estado |
| --- | --- | --- | --- |
| `spec` | `SKILL.md`, `template.md` | solo persona (`disable-model-invocation`) | activo |
| `spec-impl` | `SKILL.md` | solo persona (`disable-model-invocation`) | activo |
| `testing` | `SKILL.md`, `mocking.md`, `plantillas.md`, `checklist.md` | precargada en flutter-dev, supabase-backend, test-engineer, ui-ux-designer | activo |
| `ortiz-dark-ui` | `SKILL.md` | por descripción (crear, cambiar o revisar UI de quebrado-app); remite a `docs/design-system.md` v2 | activo (spec 01; aprobada por la persona el 2026-11-17; spec 05 añade los componentes de `lib/widgets/ortiz/`) |

Configuración de specs: `specs/.spec-config.yml` (`BaseBranch: feature/new-app`, `BranchPrefix: spec-`).

## Hooks (`.claude/settings.json` → `.claude/hooks/`)

| Evento | Matcher | Script | Timeout | Qué hace |
| --- | --- | --- | --- | --- |
| PreToolUse | Bash | `guard-bash.py` | 10 s | Bloquea escrituras y volcados de código (`.dart`, `.sql`, `lib/`, `test/`, `supabase/`) por terminal |
| PreToolUse | Edit\|Write\|MultiEdit | `guard-rls.py` | 10 s | Políticas solo en `supabase/NNN_*.sql`; nunca desactivar RLS; sin `service_role` en la app; sin claves `AIza…` fuera de `.env` |
| PostToolUse | Edit\|Write\|MultiEdit | `test-related.sh` | 240 s | `dart analyze` del archivo + test espejo o hasta 3 tests que lo importan |
| Stop | — | `test-suite.sh` → `suite-run.sh` | 480 s | Puerta: analyze → suite JSON → `parse-test-report.py` vs known-failures → `check-coverage.sh`; caché por huella (`lib-fingerprint.sh`, `.last-green`) |
| Stop | — | `mirror-tests.sh` | 30 s | `models/`, `services/`, `viewmodels/` tocados exigen test espejo o test que los importe |
| Stop | — | `docs-sync.sh` | 30 s | Cambios en `.claude/`, `CLAUDE.md` o `.mcp.json` exigen actualizar este inventario |

Auxiliares: `lib-json.sh` (lectura de JSON con python3), `suite-green.sh` ("verde" / "no verificado"), `parse-test-report.py` (rojo también sin evento `done`, con `done.success=false` sin fallos o con `skip` nuevo), tests `guard-bash.test.py` (83), `guard-rls.test.py` (37) y `parse-test-report.test.py` (16). `suite-run.sh` usa cerrojo `.claude/hooks/.suite-lock/` y borra el `lcov.info` viejo. Estado local (gitignored): `.claude/hooks/.last-green`, `.claude/hooks/.last-report*`, `.claude/hooks/.suite-lock/`.

## Umbrales y deuda congelada

| Archivo | Valor | Regla |
| --- | --- | --- |
| `.claude/coverage-threshold` | 31.3 (% de líneas de `lib/`, con `all_imports_test`) | solo sube |
| `.claude/known-failures` | 4 tests (widget_test, reminders_pinned_banner_and_sync, multi_currency_balance, `~`mobile_payment_recipient (inestable, P-14)) con su causa; diario_clipboard_image se quitó el 2026-11-17 (spec 01) porque ya pasa | solo baja (P-10 en `docs/pendientes.md`) |
| `.claude/known-skips` | 2 tests de `manual_income_savings_test.dart` | solo baja; todo `skip` nuevo = rojo (P-17) |

## Infraestructura de tests (`quebrado-app-flutter/test/`)

| Pieza | Estado |
| --- | --- |
| `helpers/pump_app.dart` (+ `pump_app_test.dart`, 6 casos) | activo; `WindowClass` compact/medium/desktop/expanded = 390/720/1000/1280 px; tema de `main.dart` sin GoogleFonts |
| `helpers/fake_supabase.dart` (+ `fake_supabase_test.dart`, 8 casos) | activo; `stubRest`/`stubRpc`/`pgError`; petición sin stub falla en tearDown; en `testWidgets` usar `tester.runAsync`; los servicios existentes no son inyectables (P-11) |
| `helpers/rows/diario_contact_row.dart` | activo (factory de ejemplo) |
| `contract/supabase_contract_test.dart` | activo; deuda congelada: 8 tablas sin documentar (P-15); falla si la deuda crece o si un elemento ya se resolvió |
| `all_imports_test.dart` + `tool/generate_all_imports_test.sh` | activo; 209 archivos (excluye `clipboard_image_web.dart` y `web_splash_web.dart`) |

## Límites conocidos de los guards

- `guard-bash`: no ve scripts guardados (`python3 x.py`, `./tool/*.sh`), `bash -c`, `awk -i inplace`, `ruby -e`, `git show HEAD:archivo` ni rutas en variables (`$S/x.dart`); la excepción del scratchpad exige la ruta literal. Falso positivo: texto que cita una ruta `.dart`/`.sql` tras `>` → `git commit -F` o Write. Tests: 83 casos.
- `guard-rls`: políticas/RLS solo se vigilan en archivos de código (`.sql`, `.dart`, `.py`, `.sh`, `.js`, `.ts`), nunca en `.md` ni en `.claude/`, para que la documentación pueda citarlas. Tests: 37 casos.
- `test-related` y la puerta no bloquean por tests listados en `.claude/known-failures` (ruta alternativa con la variable `KNOWN_FAILURES_FILE`).
- Puerta completa: ~100 s.
- `tool/generate_all_imports_test.sh --check` compara sin escribir.

## Documentos

| Documento | Dueño | Estado |
| --- | --- | --- |
| `CLAUDE.md` | persona / hilo principal | activo |
| `guia-sistema-agentico.md` | hilo principal | activo |
| `docs/reglas-de-negocio.md` | persona | índice inicial; tabla de reglas confirmadas vacía |
| `docs/design-system.md` | `ui-ux-designer` | v2 (spec 01): tema oscuro, tokens de `lib/theme/`, transición R-01 |
| `docs/pendientes.md` | todos | P-01…P-26 iniciales; P-27…P-35 transición de la spec 01; P-21 resuelto |
| `docs/design/`, `docs/api-contracts/`, `docs/qa/`, `docs/adr/`, `docs/security/`, `specs/` | según README de cada carpeta | vacíos (solo README) |

## Historial

| Fecha | Cambio |
| --- | --- |
| 2026-11-17 | Implantación inicial del sistema agéntico. |
| 2026-11-17 | Ronda 1 del `revisor`: la puerta exige el evento `done`, congela skips (`known-skips`), admite inestables (`~`), cerrojo y borrado del lcov viejo; `pump_app` con el tema completo; `FakeSupabase` verifica antes del dispose; `--check` en el generador. |
| 2026-11-17 | Ronda 2 del `revisor`: APROBADO. Menores corregidos: limpieza atómica del cerrojo (también sin pid tras 1 min), `KNOWN_SKIPS_FILE` en la huella, caso de fallo de carga oculto en el test del parser. |
| 2026-11-17 | Spec 01, paso 7: skill `ortiz-dark-ui`, `docs/design-system.md` v2, tokens `OrtizSpace`/`OrtizRadius` en `lib/theme/ortiz_space.dart`. |
| 2026-11-17 | Spec 05: skill `ortiz-dark-ui` actualizada (componentes de `lib/widgets/ortiz/`, entradas con `ortizStaggered` y no `flutter_animate`); guardián `test/contract/no_hardcoded_styles_test.dart` + `no_hardcoded_styles_debt.txt` (deuda de estilos escritos a mano que solo baja); script `tool/codemod_tokens.py` (lo ejecuta la persona: `guard-bash` bloquea scripts que escriben código). |
