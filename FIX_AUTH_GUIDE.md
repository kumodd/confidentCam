# Step-by-Step Fix from Scratch

## ⚠️ CRITICAL: Run These Steps IN ORDER

### Step 1: Clean Slate Database Setup

**Open Supabase Dashboard → SQL Editor → New Query**

Paste and run: [FRESH_START_AUTH_SETUP.sql](file:///Users/kumodyadav/Desktop/ConfidantCam/FRESH_START_AUTH_SETUP.sql)

This script:
- ✅ Drops all existing tables, triggers, functions
- ✅ Creates fresh `users` and `user_progress` tables
- ✅ Makes `phone` column nullable (key fix!)
- ✅ Sets up RLS policies correctly
- ✅ Creates working trigger with proper error handling
- ✅ Grants all necessary permissions

### Step 2: Verify Database

Run this in SQL Editor to verify:
```sql
-- Should return 2 rows
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'user_progress');

-- Should show phone is nullable
SELECT column_name, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'phone';

-- Should return 1 row
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

Expected:
- Tables: `users`, `user_progress` ✅
- Phone nullable: `YES` ✅
- Trigger: `on_auth_user_created` ✅

### Step 3: Enable Email Auth in Supabase

**Dashboard → Authentication → Settings:**

1. ✅ Enable email provider
2. ✅ Confirm email confirmations (optional - can disable for testing)
3. ✅ Set site URL: `http://localhost:3000` (or your app scheme)

### Step 4: Deploy Edge Function (for Delete Account)

**Terminal:**
```bash
cd /Users/kumodyadav/Desktop/ConfidantCam

# Install Supabase CLI if needed
# brew install supabase/tap/supabase

# Login
supabase login

# Link project
supabase link --project-ref <your-project-ref>

# Deploy delete_account function
supabase functions deploy delete_account
```

### Step 5: Test Email Signup

**In your app:**
1. Go to Email tab
2. Enter:
   - Email: `test@example.com`
   - Phone: (leave empty or fill)
   - Password: `test123`
3. Click "Create Account"

**Expected logs:**
```
📧 Starting email signup for: test@example.com
✅ Auth user created successfully: xxx-xxx-xxx
Polling for user record (attempt 1/10)...
✅ User record found in database
📧 Email signup completed successfully
```

### Step 6: Verify in Database

**SQL Editor:**
```sql
-- Check users table
SELECT id, email, phone, created_at FROM public.users;

-- Check progress table
SELECT user_id, current_day FROM public.user_progress;

-- Check auth users
SELECT id, email, phone FROM auth.users;
```

You should see your test user in all 3 queries!

---

## 🐛 Troubleshooting

### Still Getting Errors?

**Check Supabase Logs:**
Dashboard → Logs → Select "Postgres Logs"

Look for:
- `Error in handle_new_user`
- `permission denied`
- `violates constraint`

**Common Issues:**

| Error | Solution |
|-------|----------|
| Permission denied | Re-run Step 1 (FRESH_START script) |
| Constraint violation | Phone should be nullable - check Step 2 |
| Trigger not firing | Check trigger exists in Step 2 |
| RLS blocking | Policies were created in Step 1 |

---

## ✅ What Changed from Before

1. **Phone Column**: Now properly nullable (was NOT NULL before)
2. **Trigger**: Better error handling, won't fail silently
3. **RLS Policies**: Simpler naming, guaranteed to work
4. **Permissions**: Added `anon` read access for signup
5. **Fresh Start**: No conflicts with old schema

---

## 📦 Files Created

1. [FRESH_START_AUTH_SETUP.sql](file:///Users/kumodyadav/Desktop/ConfidantCam/FRESH_START_AUTH_SETUP.sql) - Main setup script
2. [delete_account/index.ts](file:///Users/kumodyadav/Desktop/ConfidantCam/supabase/functions/delete_account/index.ts) - Edge function

Run Step 1 first, then test!
