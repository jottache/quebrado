# Role & Operational Context
Act as a Principal Full-Stack Web Architect and Elite UI/UX Engineer. Your objective is to evolve and refactor our existing personal reminders web application into a **Fourth-Generation Time Management System** based strictly on **Habit 3 ("Put First Things First")** from Stephen Covey's *The 7 Habits of Highly Effective People*.

You must **adapt and extend the current architecture** (Next.js/React, Tailwind CSS, Supabase PostgreSQL, Web Push API, Service Workers, Realtime, and `chrono-node`), preserving all existing notification, snooze, and recurring reminder capabilities while introducing:
1. **First-Class Life Roles (`roles`)** with balance tracking.
2. **Covey's 4-Quadrant Matrix (`quadrant`)** with visual emphasis on Quadrant II (Important, Not Urgent).
3. **Weekly Compass & Big Rocks (`is_big_rock`)** prioritizers.
4. **Interactive 7-Day Flexible Weekly Schedule View.**
5. **Sunday Weekly Planning Ritual & Automated Alert System.**

---

## 1. Database Schema Migration (Supabase PostgreSQL)
Execute non-destructive schema migrations over the existing database to support Roles, Quadrants, Weekly Plans, and Sunday Planning Alerts:

```sql
-- 1. Create Enums for Covey Matrix
create type covey_quadrant as enum (
  'q1_urgent_important',       -- Crisis, pressuring problems, hard deadlines
  'q2_important_not_urgent',   -- Proactive preparation, planning, relationships, health (CORE)
  'q3_urgent_not_important',   -- Distractions, popular activities, urgent trivialities
  'q4_not_urgent_not_important'-- Waste, excessive mindless escapes
);

-- 2. Life Roles Table
create table public.roles (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,                       -- e.g., "Individual / Health", "Software Architect", "Family / Partner"
  purpose_statement text,                  -- Core declaration/mission for this role
  color_hex text default '#3B82F6',
  icon text default 'User',                -- Lucide icon identifier
  position integer default 0,
  archived boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Weekly Plans (Container for Weekly Compass & Retrospectives)
create table public.weekly_plans (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  week_start_date date not null,           -- Normalized to Monday of that week
  reflection_notes text,                   -- Retrospective evaluation
  status text default 'active',            -- 'active', 'archived'
  created_at timestamptz default now(),
  constraint unique_user_week unique (user_id, week_start_date)
);

-- 4. Alter Existing Reminders Table (Backward Compatible)
alter table public.reminders 
  add column if not exists role_id uuid references public.roles(id) on delete set null,
  add column if not exists weekly_plan_id uuid references public.weekly_plans(id) on delete set null,
  add column if not exists quadrant covey_quadrant default 'q2_important_not_urgent',
  add column if not exists is_big_rock boolean default false,
  add column if not exists scheduled_day_of_week integer check (scheduled_day_of_week between 0 and 6), -- 0=Sunday, 1=Monday...
  add column if not exists estimated_duration_minutes integer default 30;

-- 5. Sunday Planning Notification Preference in Profiles
alter table public.profiles
  add column if not exists sunday_planning_time time default '18:00:00',
  add column if not exists sunday_planning_enabled boolean default true;

-- Indexes for performance
create index if not exists idx_reminders_quadrant on public.reminders(user_id, quadrant);
create index if not exists idx_reminders_weekly_plan on public.reminders(weekly_plan_id);
create index if not exists idx_reminders_role on public.reminders(role_id);
create index if not exists idx_roles_user on public.roles(user_id);

-- Enable RLS on new tables
alter table public.roles enable row level security;
alter table public.weekly_plans enable row level security;

create policy "Users manage own roles" on public.roles for all using (auth.uid() = user_id);
create policy "Users manage own weekly plans" on public.weekly_plans for all using (auth.uid() = user_id);

-- Add roles & weekly_plans to Realtime
alter publication supabase_realtime add table public.roles;
alter publication supabase_realtime add table public.weekly_plans;
```

## 2. Core Functional Requirements & Views
A. The Weekly Schedule & Compass View (Primary Screen)
Implement a unified 7-day dashboard displaying Monday through Sunday:

