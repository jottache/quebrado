-- ==============================================================================
-- MIGRACIÓN 013: ÁNIMO (REGISTRO DE ESTADOS DE ÁNIMO Y EMOCIONES)
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de Supabase (https://supabase.com/dashboard)
-- Es idempotente: se puede ejecutar varias veces sin romper nada.
--
-- Añade:
-- 1. mood_tags: etiquetas de contexto (actividades, personas, salud, lugar...)
--    con presets globales del sistema (user_id NULL).
-- 2. mood_logs: registros de ánimo propios (contact_id NULL) y percibidos de
--    contactos del Diario (contact_id = diario_contacts.id).
-- 3. Triggers de limpieza (contactos, entradas, roles y etiquetas eliminados).
-- 4. Vista mood_daily_summary para agregados por día.
-- 5. RLS + Realtime.
--
-- Requisitos previos: 004 (diario), 011 (roles Covey). Si alguna tabla no existe,
-- el trigger correspondiente simplemente no se crea (se avisa con NOTICE).
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Función genérica de updated_at (ya existe desde 012, se redefine por seguridad)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 1. TABLA DE ETIQUETAS DE CONTEXTO (mood_tags)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.mood_tags (
    id TEXT PRIMARY KEY,                         -- 'mtag_*' para sistema, uuid v4 para personalizadas
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    emoji TEXT DEFAULT '🏷️',
    group_key TEXT NOT NULL DEFAULT 'otro',      -- actividad | social | salud | lugar | finanzas | clima | otro
    color_hex TEXT DEFAULT '#6366F1',
    sort_order INTEGER DEFAULT 0,
    is_system BOOLEAN DEFAULT FALSE,
    archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT mood_tags_group_chk CHECK (
        group_key IN ('actividad', 'social', 'salud', 'lugar', 'finanzas', 'clima', 'otro')
    )
);

CREATE INDEX IF NOT EXISTS idx_mood_tags_user ON public.mood_tags(user_id, group_key, sort_order);

ALTER TABLE public.mood_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir acceso a mood_tags" ON public.mood_tags;
CREATE POLICY "Permitir acceso a mood_tags" ON public.mood_tags
    FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

DROP TRIGGER IF EXISTS trigger_mood_tags_updated_at ON public.mood_tags;
CREATE TRIGGER trigger_mood_tags_updated_at
BEFORE UPDATE ON public.mood_tags
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Presets globales del sistema (visibles para todos por user_id NULL)
INSERT INTO public.mood_tags (id, user_id, name, emoji, group_key, color_hex, sort_order, is_system) VALUES
    -- Actividad
    ('mtag_trabajo',        NULL, 'Trabajo',            '💼', 'actividad', '#3B82F6', 0,  TRUE),
    ('mtag_ejercicio',      NULL, 'Ejercicio',          '🏃', 'actividad', '#10B981', 1,  TRUE),
    ('mtag_lectura',        NULL, 'Lectura',            '📚', 'actividad', '#8B5CF6', 2,  TRUE),
    ('mtag_estudio',        NULL, 'Estudio',            '🎓', 'actividad', '#6366F1', 3,  TRUE),
    ('mtag_descanso',       NULL, 'Descanso',           '🛋️', 'actividad', '#14B8A6', 4,  TRUE),
    ('mtag_hogar',          NULL, 'Tareas del hogar',   '🧹', 'actividad', '#F59E0B', 5,  TRUE),
    ('mtag_hobby',          NULL, 'Hobby',              '🎨', 'actividad', '#EC4899', 6,  TRUE),
    ('mtag_pantallas',      NULL, 'Mucha pantalla',     '📱', 'actividad', '#64748B', 7,  TRUE),
    -- Social
    ('mtag_familia',        NULL, 'Familia',            '👨‍👩‍👧', 'social',    '#F97316', 10, TRUE),
    ('mtag_pareja',         NULL, 'Pareja',             '❤️', 'social',    '#EF4444', 11, TRUE),
    ('mtag_amigos',         NULL, 'Amigos',             '🧑‍🤝‍🧑', 'social',    '#F59E0B', 12, TRUE),
    ('mtag_solo',           NULL, 'Tiempo a solas',     '🧘', 'social',    '#14B8A6', 13, TRUE),
    ('mtag_reunion',        NULL, 'Reuniones',          '🗣️', 'social',    '#3B82F6', 14, TRUE),
    ('mtag_conflicto',      NULL, 'Discusión',          '⚡', 'social',    '#DC2626', 15, TRUE),
    -- Salud
    ('mtag_dormi_bien',     NULL, 'Dormí bien',         '😴', 'salud',     '#22C55E', 20, TRUE),
    ('mtag_dormi_mal',      NULL, 'Dormí mal',          '🥱', 'salud',     '#A855F7', 21, TRUE),
    ('mtag_comi_bien',      NULL, 'Comí sano',          '🥗', 'salud',     '#16A34A', 22, TRUE),
    ('mtag_comida_chatarra',NULL, 'Comida chatarra',    '🍔', 'salud',     '#EA580C', 23, TRUE),
    ('mtag_enfermo',        NULL, 'Enfermo / Dolor',    '🤒', 'salud',     '#DC2626', 24, TRUE),
    ('mtag_alcohol',        NULL, 'Alcohol',            '🍷', 'salud',     '#9F1239', 25, TRUE),
    ('mtag_cafeina',        NULL, 'Mucha cafeína',      '☕', 'salud',     '#78350F', 26, TRUE),
    -- Lugar
    ('mtag_casa',           NULL, 'Casa',               '🏠', 'lugar',     '#0EA5E9', 30, TRUE),
    ('mtag_oficina',        NULL, 'Oficina',            '🏢', 'lugar',     '#475569', 31, TRUE),
    ('mtag_viaje',          NULL, 'Calle / Viaje',      '🚗', 'lugar',     '#F59E0B', 32, TRUE),
    ('mtag_naturaleza',     NULL, 'Naturaleza',         '🌳', 'lugar',     '#15803D', 33, TRUE),
    -- Finanzas (puente con Quebrado)
    ('mtag_estres_dinero',  NULL, 'Preocupación por dinero', '💸', 'finanzas', '#B91C1C', 40, TRUE),
    ('mtag_logro_dinero',   NULL, 'Logro financiero',   '💰', 'finanzas',  '#15803D', 41, TRUE),
    -- Clima
    ('mtag_soleado',        NULL, 'Soleado',            '☀️', 'clima',     '#FACC15', 50, TRUE),
    ('mtag_lluvia',         NULL, 'Lluvia',             '🌧️', 'clima',     '#60A5FA', 51, TRUE)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 2. TABLA PRINCIPAL DE REGISTROS DE ÁNIMO (mood_logs)
-- ==============================================================================
-- contact_id NULL            → registro propio (perspective = 'self')
-- contact_id = <contacto>    → ánimo percibido de un contacto (perspective = 'observed' | 'told')
-- kind 'momentary'           → emoción de un momento (varios por día)
-- kind 'daily'               → balance del día (si existe, manda sobre el promedio de momentáneos)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.mood_logs (
    id TEXT PRIMARY KEY,                          -- uuid v4 generado en la app (convención Diario)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    contact_id TEXT,                              -- sin FK (misma convención que 010); limpieza por trigger
    perspective TEXT NOT NULL DEFAULT 'self',     -- self | observed | told
    kind TEXT NOT NULL DEFAULT 'momentary',       -- momentary | daily
    valence SMALLINT NOT NULL,                    -- -2 Muy mal · -1 Mal · 0 Normal · 1 Bien · 2 Excelente
    energy SMALLINT,                              -- 1 (agotado) … 5 (a tope), opcional
    emotions TEXT[] NOT NULL DEFAULT '{}',        -- claves del catálogo (ej. 'ansioso', 'tranquilo')
    tag_ids TEXT[] NOT NULL DEFAULT '{}',         -- mood_tags.id
    role_ids TEXT[] NOT NULL DEFAULT '{}',        -- roles.id (Covey) como texto
    mentioned_contact_ids TEXT[] NOT NULL DEFAULT '{}', -- personas involucradas (@menciones)
    note TEXT,
    diario_entry_id TEXT,                         -- entrada de Diario asociada (opcional)
    source TEXT NOT NULL DEFAULT 'manual',        -- manual | checkin | agent | diario_entry
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    log_date DATE NOT NULL,                       -- fecha LOCAL del registro (la app la envía; trigger de respaldo)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT mood_logs_valence_chk CHECK (valence BETWEEN -2 AND 2),
    CONSTRAINT mood_logs_energy_chk CHECK (energy IS NULL OR energy BETWEEN 1 AND 5),
    CONSTRAINT mood_logs_kind_chk CHECK (kind IN ('momentary', 'daily')),
    CONSTRAINT mood_logs_source_chk CHECK (source IN ('manual', 'checkin', 'agent', 'diario_entry')),
    CONSTRAINT mood_logs_perspective_chk CHECK (
        (contact_id IS NULL AND perspective = 'self')
        OR (contact_id IS NOT NULL AND perspective IN ('observed', 'told'))
    ),
    CONSTRAINT mood_logs_note_len_chk CHECK (note IS NULL OR char_length(note) <= 5000)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_mood_logs_user_time ON public.mood_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_mood_logs_self_date ON public.mood_logs(user_id, log_date DESC) WHERE contact_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_mood_logs_contact ON public.mood_logs(contact_id, logged_at DESC) WHERE contact_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mood_logs_entry ON public.mood_logs(diario_entry_id) WHERE diario_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mood_logs_emotions_gin ON public.mood_logs USING GIN (emotions);
CREATE INDEX IF NOT EXISTS idx_mood_logs_tags_gin ON public.mood_logs USING GIN (tag_ids);
CREATE INDEX IF NOT EXISTS idx_mood_logs_roles_gin ON public.mood_logs USING GIN (role_ids);
CREATE INDEX IF NOT EXISTS idx_mood_logs_mentions_gin ON public.mood_logs USING GIN (mentioned_contact_ids);

-- RLS
ALTER TABLE public.mood_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir acceso a mood_logs" ON public.mood_logs;
CREATE POLICY "Permitir acceso a mood_logs" ON public.mood_logs
    FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- updated_at
DROP TRIGGER IF EXISTS trigger_mood_logs_updated_at ON public.mood_logs;
CREATE TRIGGER trigger_mood_logs_updated_at
BEFORE UPDATE ON public.mood_logs
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Respaldo de log_date: si la app no la envía, se calcula en hora de Venezuela
CREATE OR REPLACE FUNCTION public.mood_logs_fill_log_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.log_date IS NULL THEN
        NEW.log_date := (NEW.logged_at AT TIME ZONE 'America/Caracas')::date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_mood_logs_fill_log_date ON public.mood_logs;
CREATE TRIGGER trigger_mood_logs_fill_log_date
BEFORE INSERT OR UPDATE ON public.mood_logs
FOR EACH ROW
EXECUTE FUNCTION public.mood_logs_fill_log_date();

-- Un solo balance 'daily' por sujeto y día (los momentáneos son ilimitados)
CREATE UNIQUE INDEX IF NOT EXISTS uq_mood_logs_daily_per_subject
    ON public.mood_logs(COALESCE(user_id::text, '__anon__'), COALESCE(contact_id, '__self__'), log_date)
    WHERE kind = 'daily';

-- ==============================================================================
-- 3. TRIGGERS DE LIMPIEZA (no hay FKs: se mantiene la integridad por triggers)
-- ==============================================================================

-- 3a. Contacto eliminado → borrar su ánimo percibido y quitarlo de menciones
CREATE OR REPLACE FUNCTION public.mood_logs_on_contact_deleted()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM public.mood_logs WHERE contact_id = OLD.id;
    UPDATE public.mood_logs
       SET mentioned_contact_ids = array_remove(mentioned_contact_ids, OLD.id)
     WHERE OLD.id = ANY(mentioned_contact_ids);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3b. Entrada de Diario eliminada → desvincular (el ánimo se conserva)
CREATE OR REPLACE FUNCTION public.mood_logs_on_entry_deleted()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.mood_logs SET diario_entry_id = NULL WHERE diario_entry_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3c. Rol Covey eliminado → quitarlo de role_ids
CREATE OR REPLACE FUNCTION public.mood_logs_on_role_deleted()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.mood_logs
       SET role_ids = array_remove(role_ids, OLD.id::text)
     WHERE OLD.id::text = ANY(role_ids);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3d. Etiqueta eliminada → quitarla de tag_ids
CREATE OR REPLACE FUNCTION public.mood_logs_on_tag_deleted()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.mood_logs
       SET tag_ids = array_remove(tag_ids, OLD.id)
     WHERE OLD.id = ANY(tag_ids);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_mood_tags_cleanup ON public.mood_tags;
CREATE TRIGGER trigger_mood_tags_cleanup
AFTER DELETE ON public.mood_tags
FOR EACH ROW
EXECUTE FUNCTION public.mood_logs_on_tag_deleted();

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'diario_contacts') THEN
        DROP TRIGGER IF EXISTS trigger_diario_contacts_mood_cleanup ON public.diario_contacts;
        CREATE TRIGGER trigger_diario_contacts_mood_cleanup
        AFTER DELETE ON public.diario_contacts
        FOR EACH ROW EXECUTE FUNCTION public.mood_logs_on_contact_deleted();
    ELSE
        RAISE NOTICE 'diario_contacts no existe: ejecuta 004 y vuelve a correr 013 para crear el trigger de limpieza.';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'diario_entries') THEN
        DROP TRIGGER IF EXISTS trigger_diario_entries_mood_cleanup ON public.diario_entries;
        CREATE TRIGGER trigger_diario_entries_mood_cleanup
        AFTER DELETE ON public.diario_entries
        FOR EACH ROW EXECUTE FUNCTION public.mood_logs_on_entry_deleted();
    ELSE
        RAISE NOTICE 'diario_entries no existe: ejecuta 004 y vuelve a correr 013.';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'roles') THEN
        DROP TRIGGER IF EXISTS trigger_roles_mood_cleanup ON public.roles;
        CREATE TRIGGER trigger_roles_mood_cleanup
        AFTER DELETE ON public.roles
        FOR EACH ROW EXECUTE FUNCTION public.mood_logs_on_role_deleted();
    ELSE
        RAISE NOTICE 'roles no existe: ejecuta 011 y vuelve a correr 013.';
    END IF;
