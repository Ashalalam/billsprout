-- ============================================================================
-- Migration: 023_software_downloads_enhancement.sql
-- Description: Enhance software download and license access system
-- Created: 2026-10-06
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- 1. Update software_versions table to support file storage
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.software_versions
  ADD COLUMN IF NOT EXISTS software_name TEXT DEFAULT 'BillSprout Pharmacy ERP',
  ADD COLUMN IF NOT EXISTS platform TEXT DEFAULT 'Windows' CHECK (platform IN ('Windows', 'Mac', 'Linux', 'Web')),
  ADD COLUMN IF NOT EXISTS file_path TEXT,  -- Path in Supabase storage
  ADD COLUMN IF NOT EXISTS file_name TEXT,  -- Original filename
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deprecated')),
  ADD COLUMN IF NOT EXISTS download_count INTEGER DEFAULT 0;

-- Update existing comment
COMMENT ON TABLE public.software_versions IS 'Stores software release versions with download files and metadata';

-- ══════════════════════════════════════════════════════════════════════════
-- 2. Add access_status column to tenants table
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS access_status TEXT DEFAULT 'active' CHECK (access_status IN ('active', 'suspended'));

COMMENT ON COLUMN public.tenants.access_status IS 'Super Admin controlled access status - suspended prevents software downloads';

-- ══════════════════════════════════════════════════════════════════════════
-- 3. Update subscriptions table
-- ══════════════════════════════════════════════════════════════════════════

-- Add license_key column for future license validation
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS license_key TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS license_status TEXT DEFAULT 'active' CHECK (license_status IN ('active', 'inactive', 'suspended', 'expired'));

-- Generate license keys for existing subscriptions
UPDATE public.subscriptions
SET license_key = 'LIC-' || UPPER(SUBSTRING(id::TEXT FROM 1 FOR 8)) || '-' || UPPER(SUBSTRING(id::TEXT FROM 10 FOR 4))
WHERE license_key IS NULL;

COMMENT ON COLUMN public.subscriptions.license_key IS 'Unique license key for software activation';
COMMENT ON COLUMN public.subscriptions.license_status IS 'License status independent of subscription status';

