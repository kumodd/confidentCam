-- ConfidentCam Supabase Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- USERS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT,                          -- E.164 format (+919876543210). NULL for email-only users.
    email TEXT,                          -- NULL for phone-only users.
    display_name TEXT,                   -- Collected in OTP name dialog or Edit Profile screen.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Unique index on email (only for non-null values)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)
    WHERE email IS NOT NULL;

-- =============================================================================
-- USER PROFILES TABLE (Onboarding data)
-- =============================================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    goal TEXT,
    niche TEXT,
    fear TEXT,
    experience TEXT,
    timezone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ              -- Auto-set by trigger on every UPDATE
);

-- =============================================================================
-- USER PROGRESS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS user_progress (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    warmup_0_complete BOOLEAN DEFAULT FALSE,
    warmup_1_complete BOOLEAN DEFAULT FALSE,
    warmup_2_complete BOOLEAN DEFAULT FALSE,
    current_day INTEGER DEFAULT 0,
    streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_completed_date DATE,
    challenge_started_at TIMESTAMPTZ,
    challenge_completed_at TIMESTAMPTZ
);

-- =============================================================================
-- DAILY SCRIPTS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS daily_scripts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    script_type TEXT NOT NULL CHECK (script_type IN ('segmented', 'full')),
    script_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, day_number)
);

-- =============================================================================
-- DAILY COMPLETIONS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS daily_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    video_filename TEXT NOT NULL,
    duration_seconds INTEGER,
    checklist_responses TEXT[],
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, day_number)
);

-- =============================================================================
-- AI FEEDBACK TABLE (For Premium)
-- =============================================================================
CREATE TABLE IF NOT EXISTS ai_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    feedback_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, day_number)
);

-- =============================================================================
-- ACHIEVEMENTS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    achievement_key TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_key)
);

-- =============================================================================
-- PREMIUM STATUS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS premium_status (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    is_premium BOOLEAN DEFAULT FALSE,
    subscription_type TEXT CHECK (subscription_type IN ('monthly', 'yearly', 'lifetime')),
    expires_at TIMESTAMPTZ,
    purchased_at TIMESTAMPTZ,
    receipt_data TEXT
);

-- =============================================================================
-- NOTIFICATION SETTINGS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS notification_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    daily_reminder BOOLEAN DEFAULT TRUE,
    reminder_time TIME DEFAULT '09:00',
    streak_alerts BOOLEAN DEFAULT TRUE,
    weekly_summary BOOLEAN DEFAULT TRUE
);

-- =============================================================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_scripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE premium_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;

-- Users table policies
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data" ON users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own data" ON users;
CREATE POLICY "Users can insert own data" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- User profiles policies
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
CREATE POLICY "Users can read own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- User progress policies
DROP POLICY IF EXISTS "Users can read own progress" ON user_progress;
CREATE POLICY "Users can read own progress" ON user_progress
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own progress" ON user_progress;
CREATE POLICY "Users can insert own progress" ON user_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own progress" ON user_progress;
CREATE POLICY "Users can update own progress" ON user_progress
    FOR UPDATE USING (auth.uid() = user_id);

-- Daily scripts policies
DROP POLICY IF EXISTS "Users can read own scripts" ON daily_scripts;
CREATE POLICY "Users can read own scripts" ON daily_scripts
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own scripts" ON daily_scripts;
CREATE POLICY "Users can insert own scripts" ON daily_scripts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own scripts" ON daily_scripts;
CREATE POLICY "Users can update own scripts" ON daily_scripts
    FOR UPDATE USING (auth.uid() = user_id);

