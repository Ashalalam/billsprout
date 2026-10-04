-- ============================================================================
-- Migration: 015_create_test_users.sql
-- Description: Create test users for security testing
-- Created: 2025-01-XX
-- ============================================================================
--
-- Purpose:
-- - Create test users for each role (super_admin, business_admin, customer)
-- - Set up two test tenants (Pharmacy 1, Pharmacy 2)
-- - Enable immediate testing of authentication and authorization
--
-- Test Credentials:
-- - super@test.com / SuperTest123!
-- - admin@pharmacy1.com / Pharmacy1Admin!
-- - admin@pharmacy2.com / Pharmacy2Admin!
-- - customer@test.com / CustomerTest123!
--
-- IMPORTANT:
-- - These are TEST USERS ONLY - delete or disable in production
-- - Passwords are intentionally simple for testing
-- - Change all passwords before production deployment
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- Create test tenants
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO public.tenants (id, name, subscription_status, is_active, created_at)
VALUES 
  ('tenant_test_1', 'Test Pharmacy 1', 'active', true, NOW()),
  ('tenant_test_2', 'Test Pharmacy 2', 'active', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────
-- Create test branches
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO public.branches (id, tenant_id, name, is_active, created_at)
VALUES 
  ('branch_test_1', 'tenant_test_1', 'Main Branch - Pharmacy 1', true, NOW()),
  ('branch_test_2', 'tenant_test_2', 'Main Branch - Pharmacy 2', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────
-- NOTE: Create users in Supabase Auth Dashboard or via API
-- ──────────────────────────────────────────────────────────────────────────
--
-- These users must be created in auth.users table first (via Supabase Dashboard)
-- Then the corresponding entries in public.users will link them with roles/tenants
--
-- Manual Steps Required:
--
-- 1. Go to Supabase Dashboard → Authentication → Users
-- 2. Click "Add User" for each:
--
--    User 1: Super Admin
--    - Email: super@test.com
--    - Password: SuperTest123!
--    - Auto Confirm: Yes
--
--    User 2: Business Admin - Pharmacy 1
--    - Email: admin@pharmacy1.com
--    - Password: Pharmacy1Admin!
--    - Auto Confirm: Yes
--
--    User 3: Business Admin - Pharmacy 2
--    - Email: admin@pharmacy2.com
--    - Password: Pharmacy2Admin!
--    - Auto Confirm: Yes
--
--    User 4: Customer
--    - Email: customer@test.com
--    - Password: CustomerTest123!
--    - Auto Confirm: Yes
--
-- 3. After creating users in Auth, get their UUIDs
-- 4. Update the INSERT statements below with actual UUIDs
-- 5. Run this migration
--
-- ──────────────────────────────────────────────────────────────────────────

-- ──────────────────────────────────────────────────────────────────────────
-- Create public.users entries (UPDATE UUIDs after creating auth users)
-- ──────────────────────────────────────────────────────────────────────────

-- IMPORTANT: Replace 'UUID_FROM_AUTH_USER_1' etc. with actual UUIDs from auth.users

-- Super Admin (no tenant)
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  is_active,
  created_at
)
VALUES (
  'UUID_FROM_AUTH_USER_1',  -- ⚠️ REPLACE WITH ACTUAL UUID
  NULL,
  'Super Admin Test',
  'super@test.com',
  '+1234567890',
  'super_admin',
  true,
  NOW()
)
ON CONFLICT (id) 
DO UPDATE SET 
  role = 'super_admin',
  is_active = true;

-- Business Admin - Pharmacy 1
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  license_no,
  is_active,
  created_at
)
VALUES (
  'UUID_FROM_AUTH_USER_2',  -- ⚠️ REPLACE WITH ACTUAL UUID
  'tenant_test_1',
  'Admin One',
  'admin@pharmacy1.com',
  '+1234567891',
  'business_admin',
  'PHARM-TEST-001',
  true,
  NOW()
)
ON CONFLICT (id) 
DO UPDATE SET 
  role = 'business_admin',
  tenant_id = 'tenant_test_1',
  is_active = true;

-- Business Admin - Pharmacy 2
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  license_no,
  is_active,
  created_at
)
VALUES (
  'UUID_FROM_AUTH_USER_3',  -- ⚠️ REPLACE WITH ACTUAL UUID
  'tenant_test_2',
  'Admin Two',
  'admin@pharmacy2.com',
  '+1234567892',
  'business_admin',
  'PHARM-TEST-002',
  true,
  NOW()
)
ON CONFLICT (id) 
DO UPDATE SET 
  role = 'business_admin',
  tenant_id = 'tenant_test_2',
  is_active = true;

-- Customer
INSERT INTO public.users (
  id,
  tenant_id,
  name,
  email,
  phone,
  role,
  is_active,
  created_at
)
VALUES (
  'UUID_FROM_AUTH_USER_4',  -- ⚠️ REPLACE WITH ACTUAL UUID
  NULL,
  'Test Customer',
  'customer@test.com',
  '+1234567893',
  'customer',
  true,
  NOW()
)
ON CONFLICT (id) 
DO UPDATE SET 
  role = 'customer',
  is_active = true;

-- ──────────────────────────────────────────────────────────────────────────
-- Verification Queries
-- ──────────────────────────────────────────────────────────────────────────

-- Check tenants created
SELECT id, name, subscription_status, is_active 
FROM public.tenants 
WHERE id LIKE 'tenant_test_%';

-- Check branches created
SELECT id, tenant_id, name, is_active 
FROM public.branches 
WHERE id LIKE 'branch_test_%';

-- Check public.users entries (will show after UUIDs updated)
SELECT id, email, role, tenant_id, is_active 
FROM public.users 
WHERE email LIKE '%@test.com' OR email LIKE '%@pharmacy%.com'
ORDER BY role;

-- ──────────────────────────────────────────────────────────────────────────
-- Test User Summary
-- ──────────────────────────────────────────────────────────────────────────

/*

Test Users Created:

┌─────────────────────────┬──────────────────────┬─────────────────┬──────────────┐
│ Email                   │ Password             │ Role            │ Tenant       │
├─────────────────────────┼──────────────────────┼─────────────────┼──────────────┤
│ super@test.com          │ SuperTest123!        │ super_admin     │ (none)       │
│ admin@pharmacy1.com     │ Pharmacy1Admin!      │ business_admin  │ tenant_1     │
│ admin@pharmacy2.com     │ Pharmacy2Admin!      │ business_admin  │ tenant_2     │
│ customer@test.com       │ CustomerTest123!     │ customer        │ (none)       │
└─────────────────────────┴──────────────────────┴─────────────────┴──────────────┘

Usage:
1. Create users in Supabase Auth Dashboard with emails and passwords above
2. Get UUIDs from auth.users table
3. Update this migration file with actual UUIDs
4. Run migration to create public.users entries
5. Test login with each user

Security Testing:
- super@test.com can access all routes
- admin@pharmacy1.com can only access tenant_1 data
- admin@pharmacy2.com can only access tenant_2 data
- customer@test.com can only access customer portal

*/

-- ============================================================================
-- End of migration
-- ============================================================================
