# Guía del sistema agéntico — quebrado-app

> Cómo trabaja Claude Code en este repo: quién hace qué, qué se comprueba solo y qué documentos usa.  
> **Parte 1** es la explicación sencilla. **Parte 2** es la documentación detallada (para quien mantiene o amplía el sistema).  
> El inventario técnico exacto (estado de cada pieza) está en `docs/orquestacion.md`. Si esta guía y el código no coinciden, manda el código y hay que corregir la guía.  
> Adaptada el 2026-11-17 del sistema de un proyecto hermano (Flutter + Supabase + Odoo). Aquí no hay Odoo ni Edge Functions, y se añadió un agente de diseño UI/UX (`ui-ux-designer`).

---

# Parte 1 — Explicación sencilla

## 1. La idea en una frase

En vez de un único asistente que hace todo "a su manera", el repo tiene **un equipo de especialistas** (agentes), **manuales de trabajo** (skills), **controles automáticos que no se pueden saltar** (hooks) y **documentos de referencia** que todos leen. El resultado: los cambios salen probados, revisados y siguiendo las mismas reglas, aunque los haga una IA.

## 2. Las cinco piezas

| Pieza | Dónde vive | Qué es, en sencillo |
| --- | --- | --- |
| **Reglas del proyecto** | `CLAUDE.md` | El reglamento. Claude y todos los agentes lo leen siempre, al empezar. Dice cómo está hecha la app, qué no se toca y cómo se trabaja. |
| **Agentes** | `.claude/agents/` | Especialistas con un rol fijo (diseñar datos, diseñar UI/UX, programar Flutter, tocar Supabase, revisar…). Cada uno sabe qué puede y qué no puede hacer. |
| **Skills** | `.claude/skills/` | Manuales paso a paso para tareas concretas: escribir una spec, implementarla, escribir tests. |
| **Hooks** | `.claude/hooks/` + `.claude/settings.json` | Controles automáticos. Se ejecutan solos y frenan el trabajo si algo está mal (tests en rojo, una regla de seguridad rota…). No dependen de que la IA "se acuerde". |
| **Documentos** | `docs/` | La memoria del proyecto: reglas de negocio, design system, pendientes, contratos de datos, auditorías. Los agentes los consultan cuando los necesitan. |

## 3. El equipo de agentes

| Agente | Qué hace | Cuándo se usa | Qué NO hace |
| --- | --- | --- | --- |
| `architect` | Diseña una feature antes de programarla: tablas, permisos (RLS), migración, SQLite local vs. Supabase y plan por pasos. | Antes de un módulo nuevo, una tabla nueva o una decisión que afecta a varias mini-apps. | No programa. |
| `ui-ux-designer` | **Diseñador UI/UX.** Diseña el flujo y cómo se ve cada pantalla en móvil, tablet y escritorio; estados (vacío, carga, error), textos, accesibilidad; cuida el design system. | Antes de una vista o flujo nuevo, y después para la revisión visual y de usabilidad. | No programa pantallas de features ni toca datos. |
| `qa-analyst` | Escribe criterios de aceptación ("dado… cuando… entonces…") y luego comprueba que se cumplan. | Antes de desarrollar y al terminar. | No toca código. |
| `flutter-dev` | Programa la app: pantallas, ViewModels, modelos, servicios, navegación. | Implementador por defecto. | No escribe migraciones SQL ni cambia el design system. |
| `supabase-backend` | Base de datos: migraciones, permisos RLS, funciones (RPC), `DATABASE_MODELS.md` y los servicios de Supabase de la app. | Todo lo que toca datos o permisos. | No toca pantallas. |
| `test-engineer` | Escribe tests y averigua por qué falla algo. | Para tests nuevos o fallos difíciles. | No cambia el código de la app. |
| `revisor` | Revisa cada cambio antes de darlo por bueno: APROBADO o CAMBIOS REQUERIDOS. | **Siempre**, al terminar cualquier cambio de código. | No puede editar nada. |
| `security-auditor` | Busca problemas de seguridad y privacidad (datos personales, claves expuestas, permisos). | Antes de cada release y tras tocar tablas, permisos, respaldos o el agente. | Solo informa; no corrige. |
| `tech-lead` | Parte una feature grande en tareas para cada agente y arbitra desacuerdos con el revisor. | Features grandes o discusiones. | No programa ni revisa líneas. |

## 4. Las skills (manuales)

| Skill | Cómo se usa | Qué hace |
| --- | --- | --- |
| `/spec` | La escribes tú: `/spec quiero que el bolsillo…` | Te hace preguntas hasta entender bien lo que quieres y escribe una "spec" (el contrato del cambio) en `specs/`. **No programa nada.** |
| `/spec-impl` | La escribes tú cuando la spec está aprobada: `/spec-impl 01` | Crea una rama desde `feature/new-app` y programa la spec **paso a paso**, parando en cada paso para que revises. |
| `testing` | Se carga sola en `flutter-dev`, `supabase-backend`, `test-engineer` y `ui-ux-designer`. | Explica cómo escribir buenos tests en este proyecto (ViewModels con Provider, servicios con Supabase simulado, widgets por tamaño de pantalla, plantillas, lista de control). |

