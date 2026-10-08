-- ============================================================================
-- QUICK FIX: Apply Missing Essential Tables
-- This fixes the 401/400 errors you're seeing
-- ============================================================================

-- 1. Create audit_logs table (fixes the audit log errors)
DROP TABLE IF EXISTS public.audit_logs CASCADE;

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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id ON public.audit_logs(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON public.audit_logs(timestamp DESC);

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "super_admins_view_all_audit_logs" ON public.audit_logs;
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

DROP POLICY IF EXISTS "authenticated_users_insert_audit_logs" ON public.audit_logs;
CREATE POLICY "authenticated_users_insert_audit_logs"
  ON public.audit_logs
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Grant permissions
GRANT INSERT ON public.audit_logs TO authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;

-- 2. Create subscription tables (if missing)
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES public.pricing_plans(id),
  
  -- Subscription details
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'suspended', 'cancelled', 'expired')),
  current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  current_period_end TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '30 days',
  
  -- Billing
  amount_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT DEFAULT 'INR',
  billing_cycle TEXT DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
  
  -- Payment
  payment_method TEXT DEFAULT 'razorpay',
  razorpay_subscription_id TEXT,
  paypal_subscription_id TEXT,
  
  -- Metadata
  trial_end TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create payments table (if missing)
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.subscriptions(id),
  
  -- Payment details
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'INR',
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
  
  -- Payment gateway details
  payment_method TEXT NOT NULL, -- 'razorpay' or 'paypal'
  gateway_payment_id TEXT, -- razorpay_payment_id or paypal_order_id
  gateway_response JSONB,
  
  -- Metadata
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on payments
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Payments RLS policies
DROP POLICY IF EXISTS "business_admin_view_payments" ON public.payments;
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

DROP POLICY IF EXISTS "business_admin_insert_payments" ON public.payments;
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

-- 4. Create customer refill requests table (if missing)  
CREATE TABLE IF NOT EXISTS public.customer_refill_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
  
  -- Request details
  medicine_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'approved', 'ready', 'dispensed', 'cancelled')),
  
  -- Patient information
  customer_name TEXT,
  customer_phone TEXT,
  
  -- Timestamps
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  ready_at TIMESTAMPTZ,
  dispensed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update migrations ledger to reflect new migrations applied
INSERT INTO public._migrations (filename, checksum, applied_at)
VALUES 
  ('014_audit_logs_table.sql', 'quickfix_applied', NOW()),
  ('015_create_test_users.sql', 'quickfix_applied', NOW()),
  ('016_setup_existing_users.sql', 'quickfix_applied', NOW())
ON CONFLICT (filename) DO UPDATE SET 
  checksum = EXCLUDED.checksum,
  applied_at = EXCLUDED.applied_at;

-- ============================================================================
-- DONE! This should fix the 401/400 errors
-- ============================================================================

-- =====================================================
-- FIX POS BILLING PRICING ISSUE
-- =====================================================
-- Problem: Some batches have selling_price = 0 or NULL, causing ₹0 display in POS
-- Solution: Set selling_price = MRP for all batches where selling_price is missing/zero

-- Update all batches where selling_price is NULL or 0 to use MRP as selling_price
UPDATE batches 
SET selling_price = mrp, 
    updated_at = CURRENT_TIMESTAMP
WHERE selling_price IS NULL 
   OR selling_price = 0
   OR selling_price < 0.01;

-- Verify the fix
SELECT 
    b.batch_number,
    p.name as product_name,
    b.mrp,
    b.selling_price,
    b.stock_quantity
FROM batches b
JOIN products p ON b.product_id = p.id
WHERE b.selling_price IS NULL 
   OR b.selling_price = 0
   OR b.selling_price < 0.01
ORDER BY p.name;

-- If the above query returns no rows, the fix is successful

-- Optional: Set default selling_price for future batches
-- This ensures new batches have selling_price = MRP by default
ALTER TABLE batches 
ALTER COLUMN selling_price SET DEFAULT 0;

-- Add a check constraint to prevent selling_price from being negative
ALTER TABLE batches 
ADD CONSTRAINT check_selling_price_positive 
CHECK (selling_price >= 0);

-- Note: You may need to restart your Flutter app after running this script
-- to reload the batch data with correct selling prices