# Reglas de negocio — quebrado-app

> Índice de dónde están definidas las reglas de cada mini-app. **Las reglas las decide la persona**: si algo no está aquí ni en los documentos enlazados, se pregunta; nunca se inventa en código.
> Si un documento y el código no coinciden, manda el código y se anota la discrepancia en `docs/pendientes.md` para que la persona decida cuál es la regla correcta.
> A diferencia de un proyecto con backend, aquí las reglas viven en la app (ViewModels y servicios), no en Supabase.

## Reglas transversales

1. **Monedas:** USD, VES (Bs, tasa BCV) y EUR. Las conversiones usan las tasas del estado (`bcvRate`, `paraleloRate`, `euroRate` en `settings`), nunca valores fijos en el código.
2. **Libros (perfiles):** cada libro de `quebrado` tiene sus propios datos; uno no ve los de otro (`profile_id` en Supabase; base SQLite separada en local).
3. **Modo sin Supabase:** cada módulo funciona con su fallback local (SQLite en `quebrado`; memoria/semillas en el resto).
4. **Datos personales:** finanzas, diario, ánimo y contactos son privados; no se envían a terceros salvo al Agente Ortiz (Gemini) en lo que el módulo `agente` ya define.
5. **Idioma:** la app y sus textos están en español.

## Dónde están las reglas de cada módulo

| Módulo | Documento(s) | Secciones clave | Código donde viven |
| --- | --- | --- | --- |
| Quebrado (finanzas) | `quebrado-app-flutter/TECHNICAL_DOCUMENTATION.md` | §4 Algoritmos (dinero seguro, meta diaria, predicción BCV, asignaciones de bolsillo), §5 Políticas y validaciones (pago móvil, confirmación en timeline, cambio de divisas), §7 Gotchas | `lib/quebrado/viewmodels/app_state.dart`, `services/bcv_predictor.dart`, `services/rate_service.dart` |
| Quebrado — proyección y recurrentes en Bs | `QUEBRADO_BS_PROYECCION_PLAN.md` | Estado y decisiones (venta el mismo día del gasto, tasa BCV), §4 decisiones pendientes | `app_state.dart` |
| Respaldos | `DATABASE_MODELS.md` §7 | Respaldo JSON, restauración atómica (`import_quebrado_backup`), carga liviana | `services/backup_service.dart`, `supabase/003_import_backup_rpc.sql` |
| Diario / PRM | `DATABASE_MODELS.md` §3 | Contactos, plantillas, entradas, menciones | `lib/diario/viewmodels/diario_state.dart` |
| Ánimo | `ANIMO_PLAN.md`, `DATABASE_MODELS.md` §6B | §0 Decisiones, §6 Algoritmos de insights, §9 Decisiones abiertas | `lib/diario/viewmodels/animo_state.dart` |
| Hábitos | `habitos.md`, `DATABASE_MODELS.md` §4 | Rachas, hábitos negativos y recaídas | `lib/habitos/viewmodels/habitos_state.dart` |
| Recordatorios y Agenda Covey | `AGENDA_COVEY_SISTEMA.md`, `RECORDATORIOS_TECNICO.md`, `DATABASE_MODELS.md` §5 | Cuadrantes, roles, plan semanal, NLP | `lib/recordatorios/viewmodels/reminders_state.dart`, `services/nlp_parser.dart` |
| Notas y acuerdos | `DATABASE_MODELS.md` §6 | Bloques, reasignación de categorías al borrar, menciones bidireccionales | `lib/notas/viewmodels/notas_state.dart` |
| Agente Ortiz | `AGENDA_COVEY_SISTEMA.md` §6, `RECORDATORIOS_TECNICO.md` §7, `ANIMO_PLAN.md` | Herramientas RAG, propuestas de acción | `lib/agente/` |

`Agenda.md` es un prompt histórico (habla de Next.js); no es fuente de reglas.

## Reglas confirmadas por la persona

Cuando una spec cierre una decisión de negocio, se añade aquí con fecha y spec de origen:

| Fecha | Regla | Origen |
| --- | --- | --- |
| — | — | — |
