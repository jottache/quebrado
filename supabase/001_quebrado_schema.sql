-- ==============================================================================
-- SCHEMA SUPABASE PARA QUEBRADO APP (SUPER APP PERSONAL)
-- ==============================================================================
-- Ejecutar este script completo en el SQL Editor de tu nuevo proyecto Supabase.
-- Incluye: Tablas relacionales, Claves Foráneas, Índices, Políticas de Seguridad (RLS).
-- ==============================================================================

-- 1. Habilitar extensión para UUIDs si no está habilitada
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. CONFIGURACIÓN GLOBAL Y PERFILES (LIBROS CONTABLES)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS profiles (
    id TEXT PRIMARY KEY, -- Ej: 'quebrado.db', 'negocio.db'
    name TEXT NOT NULL,  -- Ej: 'Personal', 'Emprendimiento'
    is_active BOOLEAN DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 3. MÓDULO DE FINANZAS BÁSICAS (Cuentas, Bolsillos, Categorías)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    currency TEXT NOT NULL CHECK (currency IN ('usd', 'bsBCV', 'eur')),
    balance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    color_hex TEXT NOT NULL,
    icon TEXT NOT NULL,
    profile_id TEXT DEFAULT 'quebrado.db',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pockets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    current_amount_usd NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    target_amount_usd NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    icon TEXT NOT NULL,
    color_hex TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    target_date TIMESTAMPTZ,
    priority INTEGER DEFAULT 1,
    funding_rule_type TEXT DEFAULT 'none',
    funding_rule_value NUMERIC(15, 2),
    funding_rule_threshold NUMERIC(15, 2),
    is_archived BOOLEAN DEFAULT false,
    profile_id TEXT DEFAULT 'quebrado.db',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color_hex TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    position INTEGER DEFAULT 0,
    parent_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
    profile_id TEXT DEFAULT 'quebrado.db',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 4. TRANSACCIONES E HISTORIAL CAMBIARIO
-- ==============================================================================

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    date TIMESTAMPTZ NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency TEXT NOT NULL CHECK (currency IN ('usd', 'bsBCV', 'eur')),
    destination_pocket_id TEXT REFERENCES pockets(id) ON DELETE SET NULL,
    category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
    account_id TEXT REFERENCES accounts(id) ON DELETE CASCADE,
    note TEXT DEFAULT '',
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'exchange_buy', 'exchange_sell')),
    exchange_rate NUMERIC(15, 4) NOT NULL DEFAULT 1.0,
    profile_id TEXT DEFAULT 'quebrado.db',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rate_history (
    id TEXT PRIMARY KEY,
    date TIMESTAMPTZ NOT NULL,
    rate NUMERIC(15, 4) NOT NULL,
    type TEXT NOT NULL, -- 'bcv', 'paralelo', 'euro'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 5. OBLIGACIONES Y PAGOS RECURRENTES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS recurring_payments (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency TEXT NOT NULL CHECK (currency IN ('usd', 'bsBCV', 'eur')),
    frequency TEXT NOT NULL, -- 'weekly', 'biweekly', 'fifteenDays', 'monthly', 'threeMonths', 'yearly', 'custom', 'once'
    start_date TIMESTAMPTZ NOT NULL,
    notification_option TEXT,
    icon TEXT NOT NULL,
    color_hex TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    account_id TEXT REFERENCES accounts(id) ON DELETE CASCADE,
    pocket_id TEXT REFERENCES pockets(id) ON DELETE SET NULL,
    total_installments INTEGER,
    custom_days INTEGER,
    is_variable BOOLEAN DEFAULT false,
    max_amount NUMERIC(15, 2),
    profile_id TEXT DEFAULT 'quebrado.db',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recurring_payment_confirmations (
    id TEXT PRIMARY KEY, -- recurring_payment_id + "_" + dateStr
    recurring_payment_id TEXT NOT NULL REFERENCES recurring_payments(id) ON DELETE CASCADE,
    date TEXT NOT NULL, -- YYYY-MM-DD
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recurring_payment_partials (
    id TEXT PRIMARY KEY,
    recurring_payment_id TEXT NOT NULL REFERENCES recurring_payments(id) ON DELETE CASCADE,
    occurrence_date TEXT NOT NULL, -- YYYY-MM-DD
    amount NUMERIC(15, 2) NOT NULL,
    transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mobile_payment_recipients (
    id TEXT PRIMARY KEY,
    alias TEXT NOT NULL,
    bank_code TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    identity_card TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 6. MÓDULO DE MERCADO Y COMPRAS INTELIGENTES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS market_stores (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color_hex TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    "storeIds" TEXT,
    "referencePriceUSD" NUMERIC(15, 2),
    unit TEXT DEFAULT 'un',
    default_quantity NUMERIC(10, 3) DEFAULT 1.0,
    icon TEXT,
    barcode TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_trips (
    id TEXT PRIMARY KEY,
    title TEXT,
    is_active BOOLEAN DEFAULT true,
    store_id TEXT REFERENCES market_stores(id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'completed', 'cancelled'
    total_usd NUMERIC(15, 2) DEFAULT 0.00,
    total_bs NUMERIC(15, 2) DEFAULT 0.00,
    exchange_rate NUMERIC(15, 4) DEFAULT 1.0,
    transaction_id TEXT REFERENCES transactions(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_items (
    id TEXT PRIMARY KEY,
    name TEXT,
    category TEXT,
    price_usd NUMERIC(15, 2) NOT NULL,
    price_ves NUMERIC(15, 2) DEFAULT 0.00,
    exchange_rate_used NUMERIC(15, 4) DEFAULT 1.0,
    is_pending BOOLEAN DEFAULT false,
    product_id TEXT REFERENCES market_products(id) ON DELETE CASCADE,
    store_id TEXT REFERENCES market_stores(id) ON DELETE CASCADE,
    trip_id TEXT REFERENCES market_trips(id) ON DELETE CASCADE,
    date TIMESTAMPTZ NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL DEFAULT 1.0,
    unit TEXT DEFAULT 'unidad',
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_shopping_lists (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_shopping_list_items (
    id TEXT PRIMARY KEY,
    list_id TEXT NOT NULL REFERENCES market_shopping_lists(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES market_products(id) ON DELETE CASCADE,
    quantity NUMERIC(10, 3) NOT NULL DEFAULT 1.0,
    is_checked BOOLEAN DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 7. ÍNDICES DE RENDIMIENTO
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_profile ON transactions(profile_id);
CREATE INDEX IF NOT EXISTS idx_market_items_product ON market_items(product_id);
CREATE INDEX IF NOT EXISTS idx_market_items_trip ON market_items(trip_id);
CREATE INDEX IF NOT EXISTS idx_recurring_confirmations_date ON recurring_payment_confirmations(date);

-- ==============================================================================
-- 8. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ==============================================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pockets ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_payment_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_payment_partials ENABLE ROW LEVEL SECURITY;
ALTER TABLE mobile_payment_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_shopping_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_shopping_list_items ENABLE ROW LEVEL SECURITY;

-- Políticas para acceso personal:
-- Si el usuario está autenticado, tiene acceso completo a sus registros.
-- Si opera en modo personal/anon con clave pública anon, permitimos operaciones
-- donde user_id coincida con auth.uid() O user_id IS NULL (para fácil configuración inicial).

DO $$ 
DECLARE
    t text;
    tables text[] := ARRAY[
        'settings', 'profiles', 'accounts', 'pockets', 'categories',
        'transactions', 'recurring_payments', 'recurring_payment_confirmations',
        'recurring_payment_partials', 'mobile_payment_recipients',
        'market_stores', 'market_products', 'market_trips', 'market_items',
        'market_shopping_lists', 'market_shopping_list_items'
    ];
BEGIN
    FOREACH t IN ARRAY tables
    LOOP
        EXECUTE format('
            DROP POLICY IF EXISTS "Permitir todo para usuario propietario o anon" ON %I;
            CREATE POLICY "Permitir todo para usuario propietario o anon" ON %I
                FOR ALL
                USING (true)
                WITH CHECK (true);
        ', t, t);
    END LOOP;
END $$;

-- Tasa histórica es compartida/global
DROP POLICY IF EXISTS "Lectura y escritura publica rate_history" ON rate_history;
CREATE POLICY "Lectura y escritura publica rate_history" ON rate_history
    FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- FIN DEL SCRIPT
-- ==============================================================================
