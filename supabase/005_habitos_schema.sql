-- ==============================================================================
-- ESQUEMA DDL: HABITOS (SUPER APP ORTIZAPP)
-- Soporte para:
-- 1. Hábitos Buenos y Malos (romper hábitos / días limpios)
-- 2. Tipos: Binario, Cuantitativo (metas + unidades), Temporizador, Negativo
-- 3. Rutinas / Stacks (Mañana, Tarde, Noche, etc.)
-- 4. Registros diarios (habit_logs) con índice único por hábito y fecha
-- ==============================================================================

-- 1. PROFILES (Seguridad de usuario)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  timezone TEXT DEFAULT 'UTC',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. HABIT STACKS / RUTINAS
CREATE TABLE IF NOT EXISTS public.habit_stacks (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  time_of_day TEXT DEFAULT 'morning', -- 'morning', 'afternoon', 'evening', 'anytime'
  icon TEXT DEFAULT 'layers',
  position INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. HABITS (HÁBITOS POSITIVOS Y NEGATIVOS)
CREATE TABLE IF NOT EXISTS public.habits (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  icon TEXT DEFAULT 'check_circle_outline',
  color_hex TEXT DEFAULT '#00FF66',
  type TEXT NOT NULL DEFAULT 'binary', -- 'binary', 'quantitative', 'timer', 'negative'
  is_negative BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE = mal hábito a romper / evitar
  target_value NUMERIC DEFAULT 1,
  unit TEXT, -- 'ml', 'min', 'pag', 'veces', etc.
  frequency_type TEXT NOT NULL DEFAULT 'daily', -- 'daily', 'weekly_target', 'custom_days'
  frequency_payload JSONB DEFAULT '{}'::jsonb,
  stack_group_id TEXT REFERENCES public.habit_stacks(id) ON DELETE SET NULL,
  contact_id TEXT, -- Vinculación con diario_contacts(id)
  archived BOOLEAN DEFAULT FALSE,
  position INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. HABIT LOGS (REGISTROS DIARIOS)
CREATE TABLE IF NOT EXISTS public.habit_logs (
  id TEXT PRIMARY KEY,
  habit_id TEXT NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  log_date DATE NOT NULL, -- YYYY-MM-DD
  value NUMERIC NOT NULL DEFAULT 1,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_habit_per_day UNIQUE (habit_id, log_date)
);

-- ==============================================================================
-- 5. ÍNDICES DE ALTO RENDIMIENTO
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_habits_user ON public.habits(user_id);
CREATE INDEX IF NOT EXISTS idx_habits_archived ON public.habits(archived);
CREATE INDEX IF NOT EXISTS idx_habits_stack ON public.habits(stack_group_id);
CREATE INDEX IF NOT EXISTS idx_habits_contact_id ON public.habits(contact_id);

CREATE INDEX IF NOT EXISTS idx_habit_logs_habit ON public.habit_logs(habit_id);
CREATE INDEX IF NOT EXISTS idx_habit_logs_date ON public.habit_logs(log_date);
CREATE INDEX IF NOT EXISTS idx_habit_logs_user ON public.habit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_logs_completed ON public.habit_logs(completed);

CREATE INDEX IF NOT EXISTS idx_habit_stacks_user ON public.habit_stacks(user_id);

-- ==============================================================================
-- 6. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habit_stacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir acceso a habit_stacks" ON public.habit_stacks;
CREATE POLICY "Permitir acceso a habit_stacks" ON public.habit_stacks
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Permitir acceso a habits" ON public.habits;
CREATE POLICY "Permitir acceso a habits" ON public.habits
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Permitir acceso a habit_logs" ON public.habit_logs;
CREATE POLICY "Permitir acceso a habit_logs" ON public.habit_logs
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Permitir acceso a profiles" ON public.profiles;
CREATE POLICY "Permitir acceso a profiles" ON public.profiles
  FOR ALL USING (auth.uid() = id OR id IS NULL OR auth.uid() IS NULL);