-- Daily completions policies
DROP POLICY IF EXISTS "Users can read own completions" ON daily_completions;
CREATE POLICY "Users can read own completions" ON daily_completions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own completions" ON daily_completions;
CREATE POLICY "Users can insert own completions" ON daily_completions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- AI feedback policies
DROP POLICY IF EXISTS "Users can read own feedback" ON ai_feedback;
CREATE POLICY "Users can read own feedback" ON ai_feedback
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own feedback" ON ai_feedback;
CREATE POLICY "Users can insert own feedback" ON ai_feedback
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Achievements policies
DROP POLICY IF EXISTS "Users can read own achievements" ON achievements;
CREATE POLICY "Users can read own achievements" ON achievements
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own achievements" ON achievements;
CREATE POLICY "Users can insert own achievements" ON achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Premium status policies (read-only for users)
DROP POLICY IF EXISTS "Users can read own premium status" ON premium_status;
CREATE POLICY "Users can read own premium status" ON premium_status
    FOR SELECT USING (auth.uid() = user_id);

-- Notification settings policies
DROP POLICY IF EXISTS "Users can read own notification settings" ON notification_settings;
CREATE POLICY "Users can read own notification settings" ON notification_settings
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notification settings" ON notification_settings;
CREATE POLICY "Users can insert own notification settings" ON notification_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notification settings" ON notification_settings;
CREATE POLICY "Users can update own notification settings" ON notification_settings
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_daily_scripts_user_day ON daily_scripts(user_id, day_number);
CREATE INDEX IF NOT EXISTS idx_daily_completions_user_day ON daily_completions(user_id, day_number);
CREATE INDEX IF NOT EXISTS idx_achievements_user ON achievements(user_id);

-- =============================================================================
-- ONBOARDING QUESTIONS TABLE (Dynamic questions from Supabase)
-- =============================================================================
CREATE TABLE IF NOT EXISTS onboarding_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_key TEXT NOT NULL UNIQUE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL DEFAULT '[]',
    is_multi_select BOOLEAN DEFAULT FALSE,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE onboarding_questions ENABLE ROW LEVEL SECURITY;

-- Everyone can read questions (public)
DROP POLICY IF EXISTS "Anyone can read onboarding questions" ON onboarding_questions;
CREATE POLICY "Anyone can read onboarding questions" ON onboarding_questions
    FOR SELECT USING (true);

-- Insert default onboarding questions
INSERT INTO onboarding_questions (question_key, question_text, options, is_multi_select, order_index) VALUES
('challenges', 'What challenges do you face on camera?', 
 '["I don''t like how I look", "My voice sounds weird", "I forget what to say", "I feel fake/unnatural", "Fear of judgment", "Perfectionism", "Low confidence", "Technical issues"]'::jsonb, 
 true, 1),
('content_style', 'What type of content do you want to create?',
 '["Educational/Teaching", "Motivational/Coaching", "Entertainment/Vlogs", "Product reviews", "Behind the scenes", "Tutorials/How-to", "Storytelling", "Live streams"]'::jsonb,
 true, 2),
('platform', 'Which platforms will you post on?',
 '["Instagram Reels", "YouTube", "TikTok", "LinkedIn", "Facebook", "Twitter/X", "Personal website", "Online courses"]'::jsonb,
 true, 3),
('time_commitment', 'How much time can you dedicate daily?',
 '["5-10 minutes", "10-20 minutes", "20-30 minutes", "30+ minutes"]'::jsonb,
 false, 4)
ON CONFLICT (question_key) DO NOTHING;

-- =============================================================================
-- UPDATE USER_PROFILES TABLE (Add personal info fields)
-- =============================================================================
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS custom_goal TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS goal_category TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS onboarding_answers JSONB DEFAULT '{}';

-- =============================================================================
-- GOAL OPTIONS TABLE (Predefined goals)
-- =============================================================================
CREATE TABLE IF NOT EXISTS goal_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    goal_text TEXT NOT NULL,
    goal_key TEXT NOT NULL UNIQUE,
    description TEXT,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Enable RLS
ALTER TABLE goal_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read goal options" ON goal_options;
CREATE POLICY "Anyone can read goal options" ON goal_options
    FOR SELECT USING (true);

