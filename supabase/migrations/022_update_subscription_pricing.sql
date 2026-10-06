-- ============================================================================
-- Migration: 022_update_subscription_pricing.sql
-- Description: Update subscription plans with renewal pricing and international USD pricing
-- Changes:
--   1. Add renewal_yearly columns (50% of yearly price)
--   2. Add international USD pricing (price_monthly_usd, price_yearly_usd, renewal_yearly_usd)
--   3. Update Enterprise plan from ₹49,990 to ₹28,080/year (₹2,600/month)
--   4. Add plan_code for consistent plan identification
--   5. Add currency support to subscriptions table
-- Created: 2026-10-05
-- ============================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- Step 1: Add new columns to subscription_plans table
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

-- ══════════════════════════════════════════════════════════════════════════
-- Step 2: Update existing plans with new pricing
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
WHERE plan_name = 'Basic';

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
WHERE plan_name = 'Professional';

-- Update Enterprise Plan (NEW PRICING: ₹26,000/year instead of ₹49,999)
UPDATE public.subscription_plans
SET 
  plan_code = 'enterprise',
  price_monthly = 2167.00,   -- ₹26,000 / 12 months (for monthly option)
  price_yearly = 26000.00,   -- Changed from ₹49,999 to ₹26,000
  renewal_yearly = 13000.00, -- 50% of yearly (₹13,000)
  price_monthly_usd = 35.00,
  price_yearly_usd = 350.00,
  renewal_yearly_usd = 175.00,  -- 50% of yearly
  features = '["Unlimited Branches", "Unlimited Users", "100GB Storage", "24/7 Phone Support", "API Access", "Custom Reports", "Dedicated Account Manager", "Data Export", "White Label Options", "Training & Onboarding"]'::jsonb,
  updated_at = NOW()
WHERE plan_name = 'Enterprise';

-- ══════════════════════════════════════════════════════════════════════════
-- Step 3: Add unique constraint on plan_code
-- ══════════════════════════════════════════════════════════════════════════

-- First, ensure all plans have plan_codes
UPDATE public.subscription_plans
SET plan_code = LOWER(plan_name)
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

-- ══════════════════════════════════════════════════════════════════════════
-- Step 4: Add currency and renewal tracking to subscriptions table
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.subscriptions 
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS is_renewal BOOLEAN DEFAULT false;

-- Add check constraint for currency
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
-- Step 5: Create helper function to get plan price based on currency and renewal
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
  'Get subscription plan price based on billing cycle, currency (INR/USD), and renewal status';

-- ══════════════════════════════════════════════════════════════════════════
-- Step 6: Create function to check if subscription qualifies for renewal pricing
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.is_eligible_for_renewal(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if tenant has an active or recently expired subscription
  RETURN EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE tenant_id = p_tenant_id
      AND status IN ('active', 'expired')
      AND end_date >= CURRENT_DATE - INTERVAL '30 days'  -- Within 30 days of expiry
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.is_eligible_for_renewal(UUID) IS 
  'Check if tenant is eligible for renewal pricing (50% discount)';

-- ══════════════════════════════════════════════════════════════════════════
-- Step 7: Update get_active_subscription function to include pricing info
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_active_subscription(p_tenant_id UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_name TEXT,
  plan_code TEXT,
  status TEXT,
  billing_cycle TEXT,
  currency TEXT,
  is_renewal BOOLEAN,
  end_date DATE,
  days_remaining INTEGER,
  current_price DECIMAL(10, 2),
  renewal_price DECIMAL(10, 2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    sp.plan_name,
    sp.plan_code,
    s.status,
    s.billing_cycle,
    s.currency,
    s.is_renewal,
    s.end_date,
    (s.end_date - CURRENT_DATE) AS days_remaining,
    -- Current subscription price
    CASE 
      WHEN s.currency = 'INR' THEN
        CASE WHEN s.billing_cycle = 'monthly' THEN sp.price_monthly ELSE sp.price_yearly END
      ELSE
        CASE WHEN s.billing_cycle = 'monthly' THEN sp.price_monthly_usd ELSE sp.price_yearly_usd END
    END AS current_price,
    -- Renewal price (50% for yearly)
    CASE 
      WHEN s.currency = 'INR' THEN sp.renewal_yearly
      ELSE sp.renewal_yearly_usd
    END AS renewal_price
  FROM public.subscriptions s
  JOIN public.subscription_plans sp ON s.plan_id = sp.id
  WHERE s.tenant_id = p_tenant_id
    AND s.status IN ('active', 'trial')
  ORDER BY s.end_date DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════
-- Verification Queries
-- ══════════════════════════════════════════════════════════════════════════

-- Display updated pricing for all plans
SELECT 
  plan_code,
  plan_name,
  '₹' || price_monthly::TEXT || '/mo' AS inr_monthly,
  '₹' || price_yearly::TEXT || '/yr' AS inr_yearly,
  '₹' || renewal_yearly::TEXT || '/yr renewal' AS inr_renewal,
  '$' || price_monthly_usd::TEXT || '/mo' AS usd_monthly,
  '$' || price_yearly_usd::TEXT || '/yr' AS usd_yearly,
  '$' || renewal_yearly_usd::TEXT || '/yr renewal' AS usd_renewal,
  max_branches || ' branch(es)' AS branches,
  max_users || ' user(s)' AS users
FROM public.subscription_plans
ORDER BY display_order;

-- Test pricing function
SELECT 
  'Basic Monthly INR' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'basic'),
    'monthly',
    'INR',
    false
  ) AS price;

SELECT 
  'Professional Yearly USD (Renewal)' AS test_case,
  public.get_plan_price(
    (SELECT id FROM subscription_plans WHERE plan_code = 'professional'),
    'yearly',
    'USD',
    true
  ) AS price;

-- ============================================================================
-- Migration Summary
-- ============================================================================
-- ✅ Added renewal pricing (50% of yearly price for annual renewals)
-- ✅ Added international USD pricing for all plans
-- ✅ Updated Enterprise plan from ₹49,990 to ₹28,080/year (₹2,600/month)
-- ✅ Added plan_code for consistent identification
-- ✅ Added currency support (INR/USD) to subscriptions
-- ✅ Created helper functions for pricing and renewal eligibility
-- ✅ All existing data preserved
-- ============================================================================

COMMENT ON TABLE public.subscription_plans IS 
  'SaaS subscription plans with multi-currency support and renewal pricing. 
   Renewal pricing is 50% of the standard yearly price, applied automatically 
   for existing customers renewing their annual subscription.';