Left Sidebar - Weekly Compass:
- Displays active Roles with their defined Purpose Statement.
- For each role, showcases its 1-3 Big Rocks for the current week.
- Role Balance Indicator: Visual warning/pill if a role has 0 Big Rocks assigned for the week.

Main Canvas - 7-Day Flexible Schedule Grid:
- Columns for each day of the week (Monday to Sunday) displaying the date.
- Visual Distinction for Big Rocks: Prominent cards with colored role badges, bold typography, and an icon indicator distinct from regular reminders.
- Quadrant Color-Coded Accents: Distinct border/badge indicators for Q-I (Crimson/Red), Q-II (Emerald/Green - highlighted as primary focus), Q-III (Amber/Yellow), and Q-IV (Muted Grey).
- Flexible Block Drag-and-Drop: Ability to drag items between days or reorder within a day to adapt when real-life emergencies break a rigid schedule.
- Time Breakdown Toggle: Switch between a pure card-based day list and an hourly time-block grid (e.g., 08:00 to 20:00).

B. Natural Language Capture Refactor (chrono-node extension)
Enhance the existing Omnibox capture parser to support Habit 3 dimensions seamlessly:
Tokens to parse:
- Quadrants: !q1, !q2, !q3, !q4 (defaults to !q2).
- Roles: @rolename (fuzzy matching against active user roles).
- Big Rocks: Flagged with * or !rock (e.g., "Review quarterly budget on wednesday at 10am @finance !q2 !rock").
- Retain existing date/time parsing, timezone conversion, and Web Push scheduling.

C. Quadrant Matrix View (Alternative 2x2 Screen)
Provide a 2x2 Eisenhower/Covey Matrix interactive dashboard:
- Quadrant I (Urgent & Important)
- Quadrant II (Not Urgent & Important) -> UI must visually prioritize this area with the largest real estate and primary accent styling.
- Quadrant III (Urgent & Not Important)
- Quadrant IV (Not Urgent & Not Important)
- Drag-and-drop support to move reminders across quadrants.

D. Automated Sunday Planning Ritual & Notifications
The Automation Mechanism:
- Extend the existing background notification dispatcher (Supabase Edge Function + pg_cron running every 10-15 minutes).
- Every Sunday, check users where sunday_planning_enabled = true and now() AT TIME ZONE timezone >= (current_date + sunday_planning_time).
- Dispatch an interactive Web Push notification:
  - Title: "Organize Your Week | First Things First"
  - Body: "It's time for your weekly planning ritual. Review your roles, set your Big Rocks, and schedule your coming week."
  - Click Action URL: Deep-link to /weekly-planner?wizard=true.

The Weekly Planning Wizard Modal / Flow (/weekly-planner):
- Step 1: Role Review & Retrospective: Review the previous week's Big Rocks. Mark completions and add quick notes.
- Step 2: Define Big Rocks: Walk through each role one by one: "What is the single most important action for [Role Name] this week?".
- Step 3: Schedule the Big Rocks: Drag and place the created Big Rocks into the upcoming 7-day schedule grid before any ordinary reminders are slotted in.
- Finish: Confirms the plan and sets it as the active weekly_plans record for the week.

## 3. Architecture & Integration Rules for the Agent
- Preserve Current Functionality: Do not break existing recurring reminder logic (RRULEs), push subscription mechanics, or snooze functions. Existing records without a role_id or quadrant must default gracefully to quadrant = 'q2_important_not_urgent'.
- State Management & Caching: Maintain optimistic UI updates. When a user drags a reminder to a new day or marks a Big Rock complete, update local state immediately and dispatch updates via Supabase client in the background.
- Responsive UI: The 7-day schedule must be horizontally scrollable on mobile or collapse to an interactive day-by-day swipe view, while presenting a full desktop 7-column layout on larger screens.
- Clean Code Isolation: Create modular directories:
  - `/features/roles` (components, role management modal, balance calculations)
  - `/features/planner` (weekly calendar grid, Sunday wizard, Big Rock cards)
  - `/features/matrix` (2x2 Quadrant view)
- Keep `/features/reminders` and `/lib/push` intact, extending them via adapters.
