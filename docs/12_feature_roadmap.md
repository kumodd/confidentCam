# 12 — Feature Roadmap

## Current Status (as of March 2026)

**Version:** 1.0.1 | **Stage:** Development / Pre-release

---

## ✅ Completed Features

### Core Infrastructure
- [x] Clean Architecture setup (domain / data / presentation layers)
- [x] GetIt dependency injection
- [x] BLoC state management for all features
- [x] Hive local storage (offline-first)
- [x] Supabase backend integration (auth, db, realtime)
- [x] Network connectivity monitoring
- [x] Dark theme system (Outfit + Inter fonts, indigo/cyan/pink palette)
- [x] Daily notification reminders with custom time setting

### Authentication
- [x] Phone OTP login (SMS via Supabase)
- [x] Email + Password login/signup
- [x] Email confirmation flow
- [x] QR code login (web ↔ mobile session sharing)
- [x] Session persistence across app restarts
- [x] Logout and account deletion (edge function)
- [x] Row Level Security on all tables

### Onboarding
- [x] Multi-step onboarding wizard
- [x] Personal info collection (name, age, location)
- [x] Goal selection (from Supabase-driven list)
- [x] Language preference (English, Hindi, Hinglish)
- [x] AI script generation during onboarding (weekly batches)
- [x] Warmup script generation
- [x] Progress during generation (week-by-week UI)

### Daily Challenge
- [x] 30-day challenge grid (all days displayed)
- [x] Sequential day unlock (one per calendar day)
- [x] 3 warmup exercises (must complete before Day 1)
- [x] Day overview screen with checklist
- [x] Day details screen (script preview)
- [x] Video recording screen with camera
- [x] 3-minute max recording duration
- [x] Video review and retake functionality
- [x] Segmented script display (Days 1–5 shown in 3 parts)
- [x] Progress sync to Supabase + Hive fallback
- [x] Offline queue for failed syncs
- [x] Streak tracking and longest streak record

### Gamification
- [x] 13 achievement badges
- [x] Achievements displayed on progress screen
- [x] Achievement unlock notifications

### Content Creator (Bonus)
- [x] AI script generator (6 templates, questionnaire-based)
- [x] 3-part script structure (Hook / Body / Close)
- [x] Script management (create, view, edit, delete)
- [x] Cloud sync to Supabase
- [x] Local cache in Hive
- [x] Share scripts
- [x] Save video to gallery

### Web Portal
- [x] Email/password login
- [x] QR code login tab
- [x] Dashboard with recent scripts
- [x] Full script manager (list, edit, delete)
- [x] AI script generator (questionnaire)
- [x] Professional teleprompter (scroll speed, font size, mirror mode)
- [x] Privacy Policy page
- [x] Terms of Service page

---

## 🔧 In Progress / Partially Done

| Feature | Status | Notes |
|---|---|---|
| `isPremiumUser` flag | Skeleton | Hardcoded `false` — wired but not connected to payments |
| Premium day unlock | Skeleton | `isDayUnlocked()` accepts `isPremium` flag |
| `PremiumFailure` class | Skeleton | Error types defined, no implementation |
| Subscription BLoC folder | Created (empty) | Events/states not yet written |
| Extension scripts (Day 31+) | Code exists | `generateExtensionScripts()` method ready, not wired to UI |
| App Config cleanup | Dev | `devMode=true`, `totalDays=3` — needs production values |

---

## ⏳ Planned Features

### 🔴 High Priority — Subscriptions (Next Sprint)

| Feature | Effort | Doc |
|---|---|---|
| Add `purchases_flutter` dependency | Low | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Initialize RevenueCat in `main.dart` | Low | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Create `SubscriptionService` | Medium | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Create `SubscriptionBloc` | Medium | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Build `PaywallScreen` UI | High | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Wire entitlement to app features | Medium | [06_subscription_plan.md](./06_subscription_plan.md) |
| Identify RC user with Supabase ID on login | Low | [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) |
| Create `subscriptions` Supabase table | Low | [06_subscription_plan.md](./06_subscription_plan.md) |
| RevenueCat webhook → Supabase Edge Function | Medium | [06_subscription_plan.md](./06_subscription_plan.md) |
| Test on physical devices (sandbox) | High | — |

### 🟡 Medium Priority — Web Subscriptions

