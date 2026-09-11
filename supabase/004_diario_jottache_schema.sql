-- ==============================================================================
-- SCHEMA SUPABASE PARA: DIARIO JOTTACHE (PERSONAL RELATIONSHIP & KNOWLEDGE BASE)
-- ==============================================================================
-- Super App OrtizApp - Módulo Diario Jottache
-- Incluye: Contactos, Categorías Jerárquicas (Árbol N-niveles), Modelos Dinámicos
-- (JSONB Schemas reutilizables), Entradas Flexibles, Índices y RLS.
-- ==============================================================================

-- 1. TABLA DE CONTACTOS
CREATE TABLE IF NOT EXISTS diario_contacts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    nickname TEXT,
    relationship TEXT,
    avatar_url TEXT,
    avatar_color TEXT,
    birthdate DATE,
    phone TEXT,
    notes TEXT,
    is_favorite BOOLEAN DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABLA DE CATEGORÍAS JERÁRQUICAS (ÁRBOL DE SUB-CATEGORÍAS)
CREATE TABLE IF NOT EXISTS diario_categories (
    id TEXT PRIMARY KEY,
    contact_id TEXT REFERENCES diario_contacts(id) ON DELETE CASCADE, -- NULL = Categoría global/base
    parent_id TEXT REFERENCES diario_categories(id) ON DELETE CASCADE,  -- NULL = Categoría raíz
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'folder_outlined',
    color_hex TEXT DEFAULT '#4F46E5',
    sort_order INTEGER DEFAULT 0,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABLA DE MODELOS / PLANTILLAS REUTILIZABLES (SCHEMAS DINÁMICOS)
CREATE TABLE IF NOT EXISTS diario_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'extension',
    color_hex TEXT DEFAULT '#3B82F6',
    schema JSONB NOT NULL DEFAULT '{"fields": []}'::jsonb,
    is_system BOOLEAN DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABLA DE ENTRADAS FLEXIBLES (REGISTROS VINCULADOS A CONTACTO Y CATEGORÍA)
CREATE TABLE IF NOT EXISTS diario_entries (
    id TEXT PRIMARY KEY,
    contact_id TEXT NOT NULL REFERENCES diario_contacts(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES diario_categories(id) ON DELETE CASCADE,
    template_id TEXT REFERENCES diario_templates(id) ON DELETE SET NULL,
    entry_type TEXT NOT NULL DEFAULT 'simple_text', -- 'simple_text', 'list_item', 'template_instance'
    title TEXT NOT NULL,
    content_text TEXT,
    content_data JSONB DEFAULT '{}'::jsonb,
    is_pinned BOOLEAN DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 5. ÍNDICES DE ALTO RENDIMIENTO
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_diario_contacts_user ON diario_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_diario_contacts_favorite ON diario_contacts(is_favorite);
CREATE INDEX IF NOT EXISTS idx_diario_contacts_birthdate ON diario_contacts(birthdate);

CREATE INDEX IF NOT EXISTS idx_diario_categories_contact ON diario_categories(contact_id);
CREATE INDEX IF NOT EXISTS idx_diario_categories_parent ON diario_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_diario_categories_user ON diario_categories(user_id);

CREATE INDEX IF NOT EXISTS idx_diario_templates_user ON diario_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_diario_templates_system ON diario_templates(is_system);

CREATE INDEX IF NOT EXISTS idx_diario_entries_contact ON diario_entries(contact_id);
CREATE INDEX IF NOT EXISTS idx_diario_entries_category ON diario_entries(category_id);
CREATE INDEX IF NOT EXISTS idx_diario_entries_template ON diario_entries(template_id);
CREATE INDEX IF NOT EXISTS idx_diario_entries_user ON diario_entries(user_id);
-- Índice GIN para búsquedas ultra rápidas en los datos estructurados JSONB
CREATE INDEX IF NOT EXISTS idx_diario_entries_content_gin ON diario_entries USING GIN (content_data);

-- ==============================================================================
-- 6. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ==============================================================================
ALTER TABLE diario_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE diario_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE diario_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE diario_entries ENABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE
    t text;
    diario_tables text[] := ARRAY[
        'diario_contacts', 'diario_categories', 'diario_templates', 'diario_entries'
    ];
BEGIN
    FOREACH t IN ARRAY diario_tables
    LOOP
        EXECUTE format('
            DROP POLICY IF EXISTS "Permitir acceso completo usuario propietario o anon" ON %I;
            CREATE POLICY "Permitir acceso completo usuario propietario o anon" ON %I
                FOR ALL
                USING (true)
                WITH CHECK (true);
        ', t, t);
    END LOOP;
END $$;

-- ==============================================================================
-- 7. PLANTILLAS / MODELOS PREDETERMINADOS DEL SISTEMA
-- ==============================================================================
INSERT INTO diario_templates (id, name, description, icon, color_hex, schema, is_system)
VALUES 
(
    'tpl_automovil',
    'Automóvil / Vehículo',
    'Datos de vehículos asociados a un contacto: placa, marca, modelo, año y color.',
    'directions_car',
    '#3B82F6',
    '{
        "fields": [
            {"key": "marca", "label": "Marca", "type": "text", "required": true, "placeholder": "Ej: Toyota, Chevrolet, Ford"},
            {"key": "modelo", "label": "Modelo", "type": "text", "required": true, "placeholder": "Ej: Corolla, Spark, Explorer"},
            {"key": "anio", "label": "Año", "type": "number", "required": false, "placeholder": "Ej: 2022"},
            {"key": "placa", "label": "Placa", "type": "text", "required": true, "placeholder": "Ej: ABC123D"},
            {"key": "color", "label": "Color", "type": "text", "required": false, "placeholder": "Ej: Plata, Blanco, Azul"},
            {"key": "notas", "label": "Notas / Seguro", "type": "multiline", "required": false, "placeholder": "Póliza, taller de confianza, etc."}
        ]
    }'::jsonb,
    true
),
(
    'tpl_ropa_tallas',
    'Tallas de Ropa / Calzado',
    'Tallas, medidas y preferencias de vestimenta para regalos y compras.',
    'straighten',
    '#6366F1',
    '{
        "fields": [
            {"key": "tipo", "label": "Tipo de Prenda / Accesorio", "type": "select", "required": true, "options": ["Calzado", "Camisa / Blusa", "Pantalón", "Vestido", "Ropa Interior", "Anillo / Joyería", "Gorra / Sombrero"]},
            {"key": "talla", "label": "Talla / Medida exacta", "type": "text", "required": true, "placeholder": "Ej: 41, M, 32/30, US 9"},
            {"key": "marcas", "label": "Marcas Favoritas", "type": "text", "required": false, "placeholder": "Ej: Zara, Nike, Levi''s"},
            {"key": "notas", "label": "Notas de Ajuste", "type": "multiline", "required": false, "placeholder": "Ej: Horma ancha, prefiere corte holgado"}
        ]
    }'::jsonb,
    true
),
(
    'tpl_cuenta_bancaria',
    'Cuenta Bancaria / Pago Móvil',
    'Datos bancarios para transferencias inmediatas y pagos a contactos.',
    'credit_card',
    '#10B981',
    '{
        "fields": [
            {"key": "banco", "label": "Banco", "type": "text", "required": true, "placeholder": "Ej: Banesco, Mercantil, BDV, Chase, Wells Fargo"},
            {"key": "titular", "label": "Titular de la cuenta", "type": "text", "required": true, "placeholder": "Nombre y Apellido"},
            {"key": "identificacion", "label": "Cédula / RIF / ID", "type": "text", "required": true, "placeholder": "Ej: V-12345678"},
            {"key": "numero_cuenta", "label": "Número de Cuenta (20 dígitos)", "type": "text", "required": false, "placeholder": "0134..."},
            {"key": "pago_movil", "label": "Teléfono Pago Móvil", "type": "text", "required": false, "placeholder": "0414-1234567"},
            {"key": "zelle_correo", "label": "Correo Zelle / PayPal", "type": "text", "required": false, "placeholder": "ejemplo@correo.com"}
        ]
    }'::jsonb,
    true
),
(
    'tpl_preferencia_comida',
    'Preferencia Gastronómica',
    'Platos, bebidas y alimentos favoritos, alergias o disgustos culinarios.',
    'restaurant',
    '#F59E0B',
    '{
        "fields": [
            {"key": "alimento", "label": "Plato / Alimento", "type": "text", "required": true, "placeholder": "Ej: Pasta de hígado, Sushi, Café con leche"},
            {"key": "gusto", "label": "Preferencia", "type": "select", "required": true, "options": ["Le fascina / Favorito", "Le gusta", "No le gusta", "Detesta / No come", "Alergia / Intolerancia"]},
            {"key": "lugar", "label": "Restaurante / Lugar preferido", "type": "text", "required": false, "placeholder": "Dónde le gusta comerlo"},
            {"key": "detalles", "label": "Cómo le gusta preparado", "type": "multiline", "required": false, "placeholder": "Ej: Sin cebolla, término medio, leche deslactosada"}
        ]
    }'::jsonb,
    true
),
(
    'tpl_idea_regalo',
    'Idea de Regalo / Deseo',
    'Lista de deseos, cosas que le gustaría tener u obsequios planificados.',
    'card_giftcard',
    '#EC4899',
    '{
        "fields": [
            {"key": "articulo", "label": "Artículo / Objeto de Regalo", "type": "text", "required": true, "placeholder": "Ej: Perfume Acqua di Gio, Libro Sci-Fi"},
            {"key": "ocasion", "label": "Ocasión Ideal", "type": "select", "required": false, "options": ["Cumpleaños", "Navidad", "Aniversario", "Graduación", "Sorpresa espontánea"]},
            {"key": "precio", "label": "Precio Aproximado ($)", "type": "number", "required": false, "placeholder": "Ej: 45.00"},
            {"key": "tienda_link", "label": "Tienda o Enlace web", "type": "text", "required": false, "placeholder": "Amazon, MercadoLibre, tienda física"},
            {"key": "estado", "label": "Estado del Regalo", "type": "select", "required": true, "options": ["Idea pendiente", "Planeado comprar", "Comprado / Entregado"]}
        ]
    }'::jsonb,
    true
),
(
    'tpl_mascota',
    'Mascota de Contacto',
    'Datos de las mascotas de personas cercanas: nombre, raza, veterinario.',
    'pets',
    '#8B5CF6',
    '{
        "fields": [
            {"key": "nombre", "label": "Nombre de la Mascota", "type": "text", "required": true, "placeholder": "Ej: Firulais, Luna"},
            {"key": "especie_raza", "label": "Especie / Raza", "type": "text", "required": true, "placeholder": "Ej: Perro Golden Retriever, Gato Siamés"},
            {"key": "edad_cumple", "label": "Edad o Fecha de Nacimiento", "type": "text", "required": false, "placeholder": "Ej: 3 años / 15 de Mayo"},
            {"key": "notas", "label": "Notas / Vacunas", "type": "multiline", "required": false, "placeholder": "Alergias, alimentos prohibidos, veterinario"}
        ]
    }'::jsonb,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    color_hex = EXCLUDED.color_hex,
    schema = EXCLUDED.schema,
    updated_at = NOW();

