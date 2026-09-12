-- ==============================================================================
-- SCHEMA SUPABASE PARA: PROMPTS PERSONALIZADOS DEL AGENTE ORTIZ
-- ==============================================================================
-- Tabla: chat_prompts
-- Permite crear, editar, reordenar y borrar prompts rápidos que aparecen
-- en el dock inferior del Dashboard / Launcher de OrtizApp.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.chat_prompts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  label TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_chat_prompts_user ON public.chat_prompts(user_id, sort_order ASC, created_at ASC);

-- Row Level Security (RLS)
ALTER TABLE public.chat_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso completo a chat_prompts" ON public.chat_prompts;
CREATE POLICY "Acceso completo a chat_prompts" ON public.chat_prompts
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- Realtime
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_prompts;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
