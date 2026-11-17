---
name: spec-impl
description: Implementa paso a paso una spec APROBADA de specs/ en quebrado-app — crea la rama spec-NN-slug desde la rama base, implementa un paso por vez con verificación y pausa para revisión, y cierra con revisor, criterios y pasos manuales. Uso — /spec-impl NN (o NN-slug, o slug).
argument-hint: <NN | NN-slug | slug>
disable-model-invocation: true
---

# /spec-impl — implementar una spec

Argumento: $ARGUMENTS

## Fase 1 — Identificar
Busca en `specs/` el archivo que coincida con `NN`, `NN-slug` o `slug`. Si hay cero o varios, lista las candidatas y para.

## Fase 2 — Validar estado
Lee la cabecera. Solo continúas si `Estado:` es **Aprobado**. Si no, responde exactamente:
> La spec `<archivo>` está en estado `<estado>`. Solo se implementan specs en estado `Aprobado`, y ese cambio lo hace una persona.

y para.

## Fase 3 — Rama
1. Lee `specs/.spec-config.yml` (`AutoCreateBranch`, `BaseBranch` — por defecto `feature/new-app` —, `BranchPrefix`).
2. Si `git status` muestra cambios sin commitear, avisa y pregunta qué hacer (no los descartes nunca).
3. `git fetch origin <BaseBranch>`. Si la spec depende de otra que no está mergeada en la base, pregunta: rama apilada sobre la de la dependencia o esperar.
4. Crea `<BranchPrefix>NN-slug` desde `origin/<BaseBranch>` (si `AutoCreateBranch: true`; si no, pregunta).
5. Muestra: objetivo, alcance, contrato de datos, plan de pasos y criterios.

## Fase 4 — Implementar
Un paso del plan por vez, con el agente que indica la spec (o tú si es trivial) y respetando `CLAUDE.md`:
- Tras cada paso, verifica: app → `flutter analyze` + tests espejo del paso (el hook corre el test del archivo editado); SQL → revisión manual (idempotencia, RLS, número de migración, `DATABASE_MODELS.md`).
- Si añadiste/borraste archivos en `lib/`: `cd quebrado-app-flutter && ./tool/generate_all_imports_test.sh`.
- Resume lo hecho en ≤ 10 líneas y **espera confirmación** antes del siguiente paso.
- Ante una ambigüedad, para y ofrece 2–3 opciones con recomendación. No inventas reglas.
- **Nunca commiteas sin que la persona lo pida.**

## Fase 5 — Cierre
1. Lanza el `revisor` (desde el hilo principal) con: spec, archivos tocados y rama base. Corrige bloqueantes e importantes; máx. 3 rondas. Si tocó UI, revisión visual de `ui-ux-designer`. Si tocó datos personales, políticas o el agente, `security-auditor`.
2. Verifica cada criterio de aceptación (o con `qa-analyst`): CUMPLE / NO CUMPLE / NO VERIFICABLE.
3. Puerta completa en verde (`.claude/hooks/suite-run.sh`).
4. Cambia la spec a `Estado: Implementado` y anota desviaciones.
5. Cuando la persona lo pida: commit(s) y PR hacia la rama base (`gh pr create --base <BaseBranch>`), comprobando antes de cada push que el PR siga `OPEN`.
6. Entrega la lista de **pasos manuales** (SQL en Supabase, despliegue en Vercel, prueba en dispositivo).
