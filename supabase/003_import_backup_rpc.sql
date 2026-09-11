-- ==============================================================================
-- MIGRACIÓN 003: RPC ATÓMICO DE IMPORTACIÓN DE COPIAS DE SEGURIDAD EN SUPABASE
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de Supabase (https://supabase.com/dashboard)
-- 1. Actualiza claves primarias compuestas para permitir aislamiento por libro contable (profile_id)
--    evitando que 'default_usd' o 'default_ves' colisionen entre múltiples perfiles.
-- 2. Crea la función RPC 'import_quebrado_backup' que recibe el JSON completo y realiza
--    la importación de las 16 tablas en una sola transacción ultrarrápida (< 1 segundo).
-- ==============================================================================

-- 1. AISLAMIENTO DE REGISTROS POR PERFIL (CLAVES PRIMARIAS COMPUESTAS)
ALTER TABLE IF EXISTS accounts DROP CONSTRAINT IF EXISTS accounts_pkey CASCADE;
ALTER TABLE IF EXISTS accounts ADD PRIMARY KEY (id, profile_id);

ALTER TABLE IF EXISTS categories DROP CONSTRAINT IF EXISTS categories_pkey CASCADE;
ALTER TABLE IF EXISTS categories ADD PRIMARY KEY (id, profile_id);

ALTER TABLE IF EXISTS pockets DROP CONSTRAINT IF EXISTS pockets_pkey CASCADE;
ALTER TABLE IF EXISTS pockets ADD PRIMARY KEY (id, profile_id);

ALTER TABLE IF EXISTS recurring_payments DROP CONSTRAINT IF EXISTS recurring_payments_pkey CASCADE;
ALTER TABLE IF EXISTS recurring_payments ADD PRIMARY KEY (id, profile_id);

ALTER TABLE IF EXISTS transactions DROP CONSTRAINT IF EXISTS transactions_pkey CASCADE;
ALTER TABLE IF EXISTS transactions ADD PRIMARY KEY (id, profile_id);

-- 2. FUNCIÓN RPC DE IMPORTACIÓN ATÓMICA ULTRA RÁPIDA
CREATE OR REPLACE FUNCTION import_quebrado_backup(backup_data JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_multi BOOLEAN;
    profiles_cfg JSONB;
    active_prof TEXT := 'quebrado.db';
    prof_rec RECORD;
    dbs JSONB;
    prof_key TEXT;
    db_data JSONB;
    r JSONB;
    c_parent_id TEXT;
    total_tx INT := 0;
    total_acc INT := 0;
    total_pockets INT := 0;
BEGIN
    is_multi := COALESCE((backup_data->>'__multi_profile_backup__')::BOOLEAN, false);

    IF is_multi THEN
        profiles_cfg := backup_data->'profiles_config';
        active_prof := COALESCE(profiles_cfg->>'active_profile', 'quebrado.db');
        
        -- Guardar / sincronizar perfiles
        IF profiles_cfg->'profiles' IS NOT NULL THEN
            FOR prof_rec IN SELECT * FROM jsonb_to_recordset(profiles_cfg->'profiles') AS x(id TEXT, name TEXT)
            LOOP
                INSERT INTO profiles (id, name, is_active)
                VALUES (prof_rec.id, prof_rec.name, prof_rec.id = active_prof)
                ON CONFLICT (id) DO UPDATE 
                SET name = EXCLUDED.name, is_active = EXCLUDED.is_active;
            END LOOP;
        END IF;

        dbs := backup_data->'databases';
    ELSE
        -- Copia de perfil único (legado)
        INSERT INTO profiles (id, name, is_active)
        VALUES ('quebrado.db', 'Personal', true)
        ON CONFLICT (id) DO UPDATE SET is_active = true;

        dbs := jsonb_build_object('quebrado.db', backup_data);
    END IF;

    -- Iterar por cada base de datos (perfil) en el JSON
    FOR prof_key, db_data IN SELECT * FROM jsonb_each(dbs)
    LOOP
        -- A. Settings (Omitir metadatos y snapshots del sistema)
        IF db_data->'settings' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'settings')
            LOOP
                IF r->>'key' IS NOT NULL AND r->>'value' IS NOT NULL AND r->>'key' NOT IN ('backup_snapshots', 'backup_metadata') THEN
                    INSERT INTO settings (key, value, updated_at)
                    VALUES (r->>'key', r->>'value', NOW())
                    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
                END IF;
            END LOOP;
        END IF;

        -- B. Categories (Pase 1: Categorías Raíz con parent_id nulo)
        IF db_data->'categories' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'categories')
            LOOP
                c_parent_id := NULLIF(TRIM(COALESCE(r->>'parent_id', '')), '');
                IF c_parent_id IS NULL THEN
                    INSERT INTO categories (id, name, icon, color_hex, type, position, parent_id, profile_id)
                    VALUES (
                        r->>'id',
                        COALESCE(r->>'name', 'Categoría'),
                        COALESCE(r->>'icon', 'tag'),
                        COALESCE(r->>'color_hex', '#1F6F5F'),
                        COALESCE(r->>'type', 'expense'),
                        COALESCE((r->>'position')::INT, 0),
                        NULL,
                        prof_key
                    )
                    ON CONFLICT (id, profile_id) DO UPDATE SET
                        name = EXCLUDED.name,
                        icon = EXCLUDED.icon,
                        color_hex = EXCLUDED.color_hex,
                        type = EXCLUDED.type,
                        position = EXCLUDED.position,
                        parent_id = NULL;
                END IF;
            END LOOP;

            -- Categories (Pase 2: Subcategorías con parent_id no nulo)
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'categories')
            LOOP
                c_parent_id := NULLIF(TRIM(COALESCE(r->>'parent_id', '')), '');
                IF c_parent_id IS NOT NULL THEN
                    INSERT INTO categories (id, name, icon, color_hex, type, position, parent_id, profile_id)
                    VALUES (
                        r->>'id',
                        COALESCE(r->>'name', 'Subcategoría'),
                        COALESCE(r->>'icon', 'tag'),
                        COALESCE(r->>'color_hex', '#1F6F5F'),
                        COALESCE(r->>'type', 'expense'),
                        COALESCE((r->>'position')::INT, 0),
                        c_parent_id,
                        prof_key
                    )
                    ON CONFLICT (id, profile_id) DO UPDATE SET
                        name = EXCLUDED.name,
                        icon = EXCLUDED.icon,
                        color_hex = EXCLUDED.color_hex,
                        type = EXCLUDED.type,
                        position = EXCLUDED.position,
                        parent_id = EXCLUDED.parent_id;
                END IF;
            END LOOP;
        END IF;

        -- C. Accounts
        IF db_data->'accounts' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'accounts')
            LOOP
                INSERT INTO accounts (id, name, currency, balance, color_hex, icon, profile_id, updated_at)
                VALUES (
                    r->>'id',
                    COALESCE(r->>'name', 'Cuenta'),
                    COALESCE(r->>'currency', 'usd'),
                    COALESCE((r->>'balance')::NUMERIC, 0.00),
                    COALESCE(r->>'color_hex', '#1F6F5F'),
                    COALESCE(r->>'icon', 'wallet'),
                    prof_key,
                    NOW()
                )
                ON CONFLICT (id, profile_id) DO UPDATE SET
                    name = EXCLUDED.name,
                    currency = EXCLUDED.currency,
                    balance = EXCLUDED.balance,
                    color_hex = EXCLUDED.color_hex,
                    icon = EXCLUDED.icon,
                    updated_at = NOW();
                total_acc := total_acc + 1;
            END LOOP;
        END IF;

        -- D. Pockets
        IF db_data->'pockets' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'pockets')
            LOOP
                INSERT INTO pockets (
                    id, name, current_amount_usd, target_amount_usd, icon, color_hex,
                    description, image_url, target_date, priority, funding_rule_type,
                    funding_rule_value, funding_rule_threshold, is_archived, profile_id, updated_at
                )
                VALUES (
                    r->>'id',
                    COALESCE(r->>'name', 'Bolsillo'),
                    COALESCE((r->>'current_amount_usd')::NUMERIC, 0.00),
                    COALESCE((r->>'target_amount_usd')::NUMERIC, 0.00),
                    COALESCE(r->>'icon', 'shield'),
                    COALESCE(r->>'color_hex', '#1F6F5F'),
                    r->>'description',
                    r->>'image_url',
                    NULLIF(r->>'target_date', '')::TIMESTAMPTZ,
                    COALESCE((r->>'priority')::INT, 1),
                    COALESCE(r->>'funding_rule_type', 'none'),
                    (r->>'funding_rule_value')::NUMERIC,
                    (r->>'funding_rule_threshold')::NUMERIC,
                    COALESCE((r->>'is_archived')::BOOLEAN, false),
                    prof_key,
                    NOW()
                )
                ON CONFLICT (id, profile_id) DO UPDATE SET
                    name = EXCLUDED.name,
                    current_amount_usd = EXCLUDED.current_amount_usd,
                    target_amount_usd = EXCLUDED.target_amount_usd,
                    icon = EXCLUDED.icon,
                    color_hex = EXCLUDED.color_hex,
                    description = EXCLUDED.description,
                    image_url = EXCLUDED.image_url,
                    target_date = EXCLUDED.target_date,
                    priority = EXCLUDED.priority,
                    funding_rule_type = EXCLUDED.funding_rule_type,
                    funding_rule_value = EXCLUDED.funding_rule_value,
                    funding_rule_threshold = EXCLUDED.funding_rule_threshold,
                    is_archived = EXCLUDED.is_archived,
                    updated_at = NOW();
                total_pockets := total_pockets + 1;
            END LOOP;
        END IF;

        -- E. Transactions
        IF db_data->'transactions' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'transactions')
            LOOP
                INSERT INTO transactions (
                    id, date, amount, currency, destination_pocket_id, category_id,
                    account_id, note, type, exchange_rate, profile_id
                )
                VALUES (
                    r->>'id',
                    COALESCE(NULLIF(r->>'date', '')::TIMESTAMPTZ, NOW()),
                    COALESCE((r->>'amount')::NUMERIC, 0.00),
                    COALESCE(r->>'currency', 'usd'),
                    NULLIF(r->>'destination_pocket_id', ''),
                    NULLIF(r->>'category_id', ''),
                    NULLIF(r->>'account_id', ''),
                    COALESCE(r->>'note', ''),
                    COALESCE(r->>'type', 'expense'),
                    COALESCE((r->>'exchange_rate')::NUMERIC, 1.0),
                    prof_key
                )
                ON CONFLICT (id, profile_id) DO UPDATE SET
                    date = EXCLUDED.date,
                    amount = EXCLUDED.amount,
                    currency = EXCLUDED.currency,
                    destination_pocket_id = EXCLUDED.destination_pocket_id,
                    category_id = EXCLUDED.category_id,
                    account_id = EXCLUDED.account_id,
                    note = EXCLUDED.note,
                    type = EXCLUDED.type,
                    exchange_rate = EXCLUDED.exchange_rate;
                total_tx := total_tx + 1;
            END LOOP;
        END IF;

        -- F. Rate History (Historial de Tasas Global)
        IF db_data->'rate_history' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'rate_history')
            LOOP
                INSERT INTO rate_history (id, date, rate, type)
                VALUES (
                    r->>'id',
                    COALESCE(NULLIF(r->>'date', '')::TIMESTAMPTZ, NOW()),
                    COALESCE((r->>'rate')::NUMERIC, 1.0),
                    COALESCE(r->>'type', 'bcv')
                )
                ON CONFLICT (id) DO NOTHING;
            END LOOP;
        END IF;

        -- G. Recurring Payments
        IF db_data->'recurring_payments' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'recurring_payments')
            LOOP
                INSERT INTO recurring_payments (
                    id, name, amount, currency, frequency, start_date, notification_option,
                    icon, color_hex, type,
                    is_variable, pocket_id, account_id, custom_days, total_installments, max_amount,
                    profile_id
                )
                VALUES (
                    r->>'id',
                    COALESCE(r->>'name', 'Pago recurrente'),
                    COALESCE((r->>'amount')::NUMERIC, 0.00),
                    COALESCE(r->>'currency', 'usd'),
                    COALESCE(r->>'frequency', 'monthly'),
                    COALESCE(NULLIF(r->>'start_date', '')::TIMESTAMPTZ, NOW()),
                    r->>'notification_option',
                    COALESCE(r->>'icon', 'calendar_today'),
                    COALESCE(r->>'color_hex', '#1F6F5F'),
                    COALESCE(r->>'type', 'expense'),
                    COALESCE((r->>'is_variable')::BOOLEAN, false),
                    NULLIF(r->>'pocket_id', ''),
                    NULLIF(r->>'account_id', ''),
                    (r->>'custom_days')::INT,
                    (r->>'total_installments')::INT,
                    (r->>'max_amount')::NUMERIC,
                    prof_key
                )
                ON CONFLICT (id, profile_id) DO UPDATE SET
                    name = EXCLUDED.name,
                    amount = EXCLUDED.amount,
                    currency = EXCLUDED.currency,
                    frequency = EXCLUDED.frequency,
                    start_date = EXCLUDED.start_date,
                    notification_option = EXCLUDED.notification_option,
                    icon = EXCLUDED.icon,
                    color_hex = EXCLUDED.color_hex,
                    type = EXCLUDED.type,
                    is_variable = EXCLUDED.is_variable,
                    pocket_id = EXCLUDED.pocket_id,
                    account_id = EXCLUDED.account_id,
                    custom_days = EXCLUDED.custom_days,
                    total_installments = EXCLUDED.total_installments,
                    max_amount = EXCLUDED.max_amount;
            END LOOP;
        END IF;

        -- H. Recurring Payment Confirmations
        IF db_data->'recurring_payment_confirmations' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'recurring_payment_confirmations')
            LOOP
                INSERT INTO recurring_payment_confirmations (id, recurring_payment_id, date)
                VALUES (
                    r->>'id',
                    r->>'recurring_payment_id',
                    r->>'date'
                )
                ON CONFLICT (id) DO UPDATE SET
                    recurring_payment_id = EXCLUDED.recurring_payment_id,
                    date = EXCLUDED.date;
            END LOOP;
        END IF;

        -- I. Recurring Payment Partials
        IF db_data->'recurring_payment_partials' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'recurring_payment_partials')
            LOOP
                INSERT INTO recurring_payment_partials (id, recurring_payment_id, occurrence_date, amount, transaction_id)
                VALUES (
                    r->>'id',
                    r->>'recurring_payment_id',
                    r->>'occurrence_date',
                    COALESCE((r->>'amount')::NUMERIC, 0.00),
                    NULLIF(r->>'transaction_id', '')
                )
                ON CONFLICT (id) DO UPDATE SET
                    recurring_payment_id = EXCLUDED.recurring_payment_id,
                    occurrence_date = EXCLUDED.occurrence_date,
                    amount = EXCLUDED.amount,
                    transaction_id = EXCLUDED.transaction_id;
            END LOOP;
        END IF;

        -- J. Mobile Payment Recipients
        IF db_data->'mobile_payment_recipients' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'mobile_payment_recipients')
            LOOP
                INSERT INTO mobile_payment_recipients (id, alias, bank_code, bank_name, identity_card, phone_number)
                VALUES (
                    r->>'id',
                    COALESCE(r->>'alias', r->>'name', ''),
                    COALESCE(r->>'bank_code', ''),
                    COALESCE(r->>'bank_name', ''),
                    COALESCE(r->>'identity_card', r->>'id_number', ''),
                    COALESCE(r->>'phone_number', r->>'phone', '')
                )
                ON CONFLICT (id) DO UPDATE SET
                    alias = EXCLUDED.alias,
                    bank_code = EXCLUDED.bank_code,
                    bank_name = EXCLUDED.bank_name,
                    identity_card = EXCLUDED.identity_card,
                    phone_number = EXCLUDED.phone_number;
            END LOOP;
        END IF;

        -- K. Market Stores
        IF db_data->'market_stores' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_stores')
            LOOP
                INSERT INTO market_stores (id, name, color_hex, icon, description)
                VALUES (
                    r->>'id',
                    COALESCE(r->>'name', 'Tienda'),
                    COALESCE(r->>'color_hex', '#1F6F5F'),
                    COALESCE(r->>'icon', 'store'),
                    r->>'description'
                )
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    color_hex = EXCLUDED.color_hex,
                    icon = EXCLUDED.icon,
                    description = EXCLUDED.description;
            END LOOP;
        END IF;

        -- L. Market Products
        IF db_data->'market_products' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_products')
            LOOP
                INSERT INTO market_products (id, name, category, "storeIds", "referencePriceUSD", unit, default_quantity)
                VALUES (
                    r->>'id',
                    COALESCE(r->>'name', 'Producto'),
                    COALESCE(r->>'category', 'General'),
                    r->>'storeIds',
                    (r->>'referencePriceUSD')::NUMERIC,
                    COALESCE(r->>'unit', 'un'),
                    COALESCE((r->>'default_quantity')::NUMERIC, 1.0)
                )
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    category = EXCLUDED.category,
                    "storeIds" = EXCLUDED."storeIds",
                    "referencePriceUSD" = EXCLUDED."referencePriceUSD",
                    unit = EXCLUDED.unit,
                    default_quantity = EXCLUDED.default_quantity;
            END LOOP;
        END IF;

        -- M. Market Trips
        IF db_data->'market_trips' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_trips')
            LOOP
                INSERT INTO market_trips (id, title, is_active, store_id, date, total_usd, total_bs, exchange_rate, transaction_id)
                VALUES (
                    r->>'id',
                    r->>'title',
                    COALESCE((r->>'is_active')::BOOLEAN, true),
                    NULLIF(r->>'store_id', ''),
                    COALESCE(NULLIF(r->>'date', '')::TIMESTAMPTZ, NOW()),
                    COALESCE((r->>'total_usd')::NUMERIC, (r->>'total_spent_usd')::NUMERIC, 0.00),
                    COALESCE((r->>'total_bs')::NUMERIC, (r->>'total_spent_bs')::NUMERIC, 0.00),
                    COALESCE((r->>'exchange_rate')::NUMERIC, 1.0),
                    NULLIF(r->>'transaction_id', '')
                )
                ON CONFLICT (id) DO UPDATE SET
                    title = EXCLUDED.title,
                    is_active = EXCLUDED.is_active,
                    store_id = EXCLUDED.store_id,
                    date = EXCLUDED.date,
                    total_usd = EXCLUDED.total_usd,
                    total_bs = EXCLUDED.total_bs,
                    exchange_rate = EXCLUDED.exchange_rate,
                    transaction_id = EXCLUDED.transaction_id;
            END LOOP;
        END IF;

        -- N. Market Items
        IF db_data->'market_items' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_items')
            LOOP
                INSERT INTO market_items (
                    id, trip_id, product_id, store_id, name, category,
                    quantity, price_usd, price_ves, exchange_rate_used, is_pending, date, unit
                )
                VALUES (
                    r->>'id',
                    NULLIF(r->>'trip_id', ''),
                    NULLIF(r->>'product_id', ''),
                    NULLIF(r->>'store_id', ''),
                    r->>'name',
                    r->>'category',
                    COALESCE((r->>'quantity')::NUMERIC, 1.0),
                    COALESCE((r->>'price_usd')::NUMERIC, 0.00),
                    COALESCE((r->>'price_ves')::NUMERIC, (r->>'price_bs')::NUMERIC, 0.00),
                    COALESCE((r->>'exchange_rate_used')::NUMERIC, 1.0),
                    COALESCE((r->>'is_pending')::BOOLEAN, false),
                    COALESCE(NULLIF(r->>'date', '')::TIMESTAMPTZ, NOW()),
                    COALESCE(r->>'unit', 'un')
                )
                ON CONFLICT (id) DO UPDATE SET
                    trip_id = EXCLUDED.trip_id,
                    product_id = EXCLUDED.product_id,
                    store_id = EXCLUDED.store_id,
                    name = EXCLUDED.name,
                    category = EXCLUDED.category,
                    quantity = EXCLUDED.quantity,
                    price_usd = EXCLUDED.price_usd,
                    price_ves = EXCLUDED.price_ves,
                    exchange_rate_used = EXCLUDED.exchange_rate_used,
                    is_pending = EXCLUDED.is_pending,
                    date = EXCLUDED.date,
                    unit = EXCLUDED.unit;
            END LOOP;
        END IF;

        -- O. Shopping Lists
        IF db_data->'market_shopping_lists' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_shopping_lists')
            LOOP
                INSERT INTO market_shopping_lists (id, title, date, is_active)
                VALUES (
                    r->>'id',
                    COALESCE(r->>'title', r->>'name', 'Lista de Mercado'),
                    COALESCE(NULLIF(r->>'date', '')::TIMESTAMPTZ, NOW()),
                    COALESCE((r->>'is_active')::BOOLEAN, true)
                )
                ON CONFLICT (id) DO UPDATE SET
                    title = EXCLUDED.title,
                    date = EXCLUDED.date,
                    is_active = EXCLUDED.is_active;
            END LOOP;
        END IF;

        -- P. Shopping List Items
        IF db_data->'market_shopping_list_items' IS NOT NULL THEN
            FOR r IN SELECT * FROM jsonb_array_elements(db_data->'market_shopping_list_items')
            LOOP
                INSERT INTO market_shopping_list_items (id, list_id, product_id, is_checked, quantity)
                VALUES (
                    r->>'id',
                    NULLIF(r->>'list_id', ''),
                    NULLIF(r->>'product_id', ''),
                    COALESCE((r->>'is_checked')::BOOLEAN, false),
                    COALESCE((r->>'quantity')::NUMERIC, 1.0)
                )
                ON CONFLICT (id) DO UPDATE SET
                    list_id = EXCLUDED.list_id,
                    product_id = EXCLUDED.product_id,
                    is_checked = EXCLUDED.is_checked,
                    quantity = EXCLUDED.quantity;
            END LOOP;
        END IF;

    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'active_profile', active_prof,
        'total_accounts', total_acc,
        'total_transactions', total_tx,
        'total_pockets', total_pockets
    );
END;
$$;

-- 3. PERMISOS Y RECARGA DE CACHÉ
GRANT EXECUTE ON FUNCTION import_quebrado_backup(JSONB) TO anon, authenticated, service_role;
NOTIFY pgrst, 'reload schema';
