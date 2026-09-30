-- =====================================================
-- BillSprout/LifeSprout ERP - Row Level Security Policies
-- =====================================================
-- This migration enables RLS and creates policies for tenant isolation
-- Created: 2024
-- Description: Comprehensive RLS policies to ensure data security and multi-tenant isolation

-- =====================================================
-- HELPER FUNCTION: Get Current User's Tenant ID
-- =====================================================
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
    -- First try to get from app context (set by application)
    BEGIN
        RETURN current_setting('app.tenant_id')::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            -- Fall back to user's tenant_id from users table
            RETURN (SELECT tenant_id FROM users WHERE id = auth.uid());
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- HELPER FUNCTION: Check if User is Super Admin
-- =====================================================
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (SELECT role FROM users WHERE id = auth.uid()) = 'super_admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- HELPER FUNCTION: Check if User Belongs to Tenant
-- =====================================================
CREATE OR REPLACE FUNCTION user_has_tenant_access(check_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Super admins have access to all tenants
    IF is_super_admin() THEN
        RETURN true;
    END IF;
    
    -- Regular users can only access their own tenant
    RETURN (SELECT tenant_id FROM users WHERE id = auth.uid()) = check_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 1. TENANTS TABLE RLS
-- =====================================================
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- Super admins can view all tenants
DROP POLICY IF EXISTS "Super admins can view all tenants" ON tenants;
CREATE POLICY "Super admins can view all tenants"
ON tenants FOR SELECT
USING (is_super_admin());

-- Super admins can insert tenants
DROP POLICY IF EXISTS "Super admins can insert tenants" ON tenants;
CREATE POLICY "Super admins can insert tenants"
ON tenants FOR INSERT
WITH CHECK (is_super_admin());

-- Users can view their own tenant
DROP POLICY IF EXISTS "Users can view their own tenant" ON tenants;
CREATE POLICY "Users can view their own tenant"
ON tenants FOR SELECT
USING (id = get_current_tenant_id());

-- Business admins can update their own tenant
DROP POLICY IF EXISTS "Business admins can update their own tenant" ON tenants;
CREATE POLICY "Business admins can update their own tenant"
ON tenants FOR UPDATE
USING (
    id = get_current_tenant_id() 
    AND (SELECT role FROM users WHERE id = auth.uid()) IN ('business_admin', 'super_admin')
);

-- =====================================================
-- 2. BRANCHES TABLE RLS
-- =====================================================
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's branches" ON branches;
CREATE POLICY "Users can access their tenant's branches"
ON branches FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert branches for their tenant" ON branches;
CREATE POLICY "Users can insert branches for their tenant"
ON branches FOR INSERT
WITH CHECK (
    user_has_tenant_access(tenant_id)
    AND (SELECT role FROM users WHERE id = auth.uid()) IN ('business_admin', 'super_admin')
);

-- =====================================================
-- 3. USERS TABLE RLS
-- =====================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Super admins can see all users
DROP POLICY IF EXISTS "Super admins can view all users" ON users;
CREATE POLICY "Super admins can view all users"
ON users FOR SELECT
USING (is_super_admin());

-- Users can view users from their tenant
DROP POLICY IF EXISTS "Users can view their tenant's users" ON users;
CREATE POLICY "Users can view their tenant's users"
ON users FOR SELECT
USING (user_has_tenant_access(tenant_id) OR id = auth.uid());

-- Users can view and update their own profile
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile"
ON users FOR SELECT
USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE
USING (id = auth.uid());

-- Business admins can insert users for their tenant
DROP POLICY IF EXISTS "Business admins can insert users" ON users;
CREATE POLICY "Business admins can insert users"
ON users FOR INSERT
WITH CHECK (
    user_has_tenant_access(tenant_id)
    AND (SELECT role FROM users WHERE id = auth.uid()) IN ('business_admin', 'super_admin')
);

-- Business admins can update users in their tenant
DROP POLICY IF EXISTS "Business admins can update users" ON users;
CREATE POLICY "Business admins can update users"
ON users FOR UPDATE
USING (
    user_has_tenant_access(tenant_id)
    AND (SELECT role FROM users WHERE id = auth.uid()) IN ('business_admin', 'super_admin')
);

-- =====================================================
-- 4. SUPPLIERS TABLE RLS
-- =====================================================
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's suppliers" ON suppliers;
CREATE POLICY "Users can access their tenant's suppliers"
ON suppliers FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert suppliers for their tenant" ON suppliers;
CREATE POLICY "Users can insert suppliers for their tenant"
ON suppliers FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 5. CUSTOMERS TABLE RLS
-- =====================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's customers" ON customers;
CREATE POLICY "Users can access their tenant's customers"
ON customers FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert customers for their tenant" ON customers;
CREATE POLICY "Users can insert customers for their tenant"
ON customers FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 6. PRODUCTS TABLE RLS
-- =====================================================
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's products" ON products;
CREATE POLICY "Users can access their tenant's products"
ON products FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert products for their tenant" ON products;
CREATE POLICY "Users can insert products for their tenant"
ON products FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 7. BATCHES TABLE RLS
-- =====================================================
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's batches" ON batches;
CREATE POLICY "Users can access their tenant's batches"
ON batches FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert batches for their tenant" ON batches;
CREATE POLICY "Users can insert batches for their tenant"
ON batches FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 8. PRESCRIPTIONS TABLE RLS
-- =====================================================
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's prescriptions" ON prescriptions;
CREATE POLICY "Users can access their tenant's prescriptions"
ON prescriptions FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert prescriptions for their tenant" ON prescriptions;
CREATE POLICY "Users can insert prescriptions for their tenant"
ON prescriptions FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 9. SALES TABLE RLS
-- =====================================================
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's sales" ON sales;
CREATE POLICY "Users can access their tenant's sales"
ON sales FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert sales for their tenant" ON sales;
CREATE POLICY "Users can insert sales for their tenant"
ON sales FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 10. SALE_ITEMS TABLE RLS
-- =====================================================
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access sale items from their tenant's sales" ON sale_items;
CREATE POLICY "Users can access sale items from their tenant's sales"
ON sale_items FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM sales 
        WHERE sales.id = sale_items.sale_id 
        AND user_has_tenant_access(sales.tenant_id)
    )
);

