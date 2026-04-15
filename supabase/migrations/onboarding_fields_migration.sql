-- =============================================================================
-- ConfidantCam Onboarding Fields Migration
-- Run this in your Supabase SQL Editor if you are getting "Failed to save onboarding data"
-- =============================================================================

-- Add newly collected personal info fields to user_profiles
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS custom_goal TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS goal_category TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS onboarding_answers JSONB DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS language_preference TEXT DEFAULT 'en';
