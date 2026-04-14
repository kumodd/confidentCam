-- =============================================================================
-- ConfidantCam Auth Hardening Migration
-- Run in Supabase SQL Editor → Run this ONCE on your existing database.
-- Matches code changes from the April 2026 auth audit.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. USERS TABLE: Make phone nullable (email users have no phone)
--    ALSO: Add email column so it can be stored and returned to the app.
-- -----------------------------------------------------------------------------

-- Make phone nullable — email-only users cannot provide a phone number
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;

-- Add email column for email-authenticated users
-- This is nullable because phone users may not have an email
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;

-- Add a unique index on email to prevent duplicate accounts
-- (Only indexes non-null values, so phone-only users without email are safe)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)
    WHERE email IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2. USER_PROFILES TABLE: Add updated_at for tracking profile edits
-- -----------------------------------------------------------------------------
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- Auto-update the updated_at column on every profile UPDATE
CREATE OR REPLACE FUNCTION update_user_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profiles_updated_at();

-- -----------------------------------------------------------------------------
-- 3. VERIFY: Confirm existing RLS policies cover Edit Profile writes
--    (These should already exist from the original schema — this is a no-op
--     if already applied, safe to re-run)
-- -----------------------------------------------------------------------------

-- User profiles update policy (already in schema, keeping for completeness)
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Users table update policy (already in schema)
DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

-- -----------------------------------------------------------------------------
-- 4. SCHEMA REFERENCE UPDATE: Add comments for clarity
-- -----------------------------------------------------------------------------
COMMENT ON COLUMN users.phone IS 'Phone number in E.164 format (e.g. +919876543210). NULL for email-only users.';
COMMENT ON COLUMN users.email IS 'Email address for email-authenticated users. NULL for phone-only users.';
COMMENT ON COLUMN users.display_name IS 'Human-readable name shown on dashboard. Collected during OTP name dialog or Edit Profile.';
