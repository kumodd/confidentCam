-- ============================================
-- MINIMAL WORKING AUTH SETUP - RUN THIS FIRST
-- Delete everything and start fresh
-- ============================================

-- 1. DROP EXISTING TRIGGERS
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
DROP TRIGGER IF EXISTS update_user_progress_updated_at ON public.user_progress;

-- 2. DROP EXISTING FUNCTIONS
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

-- 3. DROP EXISTING TABLES (careful - this deletes data!)
DROP TABLE IF EXISTS public.user_progress CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ============================================
-- 4. CREATE USERS TABLE (FRESH)
-- ============================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,  -- NULL allowed - optional
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 5. CREATE USER_PROGRESS TABLE (FRESH)
-- ============================================
CREATE TABLE public.user_progress (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  current_day INTEGER DEFAULT 0 NOT NULL,
  total_days_completed INTEGER DEFAULT 0 NOT NULL,
  streak_count INTEGER DEFAULT 0 NOT NULL,
  last_completion_date DATE,
  warmup_0_done BOOLEAN DEFAULT FALSE NOT NULL,
  warmup_1_done BOOLEAN DEFAULT FALSE NOT NULL,
  warmup_2_done BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 6. ENABLE RLS
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. CREATE RLS POLICIES - USERS
-- ============================================

-- SELECT: Users can read their own profile
CREATE POLICY "users_select_own"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- INSERT: Users can create their own profile
CREATE POLICY "users_insert_own"
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their own profile
CREATE POLICY "users_update_own"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- DELETE: Users can delete their own profile
CREATE POLICY "users_delete_own"
  ON public.users
  FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- ============================================
-- 8. CREATE RLS POLICIES - USER_PROGRESS
-- ============================================

CREATE POLICY "progress_select_own"
  ON public.user_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "progress_insert_own"
  ON public.user_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "progress_update_own"
  ON public.user_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 9. CREATE TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insert user record (phone can be NULL)
  INSERT INTO public.users (id, email, phone, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,  -- This will be NULL for email signups, and that's OK!
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET email = COALESCE(EXCLUDED.email, users.email),
        phone = COALESCE(EXCLUDED.phone, users.phone),
        updated_at = NOW();
  
  -- Insert progress record
  INSERT INTO public.user_progress (user_id, created_at, updated_at)
  VALUES (NEW.id, NOW(), NOW())
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- 10. CREATE TRIGGER
-- ============================================

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 11. CREATE UPDATED_AT TRIGGERS
-- ============================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_progress_updated_at
  BEFORE UPDATE ON public.user_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 12. GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.user_progress TO authenticated;
GRANT SELECT ON public.users TO anon;  -- Needed for signup before auth

-- ============================================
-- 13. VERIFY SETUP
-- ============================================

-- Check tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('users', 'user_progress');

-- Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'user_progress');

-- Check trigger exists
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- ============================================
-- SETUP COMPLETE!
-- ============================================
-- Test by signing up with email in your app
-- Check logs with: SELECT * FROM public.users;
-- ============================================
