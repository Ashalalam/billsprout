-- =====================================================
-- Enhancement Migration: Multi-Tenant Features & Fixes
-- =====================================================
-- Created: 2025-01-08
-- Description: Completes multi-tenant isolation, pharmacist management,
--              pricing plans, public demo requests, and reporting views.
--
-- IDEMPOTENCY CONTRACT
-- This migration is safe to run repeatedly against a live database:
--   * tables/indexes use IF NOT EXISTS
--   * columns are added inside guarded DO blocks
--   * every CREATE POLICY is preceded by DROP POLICY IF EXISTS
--   * views are dropped and recreated
--   * seed data uses ON CONFLICT DO NOTHING
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. HELPER FUNCTIONS
-- =====================================================

-- Sets the tenant context for the current session (used by trusted server-side
-- callers). Client sessions via PostgREST do not set this, which is why
-- tenant_access_allowed() falls back to the users table.
CREATE OR REPLACE FUNCTION set_tenant_context(tenant_uuid UUID)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', tenant_uuid::TEXT, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Returns the tenant id for the current request.
-- The authenticated user row is authoritative; the session setting is only a
-- fallback for trusted server-side callers with no auth.uid(). Deliberately in
-- that order so a client cannot widen its own scope by setting the variable.
CREATE OR REPLACE FUNCTION current_tenant_context()
RETURNS UUID AS $$
DECLARE
    user_tenant UUID;
    session_tenant TEXT;
BEGIN
    IF auth.uid() IS NOT NULL THEN
        SELECT tenant_id INTO user_tenant FROM users WHERE id = auth.uid();
        IF user_tenant IS NOT NULL THEN
            RETURN user_tenant;
        END IF;
    END IF;

    session_tenant := NULLIF(current_setting('app.current_tenant_id', true), '');
    IF session_tenant IS NULL THEN
        session_tenant := NULLIF(current_setting('app.tenant_id', true), '');
    END IF;

    IF session_tenant IS NOT NULL THEN
        RETURN session_tenant::UUID;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(
        (SELECT role = 'super_admin' FROM users WHERE id = auth.uid()),
        false
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Single predicate used by every tenant-scoped policy below.
-- Super admins pass for any tenant; everyone else only for their own tenant.
-- A NULL check_tenant_id never passes.
CREATE OR REPLACE FUNCTION tenant_access_allowed(check_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF check_tenant_id IS NULL THEN
        RETURN false;
    END IF;

    IF is_super_admin() THEN
        RETURN true;
    END IF;

    RETURN check_tenant_id = current_tenant_context();
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. COLUMN ADDITIONS ON EXISTING TABLES
-- =====================================================

-- sales.billing_type (retail vs wholesale) - Requirement 2.4
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                     AND table_name = 'sales'
                     AND column_name = 'billing_type') THEN
        ALTER TABLE sales ADD COLUMN billing_type VARCHAR(20) DEFAULT 'retail';
    END IF;

    -- Separate guard: the column may predate the constraint (001 inlines an
    -- anonymous check, older hand-patched databases may have neither).
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid = 'public.sales'::regclass
                     AND pg_get_constraintdef(oid) ILIKE '%billing_type%') THEN
        ALTER TABLE sales ADD CONSTRAINT sales_billing_type_check
            CHECK (billing_type IN ('retail', 'wholesale'));
    END IF;
END $$;

-- sales.customer_gstin for wholesale billing - Requirement 2.4
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                     AND table_name = 'sales'
                     AND column_name = 'customer_gstin') THEN
        ALTER TABLE sales ADD COLUMN customer_gstin VARCHAR(15);
    END IF;
END $$;

-- sale_items.tenant_id so line items can be filtered without a join.
-- Normally added by migration 005; guarded here so 007 is self-sufficient.
DO $$
DECLARE
    null_rows INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                     AND table_name = 'sale_items'
                     AND column_name = 'tenant_id') THEN
        ALTER TABLE sale_items
            ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;

        UPDATE sale_items si
        SET tenant_id = s.tenant_id
        FROM sales s
        WHERE si.sale_id = s.id;

        SELECT COUNT(*) INTO null_rows FROM sale_items WHERE tenant_id IS NULL;
        IF null_rows = 0 THEN
            ALTER TABLE sale_items ALTER COLUMN tenant_id SET NOT NULL;
        ELSE
            RAISE NOTICE 'sale_items.tenant_id left nullable: % orphan rows', null_rows;
        END IF;
    END IF;
