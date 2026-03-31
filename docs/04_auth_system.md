# 04 — Authentication System

## Auth Methods

| Method | Status | Description |
|---|---|---|
| Phone OTP (SMS) | ✅ Live | Supabase sends OTP via SMS |
| Email + Password | ✅ Live | Standard email/password auth |
| Email Confirmation | ✅ Live | Verify email before login |
| Google OAuth | ⏳ Planned | Future implementation |
| Apple Sign-In | ⏳ Planned | Required for iOS App Store |
| QR Code (Web ↔ App) | ✅ Live | Scan QR on web to login with app session |

---

## Auth Flow Diagrams

### Phone OTP Flow

```
User enters phone number
    │
    ▼
SupabaseAuthDataSource.sendOtp(phone)
    │ → Supabase Auth: signInWithOtp(phone: phone)
    │
    ▼
OtpVerificationScreen
    │
User enters 6-digit OTP
    │
    ▼
SupabaseAuthDataSource.verifyOtp(phone, otp)
    │ → Supabase Auth: verifyOTP(phone, token, type: sms)
    │ → Check users table (existing?)
    │     ├── [New] → INSERT users + user_progress → isNewUser = true
    │     └── [Existing] → return user data → isNewUser = false
    │
    ▼
AuthBloc receives (user, isNewUser)
    │
    ├── [isNewUser = true]  → OnboardingScreen
    └── [isNewUser = false] → DashboardScreen
```

### Email / Password Flow

```
LoginScreen: tabs [Email | QR]

── Sign Up ──────────────────────────────────
User enters email + password
    │
    ▼
SupabaseAuthDataSource.signUpWithEmail(email, password)
    │ → Supabase Auth: signUp(email, password)
    │ → [session exists immediately?]
    │     ├── YES → call edge function 'create_user_record'
    │     └── NO  → poll users table (3x retry, 300ms delay)
    │ → If still no record → return minimal data
    │   (record created on first sign-in after email confirmation)
    │
    ▼
EmailConfirmationScreen (if no session)
    │
User confirms email → redirected to app
    │
    ▼
SignIn → DashboardScreen

── Sign In ──────────────────────────────────
User enters email + password
    │
    ▼
SupabaseAuthDataSource.signInWithEmail(email, password)
    │ → Supabase Auth: signInWithPassword(email, password)
    │ → Fetch from users table
    │     ├── [Found] → return user, isNewUser = false
    │     └── [Not found] → INSERT users + user_progress → isNewUser = true
    │
    ▼
AuthBloc → DashboardScreen or OnboardingScreen
```

### QR Code Web Login Flow

```
Web browser:                    Mobile App:
─────────────────────────       ──────────────────────────
1. Load index.html
2. Generate session_token
3. Create web_sessions row     
4. Display QR code
5. Poll for scan status ─────── User opens QR scanner in Settings
                                Scans QR code
                                Reads session_token from QR
                                calls Supabase: update web_sessions
                                  set status = 'authenticated'
                                  set user_id = current user
6. Realtime update fires ──────
7. Get auth token from session
8. signIn with token
9. Redirect to dashboard.html
```

---

## Auth BLoC

**File:** `lib/presentation/bloc/auth/auth_bloc.dart`

### Events

| Event | Trigger | Action |
|---|---|---|
| `SessionCheckRequested` | App start | Check Supabase session → restore or logout |
| `PhoneOtpRequested` | Send OTP button | Call `sendOtp()` |
| `OtpVerified` | OTP submitted | Call `verifyOtp()` |
| `EmailSignUpRequested` | Sign up button | Call `signUpWithEmail()` |
| `EmailSignInRequested` | Sign in button | Call `signInWithEmail()` |
| `LogoutRequested` | Logout button | Call `logout()` + clear Hive |
| `DeleteAccountRequested` | Delete account | Call `deleteAccount()` edge function |

### States

| State | Screen |
|---|---|
| `AuthInitial` | `SplashScreen` |
| `AuthLoading` | Inline loading indicator |
| `AuthSuccess(user, isNewUser)` | `DashboardScreen` or `OnboardingScreen` |
| `AuthLoggedOut` | `LoginScreen` |
| `AuthError(message)` | Error shown on current screen |
| `OtpSent` | `OtpVerificationScreen` |

---

## Session Persistence

- Sessions are persisted via Supabase Flutter's built-in session storage
- Hive `authBox` stores any extra local auth metadata
- On app start, `AuthBloc` dispatches `SessionCheckRequested`
  - Supabase checks for a valid local session
  - If valid → `AuthSuccess` (skip login screen)
  - If expired/missing → `AuthLoggedOut`

---

## Security Notes

| Concern | Approach |
|---|---|
| API keys in source | ⚠️ Currently hardcoded in `app_config.dart` — move to env variables before release |
| RLS on all tables | ✅ Active — users can only see their own rows |
| Account deletion | ✅ Edge function with auth token validation |
| OTP expiry | Supabase default (5 min) — max 5 attempts, then 15 min lockout |
| QR session expiry | Web sessions expire (configurable in `web_sessions` table) |

---

## Planned: Supabase Auth + RevenueCat Integration

When subscriptions are added, the auth system will need to:

1. **Set RevenueCat `appUserID`** to match Supabase `user.id` on login
2. **Identify anonymous RC user** → link to Supabase user on login
3. **Restore purchases** on sign-in for returning users
4. **Sync subscription status** to `subscriptions` Supabase table via webhook

See [06_subscription_plan.md](./06_subscription_plan.md) for full details.
