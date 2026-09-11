-- ==============================================================================
-- MIGRACIÓN 002: CORRECCIÓN Y SINCRONIZACIÓN DE ESQUEMA PARA BACKUP SUPABASE
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase (https://supabase.com/dashboard)
-- Agrega las columnas faltantes identificadas durante la restauración de copias de seguridad:
-- 1. categories.parent_id (para subcategorías)
-- 2. market_stores.description
-- 3. market_products ("storeIds", "referencePriceUSD", unit, default_quantity)
-- 4. market_trips (title, is_active)
-- 5. market_items (name, category, price_ves, exchange_rate_used, is_pending)
-- 6. pockets (is_archived)
-- ==============================================================================

-- 1. CATEGORÍAS (Soporte para subcategorías jerárquicas)
ALTER TABLE IF EXISTS categories 
ADD COLUMN IF NOT EXISTS parent_id TEXT REFERENCES categories(id) ON DELETE SET NULL;

-- 2. BOLSILLOS (Soporte para archivado)
ALTER TABLE IF EXISTS pockets 
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;

-- 3. TIENDAS DE MERCADO (Descripción de tienda)
ALTER TABLE IF EXISTS market_stores 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 4. PRODUCTOS DE MERCADO (Columnas exactas del modelo Flutter / SQLite)
ALTER TABLE IF EXISTS market_products 
ADD COLUMN IF NOT EXISTS "storeIds" TEXT,
ADD COLUMN IF NOT EXISTS "referencePriceUSD" NUMERIC(15, 2),
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'un',
ADD COLUMN IF NOT EXISTS default_quantity NUMERIC(10, 3) DEFAULT 1.0;

-- 5. TRIPS / VIAJES DE MERCADO (Título y estado activo)
ALTER TABLE IF EXISTS market_trips 
ADD COLUMN IF NOT EXISTS title TEXT,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Permitir que store_id sea opcional si no está presente en el trip
ALTER TABLE IF EXISTS market_trips 
ALTER COLUMN store_id DROP NOT NULL;

-- 6. ÍTEMS DE MERCADO (Nombre, categoría, precio en Bs, tasa y estado pendiente)
ALTER TABLE IF EXISTS market_items 
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS category TEXT,
ADD COLUMN IF NOT EXISTS price_ves NUMERIC(15, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS exchange_rate_used NUMERIC(15, 4) DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS is_pending BOOLEAN DEFAULT false;

-- Permitir que product_id y store_id sean opcionales en market_items
ALTER TABLE IF EXISTS market_items 
ALTER COLUMN product_id DROP NOT NULL;

ALTER TABLE IF EXISTS market_items 
ALTER COLUMN store_id DROP NOT NULL;

ALTER TABLE IF EXISTS market_items 
ALTER COLUMN price_bs DROP NOT NULL;

-- 7. LISTAS DE MERCADO (Garantizar columna is_active)
ALTER TABLE IF EXISTS market_shopping_lists 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- 8. ACTUALIZAR CACHÉ DE ESQUEMA DE POSTGREST
NOTIFY pgrst, 'reload schema';
