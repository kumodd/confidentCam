# 01 — Project Overview

## Product Vision

**Confident Creator** helps aspiring content creators overcome camera anxiety through a structured, gamified 30-day challenge. The app provides:

- 🎥 Daily video recording prompts with AI-generated, personalized scripts
- 🎯 Guided warmup exercises before the main challenge begins
- 📈 Progress tracking, streaks, and achievement badges
- 🤖 AI-powered Content Creator tool (script generator + teleprompter)
- 🌐 Web portal for script management from any browser

---

## Core User Journey

```
Install App
    │
    ▼
Splash Screen (session check)
    │
    ├──► [Not authenticated] ──► Login Screen
    │           │
    │           ├── Phone OTP
    │           └── Email / Password
    │
    ▼
Onboarding (new users only)
    │ - Personal info (name, age, location)
    │ - Goal selection
    │ - Language preference
    │ - AI generates personalized 30-day script pack
    │
    ▼
Dashboard Screen
    │
    ├── Warmup Section (3 warmup exercises must be completed first)
    │       └── Warmup Recording Screen
    │
    ├── 30-Day Challenge Grid
    │       ├── Day List → Day Overview → Day Details → Recording → Review
    │       └── Each day unlocks sequentially (one new day per calendar day)
    │
    ├── Progress Tab (streak, completion %, achievements)
    │
    └── Content Creator Tab (bonus feature)
            ├── Script Generator (AI-powered, questionnaire-based)
            └── Teleprompter (scrolling script display with recording)
```

---

## Feature Breakdown

### 🔐 Authentication

| Feature | Status |
|---|---|
| Phone OTP (SMS via Supabase) | ✅ Implemented |
| Email + Password | ✅ Implemented |
| Email confirmation flow | ✅ Implemented |
| QR code login (web ↔ mobile) | ✅ Implemented |
| Session persistence (Hive) | ✅ Implemented |
| Logout & Account deletion | ✅ Implemented |

### 📹 Daily Challenge

| Feature | Status |
|---|---|
| 30-day challenge grid | ✅ Implemented |
| Sequential day unlocking | ✅ Implemented (1 day/calendar day) |
| 3 warmup exercises | ✅ Implemented |
| Video recording with camera | ✅ Implemented |
| Max recording: 3 mins | ✅ Implemented |
| Video review & retake | ✅ Implemented |
| AI-generated personalized scripts | ✅ Implemented |
| Segmented script (Days 1–5) | ✅ Implemented |
| Day checklist pre-recording | ✅ Implemented |

### 📊 Progress & Gamification

| Feature | Status |
|---|---|
| Daily streak tracking | ✅ Implemented |
| Longest streak record | ✅ Implemented |
| Achievement badges (13 types) | ✅ Implemented |
| Progress sync (Supabase + Hive) | ✅ Implemented |
| Offline queue for progress | ✅ Implemented |

### 🤖 Content Creator (Bonus Feature)

| Feature | Status |
|---|---|
| AI script generator (questionnaire) | ✅ Implemented |
| 6 script templates | ✅ Implemented |
| Teleprompter (in-app) | ✅ Implemented |
| Script Cloud sync (Supabase) | ✅ Implemented |
| Script local cache (Hive) | ✅ Implemented |
| Share scripts | ✅ Implemented |

### 🌐 Web Portal

| Feature | Status |
|---|---|
| Email/password login | ✅ Implemented |
| QR code login | ✅ Implemented |
| Dashboard (recent scripts) | ✅ Implemented |
| Script manager | ✅ Implemented |
| AI script generator | ✅ Implemented |
| Teleprompter with voice control | ✅ Implemented |
| Privacy Policy & Terms | ✅ Implemented |

### 💎 Premium / Subscriptions

| Feature | Status |
|---|---|
| RevenueCat integration (mobile) | ⏳ Planned |
| Monthly subscription | ⏳ Planned |
| Yearly subscription | ⏳ Planned |
| Web subscription (Stripe) | ⏳ Planned |
| Premium feature gating | 🔧 Skeleton exists (`isPremiumUser` flag) |
| Paywall UI | ⏳ Planned |

---

## Achievement System

| Achievement | Trigger |
|---|---|
| First Step | Complete Warmup 1 |
| Warmed Up | Complete all 3 warmups |
| Day One Done | Complete Day 1 |
| First Week | Complete Day 7 |
| Halfway There | Complete Day 15 |
| Almost There | Complete Day 25 |
| Challenge Champion | Complete Day 30 |
| Perfect Week | 7-day streak |
| Unstoppable | 14-day streak |
| Legend | 30-day streak |
| Night Owl | Record after 10 PM |
| Early Bird | Record before 7 AM |
| Retake Master | 5+ takes in one day |

---

## App Configuration Flags

Located in `lib/core/config/app_config.dart`:

| Flag | Default | Description |
|---|---|---|
| `devMode` | `true` | Bypasses day-unlock restrictions |
| `isPremiumUser` | `false` | Grant premium access without payment |
| `totalDays` | `3` (dev) | Should be `30` in production |
| `enablePhoneAuth` | `true` | Enable SMS OTP login |
| `enableEmailAuth` | `true` | Enable email/password login |
| `maxRecordingDurationSeconds` | `180` | Max video length (3 min) |

> ⚠️ **Before release:** Set `devMode = false` and `totalDays = 30`.
