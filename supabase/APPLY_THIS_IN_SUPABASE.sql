-- ============================================================================
-- APPLY THIS ENTIRE FILE IN SUPABASE SQL EDITOR
-- This will fix all errors: 403 payments and 404 create_license_key
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- PART 1: Fix Payments RLS Policies (fixes 403 error)
-- ══════════════════════════════════════════════════════════════════════════

-- Enable RLS on payments if not already enabled
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "business_admin_view_payments" ON public.payments;
DROP POLICY IF EXISTS "business_admin_insert_payments" ON public.payments;

-- Create new policies with simpler logic
CREATE POLICY "business_admin_view_payments" ON public.payments
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.tenant_id = payments.tenant_id
      AND users.role IN ('business_admin', 'super_admin')
    )
  );

CREATE POLICY "business_admin_insert_payments" ON public.payments
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.tenant_id = payments.tenant_id
      AND users.role IN ('business_admin', 'super_admin')
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- PART 2: License Key System (fixes 404 create_license_key error)
-- ══════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════
-- Table: license_keys
-- Stores software license keys for paid customers
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.license_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  
  -- License Key Details
  license_key TEXT NOT NULL UNIQUE,
  license_type TEXT NOT NULL CHECK (license_type IN ('trial', 'basic', 'professional', 'enterprise')),
  
  -- Activation Details
  activation_code TEXT UNIQUE,
  is_activated BOOLEAN DEFAULT false,
  activated_at TIMESTAMPTZ,
  machine_id TEXT, -- Hardware fingerprint of activated machine
  
  -- Validity
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_until DATE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  
  -- Usage Limits (based on plan)
  max_users INTEGER DEFAULT 5,
  max_branches INTEGER DEFAULT 1,
  
  -- Metadata
  issued_by UUID REFERENCES auth.users(id), -- Admin who issued the license
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partial unique index: only one active license per tenant
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_license_per_tenant 
  ON public.license_keys(tenant_id) 
  WHERE is_active = true;

-- Indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_license_keys_tenant_id ON public.license_keys(tenant_id);
CREATE INDEX IF NOT EXISTS idx_license_keys_license_key ON public.license_keys(license_key);
CREATE INDEX IF NOT EXISTS idx_license_keys_activation_code ON public.license_keys(activation_code);
CREATE INDEX IF NOT EXISTS idx_license_keys_valid_until ON public.license_keys(valid_until);
CREATE INDEX IF NOT EXISTS idx_license_keys_is_active ON public.license_keys(is_active);

-- ══════════════════════════════════════════════════════════════════════════
-- Table: license_activations
-- Track all activation attempts and device changes
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.license_activations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_key_id UUID NOT NULL REFERENCES public.license_keys(id) ON DELETE CASCADE,
  
  -- Device Info
  machine_id TEXT NOT NULL,
  machine_name TEXT,
  os_type TEXT, -- Windows, Linux, Mac
  os_version TEXT,
  
  -- Activation Details
  activation_status TEXT NOT NULL CHECK (activation_status IN ('success', 'failed', 'revoked')),
  activation_method TEXT DEFAULT 'online', -- online, offline, manual
  ip_address TEXT,
  
  -- Timestamps
  activated_at TIMESTAMPTZ DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ,
  
  -- Metadata
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_license_activations_license_key_id ON public.license_activations(license_key_id);
CREATE INDEX IF NOT EXISTS idx_license_activations_machine_id ON public.license_activations(machine_id);

-- ══════════════════════════════════════════════════════════════════════════
-- Table: license_verifications
-- Log all license verification requests (for monitoring piracy)
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.license_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_key TEXT NOT NULL,
  machine_id TEXT,
  
  -- Verification Result
  is_valid BOOLEAN NOT NULL,
  verification_status TEXT NOT NULL, -- valid, expired, invalid, suspended, max_devices
  
  -- Request Details
  ip_address TEXT,
  user_agent TEXT,
  app_version TEXT,
  
  -- Timestamp
  verified_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_license_verifications_license_key ON public.license_verifications(license_key);
