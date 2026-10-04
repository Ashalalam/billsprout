-- Auto-confirm email addresses for new signups
-- This trigger automatically confirms email addresses when users sign up
-- Useful for internal applications where email verification is not required

-- Create a function to auto-confirm emails
CREATE OR REPLACE FUNCTION public.auto_confirm_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update the user's email_confirmed_at timestamp if it's null
  IF NEW.email_confirmed_at IS NULL THEN
    NEW.email_confirmed_at := NOW();
    NEW.confirmation_token := NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users table to auto-confirm emails
DROP TRIGGER IF EXISTS on_auth_user_created_auto_confirm ON auth.users;

CREATE TRIGGER on_auth_user_created_auto_confirm
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_user();

-- Also create a function to manually confirm existing users if needed
CREATE OR REPLACE FUNCTION public.confirm_user_email(user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET 
    email_confirmed_at = NOW(),
    confirmation_token = NULL
  WHERE id = user_id
  AND email_confirmed_at IS NULL;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_user_email(UUID) TO service_role;

COMMENT ON FUNCTION public.auto_confirm_user() IS 'Automatically confirms email addresses for new user signups';
COMMENT ON FUNCTION public.confirm_user_email(UUID) IS 'Manually confirm a user email address by user ID';