END $$;

-- demo_requests columns required by DemoRequestModel - Requirement 8.1
DO $$
DECLARE
    col RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'demo_requests') THEN
        FOR col IN
            SELECT * FROM (VALUES
                ('business_name', 'VARCHAR(255)'),
                ('email',         'VARCHAR(255)'),
                ('city',          'VARCHAR(100)'),
                ('pincode',       'VARCHAR(10)'),
                ('business_type', 'VARCHAR(100)'),
                ('num_branches',  'INTEGER DEFAULT 1'),
                ('message',       'TEXT')
            ) AS v(name, definition)
        LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                           WHERE table_schema = 'public'
                             AND table_name = 'demo_requests'
                             AND column_name = col.name) THEN
                EXECUTE format('ALTER TABLE demo_requests ADD COLUMN %I %s',
                               col.name, col.definition);
            END IF;
        END LOOP;
    END IF;
END $$;

-- =====================================================
-- 3. TABLES
-- =====================================================

-- 3a. Public lead capture - Requirement 8.1
CREATE TABLE IF NOT EXISTS demo_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    business_name VARCHAR(255),
    mobile VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    city VARCHAR(100),
    pincode VARCHAR(10),
    business_type VARCHAR(100),
    num_branches INTEGER DEFAULT 1,
    message TEXT,
    status VARCHAR(50) DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'converted', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3b. Public pricing - Requirement 8.3
CREATE TABLE IF NOT EXISTS pricing_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_name VARCHAR(100) NOT NULL UNIQUE,
    plan_code VARCHAR(50) NOT NULL UNIQUE,
    price DECIMAL(15, 2) NOT NULL,
    gst_applicable BOOLEAN DEFAULT true,
    gst_percent DECIMAL(5, 2) DEFAULT 18.00,
    max_users INTEGER,
    max_branches INTEGER,
    max_products INTEGER,
    features JSONB,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3c. Pharmacists, tenant scoped, PIN stored only as a salted hash
--     - Requirements 7.1, 7.2
CREATE TABLE IF NOT EXISTS pharmacists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    license_no VARCHAR(50),
    registration_no VARCHAR(100),
    pin_hash VARCHAR(255),
    pin_salt VARCHAR(64),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, registration_no)
);

-- Guarded column adds for databases where an earlier pharmacists table exists
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN
        SELECT * FROM (VALUES
            ('user_id',         'UUID REFERENCES users(id) ON DELETE SET NULL'),
            ('email',           'VARCHAR(255)'),
            ('phone',           'VARCHAR(20)'),
            ('license_no',      'VARCHAR(50)'),
            ('registration_no', 'VARCHAR(100)'),
            ('pin_hash',        'VARCHAR(255)'),
            ('pin_salt',        'VARCHAR(64)'),
            ('is_active',       'BOOLEAN DEFAULT true'),
            ('updated_at',      'TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP')
        ) AS v(name, definition)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = 'public'
                         AND table_name = 'pharmacists'
                         AND column_name = col.name) THEN
            EXECUTE format('ALTER TABLE pharmacists ADD COLUMN %I %s',
                           col.name, col.definition);
        END IF;
    END LOOP;
END $$;

-- =====================================================
-- 4. SEED DATA
-- =====================================================
INSERT INTO pricing_plans (plan_name, plan_code, price, max_users, max_branches, max_products, features, display_order) VALUES
('Gold Edition', 'gold', 26000.00, -1, -1, -1, '["Unlimited Users", "Unlimited Branches", "Unlimited Products", "Multi-Tenant Support", "Wholesale & Retail", "GST Compliance", "Schedule H Register", "OTA Updates", "24/7 Support"]', 1),
('Basic Plan', 'basic', 15000.00, 5, 1, 1000, '["5 Users", "1 Branch", "1000 Products", "Retail Billing", "GST Reports", "Email Support"]', 2),
('Professional Plan', 'professional', 35000.00, 20, 5, 5000, '["20 Users", "5 Branches", "5000 Products", "Retail & Wholesale", "Multi-Branch", "Advanced Reports", "Priority Support"]', 3)
ON CONFLICT (plan_code) DO NOTHING;

