# 02 — Architecture

## Architecture Pattern

The app follows **Clean Architecture** with a clear separation of concerns across three layers:

```
lib/
├── core/               # Cross-cutting concerns
│   ├── config/         # AppConfig (keys, flags, timeouts)
│   ├── constants/      # AppConstants (Hive box names, keys)
│   ├── di/             # Dependency injection (GetIt)
│   ├── error/          # Custom exception types
│   ├── network/        # NetworkInfo interface
│   └── utils/          # Logger, helpers
│
├── domain/             # Business logic (pure Dart, no Flutter)
│   ├── entities/       # Core data models (User, UserProgress, etc.)
│   └── repositories/   # Abstract repository interfaces
│
├── data/               # Data layer (implements domain interfaces)
│   ├── datasources/
│   │   ├── local/      # Hive (offline-first storage)
│   │   └── remote/     # Supabase (cloud sync)
│   ├── models/         # JSON-serializable data models
│   └── repositories/   # Repository implementations
│
├── presentation/       # UI layer
│   ├── bloc/           # BLoC state-management (per feature)
│   ├── screens/        # Feature screens
│   └── widgets/        # Shared & feature-specific widgets
│
└── services/           # App-level services
    ├── openai_service.dart
    ├── notification_service.dart
    ├── video_recording_service.dart
    └── video_storage_service.dart
```

---

## Dependency Flow

```
Presentation (BLoC)
    │ uses
    ▼
Domain (Repositories / Entities)
    │ implemented by
    ▼
Data (Datasources → Supabase / Hive)
    │ uses
    ▼
Services (OpenAI, Video, Notifications)
```

---

## Dependency Injection

Uses **GetIt** (`sl`) as the service locator. All registrations happen in `lib/core/di/injection_container.dart` via `initDependencies()`, called from `main()`.

### Registration Strategy

| Type | Strategy | Reason |
|---|---|---|
| `SupabaseClient` | `registerLazySingleton` | Single shared client |
| `NetworkBloc` | `registerLazySingleton` | Monitors connectivity app-wide |
| `AuthBloc` | `registerFactory` | Fresh instance per navigation |
| `ProgressBloc` | `registerFactory` | Fresh state per use |
| `Hive Boxes` | `registerLazySingleton` with `instanceName` | Named box access |

---

## State Management (BLoC)

Each feature has its own BLoC triplet (`_bloc.dart`, `_event.dart`, `_state.dart`):

| BLoC | Feature |
|---|---|
| `AuthBloc` | Login, logout, session check |
| `OnboardingBloc` | Onboarding questions, AI script generation |
| `WarmupBloc` | Warmup recording and completion |
| `DailyChallengeBloc` | Daily scripts, recording, completion |
| `ProgressBloc` | Fetching and displaying progress |
| `SettingsBloc` | Reminder time, preferences |
| `ContentCreatorBloc` | Script generation, CRUD |
| `NetworkBloc` | Connectivity monitoring |
| *(planned)* `SubscriptionBloc` | RevenueCat subscription state |

---

## App Entry Flow

```dart
// main.dart
main() {
  await initDependencies();      // GetIt setup
  await _initializeNotifications();
  runApp(ConfidentCamApp());
}

// app.dart
MultiBlocProvider(
  providers: [NetworkBloc, AuthBloc, WarmupBloc, ProgressBloc, ...],
  child: App()
)

// _AuthWrapper (in app.dart)
BlocBuilder<AuthBloc, AuthState>(
  builder: (state) {
    if (AuthInitial) → SplashScreen
    if (AuthSuccess) → DashboardScreen(user, isNewUser)
    else             → LoginScreen
  }
)
```

---

## Data Persistence Strategy

### Local (Hive)

| Hive Box | Content |
|---|---|
| `authBox` | Cached auth session |
| `progressBox` | Local progress cache |
| `scriptsBox` | Generated daily challenge scripts |
| `settingsBox` | User preferences (reminder time, etc.) |
| `offlineQueueBox` | Queued operations (pending sync) |
| `contentScriptsBox` | User-created content scripts |

### Remote (Supabase)

| Table | Content |
|---|---|
| `users` | User profiles |
| `user_progress` | Challenge progress |
| `content_scripts` | AI-generated user scripts |
| `onboarding_questions` | Dynamic onboarding questions |
| `goal_options` | Goal choices for onboarding |
| `language_options` | Language preference choices |
| `daily_scripts` | AI-generated challenge scripts per user |

---

## Theme System

Defined in `lib/app.dart` → `_AppTheme.buildDarkTheme()`:

| Token | Value |
|---|---|
| Background | `#0F0F1A` (deep dark) |
| Surface | `#1E1E2E` |
| Primary | `#6366F1` (indigo) |
| Secondary | `#22D3EE` (cyan) |
| Tertiary | `#F472B6` (pink) |
| Error | `#FF6B6B` |
| Font (headlines) | Google Fonts — **Outfit** |
| Font (body) | Google Fonts — **Inter** |

---

## Key Third-Party Dependencies

| Package | Purpose |
|---|---|
| `flutter_bloc` | State management |
| `get_it` | Dependency injection |
| `supabase_flutter` | Backend (auth, db, storage) |
| `hive_flutter` | Local offline storage |
| `camera` | Video recording |
| `video_player` | Video playback |
| `mobile_scanner` | QR code scanning (web login) |
| `google_fonts` | Typography |
| `flutter_animate` | Animations |
| `lottie` | Lottie animations |
| `flutter_local_notifications` | Daily reminders |
| `internet_connection_checker` | Network monitoring |
| `rxdart` | Reactive streams |
| `dartz` | Functional programming (Either) |
| `share_plus` | Share videos/scripts |
| `gal` | Save videos to gallery |
| *(planned)* `purchases_flutter` | RevenueCat subscriptions |
