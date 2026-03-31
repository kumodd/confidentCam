# 10 — State Management (BLoC Pattern)

## Overview

The app uses **flutter_bloc** for all state management. Every feature has its own BLoC consisting of three files:

```
feature/
├── feature_bloc.dart    # Business logic + event handlers
├── feature_event.dart   # User actions / triggers
└── feature_state.dart   # UI states
```

All BLoCs are registered in `lib/core/di/injection_container.dart` and provided at the top of the widget tree via `MultiBlocProvider` in `lib/main.dart`.

---

## Error Handling Pattern

The app uses a clean separation between **Exceptions** (data layer), **Failures** (domain layer), and **BLoC states** (presentation layer).

### Layer 1 — Exceptions (Data Layer)
*File: `lib/core/error/exceptions.dart`*

Thrown from datasources when raw operations fail:
- `AuthException` — login/OTP errors
- `ServerException` — HTTP or Supabase errors
- `CacheException` — Hive read/write errors

### Layer 2 — Failures (Domain Layer)
*File: `lib/core/error/failures.dart`*

Returned from repositories using `dartz` `Either<Failure, T>`:

| Failure Class | Code | Use Case |
|---|---|---|
| `ServerFailure` | `bad_request`, `unauthorized`, etc. | HTTP error codes |
| `NetworkFailure` | `no_connection` | No internet |
| `CacheFailure` | `cache_error` | Local storage issues |
| `AuthFailure` | `auth/invalid-otp`, etc. | Auth-specific errors |
| `RecordingFailure` | `recording/permission-denied` | Camera/mic issues |
| `PremiumFailure` | `premium/purchase-failed` | RevenueCat errors |
| `ScriptFailure` | `scripts/generation-failed` | OpenAI errors |
| `SyncFailure` | `sync/failed` | Background sync errors |
| `ValidationFailure` | `validation_error` | Input validation |

### Layer 3 — BLoC States (Presentation)

BLoC states carry either success data or a `Failure` message to display to the user.

---

## AuthBloc

**Purpose:** Manages authentication lifecycle across the entire app.

### Events

| Event | Payload | Description |
|---|---|---|
| `SessionCheckRequested` | — | Check Supabase session on app start |
| `PhoneOtpRequested` | `phone` | Send SMS OTP |
| `OtpVerified` | `phone`, `otp` | Verify OTP code |
| `EmailSignUpRequested` | `email`, `password`, `phone?` | Create account |
| `EmailSignInRequested` | `email`, `password` | Sign in |
| `LogoutRequested` | — | Sign out and clear local state |
| `DeleteAccountRequested` | — | Delete account via edge function |

### States

| State | UI Response |
|---|---|
| `AuthInitial` | Show `SplashScreen` |
| `AuthLoading` | Show activity indicator |
| `AuthCodeSent(phone)` | Navigate to `OtpVerificationScreen` |
| `AuthVerifying` | Show "Verifying..." indicator |
| `AuthSuccess(user, isNewUser)` | Navigate to Dashboard or Onboarding |
| `AuthFailure(message, attemptsRemaining?)` | Show error + retry |
| `AuthLoggedOut` | Navigate to `LoginScreen` |
| `AuthDeletingAccount` | Show "Deleting..." overlay |
| `EmailConfirmationRequired(email)` | Navigate to `EmailConfirmationScreen` |

---

## OnboardingBloc

**Purpose:** Drives the multi-step onboarding wizard and triggers AI script generation.

### Key Events → Side Effects

| Event | Side Effect |
|---|---|
| `OnboardingStarted` | Fetch questions + goals from Supabase |
| `PersonalInfoSubmitted` | Save to `user_profiles` table |
| `GoalSelected` | Update state |
| `LanguageSelected` | Update state |
| `GenerateScriptsRequested` | Call OpenAI weekly for all 5 weeks → save to Hive + Supabase |

### States

| State | Description |
|---|---|
| `OnboardingLoading` | Loading questions/goals |
| `OnboardingPersonalInfo` | Collecting name, age, location |
| `OnboardingGoalSelect` | Goal selection step |
| `OnboardingLanguageSelect` | Language preference step |
| `OnboardingGeneratingScripts` | AI generation in progress (shows progress) |
| `OnboardingComplete` | Done → navigates to Dashboard |
| `OnboardingError(message)` | Error state with retry |

---

## DailyChallengeBloc

**Purpose:** Manages loading scripts, tracking recording status, and marking days complete.

### Key Events

| Event | Payload | Description |
|---|---|---|
| `LoadDayChallenge` | `dayNumber` | Fetch script for the day |
| `RecordingStarted` | — | Update UI state |
| `RecordingCompleted` | `videoPath`, `duration` | Save progress + sync |
| `DayCompleted` | `dayNumber` | Mark day complete, update streak |
| `LoadExtensionScripts` | `extensionNumber` | Generate extension pack |

### States

| State | Description |
|---|---|
| `DailyChallengeLoading` | Fetching script |
| `DailyChallengeLoaded(script, isCompleted)` | Script ready for recording |
| `DailyChallengeRecording` | Active recording session |
| `DailyChallengeCompleted(dayNumber, streak)` | Day marked done |
| `DailyChallengeError(message)` | Error loading/saving |