## 5. Los hooks (controles automáticos)

| Hook | Cuándo corre | Qué hace |
| --- | --- | --- |
| `guard-bash.py` | Antes de cada comando de terminal | Bloquea escribir código (`.dart`, `.sql`) por terminal (`sed -i`, redirecciones, copias, parches, formateadores) y volcar código entero con `cat`. Obliga a editar con las herramientas normales, para que se vean los cambios y se disparen los tests. |
| `guard-rls.py` | Antes de cada edición | Bloquea escribir políticas RLS fuera de una migración de `supabase/`, desactivar RLS, poner la clave secreta de Supabase (`service_role`) dentro de la app y pegar claves de Google/Gemini en el código. |
| `test-related.sh` | Después de cada edición | Si se tocó un `.dart`, analiza ese archivo y corre su test (o los tests que lo usan). |
| `test-suite.sh` | Al terminar el turno | Corre el análisis completo, **todos** los tests y la cobertura mínima. Si algo falla, el trabajo no se puede dar por terminado. Si nada cambió desde la última vez en verde, tarda 1 segundo. |
| `mirror-tests.sh` | Al terminar el turno | Exige que todo archivo tocado en `models/`, `services/` o `viewmodels/` tenga su test. |
| `docs-sync.sh` | Al terminar el turno | Si cambió la configuración de la IA (agentes, skills, hooks, `CLAUDE.md`), exige actualizar el inventario `docs/orquestacion.md`. |

## 6. Los documentos que importan

| Documento | Para qué sirve |
| --- | --- |
| `CLAUDE.md` | El reglamento del proyecto. |
| `docs/reglas-de-negocio.md` | Índice de las reglas de cada mini-app (monedas, bolsillos, hábitos, Covey…) y de dónde están escritas. |
| `docs/design-system.md` | Cómo debe verse la app: colores, tipografía, espaciados, responsive, componentes, accesibilidad y deuda de diseño. |
| `docs/pendientes.md` | Problemas encontrados que todavía no se arreglaron. Nada se pierde. |
| `docs/orquestacion.md` | Inventario técnico: qué agentes, skills y hooks hay y en qué estado. |
| `DATABASE_MODELS.md` | Tablas y modelos de cada mini-app (el test de contrato lo usa). |
| `specs/` | Las specs: qué se va a construir y cómo se sabe que está terminado. |
| `docs/design/`, `docs/api-contracts/`, `docs/qa/`, `docs/adr/`, `docs/security/` | Diseños de features, contratos de datos, criterios de QA, decisiones de arquitectura y auditorías. |

## 7. Cómo fluye un cambio

**Cambio pequeño o mediano (el camino habitual):**

```
Tú: /spec <idea>  ──►  Claude pregunta  ──►  specs/NN-nombre.md (Borrador)
                                                     │
                       Tú lo lees y lo cambias a "Aprobado"  (solo una persona puede)
                                                     │
Tú: /spec-impl NN ──►  rama spec-NN-nombre desde feature/new-app
                       ──►  paso 1 ── (hooks: análisis + test del archivo) ── tú revisas
                       ──►  paso 2 … último paso
                                                     │
                       revisor ──► CAMBIOS REQUERIDOS ──► se corrige ──► revisor (máx. 3 rondas)
                                                     │
                                                 APROBADO   (+ revisión visual de ui-ux-designer si hubo UI)
                                                     │
                       commit + PR hacia feature/new-app  (al final del turno, el hook corre toda la suite)
```

**Feature grande:** `tech-lead` la parte en tareas → `architect` diseña datos y permisos → `ui-ux-designer` diseña flujo y pantallas → `qa-analyst` escribe criterios → `supabase-backend` / `flutter-dev` implementan con tests → `revisor` + revisión visual de `ui-ux-designer` → `security-auditor` si tocó permisos, datos personales o el agente.

## 8. Qué cambia para ti en el día a día

- **Pide cambios grandes con `/spec`.** Las preguntas del principio ahorran horas después.
- **La spec la apruebas tú.** Claude nunca la marca como aprobada.
- **Nada se da por terminado sin el `revisor` y sin la suite en verde.** Si un turno tarda más de un minuto al final, es el hook corriendo los tests.
- **Si un hook bloquea, no es un fallo del sistema**: es una señal de que falta algo (un test, una regla). No lo desactives para "seguir".
- **Los problemas que aparecen fuera del cambio** no se arreglan "de paso": van a `docs/pendientes.md`.
- **Lo que la IA no puede hacer sola** (ejecutar SQL en el panel de Supabase, desplegar en Vercel, probar en el teléfono) te lo deja como lista de pasos manuales.

