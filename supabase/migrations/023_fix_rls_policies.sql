-- ============================================================================
-- Migration: 023_fix_rls_policies.sql
-- Description: Fix RLS policies for audit_logs and subscriptions
-- Created: 2026-10-04
-- ============================================================================

-- Drop existing policies if they exist, then create new ones

-- Allow business_admin to insert audit logs
DROP POLICY IF EXISTS "business_admin_insert_audit" ON public.audit_logs;
CREATE POLICY "business_admin_insert_audit" ON public.audit_logs
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND (role = 'business_admin' OR role = 'super_admin')
    )
  );

-- Allow business_admin to view their tenant's subscription
DROP POLICY IF EXISTS "business_admin_view_subscription" ON public.subscriptions;
CREATE POLICY "business_admin_view_subscription" ON public.subscriptions
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow business_admin to insert/update their own subscription
DROP POLICY IF EXISTS "business_admin_manage_subscription" ON public.subscriptions;
CREATE POLICY "business_admin_manage_subscription" ON public.subscriptions
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


-- Allow business_admin to view their tenant's payments
DROP POLICY IF EXISTS "business_admin_view_payments" ON public.payments;
CREATE POLICY "business_admin_view_payments" ON public.payments
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow business_admin to insert payments for their tenant
DROP POLICY IF EXISTS "business_admin_insert_payments" ON public.payments;
CREATE POLICY "business_admin_insert_payments" ON public.payments
  FOR INSERT WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE id = auth.uid()
    ) AND
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND (role = 'business_admin' OR role = 'super_admin')
    )
  );