-- Insert default goals
INSERT INTO goal_options (goal_key, goal_text, description, order_index) VALUES
('10k_followers', 'Gain 10K Instagram followers in 30 days', 'Build your audience with engaging content', 1),
('1l_instagram', 'Earn ₹1 Lakh/month through Instagram', 'Monetize your content and brand deals', 2),
('1l_video_editing', 'Earn ₹1 Lakh/month with video editing', 'Offer professional video services', 3),
('personal_brand', 'Build a strong personal brand', 'Establish yourself as an authority', 4),
('youtube_channel', 'Start and grow a YouTube channel', 'Create long-form video content', 5),
('coaching_business', 'Launch a coaching/consulting business', 'Share your expertise online', 6),
('custom', 'I have a custom goal', 'Define your own unique goal', 99)
ON CONFLICT (goal_key) DO NOTHING;

-- =============================================================================
-- CHALLENGE EXTENSIONS TABLE (For post-30-day content)
-- =============================================================================
CREATE TABLE IF NOT EXISTS challenge_extensions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    extension_number INTEGER NOT NULL,
    start_day INTEGER NOT NULL,
    end_day INTEGER NOT NULL,
    scripts JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, extension_number)
);

-- Enable RLS
ALTER TABLE challenge_extensions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own extensions" ON challenge_extensions;
CREATE POLICY "Users can read own extensions" ON challenge_extensions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own extensions" ON challenge_extensions;
CREATE POLICY "Users can insert own extensions" ON challenge_extensions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Index for extensions
CREATE INDEX IF NOT EXISTS idx_challenge_extensions_user ON challenge_extensions(user_id);

-- =============================================================================
-- LANGUAGE OPTIONS TABLE (For bilingual content preferences)
-- =============================================================================
CREATE TABLE IF NOT EXISTS language_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    language_code TEXT NOT NULL UNIQUE,
    language_name TEXT NOT NULL,
    native_name TEXT NOT NULL,
    description TEXT,
    is_bilingual BOOLEAN DEFAULT FALSE,
    primary_language TEXT,
    secondary_language TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE language_options ENABLE ROW LEVEL SECURITY;

-- Anyone can read language options
DROP POLICY IF EXISTS "Anyone can read language options" ON language_options;
CREATE POLICY "Anyone can read language options" ON language_options
    FOR SELECT USING (true);

-- Insert default language options (including bilingual)
INSERT INTO language_options (language_code, language_name, native_name, description, is_bilingual, primary_language, secondary_language, order_index) VALUES
('en', 'English', 'English', 'Pure English content', FALSE, 'en', NULL, 1),
('hi', 'Hindi', 'हिन्दी', 'Pure Hindi content', FALSE, 'hi', NULL, 2),
('hinglish', 'Hinglish', 'हिंग्लिश', 'Mix of Hindi + English - perfect for Indian creators!', TRUE, 'hi', 'en', 3),
('ta', 'Tamil', 'தமிழ்', 'Pure Tamil content', FALSE, 'ta', NULL, 4),
('te', 'Telugu', 'తెలుగు', 'Pure Telugu content', FALSE, 'te', NULL, 5),
('tanglish', 'Tanglish', 'தமிழிஷ்', 'Mix of Tamil + English', TRUE, 'ta', 'en', 6),
('mr', 'Marathi', 'मराठी', 'Pure Marathi content', FALSE, 'mr', NULL, 7),
('bn', 'Bengali', 'বাংলা', 'Pure Bengali content', FALSE, 'bn', NULL, 8),
('gu', 'Gujarati', 'ગુજરાતી', 'Pure Gujarati content', FALSE, 'gu', NULL, 9),
('kn', 'Kannada', 'ಕನ್ನಡ', 'Pure Kannada content', FALSE, 'kn', NULL, 10),
('ml', 'Malayalam', 'മലയാളം', 'Pure Malayalam content', FALSE, 'ml', NULL, 11),
('pa', 'Punjabi', 'ਪੰਜਾਬੀ', 'Pure Punjabi content', FALSE, 'pa', NULL, 12)
ON CONFLICT (language_code) DO NOTHING;

