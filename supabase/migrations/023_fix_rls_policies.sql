-- ============================================================================
-- Migration: 023_fix_rls_policies.sql
-- Description: Fix RLS policies for audit_logs and subscriptions
-- Created: 2026-10-04
-- ============================================================================

-- Allow business_admin to insert audit logs
CREATE POLICY IF NOT EXISTS "business_admin_insert_audit" ON public.audit_logs
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND (role = 'business_admin' OR role = 'super_admin')
    )
  );

-- Allow business_admin to view their tenant's subscription
CREATE POLICY IF NOT EXISTS "business_admin_view_subscription" ON public.subscriptions
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow business_admin to insert/update their own subscription
CREATE POLICY IF NOT EXISTS "business_admin_manage_subscription" ON public.subscriptions
  FOR ALL USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE id = auth.uid()
    ) AND
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND (role = 'business_admin' OR role = 'super_admin')
    )
  );
