-- ==============================================================================
-- SCHEMA SUPABASE: SISTEMA DE GESTIÓN DEL TIEMPO DE 4TA GENERACIÓN
-- BASADO EN EL HÁBITO 3 ("PRIMERO LO PRIMERO") DE STEPHEN COVEY
-- ==============================================================================
-- Incluye:
-- 1. Enums base de Recordatorios y Enums de Cuadrantes de Covey
-- 2. Tabla base de Recordatorios (public.reminders) y Suscripciones (si aún no existen)
-- 3. Tabla de Roles de Vida (public.roles) con propósito, color e ícono
-- 4. Tabla de Planes Semanales (public.weekly_plans) con retrospectiva
-- 5. Extensión de public.reminders (role_id, quadrant, is_big_rock, etc.)
-- 6. Ajustes de planificación dominical en public.profiles
-- 7. Políticas RLS y publicación en Supabase Realtime
-- ==============================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Enums base de Recordatorios (Prerrequisito)
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

-- 3. Tabla base de Recordatorios (si no se corrió 006_reminders_schema.sql)
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  priority reminder_priority DEFAULT 'p3_medium',
  status reminder_status DEFAULT 'pending',
  due_at TIMESTAMPTZ,
  client_timezone TEXT DEFAULT 'UTC',
  rrule TEXT,
  parent_id UUID REFERENCES public.reminders(id) ON DELETE SET NULL,
  is_nagging BOOLEAN DEFAULT FALSE,
  nag_interval_minutes INTEGER DEFAULT 10,
  last_notified_at TIMESTAMPTZ,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  is_pinned BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Enum para Cuadrantes de Covey
DO $$ BEGIN
    CREATE TYPE covey_quadrant AS ENUM (
      'q1_urgent_important',       -- Crisis, problemas apremiantes, fechas límite
      'q2_important_not_urgent',   -- Proactividad, prevención, relaciones, salud, planificación (NÚCLEO)
      'q3_urgent_not_important',   -- Interrupciones, presiones ajenas, urgencias menores
      'q4_not_urgent_not_important'-- Escape excesivo, trivialidades, desperdicio de tiempo
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 5. Tabla de Roles de Vida (roles)
CREATE TABLE IF NOT EXISTS public.roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,                       -- ej: "Individual / Salud", "Profesional / Arquitectura", "Familia / Pareja"
  purpose_statement TEXT,                  -- Declaración de misión o propósito fundamental del rol
  color_hex TEXT DEFAULT '#3B82F6',
  icon TEXT DEFAULT 'User',                -- Identificador del ícono
  position INTEGER DEFAULT 0,
  archived BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabla de Planes Semanales (weekly_plans)
CREATE TABLE IF NOT EXISTS public.weekly_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,           -- Normalizado al Lunes de la semana
  reflection_notes TEXT,                   -- Retrospectiva y aprendizaje de la semana anterior
  status TEXT DEFAULT 'active',            -- 'active', 'archived'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_user_week UNIQUE (user_id, week_start_date)
);

-- 5. Extensión de la Tabla de Recordatorios (reminders)
ALTER TABLE public.reminders 
  ADD COLUMN IF NOT EXISTS role_id UUID REFERENCES public.roles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS weekly_plan_id UUID REFERENCES public.weekly_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS quadrant covey_quadrant DEFAULT 'q2_important_not_urgent',
  ADD COLUMN IF NOT EXISTS is_big_rock BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS scheduled_day_of_week INTEGER CHECK (scheduled_day_of_week BETWEEN 0 AND 6), -- 0=Domingo, 1=Lunes ... 6=Sábado
  ADD COLUMN IF NOT EXISTS estimated_duration_minutes INTEGER DEFAULT 30;

-- 6. Preferencias de Planificación Dominical en Perfiles (si existe la tabla)
DO $$ BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
    ALTER TABLE public.profiles
      ADD COLUMN IF NOT EXISTS sunday_planning_time TIME DEFAULT '18:00:00',
      ADD COLUMN IF NOT EXISTS sunday_planning_enabled BOOLEAN DEFAULT TRUE;
  END IF;
END $$;

-- 7. Índices de Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_reminders_quadrant ON public.reminders(user_id, quadrant);
CREATE INDEX IF NOT EXISTS idx_reminders_weekly_plan ON public.reminders(weekly_plan_id);
CREATE INDEX IF NOT EXISTS idx_reminders_role ON public.reminders(role_id);
CREATE INDEX IF NOT EXISTS idx_reminders_big_rock ON public.reminders(is_big_rock) WHERE is_big_rock = TRUE;
CREATE INDEX IF NOT EXISTS idx_roles_user ON public.roles(user_id) WHERE archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_weekly_plans_user_week ON public.weekly_plans(user_id, week_start_date);

-- 8. Políticas de Seguridad (Row Level Security - RLS)
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso completo a push_subscriptions" ON public.push_subscriptions;
CREATE POLICY "Acceso completo a push_subscriptions" ON public.push_subscriptions
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a reminders" ON public.reminders;
CREATE POLICY "Acceso completo a reminders" ON public.reminders
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a roles" ON public.roles;
CREATE POLICY "Acceso completo a roles" ON public.roles
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Acceso completo a weekly_plans" ON public.weekly_plans;
CREATE POLICY "Acceso completo a weekly_plans" ON public.weekly_plans
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- 9. Publicación en Supabase Realtime
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.reminders;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.roles;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.weekly_plans;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