## 9. Preguntas frecuentes (versión corta)

- **¿Puedo saltarme `/spec` para un arreglo de una línea?** Sí: rama corta `fix/…` desde `feature/new-app`. El revisor y los hooks aplican igual.
- **¿Por qué Claude no usa `sed` para cambiar varios archivos?** Porque el guard lo bloquea: los cambios deben hacerse con Edit/Write para que se vean y se prueben.
- **¿Por qué hay tests en rojo "permitidos"?** Había 5 tests fallando (y 2 omitidos) antes de implantar el sistema. Están congelados en `.claude/known-failures` y `.claude/known-skips`: un fallo o `skip` **nuevo** bloquea; los listados se informan como deuda; y si uno se arregla, hay que quitarlo de la lista (las listas solo bajan).
- **¿La cobertura de tests es baja?** Sí. Hay un mínimo en `.claude/coverage-threshold` que **solo sube**; cada cambio nuevo trae sus tests.
- **¿Quién decide las reglas de negocio?** Tú. Lo no definido se convierte en pregunta, nunca en código inventado.

---

# Parte 2 — Documentación detallada

## 10. Cómo carga Claude Code cada pieza

| Pieza | Se carga… | Ocupa contexto… |
| --- | --- | --- |
| `CLAUDE.md` | Al empezar cada sesión y en cada sub-agente. | Siempre (por eso se mantiene compacto y es la fuente única). |
| Agentes (`.claude/agents/*.md`) | Al abrir la sesión. | Solo su `description` hasta que se lanzan; al lanzarse, su cuerpo es el prompt del sub-agente. |
| Skills (`.claude/skills/*/SKILL.md`) | Al abrir la sesión. | Solo su `description` hasta que se usan; las precargadas (`skills:` en un agente) entran al arrancar ese agente. `/spec` y `/spec-impl` tienen `disable-model-invocation: true`: solo las invoca una persona. |
| Hooks (`.claude/settings.json`) | Al abrir la sesión. | Nada: son scripts externos. Su `stderr` llega al modelo solo cuando bloquean. |
| Documentos (`docs/`) | Bajo demanda. | Solo lo que se lee. |

**Regla práctica:** si cambias agentes, skills, hooks o `CLAUDE.md`, abre una sesión nueva para trabajar con la versión actualizada.

**Los sub-agentes no ven la conversación.** Reciben `CLAUDE.md`, su propio `.md` y el encargo (brief) que les escribe el hilo principal; devuelven solo un informe. Por eso los briefs deben ser autosuficientes y los informes, concretos.

## 11. Los agentes en detalle

Estructura habitual de cada `.claude/agents/<nombre>.md` (el `revisor` tiene su propio formato de informe; `flutter-dev` cierra con "Definición de hecho" y `tech-lead` con "Criterio de decisión"):

```markdown
---
name: <nombre>
description: <cuándo usarlo — es lo que el hilo principal lee para elegir agente>
tools: <opcional; sin "tools" = todas. Así se hacen agentes de solo lectura>
model: inherit
skills: [testing]          # opcional: skills precargadas
maxTurns: <tope de turnos>
---
## Herramientas y contexto (obligatorio)   ← Edit/Write, Read con offset, no suite completa, informe ≤ 40 líneas
## Fuentes (no las dupliques aquí)          ← remite a CLAUDE.md y docs/
## Tu rol / Cómo trabajas
## Restricciones                            ← qué carpetas toca y cuáles no
## Salida esperada
```

| Agente | Superficie que toca | Entrega |
| --- | --- | --- |
| `architect` | Sección `## Arquitectura y datos` de `docs/design/<feature>.md`; `docs/adr/`; propuesta en `docs/api-contracts/` | Design doc con datos, RLS, migración, impacto en respaldos/SQLite/agente, plan por pasos con agente, preguntas abiertas |
| `ui-ux-designer` | Sección `## UI/UX` de `docs/design/<feature>.md`; `docs/design-system.md`; `lib/theme/`, `lib/<módulo>/theme/`, componentes compartidos de `lib/widgets/` (+ tests) | Flujo, wireframes ASCII por clase de ventana, estados, textos, accesibilidad; o informe de revisión visual/UX con veredicto |
| `qa-analyst` | `docs/qa/` | Criterios Given/When/Then (multi-moneda, libros, con/sin Supabase, responsive); veredicto por criterio; gaps |
| `flutter-dev` | `quebrado-app-flutter/lib/`, `quebrado-app-flutter/test/` (no theme ni SQL) | Código + tests + informe ≤ 40 líneas |
| `supabase-backend` | `supabase/`, `DATABASE_MODELS.md`, `docs/api-contracts/`, `lib/*/services/*supabase*` (+ tests) | Contrato, migración, servicio con tests y **lista de pasos manuales** |
| `test-engineer` | `quebrado-app-flutter/test/` (en producción solo `Key`s/`Semantics`) | Tests + salida real + mutaciones comprobadas |
| `revisor` | Ninguna (solo lectura) | Informe de formato fijo con veredicto |
| `security-auditor` | `docs/security/` | `audit-AAAA-MM-DD.md` con hallazgos por severidad y checklist de release |
| `tech-lead` | Planes en scratchpad o `docs/` | Tareas por agente con archivos, orden, dependencias y pasos manuales |