-- =====================================================
-- 5. ROW LEVEL SECURITY
-- =====================================================
-- Requirements 2.1, 2.2, 2.3: every tenant-scoped table below is gated on
-- tenant_access_allowed(tenant_id), which resolves the caller's tenant from the
-- users table (or a session override) and always passes for super admins.

ALTER TABLE products      ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches      ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacists   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants       ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_plans ENABLE ROW LEVEL SECURITY;

-- 5a. Tenant-scoped tables
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'products', 'batches', 'sales', 'sale_items',
        'customers', 'suppliers', 'branches', 'pharmacists'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS "Tenant isolation on %1$s" ON %1$I;
             CREATE POLICY "Tenant isolation on %1$s"
             ON %1$I FOR ALL
             USING (tenant_access_allowed(tenant_id))
             WITH CHECK (tenant_access_allowed(tenant_id));', t);
    END LOOP;
END $$;

-- Retire the earlier session-variable-only policies from previous revisions of
-- this migration; they never matched because PostgREST sessions do not set
-- app.current_tenant_id.
DROP POLICY IF EXISTS "Tenants can only access their own products" ON products;
DROP POLICY IF EXISTS "Tenants can only access their own batches" ON batches;
DROP POLICY IF EXISTS "Tenants can only access their own sales" ON sales;
DROP POLICY IF EXISTS "Tenants can only access their own customers" ON customers;
DROP POLICY IF EXISTS "Tenants can only access their own suppliers" ON suppliers;
DROP POLICY IF EXISTS "Tenants can only access their own branches" ON branches;

-- Consolidate the overlapping policies created by 002/006 on these same tables.
-- Policies are OR'd, so leaving two predicates in place makes the effective rule
-- hard to reason about. The single "Tenant isolation on <table>" policy above is
-- equivalent and is now the only one.
DROP POLICY IF EXISTS "Users can access their tenant's products" ON products;
DROP POLICY IF EXISTS "Users can insert products for their tenant" ON products;
DROP POLICY IF EXISTS "Users can access their tenant's batches" ON batches;
DROP POLICY IF EXISTS "Users can insert batches for their tenant" ON batches;
DROP POLICY IF EXISTS "Users can access their tenant's sales" ON sales;
DROP POLICY IF EXISTS "Users can insert sales for their tenant" ON sales;
DROP POLICY IF EXISTS "Users can access sale items from their tenant's sales" ON sale_items;
DROP POLICY IF EXISTS "Users can insert sale items for their tenant's sales" ON sale_items;
DROP POLICY IF EXISTS "Users can access their tenant's sale items" ON sale_items;
DROP POLICY IF EXISTS "Users can insert sale items for their tenant" ON sale_items;
DROP POLICY IF EXISTS "Users can access their tenant's customers" ON customers;
DROP POLICY IF EXISTS "Users can insert customers for their tenant" ON customers;
DROP POLICY IF EXISTS "Users can access their tenant's suppliers" ON suppliers;
DROP POLICY IF EXISTS "Users can insert suppliers for their tenant" ON suppliers;
DROP POLICY IF EXISTS "Users can access their tenant's branches" ON branches;
DROP POLICY IF EXISTS "Users can insert branches for their tenant" ON branches;

-- 5b. Tenants table: super admin full access, tenant members read/update own row
-- Superseded by the three policies below (002 created narrower duplicates).
DROP POLICY IF EXISTS "Super admins can view all tenants" ON tenants;
DROP POLICY IF EXISTS "Super admins can insert tenants" ON tenants;
DROP POLICY IF EXISTS "Users can view their own tenant" ON tenants;

DROP POLICY IF EXISTS "Super admins can access all tenants" ON tenants;
CREATE POLICY "Super admins can access all tenants"
ON tenants FOR ALL
USING (is_super_admin())
WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS "Members can view their own tenant" ON tenants;
CREATE POLICY "Members can view their own tenant"
ON tenants FOR SELECT
USING (id = current_tenant_context());

DROP POLICY IF EXISTS "Business admins can update their own tenant" ON tenants;
CREATE POLICY "Business admins can update their own tenant"
ON tenants FOR UPDATE
USING (
    id = current_tenant_context()
    AND (SELECT role FROM users WHERE id = auth.uid()) IN ('business_admin', 'super_admin')
)
WITH CHECK (id = current_tenant_context());

