-- ==============================================================================
-- MIGRACIÓN 015: NORMALIZAR RECAÍDAS DE MALOS HÁBITOS (habit_logs)
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de Supabase. Es idempotente y NO borra nada.
--
-- Problema corregido en la app:
--   * "Reportar recaída" guardaba completed = false pero ponía value = 0 (se perdía
--     cuántas veces pasó).
--   * El +1 de un contador en un mal hábito guardaba completed = true, como si fuera un
--     logro, y el calendario lo pintaba como día cumplido.
--
-- Regla nueva para malos hábitos (habits.is_negative = TRUE):
--   completed = FALSE  → día con recaída;  value = número de recaídas (mínimo 1)
--   completed = TRUE o sin registro → día limpio
--
-- Este script lleva los registros antiguos a esa regla:
--   1. Contadores de malos hábitos con value > 0 marcados como "cumplidos" → recaída con ese valor.
--   2. Recaídas guardadas con value = 0 → value = 1 (el número exacto no se guardó; se
--      puede corregir día por día desde la app: detalle del hábito → tocar el día → ±1).
-- ==============================================================================

-- 0. VISTA PREVIA (ejecútala sola primero si quieres ver qué cambiará)
-- SELECT h.title, h.contact_id, l.log_date, l.value, l.completed, l.notes
--   FROM public.habit_logs l
--   JOIN public.habits h ON h.id = l.habit_id
--  WHERE h.is_negative
--    AND (l.completed = FALSE OR (h.type = 'counter' AND l.value > 0))
--    AND (l.completed = TRUE OR l.value < 1)
--  ORDER BY h.title, l.log_date;

-- 1. NORMALIZACIÓN
UPDATE public.habit_logs AS l
SET completed  = FALSE,
    value      = GREATEST(l.value, 1),
    notes      = CASE
                   WHEN l.completed THEN COALESCE(l.notes, 'Recaídas registradas con el contador')
                   ELSE l.notes
                 END,
    updated_at = NOW()
FROM public.habits AS h
WHERE h.id = l.habit_id
  AND h.is_negative
  AND (l.completed = FALSE OR (h.type = 'counter' AND l.value > 0))
  AND (l.completed = TRUE OR l.value < 1);

-- ==============================================================================
-- 2. VERIFICACIÓN: recaídas por hábito (ya no debe haber recaídas con value 0
--    ni contadores negativos marcados como cumplidos)
-- ==============================================================================
-- SELECT h.title,
--        COUNT(*) FILTER (WHERE NOT l.completed)            AS dias_con_recaida,
--        SUM(l.value) FILTER (WHERE NOT l.completed)         AS veces,
--        COUNT(*) FILTER (WHERE NOT l.completed AND l.value < 1)                 AS pendientes_valor_0,
--        COUNT(*) FILTER (WHERE l.completed AND h.type = 'counter' AND l.value > 0) AS pendientes_contador
--   FROM public.habit_logs l
--   JOIN public.habits h ON h.id = l.habit_id
--  WHERE h.is_negative
--  GROUP BY h.title
--  ORDER BY h.title;