`architect` y `ui-ux-designer` comparten `docs/design/<feature>.md`: cada uno edita solo su sección con Edit.

### El agente de diseño UI/UX (`ui-ux-designer`)

Es la pieza nueva respecto del sistema de referencia (allí había un `ui-designer` centrado en lo visual). Además de cuidar tokens y componentes, se ocupa de la **experiencia**:

| Antes de programar | Después de programar |
| --- | --- |
| Objetivo y tarea del usuario, frecuencia y dispositivo | Revisión del diff y de las pantallas tocadas |
| Flujo: entradas (launcher, hub, command palette, agente), pasos, salidas | Tokens en vez de literales |
| Wireframe ASCII por clase de ventana (compact/medium/expanded) y qué es diálogo, sheet o drawer | Responsive en las tres clases (con tests de widget a varios tamaños) |
| Estados: vacío, carga, error, sin Supabase, montos largos/negativos | Estados y textos |
| Microcopy en español; confirmaciones en acciones de dinero o destructivas | Accesibilidad: contraste AA, objetivo táctil ≥ 48, `Semantics` |
| Accesibilidad e identidad del módulo (claymórfico en Quebrado, terminal en Hábitos…) | Veredicto con las mismas severidades que el `revisor` |

Es dueño de `docs/design-system.md`, que documenta el sistema **tal como está hoy** (con su deuda medida) y las reglas para código nuevo.

**Cómo lanzar un agente bien** (lo hace el hilo principal):

- Encargos pequeños: **≤ 3 archivos objetivo** por agente. Varios agentes cortos en paralelo (sobre archivos distintos) mejor que uno largo.
- Brief en un archivo del scratchpad cuando es largo, y en el prompt: qué se pidió, archivos, qué ya se descartó y qué entregar.
- El `revisor` lo lanza **siempre el hilo principal**; uno lanzado por un sub-agente no cuenta.
- Si un agente agota sus turnos sin informe, se le pide que lo entregue con lo que tenga (SendMessage).
- Restaurar un archivo tras una prueba de mutación: con Edit o desde una copia, **nunca con `git checkout`** (lección del proyecto de referencia).

## 12. El flujo de revisión en detalle

1. Al terminar una tarea de código, el hilo principal lanza al `revisor` con: qué se pidió, archivos tocados, rama base (`feature/new-app`) y (desde la 2.ª ronda) el informe anterior con qué se hizo con cada punto. Cada ronda es un agente nuevo sin memoria.
2. El `revisor` delimita el cambio (`git status`, `git diff`), lee los archivos tocados más allá del diff, busca usos de lo que cambió y revisa en orden: **A. regresiones y bugs** (dinero y monedas, fechas, aislamiento entre libros, fallback sin Supabase, respaldos) → **B. convenciones del proyecto** (MVVM, SQL, seguridad, design system, tests) → **C. calidad**.
3. Ejecuta las comprobaciones: `flutter analyze`, suite (reutiliza `suite-green.sh` si la huella coincide), otra zona horaria si toca fechas; el SQL lo revisa a mano.
4. Formato fijo del informe:

```
Veredicto: APROBADO | CAMBIOS REQUERIDOS
Alcance revisado: <archivos leídos>
Comprobaciones:
  analyze → … | tests → … | tz → … | sql → …
Hallazgos (por severidad, o "ninguno"):
  [bloqueante] <archivo:línea> — <problema> — <corrección sugerida>
  [importante] …
  [menor] …
Para pendientes: …
Riesgos no verificables: …
```

5. **Severidades:** *bloqueante* = bug, regresión, pérdida o fuga de datos entre libros, analyze/tests en rojo, secreto expuesto, RLS desactivada, convención que rompe la arquitectura; *importante* = incumple una convención, caso borde sin manejar, faltan tests, falta `DATABASE_MODELS.md`, valor de diseño literal, vista rota en una clase de ventana; *menor* = legibilidad. Ante la duda, se sube la severidad.
6. Se corrige todo lo bloqueante e importante; lo menor se corrige o se justifica. **Máximo 3 rondas**; si en la 3.ª sigue en CAMBIOS REQUERIDOS, se para y se presenta el informe a la persona.
7. Si el cambio tocó la UI, `ui-ux-designer` hace además la revisión visual/UX con el mismo esquema de severidades.

