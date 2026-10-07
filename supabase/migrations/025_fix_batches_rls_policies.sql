-- =====================================================
-- Fix: Add missing RLS policies for batches table
-- =====================================================
-- Migration 007 dropped batch RLS policies but never recreated them
-- This blocks all Business Admin INSERT/UPDATE on batches
-- Products save but batches don't = medicines appear with no stock

-- Batches: Tenant isolation (INSERT, SELECT, UPDATE, DELETE)
DROP POLICY IF EXISTS "Tenant isolation on batches" ON batches;
CREATE POLICY "Tenant isolation on batches"
ON batches FOR ALL
USING (user_has_tenant_access(tenant_id))
WITH CHECK (user_has_tenant_access(tenant_id));

COMMENT ON POLICY "Tenant isolation on batches" ON batches IS
    'Users can only access batches for tenants they belong to (via user_metadata.tenant_id)';

-- =====================================================
-- Verify RLS is enabled
-- =====================================================
-- Ensure RLS is enabled on batches table
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- This fixes the missing batch RLS policies so Business Admins can:
-- ✅ INSERT batches for their tenant
-- ✅ SELECT batches for their tenant
-- ✅ UPDATE batches for their tenant
-- ✅ DELETE batches for their tenant
-- 
-- Root cause: Migration 007 dropped old policies but forgot to recreate them
-- Impact: Products saved successfully but batches silently failed RLS check
-- Result: Medicines appeared in database with 0 stock, filtered out of UI
-- =====================================================
