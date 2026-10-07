-- =====================================================
-- BillSprout - Medicine-Level Scheme/Offer Support
-- Migration 027: Product Schemes (Buy X Get Y Free)
-- =====================================================
-- Created: 2026-10-07
-- Description: Add support for medicine-level promotional schemes
--              e.g., "Buy 10 Strips Get 1 Strip Free"

-- =====================================================
-- 1. PRODUCT_SCHEMES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS product_schemes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    
    -- Scheme configuration
    scheme_type VARCHAR(50) DEFAULT 'buy_x_get_y_free' CHECK (scheme_type IN ('buy_x_get_y_free')),
    buy_quantity INTEGER NOT NULL CHECK (buy_quantity > 0),
    free_quantity INTEGER NOT NULL CHECK (free_quantity > 0),
    scheme_unit VARCHAR(20) NOT NULL CHECK (scheme_unit IN ('strip', 'tablet', 'capsule', 'bottle', 'vial', 'tube', 'sachet', 'unit')),
    
    -- Validity
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,  -- NULL means ongoing/no expiry
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Business rules
    CONSTRAINT valid_date_range CHECK (valid_until IS NULL OR valid_until >= valid_from),
    CONSTRAINT unique_active_scheme_per_product UNIQUE (product_id, is_active, tenant_id)
);

-- =====================================================
-- 2. INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX idx_product_schemes_product_id ON product_schemes(product_id);
CREATE INDEX idx_product_schemes_tenant_id ON product_schemes(tenant_id);
CREATE INDEX idx_product_schemes_active ON product_schemes(is_active) WHERE is_active = true;
CREATE INDEX idx_product_schemes_validity ON product_schemes(valid_from, valid_until) WHERE is_active = true;

-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- =====================================================
ALTER TABLE product_schemes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access schemes for their tenant
CREATE POLICY "Tenant isolation on product_schemes"
    ON product_schemes
    FOR ALL
    USING (user_has_tenant_access(tenant_id))
    WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 4. UPDATED_AT TRIGGER
-- =====================================================
CREATE TRIGGER set_product_schemes_updated_at
    BEFORE UPDATE ON product_schemes
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- =====================================================
-- 5. HELPER FUNCTION: Get Active Scheme for Product
-- =====================================================
CREATE OR REPLACE FUNCTION get_active_scheme_for_product(
    p_product_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    id UUID,
    product_id UUID,
    scheme_type VARCHAR(50),
    buy_quantity INTEGER,
    free_quantity INTEGER,
    scheme_unit VARCHAR(20),
    valid_from DATE,
    valid_until DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ps.id,
        ps.product_id,
        ps.scheme_type,
        ps.buy_quantity,
        ps.free_quantity,
        ps.scheme_unit,
        ps.valid_from,
        ps.valid_until
    FROM product_schemes ps
    WHERE ps.product_id = p_product_id
      AND ps.is_active = true
      AND ps.valid_from <= p_date
      AND (ps.valid_until IS NULL OR ps.valid_until >= p_date)
    ORDER BY ps.created_at DESC
    LIMIT 1;
END;
$$;

-- =====================================================
-- 6. HELPER FUNCTION: Calculate Free Quantity
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_free_quantity(
    p_product_id UUID,
    p_paid_quantity INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_scheme RECORD;
    v_complete_schemes INTEGER;
    v_free_qty INTEGER;
BEGIN
    -- Get active scheme for product
    SELECT * INTO v_scheme
    FROM get_active_scheme_for_product(p_product_id, CURRENT_DATE);
    
    -- If no active scheme, return 0
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Calculate number of complete schemes: floor(paid_quantity / buy_quantity)
    v_complete_schemes := FLOOR(p_paid_quantity::NUMERIC / v_scheme.buy_quantity);
    
    -- Calculate free quantity: complete_schemes * free_quantity
    v_free_qty := v_complete_schemes * v_scheme.free_quantity;
    
    RETURN v_free_qty;
END;
$$;

-- =====================================================
-- 7. COMMENTS
-- =====================================================
COMMENT ON TABLE product_schemes IS 'Medicine-level promotional schemes (e.g., Buy 10 Get 1 Free)';
COMMENT ON COLUMN product_schemes.scheme_type IS 'Type of scheme: buy_x_get_y_free (extensible for future types)';
COMMENT ON COLUMN product_schemes.buy_quantity IS 'Quantity customer must purchase to qualify for scheme';
COMMENT ON COLUMN product_schemes.free_quantity IS 'Quantity customer receives free per complete scheme';
COMMENT ON COLUMN product_schemes.scheme_unit IS 'Unit for scheme calculation (strip, tablet, etc.)';
COMMENT ON COLUMN product_schemes.valid_until IS 'Expiry date for scheme. NULL = ongoing/no expiry';
COMMENT ON FUNCTION get_active_scheme_for_product IS 'Returns the currently active scheme for a product on a given date';
COMMENT ON FUNCTION calculate_free_quantity IS 'Calculates free quantity based on paid quantity and active scheme';
