-- ============================================================================
-- Migration: 017_saas_subscription_tables.sql
-- Description: Create tables for SaaS subscription management
-- Created: 2026-10-04
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- Table: subscription_plans
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  price_monthly DECIMAL(10, 2) NOT NULL,
  price_yearly DECIMAL(10, 2) NOT NULL,
  features JSONB DEFAULT '[]'::jsonb,
  max_branches INTEGER NOT NULL DEFAULT 1,
  max_users INTEGER NOT NULL DEFAULT 3,
  storage_limit_gb INTEGER NOT NULL DEFAULT 5,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default plans
INSERT INTO public.subscription_plans (name, description, price_monthly, price_yearly, features, max_branches, max_users, storage_limit_gb, display_order)
VALUES 
  (
    'Basic',
    'Perfect for small pharmacies',
    999.00,
    9990.00,
    '["1 Branch", "3 Users", "5GB Storage", "Email Support", "Inventory Management", "POS Billing", "GST Reports"]'::jsonb,
    1,
    3,
    5,
    1
  ),
  (
    'Professional',
    'Ideal for growing pharmacies',
    2499.00,
    24990.00,
    '["3 Branches", "10 Users", "20GB Storage", "Priority Support", "Multi-Branch Management", "Advanced Reports", "Customer Management", "Supplier Management"]'::jsonb,
    3,
    10,
    20,
    2
  ),
  (
    'Enterprise',
    'For pharmacy chains',
    4999.00,
    49990.00,
    '["Unlimited Branches", "Unlimited Users", "100GB Storage", "24/7 Phone Support", "API Access", "Custom Reports", "Dedicated Account Manager", "Data Export"]'::jsonb,
    999,
    999,
    100,
    3
  )
ON CONFLICT (name) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════
-- Table: subscriptions
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES public.subscription_plans(id),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'expired', 'suspended', 'cancelled')),
  billing_cycle TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE NOT NULL,
  auto_renew BOOLEAN DEFAULT true,
  payment_method TEXT DEFAULT 'paypal',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_end_date ON public.subscriptions(end_date);

-- ══════════════════════════════════════════════════════════════════════════
-- Table: payments
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  amount DECIMAL(10, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  payment_method TEXT NOT NULL DEFAULT 'paypal',
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_id TEXT UNIQUE,
  payer_email TEXT,
  payer_name TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX idx_payments_tenant_id ON public.payments(tenant_id);
CREATE INDEX idx_payments_subscription_id ON public.payments(subscription_id);
CREATE INDEX idx_payments_status ON public.payments(payment_status);
CREATE INDEX idx_payments_transaction_id ON public.payments(transaction_id);

-- ══════════════════════════════════════════════════════════════════════════
-- Table: software_versions
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.software_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_number TEXT NOT NULL UNIQUE,
  release_date DATE NOT NULL DEFAULT CURRENT_DATE,
  release_notes TEXT,
  download_url_windows TEXT,
  download_url_mac TEXT,
  file_size_mb INTEGER,
  is_latest BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure only one version is marked as latest
CREATE UNIQUE INDEX idx_software_versions_latest ON public.software_versions(is_latest) WHERE is_latest = true;

-- ══════════════════════════════════════════════════════════════════════════
-- Table: download_logs
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.download_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  version_id UUID REFERENCES public.software_versions(id) ON DELETE SET NULL,
  ip_address TEXT,
  user_agent TEXT,
  downloaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for analytics
CREATE INDEX idx_download_logs_tenant_id ON public.download_logs(tenant_id);
CREATE INDEX idx_download_logs_version_id ON public.download_logs(version_id);
CREATE INDEX idx_download_logs_downloaded_at ON public.download_logs(downloaded_at DESC);

-- ══════════════════════════════════════════════════════════════════════════
-- Modify existing tables
-- ══════════════════════════════════════════════════════════════════════════

-- Add columns to tenants table
ALTER TABLE public.tenants 
  ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'expired', 'suspended')),
  ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  ADD COLUMN IF NOT EXISTS last_payment_date TIMESTAMPTZ;

-- Add columns to users table
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_verification_token TEXT,
  ADD COLUMN IF NOT EXISTS registration_date TIMESTAMPTZ DEFAULT NOW();

-- ══════════════════════════════════════════════════════════════════════════
-- Row Level Security (RLS)
-- ══════════════════════════════════════════════════════════════════════════

-- subscription_plans: Public read, super admin write
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone_can_view_plans" ON public.subscription_plans
  FOR SELECT USING (is_active = true);

CREATE POLICY "super_admin_manage_plans" ON public.subscription_plans
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- subscriptions: Tenant can view own, super admin all
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_view_own_subscription" ON public.subscriptions
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE users.id = auth.uid()
    )
  );

CREATE POLICY "super_admin_manage_subscriptions" ON public.subscriptions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- payments: Tenant can view own, super admin all
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_view_own_payments" ON public.payments
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE users.id = auth.uid()
    )
  );

CREATE POLICY "super_admin_manage_payments" ON public.payments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- software_versions: All authenticated users can read
ALTER TABLE public.software_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_view_versions" ON public.software_versions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "super_admin_manage_versions" ON public.software_versions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- download_logs: Tenant view own, super admin all
ALTER TABLE public.download_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_view_own_downloads" ON public.download_logs
  FOR SELECT USING (
    tenant_id IN (
      SELECT tenant_id FROM public.users WHERE users.id = auth.uid()
    )
  );

CREATE POLICY "authenticated_insert_downloads" ON public.download_logs
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "super_admin_view_all_downloads" ON public.download_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid() AND users.role = 'super_admin'
    )
  );

-- ══════════════════════════════════════════════════════════════════════════
-- Functions
-- ══════════════════════════════════════════════════════════════════════════

-- Function to check if subscription is active
CREATE OR REPLACE FUNCTION public.is_subscription_active(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE tenant_id = p_tenant_id
      AND status = 'active'
      AND end_date >= CURRENT_DATE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get active subscription
CREATE OR REPLACE FUNCTION public.get_active_subscription(p_tenant_id UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_name TEXT,
  status TEXT,
  end_date DATE,
  days_remaining INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    sp.name,
    s.status,
    s.end_date,
    (s.end_date - CURRENT_DATE) AS days_remaining
  FROM public.subscriptions s
  JOIN public.subscription_plans sp ON s.plan_id = sp.id
  WHERE s.tenant_id = p_tenant_id
    AND s.status IN ('active', 'trial')
  ORDER BY s.end_date DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════
-- Verification queries
-- ══════════════════════════════════════════════════════════════════════════

-- Check tables created
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('subscription_plans', 'subscriptions', 'payments', 'software_versions', 'download_logs');

-- Check default plans
SELECT name, price_monthly, price_yearly, max_branches, max_users FROM public.subscription_plans ORDER BY display_order;

-- ============================================================================
-- Migration complete
-- ============================================================================
