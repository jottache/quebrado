## 1. Tech Stack & State Architecture
- **Framework:** Flutter (clean architecture, strict typing, null-safety).
- **Backend & Database:** Supabase (PostgreSQL, Supabase Auth, Row Level Security, Supabase Flutter SDK).
- **State Management:** Provider / ChangeNotifier (matching OrtizApp & Quebrado & Diario architecture) with in-memory cache pattern.
- **Cache & Hydration Strategy:**
  - On app launch / auth success, execute a single `bootstrapData()` query that loads:
    1. User profile and configurations.
    2. All active `habits` and `habit_stacks`.
    3. All historical `habit_logs` (or logs for the active analysis window, e.g., past 365 days).
  - Store this data in the global application state (`HabitsState`).
  - The UI reads exclusively from this in-memory cache. Navigating between Dashboard, Metrics, and Settings triggers zero network requests.
  - Mutations (completing a habit, editing a goal) immediately update in-memory state and trigger an asynchronous `upsert` to Supabase. If the remote request fails, revert state and surface a non-blocking snackbar.

---

## 2. Supabase Data Schema (PostgreSQL DDL)
Run and enforce the following schema in Supabase:

```sql
-- 1. Profiles (if not exists)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text,
  timezone text default 'UTC',
  created_at timestamptz default now()
);

-- 2. Enums / Types
DO $$ BEGIN
    CREATE TYPE habit_type AS ENUM ('binary', 'quantitative', 'timer', 'negative');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE habit_frequency_type AS ENUM ('daily', 'weekly_target', 'custom_days');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Habits (supports positive and negative/bad habits)
CREATE TABLE IF NOT EXISTS public.habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  description text,
  icon text default 'check_circle_outline',
  color_hex text default '#1F6F5F',
  type text not null default 'binary', -- 'binary', 'quantitative', 'timer', 'negative'
  is_negative boolean not null default false, -- Malos hábitos (romper hábitos)
  target_value numeric default 1,
  unit text,
  frequency_type text not null default 'daily', -- 'daily', 'weekly_target', 'custom_days'
  frequency_payload jsonb default '{}'::jsonb,
  stack_group_id uuid,
  archived boolean default false,
  position integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 4. Habit Logs
CREATE TABLE IF NOT EXISTS public.habit_logs (
  id uuid default gen_random_uuid() primary key,
  habit_id uuid references public.habits(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade,
  log_date date not null,
  value numeric not null default 1,
  completed boolean not null default false,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint unique_habit_per_day unique (habit_id, log_date)
);

-- 5. Habit Stacks / Groups
CREATE TABLE IF NOT EXISTS public.habit_stacks (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  time_of_day text, -- 'morning', 'afternoon', 'evening', 'anytime'
  created_at timestamptz default now()
);

-- Row Level Security
alter table public.habits enable row level security;
alter table public.habit_logs enable row level security;
alter table public.habit_stacks enable row level security;

create policy "Users manage own habits" on public.habits for all using (true);
create policy "Users manage own logs" on public.habit_logs for all using (true);
create policy "Users manage own stacks" on public.habit_stacks for all using (true);
```

---

## 3. UI/UX Specifications
A. Main Dashboard (Frictionless Execution)
- **Horizontal Date Bar:** Clean weekly/monthly slider to browse days. Defaults to today.
- **Progress Header:** Real-time completion score (%) of the selected day calculated entirely in-memory.
- **Tabs/Filter:** Todos, Buenos Hábitos, Malos Hábitos (Evitar/Romper), Stacks/Rutinas.
- **Interactive Habit Tiles:**
  - *Binary:* Instant check/uncheck with haptic feedback (`HapticFeedback.lightImpact()`).
  - *Quantitative:* Quick increments via +1 / +step buttons or tap to enter custom values.
  - *Timer:* Minimal timer widget that updates progress locally on completion.
  - *Negative / Malo:* Tracker de días limpios ("X días sin fumar/azúcar") con botón de recaída o marcado de éxito diario.
- **Zero Spinner Navigation:** Switching between days re-evaluates in-memory logs instantaneously.

B. Dedicated Metrics & Analytics Section
- **GitHub-Style Contribution Heatmap:** Grid mapping the last 3-6 months. Color saturation scales with completion ratio using the primary color (`#1F6F5F`).
- **Resilience Score (Anti-Fragile Streak):** 30-day consistency score (%) instead of hard punishing single missed days.
- **Completion by Day of Week:** Bar visualization (Lunes a Domingo) to spot vulnerable days.
- **Per-Habit Deep Dive Modal:** Total repetitions, current streak, best streak, and calendar visualization for that specific habit.

---

## 4. Super App Integration
- Single unified primary color `#1F6F5F` (matching Quebrado & Diario Jottache).
- Placed in the Hub Launcher (`AppLauncherScreen`).
- Local seed demo data available immediately for testing.
