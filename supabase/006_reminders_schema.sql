-- ==============================================================================
-- SCHEMA SUPABASE PARA: RECORDATORIOS (REMINDERS APP - ORTIZAPP SUITE)
-- ==============================================================================
-- Incluye:
-- 1. Enums para Prioridades (p1_urgent, p2_high, p3_medium, p4_low) y Estados
-- 2. Tabla de Suscripciones Push (push_subscriptions)
-- 3. Tabla Principal de Recordatorios (reminders) con recurrencia RFC 5545,
--    Alertas Persistentes (nagging), Tags y Zonas Horarias.
-- 4. Índices de Alto Rendimiento para Despacho y Filtros.
-- 5. Políticas de Seguridad (RLS) y Publicación en Supabase Realtime.
-- ==============================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Enums
DO $$ BEGIN
    CREATE TYPE reminder_priority AS ENUM ('p1_urgent', 'p2_high', 'p3_medium', 'p4_low');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE reminder_status AS ENUM ('pending', 'completed', 'snoozed', 'archived');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Tabla de Suscripciones Web Push
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabla Principal de Recordatorios (reminders)
CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  priority reminder_priority DEFAULT 'p3_medium',
  status reminder_status DEFAULT 'pending',
  
  -- Programación y Zona Horaria
  due_at TIMESTAMPTZ,                 -- Timestamp exacto en UTC
  client_timezone TEXT DEFAULT 'UTC', -- Zona horaria al momento de creación
  
  -- Recurrencia estándar (RFC 5545 iCalendar, ej. "FREQ=WEEKLY;BYDAY=MO,WE,FR")
  rrule TEXT,
  parent_id UUID REFERENCES public.reminders(id) ON DELETE SET NULL,
  
  -- Alertas Persistentes (Nagging / Snooze Inteligente)
  is_nagging BOOLEAN DEFAULT FALSE,   -- Re-notificar cada X min hasta ser atendido
  nag_interval_minutes INTEGER DEFAULT 10,
  last_notified_at TIMESTAMPTZ,
  
  -- Metadatos y Organización
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  is_pinned BOOLEAN DEFAULT FALSE,    -- Recordatorio fijado en banner principal
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Índices de Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_reminders_user_status ON public.reminders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_reminders_due ON public.reminders(due_at) WHERE status IN ('pending', 'snoozed');
CREATE INDEX IF NOT EXISTS idx_reminders_pinned ON public.reminders(is_pinned) WHERE is_pinned = true;
CREATE INDEX IF NOT EXISTS idx_push_user ON public.push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_created ON public.reminders(created_at DESC);

-- 6. Políticas de Seguridad (Row Level Security - RLS)
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso completo a reminders" ON public.reminders;
CREATE POLICY "Acceso completo a reminders" ON public.reminders
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a push_subscriptions" ON public.push_subscriptions;
CREATE POLICY "Acceso completo a push_subscriptions" ON public.push_subscriptions
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- 7. Publicación en Supabase Realtime
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.reminders;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
