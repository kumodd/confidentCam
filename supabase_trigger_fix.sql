-- Better Solution: Use Database Trigger to Auto-Create Users Record
-- This runs with elevated privileges and bypasses RLS
-- Run this in your Supabase SQL Editor

-- 1. Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Insert into users table with ON CONFLICT to prevent duplicates
  INSERT INTO public.users (id, email, phone, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Also create initial progress record with ON CONFLICT
  INSERT INTO public.user_progress (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the auth user creation
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create trigger on auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 3. Grant execute permission
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