DROP POLICY IF EXISTS "Users can insert sale items for their tenant's sales" ON sale_items;
CREATE POLICY "Users can insert sale items for their tenant's sales"
ON sale_items FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM sales 
        WHERE sales.id = sale_items.sale_id 
        AND user_has_tenant_access(sales.tenant_id)
    )
);

-- =====================================================
-- 11. PURCHASES TABLE RLS
-- =====================================================
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's purchases" ON purchases;
CREATE POLICY "Users can access their tenant's purchases"
ON purchases FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert purchases for their tenant" ON purchases;
CREATE POLICY "Users can insert purchases for their tenant"
ON purchases FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 12. PURCHASE_ITEMS TABLE RLS
-- =====================================================
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access purchase items from their tenant's purchases" ON purchase_items;
CREATE POLICY "Users can access purchase items from their tenant's purchases"
ON purchase_items FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM purchases 
        WHERE purchases.id = purchase_items.purchase_id 
        AND user_has_tenant_access(purchases.tenant_id)
    )
);

DROP POLICY IF EXISTS "Users can insert purchase items for their tenant's purchases" ON purchase_items;
CREATE POLICY "Users can insert purchase items for their tenant's purchases"
ON purchase_items FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM purchases 
        WHERE purchases.id = purchase_items.purchase_id 
        AND user_has_tenant_access(purchases.tenant_id)
    )
);

-- =====================================================
-- 13. RESTRICTED_DRUG_LOGS TABLE RLS
-- =====================================================
ALTER TABLE restricted_drug_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's restricted drug logs" ON restricted_drug_logs;
CREATE POLICY "Users can access their tenant's restricted drug logs"
ON restricted_drug_logs FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert restricted drug logs for their tenant" ON restricted_drug_logs;
CREATE POLICY "Users can insert restricted drug logs for their tenant"
ON restricted_drug_logs FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 14. STOCK_MOVEMENTS TABLE RLS
-- =====================================================
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's stock movements" ON stock_movements;
CREATE POLICY "Users can access their tenant's stock movements"
ON stock_movements FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert stock movements for their tenant" ON stock_movements;
CREATE POLICY "Users can insert stock movements for their tenant"
ON stock_movements FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 15. STOCK_TRANSFERS TABLE RLS
-- =====================================================
ALTER TABLE stock_transfers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their tenant's stock transfers" ON stock_transfers;
CREATE POLICY "Users can access their tenant's stock transfers"
ON stock_transfers FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert stock transfers for their tenant" ON stock_transfers;
CREATE POLICY "Users can insert stock transfers for their tenant"
ON stock_transfers FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- =====================================================
-- 16. DEMO_REQUESTS TABLE RLS
-- =====================================================
ALTER TABLE demo_requests ENABLE ROW LEVEL SECURITY;

-- Demo requests are public for INSERT (from marketing website)
DROP POLICY IF EXISTS "Anyone can submit demo requests" ON demo_requests;
CREATE POLICY "Anyone can submit demo requests"
ON demo_requests FOR INSERT
WITH CHECK (true);

-- Only super admins can view and manage demo requests
DROP POLICY IF EXISTS "Super admins can view all demo requests" ON demo_requests;
CREATE POLICY "Super admins can view all demo requests"
ON demo_requests FOR SELECT
USING (is_super_admin());

DROP POLICY IF EXISTS "Super admins can update demo requests" ON demo_requests;
CREATE POLICY "Super admins can update demo requests"
ON demo_requests FOR UPDATE
USING (is_super_admin());

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
-- Grant authenticated users access to tables
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant anonymous users limited access (for demo requests)
GRANT INSERT ON demo_requests TO anon;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION get_current_tenant_id() IS 'Returns the tenant_id of the currently authenticated user';
COMMENT ON FUNCTION is_super_admin() IS 'Checks if the current user has super_admin role';
COMMENT ON FUNCTION user_has_tenant_access(UUID) IS 'Checks if the current user has access to a specific tenant';