---

## ProgressBloc

**Purpose:** Loads and exposes `UserProgress` and achievement data for the dashboard.

### Key Events

| Event | Description |
|---|---|
| `LoadProgress` | Fetch progress from Supabase (or Hive fallback) |
| `ProgressRefreshRequested` | Force re-fetch from server |
| `AchievementChecked` | Evaluate which achievements are newly unlocked |

### States

| State | Description |
|---|---|
| `ProgressLoading` | Fetching progress |
| `ProgressLoaded(userProgress, achievements)` | Data ready for display |
| `ProgressError(message)` | Could not load progress |

---

## WarmupBloc

**Purpose:** Drives the 3 warmup exercise recordings before the main challenge.

### Key Events

| Event | Payload | Description |
|---|---|---|
| `LoadWarmup` | `warmupIndex` (0–2) | Load warmup script |
| `WarmupRecordingCompleted` | `warmupIndex`, `videoPath` | Mark warmup done |

### States

| State | Description |
|---|---|
| `WarmupLoading` | Loading warmup script |
| `WarmupLoaded(script, isComplete)` | Ready to record |
| `WarmupCompleted(warmupIndex)` | Warmup marked done |
| `AllWarmupsComplete` | All 3 done → unlock Day 1 |

---

## ContentCreatorBloc

**Purpose:** Manages the AI-powered content script generator (separate from daily challenge).

### Key Events

| Event | Description |
|---|---|
| `LoadContentScripts` | Fetch user's saved scripts |
| `GenerateScript(questionnaire, template)` | AI generation via OpenAI |
| `SaveScript(script)` | Save to Supabase + Hive |
| `DeleteScript(scriptId)` | Remove from both |
| `UpdateScript(script)` | Edit title or content |

### States

| State | Description |
|---|---|
| `ContentCreatorLoading` | Loading/generating |
| `ContentCreatorLoaded(scripts)` | List of saved scripts |
| `ScriptGenerated(script)` | New script ready for review |
| `ContentCreatorError(message)` | Error feedback |

---

## SettingsBloc

**Purpose:** Manages user preferences stored in Hive.

### Key Events

| Event | Payload | Description |
|---|---|---|
| `LoadSettings` | — | Read settings from Hive |
| `UpdateReminderTime` | `hour`, `minute` | Change notification time |
| `ToggleNotifications` | `enabled` | Turn reminders on/off |

---

## NetworkBloc

**Purpose:** Monitors internet connectivity app-wide. Singleton.

### States

| State | UI Effect |
|---|---|
| `NetworkConnected` | Normal operation |
| `NetworkDisconnected` | Shows `NetworkStatusBanner` at top of screen |

---

## Planned: SubscriptionBloc

**Purpose:** Manage RevenueCat subscription state.

### Events

| Event | Description |
|---|---|
| `LoadSubscriptionStatus` | Check entitlements on app start |
| `PurchasePackage(package)` | Initiate purchase |
| `RestorePurchases` | Restore for returning users |

### States

| State | Description |
|---|---|
| `SubscriptionInitial` | Not yet checked |
| `SubscriptionLoading` | Loading/purchasing |
| `SubscriptionLoaded(isPremium, offering)` | State known |
| `SubscriptionPurchaseSuccess` | Entitlement active |
| `SubscriptionError(message)` | Error feedback |

---

## BLoC Registration in DI

```dart
// injection_container.dart

// Singletons (shared app-wide)
sl.registerLazySingleton<NetworkBloc>(() => NetworkBloc(networkInfo: sl()));

// Factories (fresh instance per use)
sl.registerFactory<AuthBloc>(() => AuthBloc(authRepository: sl()));
sl.registerFactory<OnboardingBloc>(() => OnboardingBloc(...));
sl.registerFactory<WarmupBloc>(() => WarmupBloc(...));
sl.registerFactory<DailyChallengeBloc>(() => DailyChallengeBloc(...));
sl.registerFactory<ProgressBloc>(() => ProgressBloc(...));
sl.registerFactory<SettingsBloc>(() => SettingsBloc(...));
sl.registerFactory<ContentCreatorBloc>(() => ContentCreatorBloc(...));
// Planned:
sl.registerFactory<SubscriptionBloc>(() => SubscriptionBloc(sl()));
```

---

## BLoC Provision in Widget Tree

```dart
// lib/main.dart → ConfidentCamApp
MultiBlocProvider(
  providers: [
    BlocProvider<NetworkBloc>(create: (_) => sl<NetworkBloc>()),
    BlocProvider<AuthBloc>(create: (_) => sl<AuthBloc>()..add(SessionCheckRequested())),
    BlocProvider<WarmupBloc>(create: (_) => sl<WarmupBloc>()),
    BlocProvider<ProgressBloc>(create: (_) => sl<ProgressBloc>()),
    BlocProvider<DailyChallengeBloc>(create: (_) => sl<DailyChallengeBloc>()),
    BlocProvider<SettingsBloc>(create: (_) => sl<SettingsBloc>()),
    // Add when ready:
    // BlocProvider<SubscriptionBloc>(create: (_) => sl<SubscriptionBloc>()),
  ],
  child: const App(),
)
```