-- 5c. demo_requests: anonymous visitors may insert only - Requirement 8.1
DROP POLICY IF EXISTS "Anyone can submit demo requests" ON demo_requests;
DROP POLICY IF EXISTS "Anon can insert demo requests" ON demo_requests;
CREATE POLICY "Anon can insert demo requests"
ON demo_requests FOR INSERT
TO anon, authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Super admins can view all demo requests" ON demo_requests;
CREATE POLICY "Super admins can view all demo requests"
ON demo_requests FOR SELECT
TO authenticated
USING (is_super_admin());

DROP POLICY IF EXISTS "Super admins can update demo requests" ON demo_requests;
CREATE POLICY "Super admins can update demo requests"
ON demo_requests FOR UPDATE
TO authenticated
USING (is_super_admin())
WITH CHECK (is_super_admin());

-- 5d. pricing_plans: world readable, super admin writable - Requirement 8.3
DROP POLICY IF EXISTS "Pricing plans are world readable" ON pricing_plans;
CREATE POLICY "Pricing plans are world readable"
ON pricing_plans FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "Super admins manage pricing plans" ON pricing_plans;
CREATE POLICY "Super admins manage pricing plans"
ON pricing_plans FOR ALL
TO authenticated
USING (is_super_admin())
WITH CHECK (is_super_admin());

-- =====================================================
-- 6. GRANTS
-- =====================================================
GRANT ALL ON pharmacists TO authenticated;
GRANT ALL ON pricing_plans TO authenticated;
GRANT ALL ON demo_requests TO authenticated;

-- Anonymous visitors may submit leads and read pricing, nothing else.
GRANT INSERT ON demo_requests TO anon;
REVOKE SELECT, UPDATE, DELETE ON demo_requests FROM anon;
GRANT SELECT ON pricing_plans TO anon;

-- =====================================================
-- 7. UPDATED_AT TRIGGERS
-- =====================================================
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables tb
          ON tb.table_schema = c.table_schema
         AND tb.table_name = c.table_name
        WHERE c.column_name = 'updated_at'
          AND c.table_schema = 'public'
          AND tb.table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS %1$I ON %2$I;
            CREATE TRIGGER %1$I
            BEFORE UPDATE ON %2$I
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
        ', 'update_' || t || '_updated_at', t);
    END LOOP;
END $$;

