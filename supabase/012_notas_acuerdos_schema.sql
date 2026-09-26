-- ==============================================================================
-- MIGRACIÓN 012: NOTAS & ACUERDOS (MINI-APP DE NOTAS RICAS ESTILO NOTION)
-- ==============================================================================
-- Esta migración añade el soporte completo para la nueva mini-app de la suite:
-- 1. Tabla de categorías personalizables (note_categories) con presets automáticos.
-- 2. Tabla principal de notas (notas) con almacenamiento estructurado en JSONB (bloques).
-- 3. Políticas de seguridad RLS (Row Level Security).
-- 4. Soporte para Realtime en Supabase.
-- ==============================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Función genérica para actualizar 'updated_at' si no existe
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Tabla de Categorías de Notas (note_categories)
CREATE TABLE IF NOT EXISTS public.note_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'folder_outlined',       -- Emoji (ej. 💍, 💡, 📍) o identificador
    color_hex TEXT DEFAULT '#6366F1',          -- Color hexadecimal
    sort_order INTEGER DEFAULT 0,
    is_system BOOLEAN DEFAULT FALSE,           -- Si es true (ej. 'General'), no se permite eliminar
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices de Categorías
CREATE INDEX IF NOT EXISTS idx_note_categories_user ON public.note_categories(user_id, sort_order);

-- RLS de Categorías
ALTER TABLE public.note_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own note categories" ON public.note_categories;
DROP POLICY IF EXISTS "Users can insert their own note categories" ON public.note_categories;
DROP POLICY IF EXISTS "Users can update their own note categories" ON public.note_categories;
DROP POLICY IF EXISTS "Users can delete their own non-system note categories" ON public.note_categories;
DROP POLICY IF EXISTS "Permitir acceso a note_categories" ON public.note_categories;

CREATE POLICY "Permitir acceso a note_categories" ON public.note_categories
    FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- Trigger de updated_at para Categorías
DROP TRIGGER IF EXISTS trigger_note_categories_updated_at ON public.note_categories;
CREATE TRIGGER trigger_note_categories_updated_at
BEFORE UPDATE ON public.note_categories
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- 4. Tabla Principal de Notas (notas)
CREATE TABLE IF NOT EXISTS public.notas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.note_categories(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    icon TEXT DEFAULT '📝',
    color_hex TEXT DEFAULT '#6366F1',
    blocks JSONB NOT NULL DEFAULT '[]'::jsonb,  -- Array de NoteBlock (títulos, to-dos, toggles, etc.)
    content_text TEXT,                         -- Texto plano / markdown para búsqueda y Agente RAG
    is_pinned BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    shared_tag TEXT,                           -- Tag para compartir/filtrar (ej. 'pareja')
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices de Alto Rendimiento para Notas
CREATE INDEX IF NOT EXISTS idx_notas_user ON public.notas(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notas_category ON public.notas(category_id);
CREATE INDEX IF NOT EXISTS idx_notas_pinned ON public.notas(user_id, is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_notas_archived ON public.notas(user_id, is_archived) WHERE is_archived = FALSE;

-- RLS de Notas
ALTER TABLE public.notas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notes" ON public.notas;
DROP POLICY IF EXISTS "Users can insert their own notes" ON public.notas;
DROP POLICY IF EXISTS "Users can update their own notes" ON public.notas;
DROP POLICY IF EXISTS "Users can delete their own notes" ON public.notas;
DROP POLICY IF EXISTS "Permitir acceso a notas" ON public.notas;

CREATE POLICY "Permitir acceso a notas" ON public.notas
    FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- Trigger de updated_at para Notas
DROP TRIGGER IF EXISTS trigger_notas_updated_at ON public.notas;
CREATE TRIGGER trigger_notas_updated_at
BEFORE UPDATE ON public.notas
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- 5. Función de Inicialización de Categorías Predeterminadas por Usuario
CREATE OR REPLACE FUNCTION public.seed_default_note_categories(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- 1. General (Sistema)
    INSERT INTO public.note_categories (id, user_id, name, icon, color_hex, sort_order, is_system)
    VALUES (gen_random_uuid(), p_user_id, 'General', '📝', '#6366F1', 0, TRUE)
    ON CONFLICT DO NOTHING;

    -- 2. Acuerdos de Pareja
    INSERT INTO public.note_categories (id, user_id, name, icon, color_hex, sort_order, is_system)
    VALUES (gen_random_uuid(), p_user_id, 'Acuerdos de Pareja', '💍', '#EC4899', 1, FALSE)
    ON CONFLICT DO NOTHING;

    -- 3. Ideas & Proyectos
    INSERT INTO public.note_categories (id, user_id, name, icon, color_hex, sort_order, is_system)
    VALUES (gen_random_uuid(), p_user_id, 'Ideas & Proyectos', '💡', '#F59E0B', 2, FALSE)
    ON CONFLICT DO NOTHING;

    -- 4. Direcciones & Datos Útiles
    INSERT INTO public.note_categories (id, user_id, name, icon, color_hex, sort_order, is_system)
    VALUES (gen_random_uuid(), p_user_id, 'Direcciones & Datos Útiles', '📍', '#10B981', 3, FALSE)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Publicación en Realtime de Supabase
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.note_categories;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notas;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
