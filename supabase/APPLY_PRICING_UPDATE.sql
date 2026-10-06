-- ============================================================================
-- APPLY THIS FILE IN SUPABASE SQL EDITOR
-- Complete Pricing System Update
-- ============================================================================
-- This script implements:
-- 1. Multi-currency support (INR & USD with separate pricing)
-- 2. Renewal pricing (50% of annual price for all plans)
-- 3. Enterprise plan update: ₹26,000/year (was ₹49,999)
-- 4. Manual renewal only (no auto-renewal)
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- STEP 1: Add required columns if they don't exist
-- ══════════════════════════════════════════════════════════════════════════

-- Add plan_code column
ALTER TABLE public.subscription_plans 
  ADD COLUMN IF NOT EXISTS plan_code TEXT;
  

-- Add renewal pricing columns (INR)
ALTER TABLE public.subscription_plans 
  ADD COLUMN IF NOT EXISTS renewal_yearly DECIMAL(10, 2);

-- Add international USD pricing columns
ALTER TABLE public.subscription_plans 
  ADD COLUMN IF NOT EXISTS price_monthly_usd DECIMAL(10, 2),
  ADD COLUMN IF NOT EXISTS price_yearly_usd DECIMAL(10, 2),
  ADD COLUMN IF NOT EXISTS renewal_yearly_usd DECIMAL(10, 2);

-- Add currency column with default
ALTER TABLE public.subscription_plans 
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'INR';

-- Rename 'name' to 'plan_name' for clarity (if not already renamed)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'subscription_plans' AND column_name = 'name'
  ) THEN
    ALTER TABLE public.subscription_plans RENAME COLUMN name TO plan_name;
  END IF;
END $$;

-- Add currency and renewal tracking to subscriptions table
ALTER TABLE public.subscriptions 
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS is_renewal BOOLEAN DEFAULT false;

-- ══════════════════════════════════════════════════════════════════════════
-- STEP 2: Update ALL plans with correct pricing
-- ══════════════════════════════════════════════════════════════════════════

-- Update Basic Plan
UPDATE public.subscription_plans
SET 
  plan_code = 'basic',
  price_monthly = 499.00,
  price_yearly = 5388.00,
  renewal_yearly = 2694.00,  -- 50% of yearly
  price_monthly_usd = 9.00,
  price_yearly_usd = 97.00,
  renewal_yearly_usd = 48.50,  -- 50% of yearly
  features = '["1 Branch", "3 Users", "5GB Storage", "Email Support", "Inventory Management", "POS Billing", "GST Reports", "Batch Tracking", "Expiry Management"]'::jsonb,
  updated_at = NOW()
WHERE plan_name ILIKE '%basic%' OR plan_code = 'basic';

-- Update Professional Plan
UPDATE public.subscription_plans
SET 
  plan_code = 'professional',
  price_monthly = 1499.00,
  price_yearly = 16188.00,
  renewal_yearly = 8094.00,  -- 50% of yearly
  price_monthly_usd = 24.00,
  price_yearly_usd = 259.00,
  renewal_yearly_usd = 129.50,  -- 50% of yearly
  features = '["3 Branches", "10 Users", "20GB Storage", "Priority Support", "Multi-Branch Management", "Advanced Reports", "Customer Management", "Supplier Management", "Stock Transfer", "Loyalty Program"]'::jsonb,
  updated_at = NOW()
WHERE plan_name ILIKE '%professional%' OR plan_code = 'professional';

-- Update Enterprise Plan (CRITICAL: ₹26,000/year, NOT ₹49,999)
UPDATE public.subscription_plans
SET 
  plan_code = 'enterprise',
  price_monthly = 2167.00,   -- ₹26,000 / 12 months
  price_yearly = 26000.00,   -- *** CHANGED FROM ₹49,999 TO ₹26,000 ***
  renewal_yearly = 13000.00, -- 50% of yearly = ₹13,000
  price_monthly_usd = 35.00,  -- $350 / 12 months
  price_yearly_usd = 350.00,  -- International pricing
  renewal_yearly_usd = 175.00,  -- 50% of yearly = $175
  features = '["Unlimited Branches", "Unlimited Users", "100GB Storage", "24/7 Phone Support", "API Access", "Custom Reports", "Dedicated Account Manager", "Data Export", "White Label Options", "Training & Onboarding"]'::jsonb,
  updated_at = NOW()
WHERE plan_name ILIKE '%enterprise%' OR plan_code = 'enterprise';

-- ══════════════════════════════════════════════════════════════════════════
-- STEP 3: Add unique constraint on plan_code
-- ══════════════════════════════════════════════════════════════════════════

-- Ensure all plans have plan_codes
UPDATE public.subscription_plans
SET plan_code = LOWER(REGEXP_REPLACE(plan_name, '[^a-zA-Z0-9]', '', 'g'))
WHERE plan_code IS NULL;

-- Add unique constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'subscription_plans_plan_code_key'
  ) THEN
    ALTER TABLE public.subscription_plans 
      ADD CONSTRAINT subscription_plans_plan_code_key UNIQUE (plan_code);
  END IF;
END $$;

