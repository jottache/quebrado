-- ==============================================================================
-- MIGRACIÓN 008: VINCULACIÓN ENTRE HÁBITOS Y CONTACTOS DE DIARIO
-- Permite asociar hábitos específicos a contactos existentes en la app de diario.
-- NOTA: Requiere que la tabla public.habits exista previamente (creada en 005_habitos_schema.sql).
-- ==============================================================================

DO $$
BEGIN
  -- Verificar si la tabla public.habits existe en la base de datos
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'habits'
  ) THEN
    ALTER TABLE public.habits
    ADD COLUMN IF NOT EXISTS contact_id TEXT;

    CREATE INDEX IF NOT EXISTS idx_habits_contact_id ON public.habits(contact_id);
    
    RAISE NOTICE 'Columna contact_id e índice agregados correctamente a public.habits.';
  ELSE
    RAISE EXCEPTION 'La tabla public.habits no existe aún. Debes ejecutar primero el script supabase/005_habitos_schema.sql antes de aplicar esta migración.';
  END IF;
END $$;
