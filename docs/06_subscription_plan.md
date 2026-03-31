# 06 — Subscription Plan (RevenueCat — Mobile + Web)

## Overview

This document defines the complete subscription strategy for Confident Creator across **mobile** (iOS + Android via RevenueCat) and **web** (Stripe with RevenueCat webhook sync).

---

## Subscription Tiers

| Tier | Price (suggested) | Billing | Features |
|---|---|---|---|
| **Free** | $0 | — | 3 warmups + Day 1 only, basic scripts |
| **Monthly** | $9.99/mo | Every 30 days | Full 30-day challenge, AI scripts, content creator |
| **Yearly** | $59.99/yr | Every 12 months | All Monthly features + best value label |

> 💡 **Pricing is a suggestion.** Adjust based on market research before launch.

---

## RevenueCat Configuration

### Products to Create in App Stores

#### iOS (App Store Connect)
```
Product ID:  confident_creator_monthly
Type:        Auto-Renewable Subscription
Duration:    1 Month
Price:       $9.99

Product ID:  confident_creator_yearly
Type:        Auto-Renewable Subscription
Duration:    1 Year
Price:       $59.99
```

#### Android (Google Play Console)
```
Product ID:  confident_creator_monthly
Type:        Subscription
Billing:     Monthly
Price:       $9.99

Product ID:  confident_creator_yearly
Type:        Subscription
Billing:     Yearly
Price:       $59.99
```

### RevenueCat Dashboard Setup

1. Create a new **Project** in RevenueCat dashboard
2. Add **iOS app** and **Android app** to the project
3. Add API keys (public SDK keys — one per platform)
4. Create **Products**:
   - `confident_creator_monthly`
   - `confident_creator_yearly`
5. Create an **Entitlement** named `premium`
6. Create an **Offering** named `default` with these products as packages:
   - `$rc_monthly` → `confident_creator_monthly`
   - `$rc_annual` → `confident_creator_yearly`
7. Set the `default` offering as the **Current Offering**

---

## Mobile Integration Plan (Flutter)

> See [07_revenuecat_mobile.md](./07_revenuecat_mobile.md) for detailed implementation.

### Steps Summary

1. Add `purchases_flutter` dependency to `pubspec.yaml`
2. Configure native platforms (Info.plist for iOS, build.gradle for Android)
3. Initialize RevenueCat SDK in `main.dart` after auth check
4. Create `SubscriptionService` to wrap RevenueCat SDK
5. Create `SubscriptionBloc` for state management
6. Create `PaywallScreen` with plan comparison + purchase buttons
7. Implement entitlement check everywhere premium features are used
8. Sync RevenueCat `appUserID` with Supabase `auth.uid()` on login

### Premium Feature Gating (Current Skeleton)

The `UserProgress.isDayUnlocked()` method already has a `isPremium` flag:

```dart
// lib/domain/entities/user_progress.dart
bool isDayUnlocked(int day, {bool devMode = false, bool isPremium = false}) {
  // Premium users can access next day without waiting
  if (isPremium && day == currentDay + 1) return true;
  ...
}
```

And `AppConfig` has:
```dart
static const bool isPremiumUser = false;  // Replace with RevenueCat entitlement check
```

---

## Web Integration Plan

> See [08_revenuecat_web.md](./08_revenuecat_web.md) for detailed implementation.

Web users will subscribe via **Stripe** (recommended) or RevenueCat's web billing (if available in your region).

### Architecture

```
User clicks "Subscribe" on pricing.html
    │
    ▼
Stripe Checkout Session created
(via Supabase Edge Function)
    │
    ▼
User completes payment on Stripe
    │
    ▼
Stripe sends webhook to Supabase Edge Function
    │
    ▼
Edge Function updates subscriptions table
    │
    ▼
Web portal reads subscriptions table → grant/revoke access
```

---

## Supabase Schema for Subscriptions

Run this SQL in Supabase SQL Editor:

```sql
-- ============================================
-- SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  revenuecat_user_id    TEXT,             -- RC's app_user_id (matches Supabase user.id)
  stripe_customer_id    TEXT,             -- For web billing
  stripe_subscription_id TEXT,           -- Active Stripe subscription ID
  product_id            TEXT,            -- 'confident_creator_monthly' or '_yearly'
  plan_type             TEXT NOT NULL DEFAULT 'free',  -- 'free' | 'monthly' | 'yearly'
  entitlement           TEXT DEFAULT 'premium',
  is_active             BOOLEAN NOT NULL DEFAULT FALSE,
  platform              TEXT,            -- 'ios' | 'android' | 'web'
  expires_at            TIMESTAMPTZ,
  started_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: users can read their own subscription
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscription"
  ON public.subscriptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role can write (for webhooks)
GRANT ALL ON public.subscriptions TO service_role;

-- Auto-update timestamp
CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

---

## RevenueCat Webhook → Supabase Sync (Mobile)

RevenueCat can send webhooks to a Supabase Edge Function to keep subscription status in sync.

### Edge Function: `revenuecat_webhook`

```
POST /functions/v1/revenuecat_webhook
Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>

Body: RevenueCat webhook payload
  event.type: INITIAL_PURCHASE | RENEWAL | CANCELLATION | EXPIRATION
  event.app_user_id: <supabase user.id>
  event.product_id: confident_creator_monthly
  event.expiration_at_ms: <unix timestamp>
```

The edge function:
1. Validates `Authorization` header against stored secret
2. Maps `app_user_id` to `user_id` in `subscriptions` table
3. Updates `is_active`, `plan_type`, `expires_at`, `product_id` accordingly

---

## Implementation Phases

### Phase 1 — Mobile Subscriptions (Priority)
- [ ] Add `purchases_flutter` to `pubspec.yaml`
- [ ] Configure iOS and Android native projects
- [ ] Create `SubscriptionService`
- [ ] Create `SubscriptionBloc` + states/events
- [ ] Build `PaywallScreen` UI
- [ ] Wire entitlement checks to app features
- [ ] Set RevenueCat `appUserID` = Supabase `auth.uid()`
- [ ] Test on physical device (subscriptions don't work on simulators)

### Phase 2 — Backend Sync
- [ ] Create `subscriptions` table in Supabase
- [ ] Create `revenuecat_webhook` Edge Function
- [ ] Configure webhook URL in RevenueCat dashboard
- [ ] Test webhook delivery (use RevenueCat's "Send Test Event")

### Phase 3 — Web Subscriptions
- [ ] Create Stripe account and products
- [ ] Build `pricing.html` page
- [ ] Create Supabase Edge Function for Stripe checkout session
- [ ] Create Stripe webhook handler edge function
- [ ] Gate premium features on web based on `subscriptions` table

### Phase 4 — Polish
- [ ] Add free trial logic (7-day trial on first install)
- [ ] Handle subscription restoration (returning users)
- [ ] Manage subscription page (cancel, change plan)
- [ ] Analytics (track paywall views, conversions)

---

## Key Considerations

> [!IMPORTANT]
> **RevenueCat `appUserID` MUST equal Supabase `auth.uid()`** — this is what links purchases to users across devices and platforms.

> [!WARNING]
> **Never test subscriptions on iOS Simulator** — use a physical device with a Sandbox Apple ID.

> [!NOTE]
> **RevenueCat does NOT support web purchases** natively. Use Stripe for web and sync status to Supabase manually via webhooks.

> [!TIP]
> Set `devMode = true` in `AppConfig` during development to bypass subscription checks without mocking RevenueCat.
