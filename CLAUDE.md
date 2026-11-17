# CLAUDE.md — quebrado-app (OrtizApp)

Reglas del proyecto. Las leen siempre el hilo principal y todos los sub-agentes. Es la **fuente única**: los agentes y skills remiten aquí en vez de copiar. Si este archivo y el código no coinciden, manda el código y se corrige este archivo.

## 1. Qué es la app

Suite personal "OrtizApp" en Flutter (móvil, escritorio y web en Vercel) con varias mini-apps que se abren desde un launcher:

| Módulo (`lib/<módulo>/`) | Qué hace | Persistencia |
| --- | --- | --- |
| `quebrado/` | Finanzas multi-moneda (USD/VES/EUR, tasas BCV/paralelo/euro), cuentas, bolsillos, pagos recurrentes, mercado, libros (perfiles), respaldos, PIN/biometría | Supabase si está configurado; si no, SQLite local (`services/db_helper.dart`) |
| `diario/` | Diario personal / PRM de contactos, plantillas, notas personales, Ánimo (mood logs) | Supabase (+ fallback en memoria) |
| `habitos/` | Hábitos, rachas, recaídas, stacks (estética "terminal") | Supabase (+ semillas en memoria) |
| `recordatorios/` | Recordatorios, NLP, agenda semanal Covey de 4.ª generación | Supabase (+ datos locales) |
| `notas/` | Notas y acuerdos con bloques enriquecidos, PDF | Supabase |
| `agente/` | Chat con Gemini ("Agente Ortiz"), RAG sobre la suite, prompts editables | Supabase + API de Gemini |
| `rich_editor/` | Editor enriquecido compartido (appflowy_editor) | — |
| `screens/`, `widgets/`, `services/`, `theme/` (raíz de `lib/`) | Launcher, scaffold responsive de la suite, servicios y colores compartidos | — |

## 2. Estructura y stack

- App: `quebrado-app-flutter/` (paquete `quebrado_app_flutter`). Flutter 3.38.3, Dart ^3.10.
- Arquitectura **MVVM con `provider`**: cada módulo tiene `models/`, `services/`, `viewmodels/` (ChangeNotifier), `screens/`, `widgets/`, `dialogs/`, `theme/` y un barrel `<módulo>.dart`. Los providers se registran en `lib/main.dart` (`MultiProvider`).
- Supabase: `supabase_flutter` con **anon key**, sin login de usuario hoy. Servicios singleton (`XxxSupabaseService.instance`, `Supabase.instance.client`).
- SQL: migraciones **planas y numeradas** en `supabase/NNN_slug.sql` (siguiente número libre). Cada migración es idempotente (`IF NOT EXISTS`, `DROP POLICY IF EXISTS` + `CREATE POLICY`). Las tablas se documentan en `DATABASE_MODELS.md`.
- Sin Edge Functions ni backend propio: toda la lógica de negocio vive hoy en los ViewModels/servicios de la app.
- Variables en `quebrado-app-flutter/.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`, `GEMINI_MODEL`); plantilla en `.env.example`. Build web: `build.sh` + `vercel.json`.

## 3. Reglas de código (Flutter)

- Código nuevo va en el módulo que corresponde, respetando sus carpetas; nada de lógica de negocio en `screens/`/`widgets/` (va al ViewModel o a un servicio).
- Servicios nuevos que usan Supabase aceptan un `SupabaseClient? client` inyectable (default `Supabase.instance.client`) para poder testearlos con `FakeSupabase`. No refactorizar los existentes "de paso".
- Todo acceso a Supabase debe funcionar si Supabase no está configurado (mismo patrón de fallback que el módulo).
- Diseño: tokens y componentes de `docs/design-system.md`. Ningún color, tamaño de letra, espaciado, radio o breakpoint literal nuevo en pantallas; si falta un token, lo crea `ui-ux-designer`.
- Responsive: toda vista nueva funciona en compact (<600), medium y expanded (≥1200) usando `ResponsiveBreakpoints` y los helpers de `lib/widgets/`.
- Textos de UI en español. Montos siempre con su moneda; las conversiones usan las tasas del estado, nunca valores fijos.
- `flutter analyze` con 0 errores y 0 warnings. No añadir nuevas exclusiones a `analysis_options.yaml`.
- Editar código solo con Edit/Write (los hooks bloquean `sed -i`, redirecciones, etc.).

## 4. Reglas de datos y seguridad (Supabase)

