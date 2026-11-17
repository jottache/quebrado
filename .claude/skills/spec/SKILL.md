---
name: spec
description: Convierte una idea en una spec (contrato del cambio) para quebrado-app haciendo preguntas hasta entenderla, y la guarda en specs/NN-slug.md en estado Borrador. No programa nada. Uso — /spec <descripción de lo que se quiere>.
argument-hint: <descripción de la feature o cambio>
disable-model-invocation: true
---

# /spec — escribir una spec

Petición: $ARGUMENTS

Tu trabajo es producir una spec clara y verificable. **No escribes código, no creas ramas y no propones implementar al final.**

## Fase 1 — Contexto (antes de preguntar)
Lee lo que aplique (Read con `offset`/`limit`, Grep):
- `CLAUDE.md`.
- `docs/reglas-de-negocio.md`, `docs/design-system.md`, `docs/pendientes.md`.
- `DATABASE_MODELS.md` y las migraciones de `supabase/` relacionadas.
- El código del módulo afectado (`quebrado-app-flutter/lib/<módulo>/`): modelos, servicio, ViewModel, pantallas.
- Los planes previos del módulo si existen (`ANIMO_PLAN.md`, `QUEBRADO_BS_PROYECCION_PLAN.md`, `AGENDA_COVEY_SISTEMA.md`, `RECORDATORIOS_TECNICO.md`, `habitos.md`, `Agenda.md`).
- Las dos specs más recientes de `specs/` (para el estilo y el siguiente número).

## Fase 2 — Preguntas (nunca se salta)
Pregunta en bloques de 3–5 preguntas, cada una con opciones y tu recomendación. Cubre lo que aplique:
- **Alcance**: qué entra y qué no; qué mini-app(s).
- **Usuario y flujo**: desde dónde se llega, pasos, dispositivo principal (móvil/escritorio/web).
- **Datos**: entidades y campos; ¿Supabase, SQLite local (`quebrado`) o ambos?; migración y datos existentes; libros/perfiles.
- **Dinero y monedas** (si aplica): moneda de registro, tasa usada (BCV/paralelo/euro) y en qué momento, redondeo.
- **Seguridad/privacidad**: RLS de tablas nuevas (la deuda `USING (true)` no se replica sin decisión), datos sensibles, ¿se envía algo a Gemini?
- **Respaldos**: ¿cambia el formato del respaldo JSON / la importación?
- **UX y estados**: vacío, carga, error, sin Supabase; responsive compact/medium/expanded; confirmaciones.
- **Integración con otras mini-apps** (menciones, agente, launcher, notificaciones).
- **Riesgos y decisiones ya cerradas**.
Para de preguntar cuando sepas: qué archivos cambian, cuál es el primer y el último paso, y cómo se verifica cada criterio.

Si la feature toca más de tres áreas (datos, varias mini-apps, agente, respaldos) o cuatro dominios de decisión, propone partirla en varias specs.

## Fase 3 — Redacción
Usa `template.md` (en esta carpeta). Si tienes todo, escribe la spec completa de una vez; si falta algo, sección por sección confirmando. Lo no decidido va a **Preguntas abiertas**, nunca se inventa. El plan de implementación indica el agente responsable de cada paso.

## Fase 4 — Guardado
- Número: siguiente `NN` libre en `specs/` (dos dígitos). Slug corto en kebab-case.
- Guarda `specs/NN-slug.md` con `Estado: Borrador`.
- Si falta `specs/.spec-config.yml`, créalo con:
  ```yaml
  AutoCreateBranch: true
  BaseBranch: feature/new-app
  BranchPrefix: spec-
  ```
- Termina con: ruta de la spec, resumen en 3 líneas, preguntas abiertas, y el recordatorio de que **solo una persona** cambia el estado a `Aprobado` antes de `/spec-impl NN`. Nunca marques tú la spec como aprobada.