-- Add language_preference column to user_profiles if not exists
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS language_preference TEXT DEFAULT 'en';

-- Index for language lookups
CREATE INDEX IF NOT EXISTS idx_language_options_active ON language_options(is_active, order_index);

-- =============================================================================
-- CREATOR GUIDES TABLE (Dashboard Tips & Content)
-- =============================================================================
CREATE TABLE IF NOT EXISTS guides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guide_key TEXT NOT NULL UNIQUE,
    order_index INTEGER NOT NULL,
    title TEXT NOT NULL,
    emoji TEXT NOT NULL,
    summary TEXT NOT NULL,
    content TEXT[] NOT NULL,
    youtube_url TEXT,
    youtube_title TEXT,
    action_route TEXT,
    action_title TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE guides ENABLE ROW LEVEL SECURITY;

-- Allow read-only access for all users
DROP POLICY IF EXISTS "Anyone can read guides" ON guides;
CREATE POLICY "Anyone can read guides" ON guides
    FOR SELECT USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_guides_active ON guides(is_active, order_index);

-- Insert default guides
INSERT INTO guides (guide_key, order_index, title, emoji, summary, content, youtube_url, youtube_title, action_route, action_title) VALUES
('overcoming_fear', 1, 'Overcoming Fear', '💪', 'Why you feel afraid and how to push through', ARRAY['Fear of judgment is completely normal. Every successful creator has felt this.', 'Your first 10 videos will feel awkward - that''s the learning curve, not failure.', 'Focus on progress, not perfection. Each video makes you 1% better.', 'Remember: Most people are too busy with their own lives to judge yours.', 'The discomfort you feel means you''re growing. Embrace it!'], 'https://www.youtube.com/watch?v=ZQUxL4Jm1Lo', 'How to Overcome Fear of Recording', '/warmup', 'Practice a Warmup'),
('consistency', 2, 'Consistency > Perfection', '📅', 'Why showing up daily beats being perfect', ARRAY['Posting consistently builds trust with the algorithm and audience.', 'A "good enough" video today beats a "perfect" video never posted.', '30 days of daily practice = more growth than 1 year of occasional perfection.', 'Your audience connects with authenticity, not polish.', 'Set a specific time each day for recording - make it a habit.', 'Track your streak and celebrate small wins!'], 'https://www.youtube.com/watch?v=sYMqVwsewSg', 'The Power of Consistency', '/challenge', 'Start Today''s Challenge'),
('no_one_is_watching', 3, 'No One Is Watching', '👀', 'The truth about engagement and visibility', ARRAY['Statistically, only 10% of your followers see your posts.', 'Your first videos will get minimal views - this is normal and good!', 'Low initial engagement = safe space to practice without pressure.', 'The algorithm shows your content to strangers first, not friends.', 'By the time people notice you, you''ll already be confident!'], 'https://www.youtube.com/watch?v=Ks-_Mh1QhMc', 'Why No One Sees Your First Posts', NULL, NULL),
('social_media_tips', 4, 'Social Media Tips', '📱', 'Practical tips for posting and growing', ARRAY['🕐 Best times to post: 7-9 AM, 12-1 PM, 7-9 PM (local time)', '📝 Hook viewers in 3 seconds or they scroll away', '#️⃣ Use 5-10 relevant hashtags, not 30 random ones', '🎵 Trending audio boosts visibility', '💬 Reply to every comment in the first hour', '📊 Study your analytics weekly - double down on what works', '🤝 Engage with others in your niche before posting', '📍 Tag your location for local discoverability'], 'https://www.youtube.com/watch?v=UF8uR6Z6KLc', 'Instagram Algorithm Tips 2024', NULL, NULL)
ON CONFLICT (guide_key) DO NOTHING;
