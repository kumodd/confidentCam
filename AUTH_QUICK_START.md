# 🚀 Auth Setup Quick Start

## Step 1: Run Database Setup
```bash
# Open Supabase Dashboard → SQL Editor
# Run: supabase_complete_setup.sql
```

## Step 2: Configure Supabase
1. Dashboard → Authentication → Settings
2. ✅ Enable email confirmations  
3. Add redirect URL: `<your-app-scheme>://auth-callback`

## Step 3: Test Flow

### Email Signup
```
1. Open app → Email tab
2. Enter email + password → Create Account
3. See confirmation screen
4. Check email → Click link
5. Return to app → Sign In
```

### Email Signin  
```
1. Email tab → Enter credentials → Sign In
2. Should proceed to dashboard
```

### Phone OTP
```
1. Phone tab → Enter number → Continue
2. Enter OTP code → Verify
3. Proceed to dashboard
```

## Logs to Watch

✅ Success pattern:
```
📧 Starting email signup for: user@example.com
✅ Auth user created successfully
✅ User record found in database
📧 Email signup completed successfully
```

❌ Error pattern:
```
❌ Email signup failed - no user in response
❌ User record not created by trigger
```

## Common Issues

| Error | Fix |
|-------|-----|
| RLS violation | Run setup script |
| Record not created | Check trigger exists |
| Email not confirmed | User must click email link |
| Invalid credentials | Check password or email |

## Files to Check

- Database: `supabase_complete_setup.sql`
- Auth config: `lib/core/config/app_config.dart`
- Full docs: `walkthrough.md`
