-- ============================================================================
-- Migration: 016_setup_existing_users.sql
-- Description: Set up roles and tenants for existing users
-- Created: 2025-01-XX
-- ============================================================================
--
-- Purpose:
-- - Configure existing authenticated users with proper roles
-- - Create tenant records for each business
-- - Link users to their respective tenants
-- - Enable immediate security testing with existing credentials
--
-- Existing Users:
-- - admin@lifesproutcare.com (Business Admin - Lifesprout Care)
-- - superadmin@lifesprout.com (Super Admin)
-- - priya@medicare.com (Business Admin - Medicare)
-- - customer@lifesprout.com (Customer)
--
-- ⚠️ IMPORTANT: 
-- - All passwords are currently "password123" - CHANGE IN PRODUCTION
-- - Update UUIDs in this migration with actual values from auth.users
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- Step 1: Create tenant records for the two businesses
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO public.tenants (id, name, subscription_status, is_active, created_at, updated_at)
VALUES 
  ('tenant_lifesprout', 'Lifesprout Care Pharmacy', 'active', true, NOW(), NOW()),
  ('tenant_medicare', 'Medicare Pharmacy', 'active', true, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  subscription_status = EXCLUDED.subscription_status,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- ──────────────────────────────────────────────────────────────────────────
-- Step 2: Create default branches for each tenant
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO public.branches (id, tenant_id, name, address, is_active, created_at, updated_at)
VALUES 
  (
    'branch_lifesprout_main',
    'tenant_lifesprout',
    'Lifesprout Care - Main Branch',
    'Main Location',
    true,
    NOW(),
    NOW()
  ),
  (
    'branch_medicare_main',
    'tenant_medicare',
    'Medicare Pharmacy - Main Branch',
    'Main Location',
    true,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- ──────────────────────────────────────────────────────────────────────────
-- Step 3: Get UUIDs from auth.users
-- ──────────────────────────────────────────────────────────────────────────
--
-- Run this query first to get the UUIDs:
--
-- SELECT id, email, created_at 
-- FROM auth.users 
-- WHERE email IN (
--   'admin@lifesproutcare.com',
--   'superadmin@lifesprout.com',
--   'priya@medicare.com',
--   'customer@lifesprout.com'
-- )
-- ORDER BY email;
--
-- Then replace the UUIDs below with the actual values
-- ──────────────────────────────────────────────────────────────────────────

-- ──────────────────────────────────────────────────────────────────────────
-- Step 4: Create/Update public.users entries
-- ──────────────────────────────────────────────────────────────────────────

-- User 1: Business Admin - Lifesprout Care
-- Email: admin@lifesproutcare.com
-- Password: password123 (⚠️ CHANGE IN PRODUCTION)
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  license_no,
  is_active,
  created_at,
  updated_at
)
VALUES (
  'UUID_ADMIN_LIFESPROUT',  -- ⚠️ REPLACE WITH ACTUAL UUID
  'tenant_lifesprout',
  'Lifesprout Admin',
  'admin@lifesproutcare.com',
  '+1234567890',
  'business_admin',
  'PHARM-LSC-001',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  tenant_id = 'tenant_lifesprout',
  role = 'business_admin',
  is_active = true,
  updated_at = NOW();

-- User 2: Super Admin
-- Email: superadmin@lifesprout.com
-- Password: password123 (⚠️ CHANGE IN PRODUCTION)
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  is_active,
  created_at,
  updated_at
)
VALUES (
  'UUID_SUPERADMIN',  -- ⚠️ REPLACE WITH ACTUAL UUID
  NULL,  -- Super admins have no tenant (can access all)
  'Super Administrator',
  'superadmin@lifesprout.com',
  '+1234567891',
  'super_admin',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  tenant_id = NULL,
  role = 'super_admin',
  is_active = true,
  updated_at = NOW();

-- User 3: Business Admin - Medicare
-- Email: priya@medicare.com
-- Password: password123 (⚠️ CHANGE IN PRODUCTION)
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  license_no,
  is_active,
  created_at,
  updated_at
)
VALUES (
  'UUID_PRIYA_MEDICARE',  -- ⚠️ REPLACE WITH ACTUAL UUID
  'tenant_medicare',
  'Priya',
  'priya@medicare.com',
  '+1234567892',
  'business_admin',
  'PHARM-MED-001',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  tenant_id = 'tenant_medicare',
  role = 'business_admin',
  is_active = true,
  updated_at = NOW();

-- User 4: Customer
-- Email: customer@lifesprout.com
-- Password: password123 (⚠️ CHANGE IN PRODUCTION)
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  is_active,
  created_at,
  updated_at
)
VALUES (
  'UUID_CUSTOMER',  -- ⚠️ REPLACE WITH ACTUAL UUID
  NULL,  -- Customers not tied to specific tenant
  'Test Customer',
  'customer@lifesprout.com',
  '+1234567893',
  'customer',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  role = 'customer',
  is_active = true,
  updated_at = NOW();

-- ──────────────────────────────────────────────────────────────────────────
-- Step 5: Create a customer record for the customer user (optional)
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO public.customers (
  id,
  tenant_id,
  name,
  email,
  phone,
  created_at,
  updated_at
)
VALUES (
  'cust_lifesprout_001',
  NULL,  -- Can be associated with multiple tenants
  'Test Customer',
  'customer@lifesprout.com',
  '+1234567893',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────
-- Verification Queries
-- ──────────────────────────────────────────────────────────────────────────

-- Check tenants created
SELECT 
  id,
  name,
  subscription_status,
  is_active,
  created_at
FROM public.tenants
WHERE id IN ('tenant_lifesprout', 'tenant_medicare');

-- Check branches created
SELECT 
  id,
  tenant_id,
  name,
  is_active
FROM public.branches
WHERE tenant_id IN ('tenant_lifesprout', 'tenant_medicare');

-- Check users configured correctly
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.tenant_id,
  t.name as tenant_name,
  u.is_active
FROM public.users u
LEFT JOIN public.tenants t ON u.tenant_id = t.id
WHERE u.email IN (
  'admin@lifesproutcare.com',
  'superadmin@lifesprout.com',
  'priya@medicare.com',
  'customer@lifesprout.com'
)
ORDER BY 
  CASE u.role
    WHEN 'super_admin' THEN 1
    WHEN 'business_admin' THEN 2
    WHEN 'customer' THEN 3
    ELSE 4
  END,
  u.email;

-- Expected result:
-- ┌─────────────────────────────────┬──────────────────┬──────────────────┬───────────────────┐
-- │ Email                           │ Role             │ Tenant           │ Active            │
-- ├─────────────────────────────────┼──────────────────┼──────────────────┼───────────────────┤
-- │ superadmin@lifesprout.com       │ super_admin      │ (null)           │ true              │
-- │ admin@lifesproutcare.com        │ business_admin   │ tenant_lifesprout│ true              │
-- │ priya@medicare.com              │ business_admin   │ tenant_medicare  │ true              │
-- │ customer@lifesprout.com         │ customer         │ (null)           │ true              │
-- └─────────────────────────────────┴──────────────────┴──────────────────┴───────────────────┘

-- ──────────────────────────────────────────────────────────────────────────
-- Test Queries
-- ──────────────────────────────────────────────────────────────────────────

-- Test 1: Verify super admin has no tenant restriction
SELECT 
  email,
  role,
  tenant_id,
  CASE WHEN tenant_id IS NULL AND role = 'super_admin' 
       THEN '✓ Can access all tenants' 
       ELSE '✗ Should have null tenant_id' 
  END as status
FROM public.users
WHERE email = 'superadmin@lifesprout.com';

-- Test 2: Verify business admins have correct tenants
SELECT 
  email,
  role,
  tenant_id,
  CASE 
    WHEN email = 'admin@lifesproutcare.com' AND tenant_id = 'tenant_lifesprout' 
         THEN '✓ Correct tenant'
    WHEN email = 'priya@medicare.com' AND tenant_id = 'tenant_medicare' 
         THEN '✓ Correct tenant'
    ELSE '✗ Wrong tenant assignment'
  END as status
FROM public.users
WHERE email IN ('admin@lifesproutcare.com', 'priya@medicare.com');

-- Test 3: Verify customer has no tenant restriction
SELECT 
  email,
  role,
  tenant_id,
  CASE WHEN tenant_id IS NULL AND role = 'customer' 
       THEN '✓ Can access multiple tenants' 
       ELSE '✗ Should have null tenant_id' 
  END as status
FROM public.users
WHERE email = 'customer@lifesprout.com';

-- ──────────────────────────────────────────────────────────────────────────
-- Security Test: Simulate RLS Policy Check
-- ──────────────────────────────────────────────────────────────────────────

-- Test that business admin can only see their tenant's data
-- This would be run with actual user context in the application

COMMENT ON TABLE public.users IS 
'After running this migration:
1. Login as admin@lifesproutcare.com → Should see tenant_lifesprout data only
2. Login as priya@medicare.com → Should see tenant_medicare data only
3. Login as superadmin@lifesprout.com → Should see all tenant data
4. Login as customer@lifesprout.com → Should see customer portal';

-- ──────────────────────────────────────────────────────────────────────────
-- User Summary
-- ──────────────────────────────────────────────────────────────────────────

/*

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━┓
┃ Email                       ┃ Password      ┃ Role             ┃ Tenant               ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━┩
│ superadmin@lifesprout.com   │ password123   │ super_admin      │ (all tenants)        │
│ admin@lifesproutcare.com    │ password123   │ business_admin   │ Lifesprout Care      │
│ priya@medicare.com          │ password123   │ business_admin   │ Medicare Pharmacy    │
│ customer@lifesprout.com     │ password123   │ customer         │ (none)               │
└─────────────────────────────┴───────────────┴──────────────────┴──────────────────────┘

SECURITY TESTING:

✅ Super Admin Tests:
   - Can login to super admin dashboard
   - Can access /#/super-admin route
   - Can view both tenant_lifesprout and tenant_medicare data

✅ Business Admin - Lifesprout Tests:
   - Can login to business admin dashboard
   - Cannot access /#/super-admin route (access denied)
   - Can view tenant_lifesprout data ONLY
   - Cannot view tenant_medicare data (RLS blocked)

✅ Business Admin - Medicare Tests:
   - Can login to business admin dashboard
   - Cannot access /#/super-admin route (access denied)
   - Can view tenant_medicare data ONLY
   - Cannot view tenant_lifesprout data (RLS blocked)

✅ Customer Tests:
   - Can login to customer portal
   - Cannot access /#/super-admin or /#/business-admin routes
   - Can view their own orders/prescriptions

⚠️  SECURITY WARNINGS:
   - All passwords are currently "password123"
   - MUST change passwords before production deployment
   - Current passwords are for TESTING ONLY
   - Enable 2FA for admin accounts in production

*/

-- ============================================================================
-- Migration complete - Users ready for security testing
-- ============================================================================
