-- ============================================================================
-- RAZORPAY CONFIGURATION FOR SUPABASE
-- ============================================================================
-- This script adds the Razorpay secret key to Supabase environment variables
-- Execute this in Supabase SQL Editor or add via Dashboard

-- Note: Environment variables for Edge Functions are set via Supabase Dashboard:
-- 1. Go to https://supabase.com/dashboard
-- 2. Select project: juvbhjqaioevpusnmonz
-- 3. Settings → Edge Functions → Environment Variables
-- 4. Add: RAZORPAY_KEY_SECRET = njOECeGNbHoztur3f5pLcniK

-- For reference, your Razorpay configuration:
-- Key ID (frontend): rzp_test_TlQpbkhf8aylDg
-- Key Secret (backend): njOECeGNbHoztur3f5pLcniK
-- Test Mode: true

-- ============================================================================
-- INSTRUCTIONS TO ADD ENVIRONMENT VARIABLE:
-- ============================================================================
-- 1. Go to: https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/functions
-- 2. Click on "Environment variables" tab
-- 3. Click "Add new variable"
-- 4. Name: RAZORPAY_KEY_SECRET
-- 5. Value: njOECeGNbHoztur3f5pLcniK
-- 6. Click "Save"
-- 7. Redeploy edge functions:
--    - supabase functions deploy create-razorpay-order
--    - supabase functions deploy verify-razorpay-payment