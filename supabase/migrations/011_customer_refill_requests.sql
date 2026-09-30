-- =====================================================
-- Customer chronic refill requests
-- =====================================================
-- The customer portal offers a "request refill" action for chronic medicines.
-- Previously that button only called notifyListeners(), so nothing was ever
-- recorded and no member of staff could act on it. This gives the request a
-- real home, tenant-scoped like every other business table.
--
-- Idempotent: safe to re-run.
-- =====================================================

CREATE TABLE IF NOT EXISTS customer_refill_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    medicine_name VARCHAR(500) NOT NULL,
    quantity INTEGER,
    notes TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'requested'
        CHECK (status IN ('requested', 'contacted', 'fulfilled', 'cancelled')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Guarded column adds for databases where an earlier version exists.
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN
        SELECT * FROM (VALUES
            ('quantity',     'INTEGER'),
            ('notes',        'TEXT'),
            ('requested_at', 'TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP'),
            ('fulfilled_at', 'TIMESTAMP WITH TIME ZONE'),
            ('updated_at',   'TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP')
        ) AS v(name, definition)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = 'public'
                         AND table_name = 'customer_refill_requests'
                         AND column_name = col.name) THEN
            EXECUTE format('ALTER TABLE customer_refill_requests ADD COLUMN %I %s',
                           col.name, col.definition);
        END IF;
    END LOOP;
END $$;

ALTER TABLE customer_refill_requests ENABLE ROW LEVEL SECURITY;

-- Same single-predicate tenant gate used by every other business table.
DROP POLICY IF EXISTS "Tenant isolation on customer_refill_requests"
    ON customer_refill_requests;
CREATE POLICY "Tenant isolation on customer_refill_requests"
ON customer_refill_requests FOR ALL
USING (tenant_access_allowed(tenant_id))
WITH CHECK (tenant_access_allowed(tenant_id));

GRANT ALL ON customer_refill_requests TO authenticated;

CREATE INDEX IF NOT EXISTS idx_refill_requests_tenant_status
    ON customer_refill_requests(tenant_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_refill_requests_customer
    ON customer_refill_requests(customer_id, requested_at DESC);

DROP TRIGGER IF EXISTS set_updated_at_customer_refill_requests
    ON customer_refill_requests;
CREATE TRIGGER set_updated_at_customer_refill_requests
    BEFORE UPDATE ON customer_refill_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE customer_refill_requests IS
    'Chronic medicine refill requests raised from the customer portal';
