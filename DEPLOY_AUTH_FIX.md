# Complete Auth Fix - Deploy Steps

## 🚨 The Real Issue

The database trigger runs as `SECURITY DEFINER` but may still fail due to:
1. Table constraints (NOT NULL on phone)
2. Trigger execution timing

**Solution**: Use Edge Function instead of trigger.

---

## Step 1: Fix Database Schema

**Supabase SQL Editor - Run This FIRST:**

```sql
-- Allow NULL phone values
ALTER TABLE public.users 
ALTER COLUMN phone DROP NOT NULL;

-- Verify it worked
SELECT column_name, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'phone';
-- Should show: YES
```

---

## Step 2: Deploy Edge Function

**Terminal:**

```bash
cd /Users/kumodyadav/Desktop/ConfidantCam

# Login to Supabase
supabase login

# Link project (get ref from Dashboard URL)
supabase link --project-ref <your-project-ref>

# Deploy the edge function
supabase functions deploy create_user_record
```

**Verify in Dashboard:**
Dashboard → Edge Functions → Should see `create_user_record`

---

## Step 3: Test Signup

1. Open app
2. Go to Email tab
3. Enter email + password
4. Click "Create Account"

**Check logs for:**
```
📧 Starting email signup for: test@example.com
✅ Auth user created successfully
Session exists, creating user record via edge function...
✅ User record created via edge function
📧 Email signup completed successfully
```

---

## Step 4: Check Flow

After signup → Email Confirmation Screen

After email verified + signin → Dashboard

If `isNewUser = true` → Auto-navigate to Onboarding → Generate Scripts

---

## 🐛 Still Not Working?

### A. Edge Function Not Deployed

If you can't deploy edge functions, the app has a fallback:
- It polls the database for 5 seconds
- If still no record, returns minimal data
- This allows email confirmation flow to work

### B. Disable Email Confirmation (For Testing)

Supabase Dashboard → Authentication → Settings:
- Uncheck "Enable email confirmations"
- Users can login immediately after signup

### C. Manual Insert (Testing Only)

If everything fails, manually insert:
```sql
INSERT INTO public.users (id, email, created_at, updated_at)
VALUES (
  'YOUR-AUTH-USER-UUID',
  'test@example.com',
  NOW(),
  NOW()
);
```

---

## Flow Summary

```
Email Signup
    ↓
auth.users created ✅
    ↓
Edge Function creates users + user_progress ✅
    ↓
Email Confirmation Screen
    ↓
User verifies email
    ↓
Email Sign In
    ↓
Dashboard (isNewUser = true)
    ↓
Onboarding Screen
    ↓
Script Generation
```

---

## Files Changed

| File | Change |
|------|--------|
| `supabase_auth_datasource.dart` | Added edge function call + fallback |
| `create_user_record/index.ts` | NEW - Edge function |
| `FRESH_START_AUTH_SETUP.sql` | Fixed schema + trigger |