- Cada tabla o RPC nueva: migración nueva `supabase/NNN_slug.sql` + entrada en `DATABASE_MODELS.md` (el test de contrato lo comprueba). Nunca editar una migración ya aplicada: se escribe otra.
- RLS siempre activada. Prohibido `DISABLE ROW LEVEL SECURITY`. Políticas solo dentro de migraciones de `supabase/`.
- Nunca `service_role` ni claves secretas dentro de `quebrado-app-flutter/` (el `.env` se empaqueta en el build web y es público).
- Deuda conocida (ver `docs/pendientes.md`): las políticas actuales son permisivas (`USING (true)`) con anon key pública, y la clave de Gemini viaja en el bundle web. No se replica ese patrón en tablas nuevas sin decisión explícita de la persona.
- Los datos son personales y sensibles (finanzas, diario, ánimo, contactos): nada de datos reales en tests, logs nuevos ni fixtures.

## 5. Reglas de negocio

- Fuente: `docs/reglas-de-negocio.md` (índice de reglas y de los documentos de diseño de cada módulo).
- **Lo no definido se convierte en pregunta, nunca en código inventado.** Las reglas las decide la persona.

## 6. Tests

- Skill `testing` (`.claude/skills/testing/`) es la referencia. Tests nuevos en espejo: `lib/a/b.dart` → `test/a/b_test.dart`; los tests planos antiguos se quedan.
- Todo archivo tocado en `models/`, `services/` o `viewmodels/` necesita test (lo exige el hook `mirror-tests.sh`).
- Si un test falla, el sospechoso es el código nuevo. Prohibido `skip`, aserciones vacías, borrar tests, bajar `.claude/coverage-threshold` o ampliar `.claude/known-failures` (ambos solo mejoran).
- Añadir/borrar archivos en `lib/` → `cd quebrado-app-flutter && ./tool/generate_all_imports_test.sh`.
- Puerta completa: `.claude/hooks/suite-run.sh` (analyze + suite + known-failures + cobertura).

## 7. Equipo de agentes (`.claude/agents/`)

| Agente | Rol |
| --- | --- |
| `architect` | Diseña datos, RLS, migraciones y plan por pasos. No programa. |
| `ui-ux-designer` | Flujos, UX, vistas por clase de ventana, accesibilidad y design system (dueño de `docs/design-system.md` y `lib/theme/`). Revisión visual. |
| `qa-analyst` | Criterios Given/When/Then y verificación. No toca código. |
| `flutter-dev` | Implementa pantallas, ViewModels y servicios de la app (implementador por defecto). |
| `supabase-backend` | Migraciones, RLS, RPC, `DATABASE_MODELS.md` y servicios `*_supabase_service.dart`. |
| `test-engineer` | Tests y diagnóstico de fallos. No cambia producción. |
| `revisor` | Revisa todo cambio de código: APROBADO / CAMBIOS REQUERIDOS. Solo lectura. |
| `security-auditor` | Seguridad y privacidad de datos personales. Solo informa. |
| `tech-lead` | Parte features grandes en tareas por agente y arbitra desacuerdos. |

Cómo lanzarlos: briefs autosuficientes, ≤ 3 archivos objetivo por agente, informe ≤ 40 líneas. El `revisor` lo lanza **siempre el hilo principal** al terminar cualquier cambio de código (máx. 3 rondas). Si se tocó UI, además revisión visual de `ui-ux-designer`.

## 8. Flujo de trabajo y git

- Rama base: **`feature/new-app`** (configurable en `specs/.spec-config.yml`). Specs: `/spec` → `specs/NN-slug.md` (Borrador; solo una persona la aprueba) → `/spec-impl NN` en rama `spec-NN-slug`.
- Fixes pequeños, docs o config: rama corta `fix/…`, `docs/…`, `chore/…` desde `feature/new-app`.
- Nunca commitear sin que la persona lo pida; nunca push a `main`. Commits con la línea `Co-Authored-By` del asistente; mensajes largos con `git commit -F <archivo>`.
- Antes de cada push a una rama con PR: `gh pr view <n> --json state` debe decir `OPEN`.
- Problemas encontrados fuera del cambio → `docs/pendientes.md`, no se arreglan "de paso".
- Lo que la IA no puede hacer sola (aplicar SQL en el panel de Supabase, desplegar en Vercel, probar en un dispositivo) se entrega como lista de pasos manuales.

## 9. Documentos

`docs/reglas-de-negocio.md` · `docs/design-system.md` · `docs/pendientes.md` · `docs/orquestacion.md` (inventario del sistema agéntico; actualizarlo al tocar `.claude/` o este archivo) · `DATABASE_MODELS.md` · `quebrado-app-flutter/TECHNICAL_DOCUMENTATION.md` · `specs/` · `docs/design/`, `docs/api-contracts/`, `docs/qa/`, `docs/adr/`, `docs/security/` · Guía del sistema: `guia-sistema-agentico.md`.