## 13. Specs: `/spec` y `/spec-impl`

`/spec <descripción>` (`.claude/skills/spec/`, solo la invoca una persona):

| Fase | Qué hace |
| --- | --- |
| 1. Contexto | Lee `CLAUDE.md`, `docs/reglas-de-negocio.md`, `docs/design-system.md`, `docs/pendientes.md`, `DATABASE_MODELS.md`, migraciones relacionadas, el código del módulo, los planes previos del módulo (`ANIMO_PLAN.md`, `QUEBRADO_BS_PROYECCION_PLAN.md`, `AGENDA_COVEY_SISTEMA.md`…) y las dos specs más recientes. |
| 2. Preguntas (nunca se salta) | Bloques de 3–5 preguntas con opciones y recomendación: alcance, flujo, datos (Supabase/SQLite/ambos, libros), **dinero y monedas**, **seguridad y privacidad** (RLS, Gemini), **respaldos**, UX y estados, integración con otras mini-apps, riesgos. Para cuando sabe qué archivos cambian, cuál es el primer y último paso y cómo se verifica. |
| 3. Redacción | Plantilla en español (`template.md`): cabecera (Estado, Depende de, Fecha, Módulos, Objetivo), Alcance, Flujo y UX, Modelo de datos, Contrato de datos, **Impacto** (respaldos, SQLite, agente, otras mini-apps, design system), Plan (con agente por paso), Criterios, Decisiones, Riesgos, Preguntas abiertas, Qué NO entra, Pasos manuales. |
| 4. Guardado | `specs/NN-slug.md` en estado `Borrador`; crea `specs/.spec-config.yml` si falta; **se detiene**. |

Si la feature toca más de tres áreas o cuatro dominios de decisión, propone partirla.

`/spec-impl NN` (`.claude/skills/spec-impl/`):

| Fase | Qué hace |
| --- | --- |
| 1. Identificar | Acepta `01-slug`, `01` o `slug`. |
| 2. Validar estado | Solo continúa si el estado es **Aprobado**; si no, mensaje fijo y para. |
| 3. Rama | Si hay cambios sin commitear, avisa y pregunta. `git fetch origin feature/new-app`; si una spec de la que depende no está mergeada, pregunta (rama apilada o esperar). Crea `spec-NN-slug` desde `origin/feature/new-app` (`specs/.spec-config.yml`). Muestra objetivo, alcance, contrato, plan y criterios. |
| 4. Implementar | Un paso por vez; tras cada uno, `flutter analyze` + tests espejo o revisión manual del SQL; espera confirmación. **Nunca commitea sola.** Ante una ambigüedad, para y ofrece 2–3 opciones. |
| 5. Cierre | `revisor` (+ `ui-ux-designer` si hubo UI, `security-auditor` si tocó datos personales) → criterios → puerta completa → spec a `Implementado` → commit y PR cuando se pida → pasos manuales. |

Estados válidos de una spec: `Borrador`, `En revisión`, `Aprobado`, `Implementado`, `Obsoleto`.

## 14. Testing: skill e infraestructura

La skill `testing` (`.claude/skills/testing/`: `SKILL.md`, `mocking.md`, `plantillas.md`, `checklist.md`) es la referencia completa. Infraestructura en `quebrado-app-flutter/test/`:

| Pieza | Qué es |
| --- | --- |
| Tests espejo | Tests nuevos: `lib/a/b.dart` → `test/a/b_test.dart`. Nombres en español, en presente. Los ~40 tests planos antiguos (`test/*_test.dart`) se quedan donde están. |
| `helpers/pump_app.dart` | Monta un widget como lo vería el usuario: `MultiProvider` con los ViewModels que se pasen, tema de la app y clase de ventana (`WindowClass.compact/medium/desktop/expanded` = 390/720/1000/1280 px). |
| `helpers/fake_supabase.dart` | `SupabaseClient` real con la red sustituida. Para testear **servicios**: se afirma la petición (tabla, filtros, cuerpo) y se decide la respuesta (filas o error de PostgREST). Una petición sin stub hace fallar el test **aunque el servicio se trague el error**. Requiere un cliente inyectable: los servicios nuevos lo traen; de los existentes, solo Diario, Ánimo y MediaStorage tienen `forTesting()` (P-11). |
| `contract/supabase_contract_test.dart` | Falla si la app usa una tabla sin `CREATE TABLE` en `supabase/` o sin documentar en `DATABASE_MODELS.md`, o llama a una RPC que ninguna migración crea (con lista de deuda explícita que no se amplía). |
| `all_imports_test.dart` | Generado por `tool/generate_all_imports_test.sh`; importa todo `lib/` para que la cobertura sea real. Se autoverifica: si se añaden o borran archivos, falla hasta regenerarlo. |
| Cobertura | Umbral en `.claude/coverage-threshold`. **Solo sube**; lo suben personas por hitos. |
| Fallos conocidos | `.claude/known-failures`: tests en rojo preexistentes, con su causa (`~` = inestable, depende del entorno). **Solo baja.** |
| Omitidos conocidos | `.claude/known-skips`: los 2 `skip` preexistentes. Cualquier `skip` nuevo pone la puerta en rojo. **Solo baja.** |
| Comprobar la lista de imports | `./tool/generate_all_imports_test.sh --check` compara sin escribir. |

