-- ============================================
-- WEB SESSIONS TABLE FOR QR AUTHENTICATION
-- Run this in Supabase SQL Editor
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. CREATE WEB_SESSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.web_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_token TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'authenticated', 'expired')),
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    authenticated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '5 minutes')
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_web_sessions_token ON public.web_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_web_sessions_status ON public.web_sessions(status);
CREATE INDEX IF NOT EXISTS idx_web_sessions_user ON public.web_sessions(user_id);

-- ============================================
-- 3. ENABLE RLS
-- ============================================
ALTER TABLE public.web_sessions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. RLS POLICIES
-- ============================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Anyone can create pending sessions" ON public.web_sessions;
DROP POLICY IF EXISTS "Anyone can read pending sessions by token" ON public.web_sessions;
DROP POLICY IF EXISTS "Authenticated users can update sessions" ON public.web_sessions;
DROP POLICY IF EXISTS "Users can read their own sessions" ON public.web_sessions;

-- Allow anonymous users to create pending sessions (for QR display)
CREATE POLICY "Anyone can create pending sessions"
    ON public.web_sessions
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (status = 'pending' AND user_id IS NULL);

-- Allow reading pending sessions by token (for QR scanning)
CREATE POLICY "Anyone can read pending sessions by token"
    ON public.web_sessions
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow authenticated users to update session (set user_id when authenticating)
CREATE POLICY "Authenticated users can update sessions"
    ON public.web_sessions
    FOR UPDATE
    TO authenticated
    USING (status = 'pending')
    WITH CHECK (user_id = auth.uid());

-- ============================================
-- 5. AUTO-EXPIRE FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.expire_old_web_sessions()
RETURNS TRIGGER AS $$
BEGIN
    -- Expire sessions older than 5 minutes that are still pending
    UPDATE public.web_sessions
    SET status = 'expired'
    WHERE status = 'pending' 
      AND expires_at < NOW();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to run on new session creation
DROP TRIGGER IF EXISTS trigger_expire_old_sessions ON public.web_sessions;
CREATE TRIGGER trigger_expire_old_sessions
    AFTER INSERT ON public.web_sessions
    EXECUTE FUNCTION public.expire_old_web_sessions();

-- ============================================
-- 6. GRANT PERMISSIONS
-- ============================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.web_sessions TO anon, authenticated;

-- ============================================
-- 7. ENABLE REALTIME FOR web_sessions
-- ============================================
-- This allows the web portal to listen for session status changes
ALTER PUBLICATION supabase_realtime ADD TABLE public.web_sessions;

-- ============================================
-- SETUP COMPLETE!
-- ============================================
-- The web portal can now:
-- 1. Create pending sessions with unique tokens
-- 2. Display QR codes with session tokens
-- 3. Poll for status changes
-- 4. Mobile app can authenticate sessions
-- ============================================
