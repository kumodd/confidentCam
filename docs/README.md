# 📚 Confident Creator — Documentation Hub

> **App Name:** Confident Creator (package: `confident_cam`)
> **Version:** 1.0.1 | **Framework:** Flutter (Dart) | **Backend:** Supabase

---

## Overview

**Confident Creator** is a 30-day AI-guided video challenge app designed to help creators overcome camera anxiety. It combines structured daily video challenges, warmup exercises, AI-generated personalized scripts, real-time progress tracking, and a companion web portal — all powered by Supabase and OpenAI.

---

## 📁 Documentation Index

| Document | Description |
|---|---|
| [01_project_overview.md](./01_project_overview.md) | Product vision, features, and app flow |
| [02_architecture.md](./02_architecture.md) | Technical architecture, folder structure, and patterns |
| [03_backend_supabase.md](./03_backend_supabase.md) | Supabase setup, database schema, RLS, triggers |
| [04_auth_system.md](./04_auth_system.md) | Authentication flows (Phone OTP, Email/Password) |
| [05_web_portal.md](./05_web_portal.md) | Web portal pages, QR login, teleprompter features |
| [06_subscription_plan.md](./06_subscription_plan.md) | **RevenueCat subscription implementation plan (mobile + web)** |
| [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) | Mobile RevenueCat integration guide (Flutter) |
| [08_revenuecat_web.md](./08_revenuecat_web.md) | Web subscription integration guide (Stripe/RevenueCat) |
| [09_openai_integration.md](./09_openai_integration.md) | AI script generation, prompts, and OpenAI service |
| [10_state_management.md](./10_state_management.md) | BLoC pattern, events, states, and data flow |
| [11_environment_setup.md](./11_environment_setup.md) | Dev environment setup, secrets, and configuration |
| [12_feature_roadmap.md](./12_feature_roadmap.md) | Current status, completed features, and roadmap |

---

## 🚀 Quick Start

```bash
# 1. Clone and enter the project
cd ConfidantCam

# 2. Install dependencies
flutter pub get

# 3. Run on device/emulator
flutter run
```

> ⚠️ **Before running**, ensure `lib/core/config/app_config.dart` has valid Supabase and OpenAI credentials.

---

## 🔑 Key Credentials (see Environment Setup)

| Service | Location |
|---|---|
| Supabase URL & Anon Key | `lib/core/config/app_config.dart` |
| OpenAI API Key | `lib/core/config/app_config.dart` |
| RevenueCat API Keys | **To be added** (see `06_subscription_plan.md`) |

---

## 📱 Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Supported |
| iOS | ✅ Supported |
| Web (Flutter) | ✅ Supported |
| Web Portal (HTML/JS) | ✅ Live at `web_portal/` |
| macOS | 🔧 Scaffold only |
| Windows / Linux | 🔧 Scaffold only |