Reglas clave: si un test falla, el sospechoso es el código nuevo; un test solo se cambia si se demuestra que estaba mal y con confirmación; prohibido `skip`, aserciones vacías, bajar el umbral, ampliar known-failures o borrar tests; cada test debe poder fallar; no se fijan en tests reglas inventadas ni bugs listados en `docs/pendientes.md`.

## 15. Hooks en detalle

Configurados en `.claude/settings.json`. Convención de salida: **0** sigue; **2** bloquea y el `stderr` llega al modelo como error a atender; en los hooks de Stop, la **segunda vuelta** (`stop_hook_active: true`) sale con **1** (avisa sin bloquear, para no entrar en bucle). Los hooks de shell leen su entrada con `lib-json.sh` (python3, sin `jq`).

### `guard-bash.py` — PreToolUse (Bash)

- **Código vigilado:** extensiones `.dart` y `.sql` y los directorios `quebrado-app-flutter/lib`, `quebrado-app-flutter/test` y `supabase`.
- **Bloquea escrituras:** heredocs/`python -c`/`node -e` que escriben código, redirecciones (`>`, `>>`, `1>`, `&>`, `>&`) y `tee` hacia código, `sed`/`perl -i` en cualquier posición (incluido `xargs`, `find -exec`, `env`, `-i.bak`), `cp`/`mv`/`git mv`/`install`/`rsync` con destino en código, `git apply` (salvo `--check`), `patch`, `dart format` sin `--output none`/`--set-exit-if-changed`, `dart fix --apply`.
- **Bloquea volcados:** `cat`, `nl`, `less`, `more`, `sed -n` sobre código sin `|` que filtre, y bucles `for … do cat`.
- **Permite:** `grep`, `head`, `tail`, `wc`, `git diff/status/log`, `flutter analyze/test`, `dart analyze`, `cat` de no-código y escribir en rutas literales del scratchpad.
- **Límites conocidos:** no ve lo que hace un script guardado ni `bash -c`. **Falsos positivos:** textos (p. ej. un mensaje de commit) que citan `sed -i` o una ruta de código junto a `>`; solución: Edit para docs, `git commit -F <archivo>` para mensajes.
- **Tests:** `python3 .claude/hooks/guard-bash.test.py`. Cada cambio en el guard lleva su caso.

### `guard-rls.py` — PreToolUse (Edit|Write|MultiEdit)

- Mira **solo el texto nuevo** (Write: `content`; Edit: `new_string`; MultiEdit: `edits[].new_string`).
- **Bloquea** `CREATE/ALTER/DROP POLICY` fuera de una migración `supabase/NNN_*.sql`, y `DISABLE`/`NO FORCE ROW LEVEL SECURITY` en cualquier archivo de código (`.sql`, `.dart`, `.py`, `.sh`, `.js`, `.ts`; los `.md` y `.claude/` pueden citarlas).
- **Bloquea** dentro de `quebrado-app-flutter/`: `service_role`, `SERVICE_ROLE_KEY` o un JWT cuyo payload diga `"role":"service_role"` (el `.env` de la app es público en web).
- **Bloquea** claves literales de Google/Gemini (`AIza…`) en cualquier archivo salvo `.env`.
- **No bloquea** `USING (true)`: es el patrón actual (deuda P-01 en `docs/pendientes.md`); lo vigilan el `revisor` y el `security-auditor`.
- **Tests:** `python3 .claude/hooks/guard-rls.test.py`.

### `test-related.sh` — PostToolUse (Edit|Write|MultiEdit)

- `.dart` de `lib` o `test`: `dart analyze <archivo>` (errores y warnings fallan, infos no) + tests: si es un test, ese test; si es de `lib/a/b.dart`, su espejo `test/a/b_test.dart`; si no hay espejo, hasta 3 tests que lo importan; si ninguno, avisa sin bloquear. Ignora `all_imports_test.dart`.
- Todo lo demás (incluido `.sql`): nada.

### `test-suite.sh` (+ `suite-run.sh`, `suite-green.sh`, `lib-fingerprint.sh`, `check-coverage.sh`, `parse-test-report.py`) — Stop

