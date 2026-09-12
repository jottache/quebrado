-- ==============================================================================
-- SCHEMA SUPABASE PARA: AGENTE INTELIGENTE / CHATBOT (ORTIZAPP SUITE)
-- ==============================================================================
-- Incluye:
-- 1. Tabla de Sesiones de Chat (chat_sessions)
-- 2. Tabla de Mensajes (chat_messages) con soporte para tool_calls / JSONB
-- 3. Tabla de Artefactos Generados (chat_artifacts) para almacenar resúmenes,
--    cálculos financieros, tablas y notas generadas por el agente.
-- 4. Índices de Alto Rendimiento y Políticas de Seguridad (RLS).
-- 5. Publicación en Supabase Realtime.
-- ==============================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tabla de Sesiones de Chat
CREATE TABLE IF NOT EXISTS public.chat_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Nueva conversación',
  pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabla de Mensajes
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'model', 'system')),
  content TEXT NOT NULL,
  tool_calls JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabla de Artefactos Generados por la IA
CREATE TABLE IF NOT EXISTS public.chat_artifacts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'financial_summary', 'table', 'calculation', 'note', 'reminder_list', etc.
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Índices de Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user ON public.chat_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.chat_messages(session_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_artifacts_user ON public.chat_artifacts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_artifacts_session ON public.chat_artifacts(session_id);

-- 6. Políticas de Seguridad (Row Level Security - RLS)
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_artifacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso completo a chat_sessions" ON public.chat_sessions;
CREATE POLICY "Acceso completo a chat_sessions" ON public.chat_sessions
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a chat_messages" ON public.chat_messages;
CREATE POLICY "Acceso completo a chat_messages" ON public.chat_messages
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a chat_artifacts" ON public.chat_artifacts;
CREATE POLICY "Acceso completo a chat_artifacts" ON public.chat_artifacts
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- 7. Publicación en Supabase Realtime
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_sessions;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
