-- ============================================================================
-- Remove the auto-confirm trigger that's blocking signup
-- ============================================================================
-- The BEFORE INSERT trigger on auth.users is interfering with Supabase's
-- internal auth system and causing signup to fail completely.
-- 
-- Instead of using a trigger, email confirmation should be disabled in the
-- Supabase Dashboard: Authentication -> Providers -> Email -> Confirm email: OFF
-- ============================================================================

-- Drop the problematic trigger
DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;

-- Drop the trigger function (keep the manual confirm function)
DROP FUNCTION IF EXISTS public.auto_confirm_user();

-- Keep the manual confirm function for existing users
-- This function can still be used to manually confirm users if needed
COMMENT ON FUNCTION public.confirm_user_email(UUID) IS 'Manually confirm a user email address by user ID - Safe to use after signup';
