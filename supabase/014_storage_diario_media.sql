-- ==============================================================================
-- MIGRACIÓN 014: STORAGE PARA FOTOS DE DIARIO (avatares de contactos y fotos de entradas)
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de Supabase (https://supabase.com/dashboard)
-- Es idempotente.
--
-- Antes las fotos se guardaban como texto base64 dentro de diario_contacts.avatar_url
-- y diario_entries.content_data (hasta ~2 MB por foto) o como rutas locales de macOS.
-- Ahora la app las comprime (JPEG) y las sube a este bucket; en la tabla queda solo la URL.
--
-- Estructura de rutas:  diario-media/avatars/<uuid>.jpg
--                       diario-media/entries/<uuid>.jpg
--
-- Bucket PÚBLICO: la app muestra las fotos con su URL pública (Image.network). Las rutas
-- son UUID aleatorios, no adivinables. Las políticas replican el acceso abierto (anon)
-- que ya usan las tablas de la suite.
-- ==============================================================================

-- 1. Bucket (5 MB por archivo, solo imágenes)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('diario-media', 'diario-media', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Políticas sobre storage.objects limitadas a este bucket
DROP POLICY IF EXISTS "diario_media_select" ON storage.objects;
CREATE POLICY "diario_media_select" ON storage.objects
    FOR SELECT
    USING (bucket_id = 'diario-media');

DROP POLICY IF EXISTS "diario_media_insert" ON storage.objects;
CREATE POLICY "diario_media_insert" ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id = 'diario-media');

DROP POLICY IF EXISTS "diario_media_update" ON storage.objects;
CREATE POLICY "diario_media_update" ON storage.objects
    FOR UPDATE
    USING (bucket_id = 'diario-media')
    WITH CHECK (bucket_id = 'diario-media');

DROP POLICY IF EXISTS "diario_media_delete" ON storage.objects;
CREATE POLICY "diario_media_delete" ON storage.objects
    FOR DELETE
    USING (bucket_id = 'diario-media');

-- ==============================================================================
-- 3. VERIFICACIÓN
-- ==============================================================================
-- SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id = 'diario-media';
-- SELECT policyname, cmd FROM pg_policies WHERE schemaname = 'storage' AND policyname LIKE 'diario_media_%';  -- 4 filas
--
-- Tras abrir la app, las fotos antiguas se migran solas en segundo plano. Para revisar:
-- SELECT COUNT(*) FILTER (WHERE avatar_url LIKE 'data:%') AS pendientes_base64,
--        COUNT(*) FILTER (WHERE avatar_url LIKE 'http%')  AS en_storage
--   FROM diario_contacts;

-- ==============================================================================
-- 4. ROLLBACK (solo si hace falta; las fotos ya migradas quedarían sin archivo)
-- ==============================================================================
-- DROP POLICY IF EXISTS "diario_media_select" ON storage.objects;
-- DROP POLICY IF EXISTS "diario_media_insert" ON storage.objects;
-- DROP POLICY IF EXISTS "diario_media_update" ON storage.objects;
-- DROP POLICY IF EXISTS "diario_media_delete" ON storage.objects;
-- DELETE FROM storage.objects WHERE bucket_id = 'diario-media';
-- DELETE FROM storage.buckets WHERE id = 'diario-media';
