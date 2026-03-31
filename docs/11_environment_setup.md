# 11 — Environment Setup

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.7.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | bundled with Flutter | — |
| Xcode | ≥ 15 (macOS only) | App Store |
| Android Studio | ≥ Hedgehog | [developer.android.com](https://developer.android.com/studio) |
| CocoaPods | latest | `sudo gem install cocoapods` |

---

## First-Time Setup

```bash
# 1. Clone the repository
git clone <repo-url>
cd ConfidantCam

# 2. Install Flutter dependencies
flutter pub get

# 3. iOS — Install CocoaPods dependencies
cd ios && pod install && cd ..

# 4. Run on a device/emulator
flutter run
```

---

## Configuration File

**`lib/core/config/app_config.dart`** is the single source of truth for all service keys and feature flags.

```dart
class AppConfig {
  // ──────────────────────────────────────────────────
  // Supabase
  // ──────────────────────────────────────────────────
  static const String supabaseUrl = 'https://govbpayonsbfwrfxzbgq.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_...';

  // ──────────────────────────────────────────────────
  // OpenAI
  // ──────────────────────────────────────────────────
  static const String openAiApiKey  = 'sk-proj-...';
  static const String openAiModel   = 'gpt-4o-mini';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const int    maxScriptTokens = 16300;

  // ──────────────────────────────────────────────────
  // RevenueCat (to be added)
  // ──────────────────────────────────────────────────
  // static const String revenueCatApiKeyAndroid = 'goog_xxx';
  // static const String revenueCatApiKeyIos     = 'appl_xxx';
  // static const String revenueCatEntitlement   = 'premium';

  // ──────────────────────────────────────────────────
  // Developer / Feature Flags
  // ──────────────────────────────────────────────────
  static const bool devMode       = true;   // ← Set false for production
  static const bool isPremiumUser = false;  // ← Replace with RC entitlement check

  // ──────────────────────────────────────────────────
  // Challenge Settings
  // ──────────────────────────────────────────────────
  static const int totalDays              = 3;   // ← Set 30 for production
  static const int totalWarmups           = 1;   // ← Set 3 for production
  static const int segmentedDaysEnd       = 5;
}
```

---

## Production Checklist

Before releasing to app stores, update the following:

| Setting | Dev Value | Production Value |
|---|---|---|
| `devMode` | `true` | **`false`** |
| `isPremiumUser` | `false` | **RevenueCat entitlement** |
| `totalDays` | `3` | **`30`** |
| `totalWarmups` | `1` | **`3`** |
| `openAiApiKey` | hardcoded | **Server-side via Edge Function** |
| `supabaseAnonKey` | hardcoded | **OK to stay (anon key is public)** |
| RevenueCat keys | (not added) | **Required for subscriptions** |
| EasyLoading debug | visible | Keep (harmless) |

---

## Hive Box Names

Defined in `lib/core/constants/app_constants.dart`:

| Constant | Box Name | Contents |
|---|---|---|
| `authBox` | `auth_box` | User session metadata |
| `progressBox` | `progress_box` | Daily challenge progress |
| `scriptsBox` | `scripts_box` | Daily AI-generated scripts |
| `settingsBox` | `settings_box` | Reminder time, preferences |
| `offlineQueueBox` | `offline_queue_box` | Queued sync operations |
| `contentScriptsBox` | `content_scripts_box` | User-created content scripts |

---

## Android Setup

### `android/app/build.gradle`

```groovy
android {
    defaultConfig {
        applicationId "com.confidentcreator.app"
        minSdkVersion 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.1"
    }
}
```

### `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Required permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<!-- For RevenueCat (when added) -->
<uses-permission android:name="com.android.vending.BILLING" />
```

---

## iOS Setup

### `ios/Runner/Info.plist`

```xml
<!-- Required for camera and microphone -->
<key>NSCameraUsageDescription</key>
<string>ConfidentCreator needs camera access to record your videos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>ConfidentCreator needs microphone access to record your videos.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ConfidentCreator saves your videos to your photo library.</string>
```

### Minimum iOS Version

Set in `ios/Podfile`:
```ruby
platform :ios, '14.0'
```

---

## Web Portal Setup

The web portal (`web_portal/`) is a static HTML/JS application. No build step required.

### Local Development

```bash
# Option 1: Python HTTP server
cd web_portal && python3 -m http.server 8080

# Option 2: npx serve
npx serve web_portal

# Option 3: VS Code Live Server extension
```

### Configuration (`web_portal/js/config.js`)

```javascript
const SUPABASE_URL      = 'https://govbpayonsbfwrfxzbgq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_...';
const STRIPE_PUB_KEY    = 'pk_live_...';  // Add when Stripe is integrated
```

### Deployment Options

| Platform | Notes |
|---|---|
| **GitHub Pages** | Free, simple static hosting |
| **Netlify** | Free tier, drag-and-drop deploy |
| **Vercel** | Free tier, fast CDN |
| **Firebase Hosting** | Integrates with Firebase if needed |
| **Supabase Storage** | Can host static assets (limited) |

---

## Supabase CLI Setup (for Edge Functions)

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Login
supabase login

# Link to project
supabase link --project-ref govbpayonsbfwrfxzbgq

# Deploy an edge function
supabase functions deploy create_user_record

# Set secrets
supabase secrets set OPENAI_API_KEY=sk-proj-...
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...

# View logs
supabase functions logs create_user_record
```

---

## Environment Variables (Recommended for CI/CD)

Use `--dart-define` to pass keys at build time (avoids storing secrets in source):

```bash
# Build with env vars
flutter build apk \
  --dart-define=OPENAI_API_KEY=sk-proj-... \
  --dart-define=REVENUECAT_ANDROID=goog_... \
  --dart-define=REVENUECAT_IOS=appl_...
```

Then in `app_config.dart`:

```dart
static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
static const String revenueCatApiKeyAndroid = String.fromEnvironment('REVENUECAT_ANDROID');
```

---

## Useful Flutter Commands

```bash
# Run app (debug)
flutter run

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices

# Clean build cache
flutter clean && flutter pub get

# Build Android APK (debug)
flutter build apk --debug

# Build Android App Bundle (release)
flutter build appbundle --release

# Build iOS IPA
flutter build ipa --release

# Run tests
flutter test

# Analyze code
flutter analyze
```