-- ══════════════════════════════════════════════════════════════════════════
-- 4. Function: Check if tenant can download software
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_download_software(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_access_status TEXT;
  v_subscription_status TEXT;
  v_subscription_end_date DATE;
BEGIN
  -- Check tenant access status
  SELECT access_status INTO v_access_status
  FROM public.tenants
  WHERE id = p_tenant_id;

  -- If suspended by Super Admin, deny
  IF v_access_status = 'suspended' THEN
    RETURN FALSE;
  END IF;

  -- Check active subscription
  SELECT status, end_date INTO v_subscription_status, v_subscription_end_date
  FROM public.subscriptions
  WHERE tenant_id = p_tenant_id
    AND status IN ('active', 'trial')
  ORDER BY end_date DESC
  LIMIT 1;

  -- Must have active subscription that hasn't expired
  IF v_subscription_status IS NULL THEN
    RETURN FALSE;
  END IF;

  IF v_subscription_end_date < CURRENT_DATE THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.can_download_software(UUID) IS 'Checks if a tenant is authorized to download software based on access status and active subscription';

-- ══════════════════════════════════════════════════════════════════════════
-- 5. Function: Get download authorization
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_download_authorization(p_tenant_id UUID)
RETURNS TABLE (
  can_download BOOLEAN,
  reason TEXT,
  subscription_status TEXT,
  license_status TEXT,
  access_status TEXT,
  subscription_end_date DATE
) AS $$
DECLARE
  v_tenant_access TEXT;
  v_sub_status TEXT;
  v_lic_status TEXT;
  v_end_date DATE;
  v_reason TEXT := '';
BEGIN
  -- Get tenant access status
  SELECT t.access_status INTO v_tenant_access
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  -- Get subscription details
  SELECT s.status, s.license_status, s.end_date 
  INTO v_sub_status, v_lic_status, v_end_date
  FROM public.subscriptions s
  WHERE s.tenant_id = p_tenant_id
    AND s.status IN ('active', 'trial', 'expired')
  ORDER BY s.end_date DESC
  LIMIT 1;

  -- Determine authorization
  IF v_tenant_access = 'suspended' THEN
    RETURN QUERY SELECT 
      FALSE,
      'Access suspended by administrator. Please contact support.',
      v_sub_status,
      v_lic_status,
      v_tenant_access,
      v_end_date;
  ELSIF v_sub_status IS NULL THEN
    RETURN QUERY SELECT 
      FALSE,
      'No active subscription found. Please purchase a plan.',
      v_sub_status,
      v_lic_status,
      v_tenant_access,
      v_end_date;
  ELSIF v_end_date < CURRENT_DATE THEN
    RETURN QUERY SELECT 
      FALSE,
      'Subscription expired. Please renew to continue.',
      'expired'::TEXT,
      'expired'::TEXT,
      v_tenant_access,
      v_end_date;
  ELSE
    RETURN QUERY SELECT 
      TRUE,
      'Authorized'::TEXT,
      v_sub_status,
      v_lic_status,
      v_tenant_access,
      v_end_date;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_download_authorization(UUID) IS 'Returns detailed download authorization status for a tenant';

-- ══════════════════════════════════════════════════════════════════════════
-- 6. Update RLS policies for software_versions
-- ══════════════════════════════════════════════════════════════════════════

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "authenticated_view_versions" ON public.software_versions;
DROP POLICY IF EXISTS "super_admin_manage_versions" ON public.software_versions;

-- Only show active versions to authenticated users
CREATE POLICY "authenticated_view_active_versions" ON public.software_versions
  FOR SELECT TO authenticated 
  USING (status = 'active');

-- Super admin can manage all versions
CREATE POLICY "super_admin_full_access_versions" ON public.software_versions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- 7. Update download_logs to track authorization checks
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.download_logs
  ADD COLUMN IF NOT EXISTS was_authorized BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS platform TEXT,
  ADD COLUMN IF NOT EXISTS failure_reason TEXT;

COMMENT ON COLUMN public.download_logs.was_authorized IS 'Whether the download was authorized (tracks both successful and denied attempts)';

-- ══════════════════════════════════════════════════════════════════════════
-- 8. Create view for Super Admin dashboard
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.business_admin_access_overview AS
SELECT 
  t.id as tenant_id,
  t.business_name,
  t.contact_email as admin_email,
  t.contact_person as admin_name,
  t.access_status,
  t.subscription_status,
  sp.plan_name,
  sp.plan_code,
  s.status as subscription_status_detail,
  s.license_status,
  s.license_key,
  s.start_date as subscription_start,
  s.end_date as subscription_end,
  s.billing_cycle,
  (s.end_date - CURRENT_DATE) as days_remaining,
  CASE 
    WHEN s.end_date < CURRENT_DATE THEN 'Expired'
    WHEN s.end_date <= CURRENT_DATE + 30 THEN 'Expiring Soon'
    ELSE 'Active'
  END as renewal_status,
  p.amount as last_payment_amount,
  p.paid_at as last_payment_date,
  p.payment_status as last_payment_status,
  dl.download_count,
  dl.last_download_date,
  t.created_at as business_created_at
FROM public.tenants t
LEFT JOIN public.subscriptions s ON t.id = s.tenant_id 
  AND s.id = (
    SELECT id FROM public.subscriptions 
    WHERE tenant_id = t.id 
    ORDER BY end_date DESC 
    LIMIT 1
  )
LEFT JOIN public.subscription_plans sp ON s.plan_id = sp.id
LEFT JOIN public.payments p ON t.id = p.tenant_id 
  AND p.id = (
    SELECT id FROM public.payments 
    WHERE tenant_id = t.id 
    ORDER BY paid_at DESC 
    LIMIT 1
  )
LEFT JOIN (
  SELECT 
    tenant_id,
    COUNT(*) as download_count,
    MAX(downloaded_at) as last_download_date
  FROM public.download_logs
  WHERE was_authorized = true
  GROUP BY tenant_id
) dl ON t.id = dl.tenant_id
WHERE t.id != '00000000-0000-0000-0000-000000000000'  -- Exclude system tenant if any
ORDER BY t.created_at DESC;

COMMENT ON VIEW public.business_admin_access_overview IS 'Comprehensive view of all Business Admins with subscription, license, and download status for Super Admin dashboard';

-- ══════════════════════════════════════════════════════════════════════════
-- Grant permissions
-- ══════════════════════════════════════════════════════════════════════════

-- Super Admin can view the overview
GRANT SELECT ON public.business_admin_access_overview TO authenticated;

-- Create RLS policy for the view
ALTER VIEW public.business_admin_access_overview SET (security_barrier = true);

-- ══════════════════════════════════════════════════════════════════════════
-- Indexes for performance
-- ══════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_tenants_access_status ON public.tenants(access_status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_license_key ON public.subscriptions(license_key);
CREATE INDEX IF NOT EXISTS idx_subscriptions_license_status ON public.subscriptions(license_status);
CREATE INDEX IF NOT EXISTS idx_software_versions_status ON public.software_versions(status);
CREATE INDEX IF NOT EXISTS idx_software_versions_platform ON public.software_versions(platform);

-- ============================================================================
-- Migration complete
-- ============================================================================