-- ==============================================================================
-- 8. CATEGORÍAS RAÍZ Y SUBCATEGORÍAS PREDETERMINADAS (GLOBALES)
-- ==============================================================================
-- Raíz: Alimentos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_alimentos', NULL, NULL, 'Alimentos & Bebidas', 'restaurant', '#F59E0B', 1)
ON CONFLICT (id) DO NOTHING;

-- Subcategorías de Alimentos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES 
('cat_alimentos_favoritos', NULL, 'cat_alimentos', 'Me Gusta / Favoritos', 'thumb_up', '#10B981', 1),
('cat_alimentos_disgustos', NULL, 'cat_alimentos', 'No Le Gusta / Detesta', 'thumb_down', '#EF4444', 2)
ON CONFLICT (id) DO NOTHING;

-- Raíz: Regalos & Deseos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_regalos', NULL, NULL, 'Regalos & Deseos', 'card_giftcard', '#EC4899', 2)
ON CONFLICT (id) DO NOTHING;

-- Subcategorías de Regalos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES 
('cat_regalos_cumple', NULL, 'cat_regalos', 'Ideas de Cumpleaños', 'cake', '#EC4899', 1),
('cat_regalos_deseos', NULL, 'cat_regalos', 'Cosas que quiere comprar', 'shopping_bag', '#8B5CF6', 2)
ON CONFLICT (id) DO NOTHING;

