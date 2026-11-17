# NN — <Título>

- **Estado:** Borrador <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** <specs NN o "ninguna">
- **Fecha:** AAAA-MM-DD
- **Módulo(s):** <quebrado | diario | habitos | recordatorios | notas | agente | rich_editor | suite>
- **Objetivo (una frase):** …

## Alcance
**Entra:**
- …

**Fuera:**
- …

## Flujo y UX
- Punto de entrada y pasos.
- Vista por clase de ventana (compact / medium / expanded) — o referencia a `docs/design/<feature>.md`.
- Estados: vacío, carga, error, sin Supabase.
- Textos clave (en español).

## Modelo de datos
| Entidad / tabla | Campo | Tipo | Notas |
| --- | --- | --- | --- |

Persistencia: Supabase / SQLite local / ambos. Libros/perfiles: …

## Contrato de datos
- Tablas y operaciones (`select`/`insert`/`update`/`delete`) por servicio.
- RPC: nombre, parámetros, retorno.
- RLS por tabla (quién lee/escribe). Si se usa una política permisiva, decisión explícita y su porqué.
- Migración: `supabase/NNN_slug.sql` (idempotente) + `DATABASE_MODELS.md`.

## Impacto
- [ ] Respaldo JSON / importación (`BackupService`, `import_quebrado_backup`)
- [ ] SQLite local de `quebrado` (`db_helper.dart`)
- [ ] Agente Ortiz (RAG / datos enviados a Gemini)
- [ ] Otras mini-apps (menciones, launcher, notificaciones)
- [ ] Design system (tokens/componentes nuevos)

## Plan de implementación
| Paso | Qué | Archivos | Agente | Verificación |
| --- | --- | --- | --- | --- |
| 1 | … | … | supabase-backend | revisión manual del SQL |
| 2 | … | … | flutter-dev | `flutter analyze` + tests espejo |

## Criterios de aceptación
- **CA-01** Dado … cuando … entonces …
- **CA-02** …

## Decisiones
**Tomadas:** …
**Descartadas (y por qué):** …

## Riesgos
- …

## Preguntas abiertas
- …

## Qué NO entra
- …

## Pasos manuales
- Ejecutar `supabase/NNN_slug.sql` en el SQL Editor de Supabase.
- …