| Feature | Effort | Doc |
|---|---|---|
| Create Stripe account + products | Low | [08_revenuecat_web.md](./08_revenuecat_web.md) |
| Create `pricing.html` page | Medium | [08_revenuecat_web.md](./08_revenuecat_web.md) |
| Supabase Edge: `create_checkout_session` | Medium | [08_revenuecat_web.md](./08_revenuecat_web.md) |
| Supabase Edge: `stripe_webhook` | Medium | [08_revenuecat_web.md](./08_revenuecat_web.md) |
| Feature gating on web (check `subscriptions` table) | Medium | [08_revenuecat_web.md](./08_revenuecat_web.md) |
| `billing.html` — manage/cancel subscription | Medium | — |
| `success.html` — post-payment confirmation | Low | — |

### 🟢 Lower Priority — Post-MVP

| Feature | Effort | Notes |
|---|---|---|
| Google Sign-In (OAuth) | Medium | Needed for broader user base |
| Apple Sign-In | Medium | Required for iOS App Store if Google login is included |
| Move OpenAI key server-side (Edge Function) | High | Security improvement |
| Free trial (7-day) | Medium | Configure in RevenueCat dashboard |
| Subscription management screen (cancel, switch plan) | Medium | Links to Stripe portal |
| Push notifications (FCM) | High | Replace local notifications with FCM for better reliability |
| Video sharing to social media (Reels, TikTok) | High | Use `share_plus` + video export |
| Leaderboard / social features | Very High | Community aspect |
| Progress reports (weekly email digest) | High | Supabase Edge Function + email |
| Analytics integration (Mixpanel/PostHog) | Medium | Track paywall views, purchases, retention |
| A/B test paywall pricing | Medium | Use RevenueCat Experiments |
| iPad / tablet layout | Medium | Responsive layout improvements |
| macOS desktop app | Low | Minor adaptations needed |
| Day 31+ content (extension packs) | Medium | Code exists, needs UI |
| Multi-language UI translations (i18n) | High | App UI currently English-only |
| Video transcript generation | High | OpenAI Whisper API |
| Community challenges | Very High | New social feature |

---

## Known Issues / Technical Debt

| Issue | Severity | Fix |
|---|---|---|
| API keys hardcoded in `app_config.dart` | 🔴 High | Move to `--dart-define` or server-side |
| `devMode = true` and `totalDays = 3` in production code | 🔴 High | Set correct values before release |
| OpenAI called directly from mobile | 🟡 Medium | Route through Supabase Edge Function |
| No free trial logic | 🟡 Medium | Add with RevenueCat configuration |
| Local notifications only (no push) | 🟡 Medium | Users miss reminders after uninstall/reinstall |
| No analytics | 🟡 Medium | Blind to conversion rates and churn |
| Premium BLoC folder is empty | 🟡 Medium | Implement in next sprint |
| `generateScripts()` (batch-30) deprecated but not removed | 🟢 Low | Remove to clean up |
| No unit tests for critical paths | 🟢 Low | Add for auth, progress, billing |
| Supabase anon key exposed in web portal `config.js` | 🟢 Low | Acceptable (anon key is designed to be public) |

---

## Release Blocklist (DO NOT SHIP UNTIL FIXED)

- [ ] Set `devMode = false`
- [ ] Set `totalDays = 30`
- [ ] Set `totalWarmups = 3`
- [ ] Remove hardcoded OpenAI API key (use Edge Function)
- [ ] Add camera + microphone permission strings (iOS `Info.plist`)
- [ ] Add BILLING permission (Android `AndroidManifest.xml`)
- [ ] Add Privacy Policy URL in App Store / Play Store listing
- [ ] Verify Supabase RLS is active on all tables
- [ ] Test full onboarding → challenge → completion flow on real device
- [ ] Test subscription purchase → entitlement → gating on physical device (sandbox)

---

## Milestone Timeline (Suggested)

```
April 2026
├── Week 1–2: Mobile Subscription Integration (RevenueCat)
│   └── PaywallScreen + SubscriptionBloc + revoke/grant feature access
│
├── Week 3:   Backend Sync
│   └── subscriptions table + RevenueCat webhook Edge Function
│
└── Week 4:   QA + App Store Submission Prep
    └── Production config, remove dev flags, final testing

May 2026
├── Week 1–2: Web Subscriptions (Stripe)
│   └── pricing.html + Edge Functions + checkout flow
│
└── Week 3–4: Analytics + Post-Launch Monitoring
    └── Mixpanel/PostHog + RevenueCat dashboard setup

June 2026
└── Post-Launch Improvements
    └── Google/Apple OAuth + push notifications + A/B paywall tests
```
