-- ============================================================================
-- STEP 1: Remove the problematic trigger
-- ============================================================================
DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;
DROP FUNCTION IF EXISTS public.auto_confirm_user();

-- ============================================================================
-- STEP 2: Check current auth configuration
-- ============================================================================
-- Check if there are any remaining triggers on auth.users
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
  AND event_object_schema = 'auth';

-- ============================================================================
-- STEP 3: Verify email confirmation setting
-- ============================================================================
-- Check the auth.config table for email confirmation settings
SELECT * FROM auth.config WHERE parameter = 'CONFIRM_EMAIL';

-- If the above doesn't work, try:
SHOW mailer_autoconfirm;