- **La puerta** (`suite-run.sh`): `flutter analyze --no-fatal-infos` (0 errores y 0 warnings) → `flutter test --coverage --reporter json` → `parse-test-report.py` compara con `.claude/known-failures` (fallo nuevo = rojo; listado = deuda informada; listado que ya pasa = rojo hasta quitarlo de la lista; con prefijo `~` = inestable, puede pasar o fallar) y con `.claude/known-skips` (todo `skip` nuevo = rojo); además da rojo si el runner se corta sin su evento final o termina en error sin ningún fallo (error de carga) → `check-coverage.sh` contra `.claude/coverage-threshold` (solo archivos de `lib/`; se borra el `lcov.info` viejo antes de medir).
- **Cerrojo:** dos puertas no corren a la vez (`.claude/hooks/.suite-lock/`); la segunda espera hasta 10 min y un cerrojo de un proceso muerto se limpia solo.
- **Caché por huella:** hash del **contenido** de `lib`, `test`, `tool`, `pubspec.yaml`/`.lock`, `analysis_options.yaml`, `supabase/*.sql`, `DATABASE_MODELS.md`, el umbral, known-failures, known-skips y los scripts de la puerta. Si la puerta pasó con ese contenido, se guarda en `.claude/hooks/.last-green` (gitignored) y no se repite (~1 s). Cambiar `docs/` no invalida la huella.
- `suite-run.sh` con argumentos (un subconjunto de tests) **no** registra huella. `suite-green.sh` responde "verde" o "no verificado" (lo usa el `revisor`).
- Tiempo de la puerta completa: ~100 s (la suite tiene ~300 tests).
- **Tests del parser:** `python3 .claude/hooks/parse-test-report.test.py` (informes sintéticos, incluido uno cortado).

### `mirror-tests.sh` — Stop

- Lista los `.dart` creados o modificados **sin commitear** en `lib/**/models/`, `lib/**/services/` y `lib/**/viewmodels/` y exige para cada uno su test espejo o algún test que lo importe.

### `docs-sync.sh` — Stop

- Si cambió `CLAUDE.md`, algo bajo `.claude/` o `.mcp.json` y no cambió `docs/orquestacion.md`, bloquea una vez pidiendo actualizar el inventario o justificar por qué no aplica.

### Probar un hook a mano

```bash
R=$PWD
printf '{"tool_input":{"file_path":"%s/quebrado-app-flutter/lib/quebrado/models/account.dart"}}' "$R" \
  | CLAUDE_PROJECT_DIR=$R .claude/hooks/test-related.sh; echo "exit=$?"
echo '{"stop_hook_active":false}' | CLAUDE_PROJECT_DIR=$R .claude/hooks/test-suite.sh; echo "exit=$?"
.claude/hooks/suite-green.sh
```

## 16. Design system dentro del sistema

- Fuente única: `docs/design-system.md` (personalidad por mini-app, tokens, responsive, componentes, patrones de UX, accesibilidad, deuda medida, checklist de revisión). Dueño: `ui-ux-designer`.
- Código: `AppColors` en `lib/theme/colors.dart`, colores por módulo en `lib/<módulo>/theme/`, `ResponsiveBreakpoints` y helpers responsive en `lib/widgets/`, componentes claymórficos en `lib/quebrado/widgets/`.
- Regla: código nuevo usa tokens y componentes existentes; si falta uno, lo crea `ui-ux-designer`. Ningún valor literal nuevo de color, tamaño de letra, espaciado, radio ni breakpoint en pantallas. Las pantallas existentes **no** se migran "de paso": la deuda está medida en el design system y en `docs/pendientes.md` (P-20 a P-24).

## 17. Ramas, PRs y git

| Situación | Rama | PR |
| --- | --- | --- |
| Trabajo con spec | `spec-NN-slug` creada por `/spec-impl` desde `origin/feature/new-app` | Uno por spec, hacia `feature/new-app` |
| Fix pequeño, docs, config | Rama corta desde `feature/new-app`: `fix/…`, `docs/…`, `chore/…` | Uno por rama |

- `main` no se toca desde el flujo agéntico; pasar `feature/new-app` a `main` es decisión de la persona.
- **Antes de cada push** a una rama con PR: `gh pr view <n> --json state` debe decir `OPEN` (un push a un PR ya mergeado queda huérfano).
- Commits: uno por paso coherente, con la línea `Co-Authored-By` del asistente. Mensajes largos con `git commit -F <archivo>`.
- Claude nunca commitea durante `/spec-impl` sin que se lo pidas.
- SQL: la IA no tiene acceso a Supabase; cada migración nueva termina en un paso manual "ejecutar `supabase/NNN_x.sql` en el SQL Editor".

## 18. Mantenimiento del sistema