CREATE INDEX IF NOT EXISTS idx_license_verifications_verified_at ON public.license_verifications(verified_at DESC);

-- ══════════════════════════════════════════════════════════════════════════
-- Functions: License Key Generation
-- ══════════════════════════════════════════════════════════════════════════

-- Generate a license key in format: XXXX-XXXX-XXXX-XXXX-XXXX
CREATE OR REPLACE FUNCTION public.generate_license_key()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude confusing chars
  result TEXT := '';
  segment TEXT;
  i INTEGER;
  j INTEGER;
BEGIN
  -- Generate 5 segments of 4 characters
  FOR i IN 1..5 LOOP
    segment := '';
    FOR j IN 1..4 LOOP
      segment := segment || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    
    IF i > 1 THEN
      result := result || '-';
    END IF;
    result := result || segment;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Generate activation code (shorter, for offline activation)
CREATE OR REPLACE FUNCTION public.generate_activation_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  -- Generate 12-character activation code
  FOR i IN 1..12 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ══════════════════════════════════════════════════════════════════════════
-- Function: Create License Key for Tenant
-- ══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.create_license_key(
  p_tenant_id UUID,
  p_subscription_id UUID,
  p_license_type TEXT,
  p_valid_days INTEGER DEFAULT 365
)
RETURNS TABLE (
  license_key TEXT,
  activation_code TEXT,
  valid_until DATE
) AS $$
DECLARE
  v_license_key TEXT;
  v_activation_code TEXT;
  v_valid_until DATE;
  v_max_users INTEGER;
  v_max_branches INTEGER;
BEGIN
  -- Set limits based on license type
  CASE p_license_type
    WHEN 'trial' THEN
      v_max_users := 3;
      v_max_branches := 1;
    WHEN 'basic' THEN
      v_max_users := 5;
      v_max_branches := 1;
    WHEN 'professional' THEN
      v_max_users := 20;
      v_max_branches := 5;
    WHEN 'enterprise' THEN
      v_max_users := 999;
      v_max_branches := 999;
  END CASE;

  -- Generate unique license key
  LOOP
    v_license_key := generate_license_key();
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.license_keys WHERE license_keys.license_key = v_license_key);
  END LOOP;

  -- Generate unique activation code
  LOOP
    v_activation_code := generate_activation_code();
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.license_keys WHERE license_keys.activation_code = v_activation_code);
  END LOOP;

  -- Calculate valid until date
  v_valid_until := CURRENT_DATE + p_valid_days;

  -- Insert license key
  INSERT INTO public.license_keys (
    tenant_id,
    subscription_id,
    license_key,
    activation_code,
    license_type,
    valid_from,
    valid_until,
    max_users,
    max_branches,
    is_active
  ) VALUES (
    p_tenant_id,
    p_subscription_id,
    v_license_key,
    v_activation_code,
    p_license_type,
    CURRENT_DATE,
    v_valid_until,
    v_max_users,
    v_max_branches,
    true
  );

  -- Return license details
  RETURN QUERY
  SELECT v_license_key, v_activation_code, v_valid_until;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════
-- Function: Verify License Key
-- ══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.verify_license_key(
  p_license_key TEXT,
  p_machine_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  is_valid BOOLEAN,
  status TEXT,
  message TEXT,
  valid_until DATE,
  license_type TEXT,
  tenant_id UUID
) AS $$
DECLARE
  v_license RECORD;
  v_is_valid BOOLEAN := false;
  v_status TEXT;
  v_message TEXT;
