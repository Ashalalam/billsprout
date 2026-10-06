-- ============================================================================
-- Migration: 023_update_enterprise_pricing.sql
-- Description: Update Enterprise plan to ₹26,000/year (from ₹49,999)
-- Changes:
--   1. Update Enterprise INR pricing: ₹26,000/year, ₹13,000 renewal
--   2. Update Enterprise USD pricing: $350/year, $175 renewal
--   3. Ensure renewal pricing is exactly 50% of yearly price
-- Created: 2026-10-05
-- ============================================================================

-- Update Enterprise Plan with correct pricing
UPDATE public.subscription_plans
SET 
  plan_code = 'enterprise',
  price_monthly = 2167.00,   -- ₹26,000 / 12 months
  price_yearly = 26000.00,   -- NEW: ₹26,000 (was ₹49,999)
  renewal_yearly = 13000.00, -- 50% of yearly = ₹13,000
  price_monthly_usd = 35.00,  -- $350 / 12 months
  price_yearly_usd = 350.00,  -- International pricing
  renewal_yearly_usd = 175.00,  -- 50% of yearly = $175
  features = '["Unlimited Branches", "Unlimited Users", "100GB Storage", "24/7 Phone Support", "API Access", "Custom Reports", "Dedicated Account Manager", "Data Export", "White Label Options", "Training & Onboarding"]'::jsonb,
  updated_at = NOW()
WHERE plan_name = 'Enterprise' OR plan_code = 'enterprise';

-- Verify the update
SELECT 
  plan_code,
  plan_name,
  '₹' || price_monthly::TEXT || '/mo' AS inr_monthly,
  '₹' || price_yearly::TEXT || '/yr' AS inr_yearly,
  '₹' || renewal_yearly::TEXT || '/yr renewal' AS inr_renewal,
  '$' || price_monthly_usd::TEXT || '/mo' AS usd_monthly,
  '$' || price_yearly_usd::TEXT || '/yr' AS usd_yearly,
  '$' || renewal_yearly_usd::TEXT || '/yr renewal' AS usd_renewal
FROM public.subscription_plans
WHERE plan_code = 'enterprise';

-- ============================================================================
-- Verification
-- ============================================================================
-- Expected Results:
-- Enterprise Plan:
--   INR: ₹2,167/mo, ₹26,000/yr, ₹13,000/yr renewal (50% OFF)
--   USD: $35/mo, $350/yr, $175/yr renewal (50% OFF)
-- ============================================================================