| Quiero… | Cómo |
| --- | --- |
| Añadir un agente | Nuevo `.claude/agents/<nombre>.md` con la estructura de la §11; remite a `CLAUDE.md`; añádelo al equipo en `CLAUDE.md` y al inventario `docs/orquestacion.md` (lo exige `docs-sync.sh`). |
| Cambiar una regla del proyecto | Edita `CLAUDE.md` (fuente única). Si es de negocio, `docs/reglas-de-negocio.md`. No dupliques en los agentes. |
| Ajustar un guard | Añade primero el caso al `*.test.py`, luego cambia el guard, y corre los dos tests. |
| Subir el umbral de cobertura | Edita `.claude/coverage-threshold` (solo hacia arriba) tras comprobar la cobertura real con `.claude/hooks/suite-run.sh`. |
| Arreglar un test de known-failures | Arregla el código o el test (con confirmación) y quita su línea de `.claude/known-failures`. |
| Añadir una tabla o RPC | Migración nueva + `DATABASE_MODELS.md`; el test de contrato lo comprueba. |
| Añadir/borrar archivos en `lib/` | `cd quebrado-app-flutter && ./tool/generate_all_imports_test.sh`. |
| Actualizar la skill de testing | Prueba el patrón con código real antes de documentarlo. |
| Actualizar esta guía | Cuando cambie el flujo, un agente, una skill o un hook. El inventario técnico va en `docs/orquestacion.md`. |

## 19. Solución de problemas

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| "Bloqueado: escritura a código por Bash" | El guard detectó una escritura (o un falso positivo con texto que cita rutas de código). | Usa Edit/Write. Para un mensaje de commit, `git commit -F <archivo>`. |
| "Bloqueado: volcado de código" | `cat`/`sed -n` de un archivo de código. | Read con `offset`/`limit` o Grep. |
| "Bloqueado: políticas RLS fuera de una migración" | Se intentó escribir una política fuera de `supabase/NNN_*.sql`. | Crea una migración nueva. |
| El turno no termina: "Lista desactualizada" | Se añadió o borró un archivo en `lib/`. | `cd quebrado-app-flutter && ./tool/generate_all_imports_test.sh`. |
| El turno no termina: fallo nuevo de test | Un test que no está en known-failures falla. | Arregla el código (el sospechoso es el cambio nuevo). |
| El turno no termina: "quítalo de known-failures" | Un test congelado ahora pasa. | Borra su línea de `.claude/known-failures`. (Los marcados `~` son inestables y no bloquean.) |
| El turno no termina: "TESTS OMITIDOS NUEVOS" | Se añadió un `skip`. | Quítalo: `skip` está prohibido. |
| El turno no termina: "sin el evento final `done`" | `flutter test` se cortó (crash, kill, `exit` en un test). | Repite la puerta; si persiste, busca el test que mata el proceso. |
| "Esperando a otra ejecución de la puerta" | Otra puerta corre a la vez. | Espera; si no hay ninguna, borra `.claude/hooks/.suite-lock/`. |
| El turno no termina: "sin su test" | Se tocó un archivo de `models/`, `services/` o `viewmodels/` sin test. | Escribe el test (plantillas en la skill `testing`). |
| El turno no termina: "Cambió la configuración de la IA" | Se tocó `.claude/` o `CLAUDE.md` sin actualizar el inventario. | Actualiza `docs/orquestacion.md` o justifica por qué no aplica. |
| El turno no termina: cobertura bajo el umbral | Código nuevo sin tests suficientes. | Añade tests; no bajes el umbral. |
| Un test falla "Peticiones sin stub" | El servicio hace una petición que el test no previó. | Regístrala con `stubRest`/`stubRpc`: el mensaje dice método y ruta. |
| Un agente termina sin informe | Agotó `maxTurns`. | Pídele que entregue lo que tenga; parte el encargo. |
| Hiciste push pero el commit no aparece en ningún PR abierto | El PR se mergeó antes del push. | Rama nueva desde `feature/new-app`, cherry-pick y PR nuevo. |
| Algo nuevo de `.claude/` no aparece o se comporta como antes | Los cambios se cargan al abrir la sesión. | Abre una sesión nueva. |

## 20. Referencias

- Reglas: `CLAUDE.md` · Inventario: `docs/orquestacion.md`.
- Agentes: `.claude/agents/` · Skills: `.claude/skills/{spec,spec-impl,testing}/` · Hooks: `.claude/hooks/` + `.claude/settings.json` · Umbrales: `.claude/coverage-threshold`, `.claude/known-failures`.
- Negocio: `docs/reglas-de-negocio.md` · Diseño: `docs/design-system.md`, `docs/design/` · Datos: `DATABASE_MODELS.md`, `supabase/`, `docs/api-contracts/` · Técnica: `quebrado-app-flutter/TECHNICAL_DOCUMENTATION.md` · QA: `docs/qa/` · Decisiones: `docs/adr/` · Seguridad: `docs/security/` · Pendientes: `docs/pendientes.md` · Specs: `specs/`.
