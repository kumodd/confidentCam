-- ============================================
-- CONTENT_SCRIPTS TABLE RLS POLICIES (CORRECTED)
-- Run this in Supabase SQL Editor
-- ============================================
-- 
-- IMPORTANT: Your content_scripts table has user_id as TEXT type
-- This policy converts auth.uid() to TEXT for comparison
-- ============================================

-- First, drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can insert own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can update own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can delete own scripts" ON public.content_scripts;

-- Enable RLS if not already enabled
ALTER TABLE public.content_scripts ENABLE ROW LEVEL SECURITY;

-- ============================================
-- CREATE NEW RLS POLICIES
-- Note: We cast auth.uid() to TEXT to match your user_id column type
-- ============================================

-- Users can read their own scripts
CREATE POLICY "Users can read own scripts" ON public.content_scripts
    FOR SELECT USING (auth.uid()::text = user_id);

-- Users can insert their own scripts
CREATE POLICY "Users can insert own scripts" ON public.content_scripts
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Users can update their own scripts
CREATE POLICY "Users can update own scripts" ON public.content_scripts
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Users can delete their own scripts
CREATE POLICY "Users can delete own scripts" ON public.content_scripts
    FOR DELETE USING (auth.uid()::text = user_id);

-- Enable Realtime for synchronization with mobile app
ALTER PUBLICATION supabase_realtime ADD TABLE public.content_scripts;
