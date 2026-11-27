-- =============================================================================
-- ConfidentCam Auth & Remote Config Security Hardening Migration
-- Date: 2026-11-27
--
-- Fixes:
--   1. Restrict public.app_config SELECT RLS so secrets (openai_api_key, etc.)
--      are never readable by anon/authenticated clients; keep full read for admins.
--   2. Sanitize stale/conflicting app_config rows (total_days, total_warmups,
--      app_version, openai_model, enable_phone_auth, enable_google_auth, legacy theme).
--   3. Enable RLS on public.content_scripts and replace leaky policies with
--      strict owner-only policies.
--   4. Remove overly permissive public.web_sessions policies and add safe exact-token RPC.
--   5. Deduplicate overlapping {public} vs {authenticated} RLS policies on
--      public.users and public.user_progress.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. PUBLIC.APP_CONFIG: Lock down secret exposure in RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read app_config" ON public.app_config;
DROP POLICY IF EXISTS "Public read safe active app_config" ON public.app_config;
DROP POLICY IF EXISTS "Admins can read all app_config" ON public.app_config;
DROP POLICY IF EXISTS "Admins can insert app_config" ON public.app_config;
DROP POLICY IF EXISTS "Admins can update app_config" ON public.app_config;
DROP POLICY IF EXISTS "Admins can delete app_config" ON public.app_config;

CREATE POLICY "Public read safe active app_config"
    ON public.app_config
    FOR SELECT
    TO anon, authenticated
    USING (
        is_active = true
        AND key <> 'openai_api_key'
        AND key !~* '(api_key|secret|password|private_key)'
    );

CREATE POLICY "Admins can read all app_config"
    ON public.app_config
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can insert app_config"
    ON public.app_config
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can update app_config"
    ON public.app_config
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can delete app_config"
    ON public.app_config
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- 2. PUBLIC.APP_CONFIG: Clean up stale/conflicting rows before client wiring
-- -----------------------------------------------------------------------------
UPDATE public.app_config
SET value = '30', value_type = 'int', is_active = true, updated_at = NOW()
WHERE key = 'total_days';

UPDATE public.app_config
SET value = '3', value_type = 'int', is_active = true, updated_at = NOW()
WHERE key = 'total_warmups';

UPDATE public.app_config
SET value = '1.2.2', value_type = 'string', is_active = true, updated_at = NOW()
WHERE key = 'app_version';

UPDATE public.app_config
SET value = 'gpt-4o-mini', value_type = 'string', is_active = true, updated_at = NOW()
WHERE key = 'openai_model';

-- Align auth toggles: use value='true'/'false' with is_active=true & value_type='bool'
UPDATE public.app_config
SET value = 'true', value_type = 'bool', is_active = true, updated_at = NOW()
WHERE key = 'enable_email_auth';

UPDATE public.app_config
SET value = 'false', value_type = 'bool', is_active = true, updated_at = NOW()
WHERE key = 'enable_phone_auth';

UPDATE public.app_config
SET value = 'false', value_type = 'bool', is_active = true, updated_at = NOW()
WHERE key = 'enable_google_auth';

-- Deactivate legacy dark-indigo theme & splash config rows (superseded by Sage & Olive theme)
UPDATE public.app_config
SET is_active = false, updated_at = NOW()
WHERE category IN ('theme', 'splash');

-- -----------------------------------------------------------------------------
-- 3. PUBLIC.FEATURE_FLAGS: Ensure clean RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read feature_flags" ON public.feature_flags;
DROP POLICY IF EXISTS "Admins can insert feature_flags" ON public.feature_flags;
DROP POLICY IF EXISTS "Admins can update feature_flags" ON public.feature_flags;
DROP POLICY IF EXISTS "Admins can delete feature_flags" ON public.feature_flags;

CREATE POLICY "Public read feature_flags"
    ON public.feature_flags
    FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Admins can insert feature_flags"
    ON public.feature_flags
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can update feature_flags"
    ON public.feature_flags
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can delete feature_flags"
    ON public.feature_flags
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- 4. PUBLIC.CONTENT_SCRIPTS: Enable RLS & enforce strict owner isolation
-- -----------------------------------------------------------------------------
ALTER TABLE public.content_scripts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can delete own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can manage their own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can read own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "Users can update own scripts" ON public.content_scripts;
DROP POLICY IF EXISTS "content_scripts_select_own" ON public.content_scripts;
DROP POLICY IF EXISTS "content_scripts_insert_own" ON public.content_scripts;
DROP POLICY IF EXISTS "content_scripts_update_own" ON public.content_scripts;
DROP POLICY IF EXISTS "content_scripts_delete_own" ON public.content_scripts;

CREATE POLICY "content_scripts_select_own"
    ON public.content_scripts
    FOR SELECT
    TO authenticated
    USING ((auth.uid())::text = user_id);

CREATE POLICY "content_scripts_insert_own"
    ON public.content_scripts
    FOR INSERT
    TO authenticated
    WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "content_scripts_update_own"
    ON public.content_scripts
    FOR UPDATE
    TO authenticated
    USING ((auth.uid())::text = user_id)
    WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "content_scripts_delete_own"
    ON public.content_scripts
    FOR DELETE
    TO authenticated
    USING ((auth.uid())::text = user_id);

-- -----------------------------------------------------------------------------
-- 5. PUBLIC.WEB_SESSIONS: Close table-wide read & spoofable update holes
-- -----------------------------------------------------------------------------
ALTER TABLE public.web_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow reading sessions by token" ON public.web_sessions;
DROP POLICY IF EXISTS "Allow authenticated users to update pending sessions" ON public.web_sessions;
DROP POLICY IF EXISTS "Read pending or own sessions" ON public.web_sessions;
DROP POLICY IF EXISTS "Authenticated users can update valid sessions" ON public.web_sessions;

CREATE POLICY "Read pending or own sessions"
    ON public.web_sessions
    FOR SELECT
    TO anon, authenticated
    USING (
        (status = 'pending' AND expires_at > NOW())
        OR (auth.uid() = user_id)
    );

CREATE POLICY "Authenticated users can update valid sessions"
    ON public.web_sessions
    FOR UPDATE
    TO authenticated
    USING (status = 'pending' AND expires_at > NOW())
    WITH CHECK (
        user_id = auth.uid()
        AND status IN ('authenticated', 'expired')
    );

-- Safe exact-token status lookup for web portal polling without exposing table scan
CREATE OR REPLACE FUNCTION public.get_web_session_by_token(p_session_token TEXT)
RETURNS TABLE (
    id UUID,
    status TEXT,
    user_id UUID,
    authenticated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT ws.id, ws.status, ws.user_id, ws.authenticated_at, ws.expires_at
    FROM public.web_sessions ws
    WHERE ws.session_token = p_session_token
      AND ws.expires_at > NOW() - INTERVAL '10 minutes'
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_web_session_by_token(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_web_session_by_token(TEXT) TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6. PUBLIC.USERS & PUBLIC.USER_PROGRESS: Remove duplicate {public} policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;

DROP POLICY IF EXISTS "Users can insert own progress" ON public.user_progress;
DROP POLICY IF EXISTS "Users can read own progress" ON public.user_progress;
DROP POLICY IF EXISTS "Users can update own progress" ON public.user_progress;

DROP POLICY IF EXISTS "progress_delete_own" ON public.user_progress;
CREATE POLICY "progress_delete_own"
    ON public.user_progress
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

COMMIT;
