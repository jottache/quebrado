-- ==============================================================================
-- MIGRACIÓN 008: VINCULACIÓN ENTRE HÁBITOS Y CONTACTOS DE DIARIO
-- Permite asociar hábitos específicos a contactos existentes en la app de diario
-- ==============================================================================

ALTER TABLE public.habits
ADD COLUMN IF NOT EXISTS contact_id TEXT;

-- Índice para consultas rápidas de hábitos vinculados a un contacto
CREATE INDEX IF NOT EXISTS idx_habits_contact_id ON public.habits(contact_id);
