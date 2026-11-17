-- ==============================================================================
-- MIGRACIÓN 016: NOTAS CON EDITOR ENRIQUECIDO (AppFlowy)
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de Supabase. Es idempotente y no borra nada.
--
-- Agrega la columna `document` a `notas` para guardar el documento del editor nuevo
-- (negrita, colores, enlaces, código, desplegables anidados…) como JSON.
-- Las columnas existentes se siguen llenando:
--   * blocks       → versión simplificada (lector clásico, PDF, versiones anteriores)
--   * content_text → texto en Markdown (búsqueda y Agente Ortiz)
--
-- Si la app se usa antes de correr este script, las notas se guardan igual pero sin
-- el formato enriquecido (solo la versión simplificada).
-- ==============================================================================

ALTER TABLE public.notas
    ADD COLUMN IF NOT EXISTS document JSONB;

COMMENT ON COLUMN public.notas.document IS
    'Documento del editor enriquecido (AppFlowy Editor, JSON). Fuente de verdad del contenido si no es NULL.';

-- Refrescar el caché de esquema de la API (para que PostgREST vea la columna nueva)
NOTIFY pgrst, 'reload schema';

-- ==============================================================================
-- VERIFICACIÓN
-- ==============================================================================
-- SELECT column_name, data_type FROM information_schema.columns
--  WHERE table_schema = 'public' AND table_name = 'notas' AND column_name = 'document';  -- 1 fila, jsonb
--
-- Notas ya guardadas con el editor nuevo:
-- SELECT COUNT(*) FILTER (WHERE document IS NOT NULL) AS con_formato, COUNT(*) AS total FROM public.notas;

-- ==============================================================================
-- ROLLBACK (solo si hace falta; se perdería el formato enriquecido, no el texto)
-- ==============================================================================
-- ALTER TABLE public.notas DROP COLUMN IF EXISTS document;
