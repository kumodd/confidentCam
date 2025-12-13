-- Fix RLS policy for users table to allow email signup
-- Run this in your Supabase SQL Editor

-- Drop existing INSERT policy if it exists
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;

-- Create new INSERT policy that allows authenticated users to insert their own record
CREATE POLICY "Users can insert their own profile"
ON users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Also ensure UPDATE policy exists
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

CREATE POLICY "Users can update their own profile"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Ensure SELECT policy exists
DROP POLICY IF EXISTS "Users can view their own profile" ON users;

CREATE POLICY "Users can view their own profile"
ON users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON users TO authenticated;
GRANT ALL ON user_progress TO authenticated;
