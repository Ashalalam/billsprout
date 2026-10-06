-- ============================================================================
-- Fix users table constraint to allow NULL tenant_id for customers
-- ============================================================================
-- The existing constraint only allows NULL tenant_id for super_admin
-- but customers also don't have a tenant_id since they access multiple pharmacies
-- ============================================================================

-- Drop the existing restrictive constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_tenant_id_required;

-- Add new constraint that allows NULL tenant_id for super_admin AND customer roles
ALTER TABLE users 
ADD CONSTRAINT users_tenant_id_required
CHECK (tenant_id IS NOT NULL OR role IN ('super_admin', 'customer'));

-- Update comment to explain the new logic
COMMENT ON CONSTRAINT users_tenant_id_required ON users IS 
'Ensures all users except super_admin and customer have a tenant_id assigned. Customers access multiple tenants and super_admins manage all tenants.';
