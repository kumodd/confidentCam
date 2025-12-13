-- ============================================
-- COMPLETE AUTH SETUP FOR CONFIDENTCAM
-- Run this script in Supabase SQL Editor
-- ============================================

-- 1. ENABLE REQUIRED EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 2. CREATE/UPDATE USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,  -- Nullable, can be NULL for email-only signups
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. CREATE/UPDATE USER_PROGRESS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_progress (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  current_day INTEGER DEFAULT 0,
  total_days_completed INTEGER DEFAULT 0,
  streak_count INTEGER DEFAULT 0,
  last_completion_date DATE,
  warmup_0_done BOOLEAN DEFAULT FALSE,
  warmup_1_done BOOLEAN DEFAULT FALSE,
  warmup_2_done BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. DROP EXISTING RLS POLICIES
-- ============================================
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.users;

DROP POLICY IF EXISTS "Users can view their own progress" ON public.user_progress;
DROP POLICY IF EXISTS "Users can insert their own progress" ON public.user_progress;
DROP POLICY IF EXISTS "Users can update their own progress" ON public.user_progress;

-- ============================================
-- 5. ENABLE RLS
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 6. CREATE RLS POLICIES FOR USERS TABLE
-- ============================================

-- Allow users to view their own profile
CREATE POLICY "Users can view their own profile"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Allow users to insert their own profile (needed for trigger fallback)
CREATE POLICY "Users can insert their own profile"
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to delete their own profile
CREATE POLICY "Users can delete their own profile"
  ON public.users
  FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- ============================================
-- 7. CREATE RLS POLICIES FOR USER_PROGRESS TABLE
-- ============================================

-- Allow users to view their own progress
CREATE POLICY "Users can view their own progress"
  ON public.user_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow users to insert their own progress
CREATE POLICY "Users can insert their own progress"
  ON public.user_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own progress
CREATE POLICY "Users can update their own progress"
  ON public.user_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 8. CREATE TRIGGER FUNCTION FOR NEW USERS
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insert into users table
  INSERT INTO public.users (id, email, phone, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        updated_at = NOW();
  
  -- Insert into user_progress table
  INSERT INTO public.user_progress (user_id, created_at)
  VALUES (NEW.id, NOW())
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail auth user creation
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- 9. CREATE TRIGGER ON AUTH.USERS
-- ============================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.user_progress TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- ============================================
-- 11. CREATE UPDATED_AT TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to users table
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Apply to user_progress table
DROP TRIGGER IF EXISTS update_user_progress_updated_at ON public.user_progress;
CREATE TRIGGER update_user_progress_updated_at
  BEFORE UPDATE ON public.user_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 12. VERIFY SETUP
-- ============================================

-- Check if policies are created
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'user_progress');

-- Check if triggers are created
SELECT 
  trigger_name, 
  event_manipulation, 
  event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public' OR event_object_schema = 'auth';

-- ============================================
-- SETUP COMPLETE!
-- ============================================
-- You can now:
-- 1. Sign up with email/phone
-- 2. Trigger will auto-create user records
-- 3. RLS policies protect user data
-- ============================================
