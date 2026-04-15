-- ============================================================
-- FIX: QR Session RLS — Restrict over-permissive SELECT policy
-- Run this in Supabase SQL Editor AFTER web_sessions_setup.sql
-- ============================================================

-- Drop the over-permissive policy that exposes ALL sessions
DROP POLICY IF EXISTS "Anyone can read pending sessions by token" ON public.web_sessions;

-- Replacement: only pending sessions readable anonymously;
--   authenticated users can see their own sessions.
CREATE POLICY "Read pending or own sessions"
    ON public.web_sessions
    FOR SELECT
    TO anon, authenticated
    USING (
        status = 'pending'          -- Anonymous users: only pending (for QR scanning)
        OR auth.uid() = user_id     -- Authenticated users: can see their own sessions
    );

-- ============================================================
-- FIX: Also add expires_at guard to the UPDATE policy so
--   the mobile app can never authenticate an expired session.
-- ============================================================

DROP POLICY IF EXISTS "Authenticated users can update sessions" ON public.web_sessions;

CREATE POLICY "Authenticated users can update valid sessions"
    ON public.web_sessions
    FOR UPDATE
    TO authenticated
    USING (
        status = 'pending'
        AND expires_at > NOW()   -- Reject expired sessions at the DB level
    )
    WITH CHECK (user_id = auth.uid());
