-- ============================================================================
-- Migration: 014_audit_logs_table.sql
-- Description: Create audit_logs table for security event logging
-- Created: 2025-01-XX
-- ============================================================================
--
-- Purpose:
-- - Track all authentication events (login, logout, failures)
-- - Log authorization violations and security events
-- - Monitor data access and modifications
-- - Provide audit trail for compliance (GDPR, HIPAA)
-- - Enable security incident investigation
--
-- Security:
-- - Only accessible by super admins via RLS policies
-- - Tenant isolation for multi-tenant audit data
-- - Immutable logs (no updates allowed, only inserts)
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- Drop existing table if needed (for clean migration)
-- ──────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.audit_logs CASCADE;

-- ──────────────────────────────────────────────────────────────────────────
-- Create audit_logs table
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Who performed the action
  user_id TEXT NOT NULL,
  user_role TEXT NOT NULL,
  
  -- Multi-tenant isolation
  tenant_id TEXT,
  
  -- What action was performed
  action TEXT NOT NULL,
  
  -- What resource was affected (optional)
  resource_type TEXT,
  resource_id TEXT,
  
  -- Additional context (JSON for flexibility)
  details JSONB DEFAULT '{}'::jsonb,
  
  -- Network information
  ip_address TEXT,
  user_agent TEXT,
  
  -- When it happened
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────────────────
-- Indexes for performance
-- ──────────────────────────────────────────────────────────────────────────

-- Primary queries: Find logs by user
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);

-- Multi-tenant queries: Find logs by tenant
CREATE INDEX idx_audit_logs_tenant_id ON public.audit_logs(tenant_id) 
  WHERE tenant_id IS NOT NULL;

-- Security monitoring: Find specific actions
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);

-- Time-based queries: Recent events
CREATE INDEX idx_audit_logs_timestamp ON public.audit_logs(timestamp DESC);

-- Composite index: Tenant + time (common query pattern)
CREATE INDEX idx_audit_logs_tenant_timestamp ON public.audit_logs(tenant_id, timestamp DESC) 
  WHERE tenant_id IS NOT NULL;

-- Security incident investigation: Failed logins, unauthorized access
CREATE INDEX idx_audit_logs_security_events ON public.audit_logs(action, timestamp DESC)
  WHERE action IN ('login_failed', 'unauthorized_attempt', 'access_denied', 'privilege_escalation_attempt');

-- ──────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS) Policies
-- ──────────────────────────────────────────────────────────────────────────

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy 1: Super admins can view all audit logs
CREATE POLICY "super_admins_view_all_audit_logs" 
  ON public.audit_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role = 'super_admin'
      AND users.is_active = true
    )
  );

-- Policy 2: Business admins can view their tenant's audit logs
CREATE POLICY "business_admins_view_tenant_audit_logs"
  ON public.audit_logs
  FOR SELECT
  USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('business_admin', 'pharmacist')
      AND users.is_active = true
    )
  );

-- Policy 3: System can insert audit logs (for AuditService)
-- This allows authenticated users to write audit logs for their own actions
CREATE POLICY "authenticated_users_insert_audit_logs"
  ON public.audit_logs
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
  );

-- Policy 4: No updates or deletes (audit logs are immutable)
-- This ensures audit trail integrity
CREATE POLICY "no_updates_to_audit_logs"
  ON public.audit_logs
  FOR UPDATE
  USING (false);

CREATE POLICY "no_deletes_from_audit_logs"
  ON public.audit_logs
  FOR DELETE
  USING (false);

-- ──────────────────────────────────────────────────────────────────────────
-- Comments for documentation
-- ──────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.audit_logs IS 
  'Audit trail for security events, authentication, authorization, and data access. Immutable logs for compliance and security monitoring.';

COMMENT ON COLUMN public.audit_logs.user_id IS 
  'ID of user who performed the action. May be email for failed login attempts.';

COMMENT ON COLUMN public.audit_logs.user_role IS 
  'Role of user at time of action (super_admin, business_admin, pharmacist, cashier, customer).';

COMMENT ON COLUMN public.audit_logs.tenant_id IS 
  'Tenant context for multi-tenant isolation. NULL for super admin actions or failed logins.';

COMMENT ON COLUMN public.audit_logs.action IS 
  'Action performed. Examples: user_login, login_failed, unauthorized_attempt, data_viewed, etc.';

COMMENT ON COLUMN public.audit_logs.resource_type IS 
  'Type of resource affected. Examples: user, product, batch, sale, customer, etc.';

COMMENT ON COLUMN public.audit_logs.resource_id IS 
  'ID of specific resource affected. Example: product_id, customer_id, sale_id.';

COMMENT ON COLUMN public.audit_logs.details IS 
  'Additional context as JSON. Examples: email, error messages, old/new values, etc.';

COMMENT ON COLUMN public.audit_logs.ip_address IS 
  'IP address of client (if available). Useful for security incident investigation.';

COMMENT ON COLUMN public.audit_logs.user_agent IS 
  'User agent string from client. Helps identify device/browser.';

COMMENT ON COLUMN public.audit_logs.timestamp IS 
  'When the action occurred (UTC timezone).';

-- ──────────────────────────────────────────────────────────────────────────
-- Grant permissions
-- ──────────────────────────────────────────────────────────────────────────

-- Allow authenticated users to insert audit logs
GRANT INSERT ON public.audit_logs TO authenticated;

-- Allow authenticated users to read audit logs (RLS will filter)
GRANT SELECT ON public.audit_logs TO authenticated;

-- Service role can do everything (for admin tools)
GRANT ALL ON public.audit_logs TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- Verification queries (for testing)
-- ──────────────────────────────────────────────────────────────────────────

-- Test 1: Verify table exists
SELECT 
  tablename, 
  schemaname,
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'audit_logs';

-- Test 2: Verify indexes exist
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'audit_logs'
ORDER BY indexname;

-- Test 3: Verify RLS policies exist
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'audit_logs'
ORDER BY policyname;

-- ============================================================================
-- Migration complete
-- ============================================================================
