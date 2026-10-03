-- =====================================================
-- Migration: Sync User Tenant Metadata
-- =====================================================
-- Created: 2026-03-10
-- Description: Ensures tenant_id and branch_id from public.users
--              are automatically synced to auth.users metadata for RLS
-- =====================================================

-- =====================================================
-- 1. FUNCTION TO SYNC USER METADATA TO AUTH
-- =====================================================
-- This function updates auth.users.raw_user_meta_data with tenant_id
-- and branch_id whenever the public.users record is created or updated
CREATE OR REPLACE FUNCTION sync_user_metadata_to_auth()
RETURNS TRIGGER AS $$
DECLARE
    default_branch UUID;
BEGIN
    -- If tenant_id is set, sync it to auth metadata
    IF NEW.tenant_id IS NOT NULL THEN
        -- Get the first active branch for this tenant as default
        SELECT id INTO default_branch
        FROM branches
        WHERE tenant_id = NEW.tenant_id
          AND is_active = true
        ORDER BY created_at ASC
        LIMIT 1;

        -- Update auth.users metadata with tenant and branch info
        UPDATE auth.users
        SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
            'tenant_id', NEW.tenant_id::TEXT,
            'branch_id', COALESCE(default_branch::TEXT, NULL),
            'name', NEW.name,
            'phone', NEW.phone,
            'role', NEW.role,
            'licenseNo', NEW.license_no
        )
        WHERE id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. TRIGGER ON USERS TABLE
-- =====================================================
DROP TRIGGER IF EXISTS sync_metadata_after_user_change ON users;
CREATE TRIGGER sync_metadata_after_user_change
    AFTER INSERT OR UPDATE OF tenant_id, name, phone, role, license_no
    ON users
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_metadata_to_auth();

-- =====================================================
-- 3. FUNCTION TO ASSIGN DEFAULT TENANT FOR NEW USERS
-- =====================================================
-- This function can be called to assign a demo/default tenant
-- to users who don't have one yet
CREATE OR REPLACE FUNCTION assign_default_tenant_to_user(user_id UUID)
RETURNS void AS $$
DECLARE
    demo_tenant_id UUID;
    demo_branch_id UUID;
BEGIN
    -- Find or create a "Demo Tenant" for testing purposes
    SELECT id INTO demo_tenant_id
    FROM tenants
    WHERE business_name = 'Demo Tenant'
    LIMIT 1;

    -- If no demo tenant exists, create one
    IF demo_tenant_id IS NULL THEN
        INSERT INTO tenants (business_name, gstin, contact_email, contact_phone, is_active)
        VALUES ('Demo Tenant', 'DEMO000000', 'demo@lifesprout.com', '0000000000', true)
        RETURNING id INTO demo_tenant_id;

        -- Create a default branch for the demo tenant
        INSERT INTO branches (tenant_id, branch_name, branch_code, address, city, state, pincode, is_active)
        VALUES (demo_tenant_id, 'Main Branch', 'MAIN', 'Demo Address', 'Demo City', 'Demo State', '000000', true)
        RETURNING id INTO demo_branch_id;
    ELSE
        -- Get the first active branch
        SELECT id INTO demo_branch_id
        FROM branches
        WHERE tenant_id = demo_tenant_id
          AND is_active = true
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    -- Update the user's tenant_id
    UPDATE users
    SET tenant_id = demo_tenant_id
    WHERE id = user_id AND tenant_id IS NULL;

    -- The trigger will automatically sync to auth.users metadata
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. BACKFILL EXISTING USERS' METADATA
-- =====================================================
-- Sync all existing users' tenant_id to their auth metadata
DO $$
DECLARE
    user_record RECORD;
    default_branch UUID;
BEGIN
    FOR user_record IN
        SELECT u.id, u.tenant_id, u.name, u.phone, u.role, u.license_no
        FROM users u
        WHERE u.tenant_id IS NOT NULL
    LOOP
        -- Get the first active branch for this user's tenant
        SELECT id INTO default_branch
        FROM branches
        WHERE tenant_id = user_record.tenant_id
          AND is_active = true
        ORDER BY created_at ASC
        LIMIT 1;

        -- Update auth metadata
        UPDATE auth.users
        SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
            'tenant_id', user_record.tenant_id::TEXT,
            'branch_id', COALESCE(default_branch::TEXT, NULL),
            'name', user_record.name,
            'phone', COALESCE(user_record.phone, ''),
            'role', user_record.role,
            'licenseNo', COALESCE(user_record.license_no, '')
        )
        WHERE id = user_record.id;

        RAISE NOTICE 'Synced metadata for user %', user_record.id;
    END LOOP;
END $$;

-- =====================================================
-- 5. FUNCTION TO CREATE USER WITH TENANT
-- =====================================================
-- Helper function for creating users with proper tenant context
-- Can be called from application code after auth.signUp
CREATE OR REPLACE FUNCTION create_user_with_tenant(
    p_user_id UUID,
    p_tenant_id UUID,
    p_name VARCHAR,
    p_email VARCHAR,
    p_phone VARCHAR,
    p_role VARCHAR,
    p_license_no VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    -- Insert into public.users table
    INSERT INTO users (id, tenant_id, name, email, phone, role, license_no, is_active)
    VALUES (p_user_id, p_tenant_id, p_name, p_email, p_phone, p_role, p_license_no, true)
    RETURNING id INTO new_user_id;

    -- The trigger will automatically sync to auth.users metadata

    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. COMMENTS
-- =====================================================
COMMENT ON FUNCTION sync_user_metadata_to_auth() IS 'Automatically syncs public.users tenant_id and other fields to auth.users metadata for RLS';
COMMENT ON FUNCTION assign_default_tenant_to_user(UUID) IS 'Assigns a demo tenant to users without tenant_id';
COMMENT ON FUNCTION create_user_with_tenant(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS 'Helper to create user with tenant context in both public.users and auth.users';