BEGIN
  -- Get license details
  SELECT * INTO v_license
  FROM public.license_keys
  WHERE license_keys.license_key = p_license_key;

  -- Check if license exists
  IF NOT FOUND THEN
    v_status := 'invalid';
    v_message := 'License key not found';
    
    -- Log verification attempt
    INSERT INTO public.license_verifications (license_key, machine_id, is_valid, verification_status)
    VALUES (p_license_key, p_machine_id, false, v_status);
    
    RETURN QUERY SELECT false, v_status, v_message, NULL::DATE, NULL::TEXT, NULL::UUID;
    RETURN;
  END IF;

  -- Check if license is active
  IF NOT v_license.is_active THEN
    v_status := 'suspended';
    v_message := 'License has been suspended';
    
    INSERT INTO public.license_verifications (license_key, machine_id, is_valid, verification_status)
    VALUES (p_license_key, p_machine_id, false, v_status);
    
    RETURN QUERY SELECT false, v_status, v_message, v_license.valid_until, v_license.license_type, v_license.tenant_id;
    RETURN;
  END IF;

  -- Check if license has expired
  IF v_license.valid_until < CURRENT_DATE THEN
    v_status := 'expired';
    v_message := 'License has expired on ' || v_license.valid_until::TEXT;
    
    INSERT INTO public.license_verifications (license_key, machine_id, is_valid, verification_status)
    VALUES (p_license_key, p_machine_id, false, v_status);
    
    RETURN QUERY SELECT false, v_status, v_message, v_license.valid_until, v_license.license_type, v_license.tenant_id;
    RETURN;
  END IF;

  -- License is valid
  v_is_valid := true;
  v_status := 'valid';
  v_message := 'License is valid until ' || v_license.valid_until::TEXT;
  
  -- Log successful verification
  INSERT INTO public.license_verifications (license_key, machine_id, is_valid, verification_status)
  VALUES (p_license_key, p_machine_id, true, v_status);

  RETURN QUERY SELECT v_is_valid, v_status, v_message, v_license.valid_until, v_license.license_type, v_license.tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════
-- Row Level Security (RLS)
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.license_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.license_activations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.license_verifications ENABLE ROW LEVEL SECURITY;

-- Tenants can view their own license keys
DROP POLICY IF EXISTS "tenants_view_own_licenses" ON public.license_keys;
CREATE POLICY "tenants_view_own_licenses" ON public.license_keys
  FOR SELECT USING (
    tenant_id IN (SELECT tenant_id FROM public.users WHERE users.id = auth.uid())
  );

-- Super admins can manage all licenses
DROP POLICY IF EXISTS "super_admin_manage_licenses" ON public.license_keys;
CREATE POLICY "super_admin_manage_licenses" ON public.license_keys
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- Anyone can verify licenses (for app activation)
DROP POLICY IF EXISTS "anyone_can_verify_licenses" ON public.license_verifications;
CREATE POLICY "anyone_can_verify_licenses" ON public.license_verifications
  FOR INSERT WITH CHECK (true);

-- ══════════════════════════════════════════════════════════════════════════
-- Trigger: Auto-update updated_at
-- ══════════════════════════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS update_license_keys_updated_at ON public.license_keys;
CREATE TRIGGER update_license_keys_updated_at
  BEFORE UPDATE ON public.license_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ══════════════════════════════════════════════════════════════════════════
-- Sample Data: Create trial license keys for existing tenants
-- ══════════════════════════════════════════════════════════════════════════

-- Create trial licenses for all existing tenants without licenses
INSERT INTO public.license_keys (tenant_id, license_type, license_key, activation_code, valid_from, valid_until, max_users, max_branches)
SELECT 
  t.id,
  'trial',
  generate_license_key(),
  generate_activation_code(),
  CURRENT_DATE,
  CURRENT_DATE + INTERVAL '7 days',
  3,
  1
FROM public.tenants t
WHERE NOT EXISTS (
  SELECT 1 FROM public.license_keys lk WHERE lk.tenant_id = t.id AND lk.is_active = true
)
AND t.subscription_status = 'trial';

-- ============================================================================
-- ✅ DONE! All errors should be fixed now.
-- ============================================================================
