-- ==============================================================================
-- MIGRACIÓN 010: DIARIO JOTTACHE - NOTAS PERSONALES
-- ==============================================================================
-- Esta migración adapta las tablas para permitir notas personales independientes
-- de contactos específicos (contact_id = 'personal' o NULL).

-- 1. Quitar la restricción NOT NULL de contact_id en diario_entries
ALTER TABLE diario_entries ALTER COLUMN contact_id DROP NOT NULL;

-- 2. Eliminar la restricción de clave foránea estricta a diario_contacts
-- para permitir entradas con contact_id = 'personal' o NULL
ALTER TABLE diario_entries DROP CONSTRAINT IF EXISTS diario_entries_contact_id_fkey;

-- 3. Asegurar que diario_categories permita contact_id sin restricción estricta
ALTER TABLE diario_categories DROP CONSTRAINT IF EXISTS diario_categories_contact_id_fkey;

-- 4. Registrar la categoría raíz predeterminada 'cat_notas_personales'
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_notas_personales', NULL, NULL, 'Notas Personales', 'edit_note', '#1F6F5F', 0)
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    icon = EXCLUDED.icon,
    color_hex = EXCLUDED.color_hex;