END $$;

-- ==============================================================================
-- 4. VISTA DE RESUMEN DIARIO (para Agente Ortiz, reportes y consultas rápidas)
-- ==============================================================================
-- day_valence: si hay un registro 'daily' se usa ese; si no, el promedio de momentáneos.
DROP VIEW IF EXISTS public.mood_daily_summary;
CREATE VIEW public.mood_daily_summary
WITH (security_invoker = true) AS
WITH agg AS (
    SELECT
        user_id,
        contact_id,
        log_date,
        COUNT(*)                                          AS logs_count,
        MAX(valence) FILTER (WHERE kind = 'daily')        AS daily_valence,
        ROUND(AVG(valence)::numeric, 2)                   AS avg_valence,
        MIN(valence)                                      AS min_valence,
        MAX(valence)                                      AS max_valence,
        ROUND(AVG(energy)::numeric, 2)                    AS avg_energy
    FROM public.mood_logs
    GROUP BY user_id, contact_id, log_date
),
emo AS (
    SELECT user_id, contact_id, log_date, array_agg(DISTINCT e ORDER BY e) AS emotions
    FROM public.mood_logs, unnest(emotions) AS e
    GROUP BY user_id, contact_id, log_date
)
SELECT
    agg.user_id,
    agg.contact_id,
    agg.log_date,
    agg.logs_count,
    COALESCE(agg.daily_valence::numeric, agg.avg_valence) AS day_valence,
    agg.min_valence,
    agg.max_valence,
    agg.avg_energy,
    COALESCE(emo.emotions, '{}')                         AS emotions