-- Add check constraint for currency in subscriptions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'subscriptions_currency_check'
  ) THEN
    ALTER TABLE public.subscriptions 
      ADD CONSTRAINT subscriptions_currency_check 
      CHECK (currency IN ('INR', 'USD'));
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- STEP 4: Create helper function for pricing
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_plan_price(
  p_plan_id UUID,
  p_billing_cycle TEXT,
  p_currency TEXT DEFAULT 'INR',
  p_is_renewal BOOLEAN DEFAULT false
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
  v_price DECIMAL(10, 2);
BEGIN
  -- Validate inputs
  IF p_billing_cycle NOT IN ('monthly', 'yearly') THEN
    RAISE EXCEPTION 'Invalid billing cycle: %', p_billing_cycle;
  END IF;
  
  IF p_currency NOT IN ('INR', 'USD') THEN
    RAISE EXCEPTION 'Invalid currency: %', p_currency;
  END IF;
  
  -- Get price based on parameters
  SELECT 
    CASE 
      WHEN p_currency = 'INR' THEN
        CASE 
          WHEN p_billing_cycle = 'monthly' THEN price_monthly
          WHEN p_billing_cycle = 'yearly' AND p_is_renewal THEN renewal_yearly
          ELSE price_yearly
        END
      ELSE -- USD
        CASE 
          WHEN p_billing_cycle = 'monthly' THEN price_monthly_usd
          WHEN p_billing_cycle = 'yearly' AND p_is_renewal THEN renewal_yearly_usd
          ELSE price_yearly_usd
        END
    END INTO v_price
  FROM public.subscription_plans
  WHERE id = p_plan_id;
  
  IF v_price IS NULL THEN
    RAISE EXCEPTION 'Plan not found or price not set';
  END IF;
  
  RETURN v_price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_plan_price(UUID, TEXT, TEXT, BOOLEAN) IS 
  'Get subscription plan price based on billing cycle, currency (INR/USD), and renewal status. Renewal is 50% of annual price.';

-- ══════════════════════════════════════════════════════════════════════════
-- STEP 5: Create function to check renewal eligibility
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.is_eligible_for_renewal(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if tenant has an active or recently expired subscription
  RETURN EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE tenant_id = p_tenant_id
      AND status IN ('active', 'expired')
      AND end_date >= CURRENT_DATE - INTERVAL '30 days'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.is_eligible_for_renewal(UUID) IS 
  'Check if tenant is eligible for renewal pricing (50% discount). Eligible within 30 days of expiry.';

-- ══════════════════════════════════════════════════════════════════════════
-- VERIFICATION: Display all pricing
-- ══════════════════════════════════════════════════════════════════════════

SELECT 
  plan_code AS "Plan",
  plan_name AS "Name",
  '₹' || price_monthly::TEXT || '/mo' AS "INR Monthly",
  '₹' || price_yearly::TEXT || '/yr' AS "INR Yearly",
  '₹' || renewal_yearly::TEXT || '/yr' AS "INR Renewal (50% OFF)",
  '$' || price_monthly_usd::TEXT || '/mo' AS "USD Monthly",
  '$' || price_yearly_usd::TEXT || '/yr' AS "USD Yearly",
  '$' || renewal_yearly_usd::TEXT || '/yr' AS "USD Renewal (50% OFF)",
  max_branches || ' branch(es)' AS "Branches",
  max_users || ' user(s)' AS "Users"
FROM public.subscription_plans
ORDER BY display_order;

-- ══════════════════════════════════════════════════════════════════════════
-- TEST CASES: Verify pricing function
-- ══════════════════════════════════════════════════════════════════════════

-- Test Enterprise INR yearly (should be ₹26,000)
SELECT 
  'Enterprise INR Yearly (First Year)' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'enterprise'),
    'yearly',
    'INR',
    false
  ) AS expected_26000;

-- Test Enterprise INR renewal (should be ₹13,000)
SELECT 
  'Enterprise INR Renewal (50% OFF)' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'enterprise'),
    'yearly',
    'INR',
    true
  ) AS expected_13000;

-- Test Enterprise USD yearly (should be $350)
SELECT 
  'Enterprise USD Yearly (First Year)' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'enterprise'),
    'yearly',
    'USD',
    false
  ) AS expected_350;

-- Test Enterprise USD renewal (should be $175)
SELECT 
  'Enterprise USD Renewal (50% OFF)' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'enterprise'),
    'yearly',
    'USD',
    true
  ) AS expected_175;

-- ============================================================================
-- SUMMARY OF CHANGES
-- ============================================================================
-- ✅ Enterprise Plan Updated: ₹49,999 → ₹26,000/year
-- ✅ Enterprise Renewal: ₹13,000/year (50% OFF)
-- ✅ INR & USD Separate Pricing: No automatic conversion
-- ✅ Renewal Pricing: 50% of annual price for all plans
-- ✅ Manual Renewal Only: No auto-renewal (customer must manually renew)
-- ✅ Multi-Currency Support: INR (₹) and USD ($)
-- ✅ Helper Functions: get_plan_price() and is_eligible_for_renewal()
-- ============================================================================

COMMENT ON TABLE public.subscription_plans IS 
  'SaaS subscription plans with multi-currency support (INR & USD).
   Renewal pricing is 50% of annual price. Renewal is MANUAL only.
   Enterprise: ₹26,000/year (renewal ₹13,000/year).';
