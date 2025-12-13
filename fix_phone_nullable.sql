-- Fix phone column to allow NULL values
-- Run this in Supabase SQL Editor

-- Make phone column nullable
ALTER TABLE public.users 
ALTER COLUMN phone DROP NOT NULL;

-- Verify the change
SELECT column_name, is_nullable, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND column_name IN ('email', 'phone');