FROM agg
LEFT JOIN emo
  ON emo.log_date = agg.log_date
 AND emo.user_id IS NOT DISTINCT FROM agg.user_id
 AND emo.contact_id IS NOT DISTINCT FROM agg.contact_id;

-- ==============================================================================
-- 5. REALTIME (bloques separados: si una tabla ya está publicada no bloquea la otra)
-- ==============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.mood_logs;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.mood_tags;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ==============================================================================
-- 6. VERIFICACIÓN (ejecutar después para confirmar; deben devolver filas)
-- ==============================================================================
-- SELECT COUNT(*) AS tags_sistema FROM public.mood_tags WHERE is_system;          -- 29
-- SELECT column_name, data_type FROM information_schema.columns
--  WHERE table_schema = 'public' AND table_name = 'mood_logs' ORDER BY ordinal_position;
-- SELECT tgname FROM pg_trigger WHERE tgname LIKE '%mood%' AND NOT tgisinternal;  -- 7 triggers
-- SELECT * FROM public.mood_daily_summary LIMIT 5;
--
-- Prueba rápida (luego bórrala):
-- INSERT INTO public.mood_logs (id, valence, energy, emotions, tag_ids, log_date)
-- VALUES ('test_mood_1', 1, 4, ARRAY['motivado'], ARRAY['mtag_ejercicio'], CURRENT_DATE);
-- SELECT * FROM public.mood_daily_summary WHERE log_date = CURRENT_DATE;
-- DELETE FROM public.mood_logs WHERE id = 'test_mood_1';

-- ==============================================================================
-- 7. ROLLBACK (solo si necesitas deshacer la migración por completo)
-- ==============================================================================
-- DROP TRIGGER IF EXISTS trigger_diario_contacts_mood_cleanup ON public.diario_contacts;
-- DROP TRIGGER IF EXISTS trigger_diario_entries_mood_cleanup ON public.diario_entries;
-- DROP TRIGGER IF EXISTS trigger_roles_mood_cleanup ON public.roles;
-- DROP VIEW IF EXISTS public.mood_daily_summary;
-- DROP TABLE IF EXISTS public.mood_logs;
-- DROP TABLE IF EXISTS public.mood_tags;
-- DROP FUNCTION IF EXISTS public.mood_logs_on_contact_deleted();
-- DROP FUNCTION IF EXISTS public.mood_logs_on_entry_deleted();
-- DROP FUNCTION IF EXISTS public.mood_logs_on_role_deleted();
-- DROP FUNCTION IF EXISTS public.mood_logs_on_tag_deleted();
-- DROP FUNCTION IF EXISTS public.mood_logs_fill_log_date();
