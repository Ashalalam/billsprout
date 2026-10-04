-- ============================================================================
-- Migration: 018_fix_tenant_registration_rls.sql
-- Description: Fix RLS policies to allow business registration
-- Created: 2026-10-04
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- Problem: Users cannot register because tenants table RLS blocks INSERT
-- Solution: Allow authenticated users to create tenants during registration
-- ══════════════════════════════════════════════════════════════════════════

-- Drop the restrictive policy that only allows super admins
DROP POLICY IF EXISTS "Super admins can insert tenants" ON public.tenants;

-- New policy: Allow authenticated users to insert tenants
-- This enables self-service business registration
CREATE POLICY "authenticated_users_can_create_tenant" ON public.tenants
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    -- User can only create a tenant using their own auth.uid() as tenant_id
    id = auth.uid()
  );

-- Keep the super admin access for management
CREATE POLICY "super_admin_full_tenant_access" ON public.tenants
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- Users can view their own tenant
CREATE POLICY "users_view_own_tenant" ON public.tenants
  FOR SELECT
  USING (
    id IN (
      SELECT tenant_id FROM public.users WHERE users.id = auth.uid()
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- Fix users table RLS for registration
-- ══════════════════════════════════════════════════════════════════════════

-- Drop existing restrictive INSERT policy on users if it exists
DROP POLICY IF EXISTS "Super admins can insert users" ON public.users;
DROP POLICY IF EXISTS "Business admins can create users" ON public.users;

-- Allow authenticated users to create their own user record during registration
CREATE POLICY "authenticated_users_can_create_own_user" ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User can only create a user record for themselves
    id = auth.uid()
  );

-- Business admins can create users for their tenant
CREATE POLICY "business_admins_can_create_tenant_users" ON public.users
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users existing
      WHERE existing.id = auth.uid() 
        AND existing.role = 'business_admin'
        AND existing.tenant_id = tenant_id
    )
  );

-- Super admin full access
CREATE POLICY "super_admin_full_user_access" ON public.users
  FOR ALL
  USING (
    role = 'super_admin' OR
    EXISTS (
      SELECT 1 FROM public.users existing
      WHERE existing.id = auth.uid() AND existing.role = 'super_admin'
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- Fix branches table RLS for registration
-- ══════════════════════════════════════════════════════════════════════════

-- Allow authenticated users to create branches for their tenant during registration
DROP POLICY IF EXISTS "Business admins can create branches" ON public.branches;

CREATE POLICY "authenticated_users_can_create_tenant_branches" ON public.branches
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User can create branches for their own tenant
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE users.id = auth.uid()
    )
    OR
    -- Or if they are creating the first branch during registration
    tenant_id = auth.uid()
  );

-- Business admins can manage branches in their tenant
CREATE POLICY "business_admins_manage_tenant_branches" ON public.branches
  FOR ALL
  USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('business_admin', 'super_admin')
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- Verification
-- ══════════════════════════════════════════════════════════════════════════

-- Check policies on tenants table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'tenants'
ORDER BY policyname;

-- Check policies on users table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;

-- Check policies on branches table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'branches'
ORDER BY policyname;

-- ============================================================================
-- Migration complete - Business registration should now work!
-- ============================================================================