-- Raíz: Vehículos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_vehiculos', NULL, NULL, 'Vehículos & Transporte', 'directions_car', '#3B82F6', 3)
ON CONFLICT (id) DO NOTHING;

-- Raíz: Salud & Medidas
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_salud', NULL, NULL, 'Salud & Medidas', 'favorite', '#EF4444', 4)
ON CONFLICT (id) DO NOTHING;

-- Subcategorías de Salud & Medidas
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES 
('cat_salud_tallas', NULL, 'cat_salud', 'Tallas de Ropa & Calzado', 'straighten', '#6366F1', 1),
('cat_salud_alergias', NULL, 'cat_salud', 'Alergias & Medicación', 'medical_services', '#EF4444', 2)
ON CONFLICT (id) DO NOTHING;

-- Raíz: Finanzas & Pagos
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_finanzas', NULL, NULL, 'Finanzas & Cuentas', 'account_balance', '#10B981', 5)
ON CONFLICT (id) DO NOTHING;

-- Raíz: Mascotas
INSERT INTO diario_categories (id, contact_id, parent_id, name, icon, color_hex, sort_order)
VALUES ('cat_mascotas', NULL, NULL, 'Mascotas', 'pets', '#8B5CF6', 6)
ON CONFLICT (id) DO NOTHING;