-- =====================================================
-- 8. INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_batches_tenant_branch ON batches(tenant_id, branch_id);
CREATE INDEX IF NOT EXISTS idx_sales_tenant_branch_date ON sales(tenant_id, branch_id, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_tenant_id ON sale_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_tenant_type ON customers(tenant_id, customer_type);
CREATE INDEX IF NOT EXISTS idx_suppliers_tenant_active ON suppliers(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_branches_tenant_active ON branches(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_pharmacists_tenant_active ON pharmacists(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_pharmacists_tenant_name ON pharmacists(tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_pricing_plans_active_order ON pricing_plans(is_active, display_order);
CREATE INDEX IF NOT EXISTS idx_demo_requests_created_at ON demo_requests(created_at DESC);

-- Near-expiry tracking - Requirement 6.1
CREATE INDEX IF NOT EXISTS idx_batches_expiry_date ON batches(exp_date) WHERE stock_quantity > 0;
CREATE INDEX IF NOT EXISTS idx_batches_tenant_expiry ON batches(tenant_id, exp_date) WHERE stock_quantity > 0;

CREATE INDEX IF NOT EXISTS idx_restricted_logs_tenant_date ON restricted_drug_logs(tenant_id, authorization_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_tenant_product ON stock_movements(tenant_id, product_id, created_at DESC);

-- =====================================================
-- 9. VIEWS
-- =====================================================
-- Dropped and recreated so column list changes do not break re-runs.

DROP VIEW IF EXISTS near_expiry_stock CASCADE;
CREATE VIEW near_expiry_stock AS
SELECT
    b.id AS batch_id,
    b.tenant_id,
    b.branch_id,
    br.branch_name,
    b.product_id,
    p.name AS product_name,
    p.generic_salt,
    p.manufacturer,
    b.batch_number,
    b.exp_date,
    b.stock_quantity,
    b.mrp,
    b.ptr_price,
    b.selling_price,
    b.rack_location,
    -- date - date yields an integer in PostgreSQL, so cast directly.
    -- EXTRACT(DAY FROM ...) over that difference is a type error.
    (b.exp_date - CURRENT_DATE)::INTEGER AS days_until_expiry,
    s.supplier_name,
    CASE
        WHEN b.exp_date < CURRENT_DATE THEN 'expired'
        WHEN (b.exp_date - CURRENT_DATE) <= 30 THEN 'critical'
        WHEN (b.exp_date - CURRENT_DATE) <= 60 THEN 'warning'
        WHEN (b.exp_date - CURRENT_DATE) <= 90 THEN 'near_expiry'
        ELSE 'ok'
    END AS expiry_status
FROM batches b
JOIN products p ON b.product_id = p.id
JOIN branches br ON b.branch_id = br.id
LEFT JOIN suppliers s ON b.supplier_id = s.id
WHERE b.stock_quantity > 0
  -- Widened to a year so the client can apply a configurable window.
  AND b.exp_date <= CURRENT_DATE + INTERVAL '365 days';

DROP VIEW IF EXISTS tenant_dashboard_metrics CASCADE;
CREATE VIEW tenant_dashboard_metrics AS
SELECT
    t.id AS tenant_id,
    t.business_name,
    COUNT(DISTINCT b.id) AS total_branches,
    COUNT(DISTINCT p.id) AS total_products,
    COALESCE(SUM(CASE WHEN bat.stock_quantity > 0 THEN bat.stock_quantity ELSE 0 END), 0) AS total_stock,
    COUNT(DISTINCT c.id) AS total_customers,
    COUNT(DISTINCT s.id) AS total_sales,
    COALESCE(SUM(s.grand_total), 0) AS total_revenue,
    COUNT(DISTINCT CASE WHEN s.invoice_date >= CURRENT_DATE - INTERVAL '30 days' THEN s.id END) AS sales_last_30_days,
    COALESCE(SUM(CASE WHEN s.invoice_date >= CURRENT_DATE - INTERVAL '30 days' THEN s.grand_total ELSE 0 END), 0) AS revenue_last_30_days
FROM tenants t
LEFT JOIN branches b ON t.id = b.tenant_id AND b.is_active = true
LEFT JOIN products p ON t.id = p.tenant_id
LEFT JOIN batches bat ON p.id = bat.product_id
LEFT JOIN customers c ON t.id = c.tenant_id
LEFT JOIN sales s ON t.id = s.tenant_id
WHERE t.is_active = true
GROUP BY t.id, t.business_name;

-- Views default to running with the owner's rights, which would bypass RLS.
-- security_invoker makes the caller's policies apply (PostgreSQL 15+).
DO $$
BEGIN
    EXECUTE 'ALTER VIEW near_expiry_stock SET (security_invoker = true)';
    EXECUTE 'ALTER VIEW tenant_dashboard_metrics SET (security_invoker = true)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'security_invoker unavailable on this PostgreSQL version; views run as owner and MUST be filtered by tenant_id in the client';
END $$;

GRANT SELECT ON near_expiry_stock TO authenticated;
GRANT SELECT ON tenant_dashboard_metrics TO authenticated;

-- =====================================================
-- 10. COMMENTS
-- =====================================================
COMMENT ON TABLE pricing_plans IS 'Flexible pricing plans for SaaS subscriptions (world readable)';
COMMENT ON TABLE demo_requests IS 'Demo request leads; insert-only for anonymous visitors';
COMMENT ON TABLE pharmacists IS 'Tenant-scoped pharmacists with salted PIN hashes for Schedule H authorisation';
COMMENT ON COLUMN pharmacists.pin_hash IS 'SHA-256 hash of PIN + pin_salt; plaintext PINs are never stored';
COMMENT ON VIEW near_expiry_stock IS 'Stock expiring within 365 days with days_until_expiry for client-side windowing';
COMMENT ON VIEW tenant_dashboard_metrics IS 'Pre-calculated metrics for tenant dashboards';
COMMENT ON FUNCTION set_tenant_context(UUID) IS 'Sets the session tenant override used by RLS policies';
COMMENT ON FUNCTION current_tenant_context() IS 'Resolves the caller tenant from session override or the users table';
COMMENT ON FUNCTION tenant_access_allowed(UUID) IS 'RLS predicate: true for super admins or the caller own tenant';
COMMENT ON FUNCTION update_updated_at_column() IS 'Automatically updates updated_at timestamp on row updates';
