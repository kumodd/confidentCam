# 08 — Web Subscription Integration (Stripe + RevenueCat Sync)

## Overview

RevenueCat does not natively support web purchases. For the Confident Creator web portal, we use **Stripe** for payment processing, with a Supabase Edge Function to:
1. Create Stripe Checkout sessions
2. Handle Stripe webhooks and update the `subscriptions` table
3. Allow web users' premium status to cascade back to mobile (via shared Supabase `user_id`)

---

## Architecture

```
Web Portal (web_portal/)
    │
    ▼
pricing.html → user clicks "Subscribe Monthly/Yearly"
    │
    ▼
POST /functions/v1/create_checkout_session
(Supabase Edge Function)
    │
    ├── auth.uid() from JWT header
    ├── Creates/retrieves Stripe Customer
    ├── Creates Stripe Checkout Session
    └── Returns { checkout_url }
    │
    ▼
Browser → stripe.com checkout page
    │
User completes payment
    │
    ▼
Stripe sends webhook to:
POST /functions/v1/stripe_webhook
    │
    ├── Verifies Stripe signature
    ├── Handles events:
    │     checkout.session.completed → activate subscription
    │     customer.subscription.updated → update plan
    │     customer.subscription.deleted → deactivate
    └── Updates public.subscriptions table
    │
    ▼
Web portal reads subscriptions table on page load → grant/revoke access
```

---

## Step 1: Stripe Account Setup

1. Create account at [stripe.com](https://stripe.com)
2. Create **Products**:
   - Product: "Confident Creator Monthly"
     - Price: $9.99 / month, recurring
     - Price ID: `price_xxxxx_monthly`
   - Product: "Confident Creator Yearly"
     - Price: $59.99 / year, recurring
     - Price ID: `price_xxxxx_yearly`
3. Note your API keys:
   - Publishable key: `pk_live_xxx` / `pk_test_xxx`
   - Secret key: `sk_live_xxx` / `sk_test_xxx`
4. Set up webhook endpoint (after deploying edge function):
   - URL: `https://govbpayonsbfwrfxzbgq.supabase.co/functions/v1/stripe_webhook`
   - Events to listen: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
   - Webhook signing secret: `whsec_xxx`

---

## Step 2: Store Stripe Config

### Supabase Secrets (for Edge Functions)

In Supabase Dashboard → Settings → Edge Functions → Secrets:

```
STRIPE_SECRET_KEY      = sk_live_xxx (or sk_test_xxx)
STRIPE_WEBHOOK_SECRET  = whsec_xxx
STRIPE_MONTHLY_PRICE   = price_xxxxx_monthly
STRIPE_YEARLY_PRICE    = price_xxxxx_yearly
```

### Web Portal Config (`web_portal/js/config.js`)

```javascript
const SUPABASE_URL = 'https://govbpayonsbfwrfxzbgq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_...';
const STRIPE_PUBLISHABLE_KEY = 'pk_live_xxx';
```

---

## Step 3: Supabase Edge Functions

### `create_checkout_session`

**File:** `supabase/functions/create_checkout_session/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);

serve(async (req) => {
  const { plan } = await req.json(); // 'monthly' | 'yearly'
  
  // Get authenticated user
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  // Get or create Stripe customer
  const existing = await supabase
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', user.id)
    .maybeSingle();

  let customerId = existing?.data?.stripe_customer_id;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user.email,
      metadata: { supabase_user_id: user.id },
    });
    customerId = customer.id;
  }

  // Select price based on plan
  const priceId = plan === 'yearly'
    ? Deno.env.get('STRIPE_YEARLY_PRICE')
    : Deno.env.get('STRIPE_MONTHLY_PRICE');

  // Create checkout session
  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${req.headers.get('origin')}/success.html?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${req.headers.get('origin')}/pricing.html`,
    metadata: { supabase_user_id: user.id },
    subscription_data: {
      metadata: { supabase_user_id: user.id },
    },
  });

  return new Response(JSON.stringify({ url: session.url }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

### `stripe_webhook`

**File:** `supabase/functions/stripe_webhook/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

serve(async (req) => {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature')!;

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.CheckoutSession;
    const userId = session.metadata?.supabase_user_id;
    const subscription = await stripe.subscriptions.retrieve(session.subscription as string);
    
    await supabase.from('subscriptions').upsert({
      user_id: userId,
      stripe_customer_id: session.customer as string,
      stripe_subscription_id: subscription.id,
      product_id: subscription.items.data[0].price.id,
      plan_type: subscription.items.data[0].price.recurring?.interval === 'year' ? 'yearly' : 'monthly',
      is_active: true,
      platform: 'web',
      expires_at: new Date(subscription.current_period_end * 1000).toISOString(),
    }, { onConflict: 'user_id' });
  }

  if (event.type === 'customer.subscription.deleted') {
    const sub = event.data.object as Stripe.Subscription;
    const userId = sub.metadata?.supabase_user_id;
    await supabase.from('subscriptions')
      .update({ is_active: false, plan_type: 'free' })
      .eq('user_id', userId);
  }

  if (event.type === 'customer.subscription.updated') {
    const sub = event.data.object as Stripe.Subscription;
    const userId = sub.metadata?.supabase_user_id;
    await supabase.from('subscriptions')
      .update({
        is_active: sub.status === 'active',
        expires_at: new Date(sub.current_period_end * 1000).toISOString(),
      })
      .eq('user_id', userId);
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

---

## Step 4: Web Pages to Create

### `pricing.html`

```html
<!-- Plan comparison page -->
<div class="pricing-cards">
  <!-- Free Tier -->
  <div class="plan-card">
    <h2>Free</h2>
    <p class="price">$0 <span>/forever</span></p>
    <ul>
      <li>✅ 3 Warmup exercises</li>
      <li>✅ Day 1 challenge</li>
      <li>❌ Full 30-day challenge</li>
      <li>❌ AI script generation</li>
    </ul>
    <button class="btn-outline" disabled>Current Plan</button>
  </div>

  <!-- Monthly -->
  <div class="plan-card">
    <h2>Monthly</h2>
    <p class="price">$9.99 <span>/month</span></p>
    <ul>...</ul>
    <button id="subscribe-monthly" class="btn-primary">Subscribe Monthly</button>
  </div>

  <!-- Yearly (Best Value) -->
  <div class="plan-card featured">
    <span class="badge">BEST VALUE</span>
    <h2>Yearly</h2>
    <p class="price">$59.99 <span>/year</span></p>
    <p class="savings">Save 50% vs monthly</p>
    <ul>...</ul>
    <button id="subscribe-yearly" class="btn-primary">Subscribe Yearly</button>
  </div>
</div>
```

### `pricing.js` logic

```javascript
async function subscribe(plan) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) { window.location.href = '/index.html'; return; }

  const response = await fetch(`${SUPABASE_URL}/functions/v1/create_checkout_session`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ plan }),
  });

  const { url } = await response.json();
  window.location.href = url; // Redirect to Stripe Checkout
}

document.getElementById('subscribe-monthly').addEventListener('click', () => subscribe('monthly'));
document.getElementById('subscribe-yearly').addEventListener('click', () => subscribe('yearly'));
```

---

## Step 5: Feature Gating on Web

On each page (dashboard, generator, teleprompter), check subscription status:

```javascript
// js/subscription.js
async function checkPremiumAccess() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;

  const { data } = await supabase
    .from('subscriptions')
    .select('is_active, expires_at, plan_type')
    .eq('user_id', user.id)
    .maybeSingle();

  if (!data) return false;
  
  const isActive = data.is_active && new Date(data.expires_at) > new Date();
  return isActive;
}

// On page load:
const isPremium = await checkPremiumAccess();
if (!isPremium) {
  showUpgradePrompt(); // show modal linking to pricing.html
}
```

---

## Cross-Platform Status Sync

The `subscriptions` table is the **single source of truth** for premium status:

| Source | Updates Table? | Reads Table? |
|---|---|---|
| RevenueCat webhook (mobile) | ✅ Yes (via edge function) | — |
| Stripe webhook (web) | ✅ Yes (via edge function) | — |
| Mobile app | — | ✅ Yes (via Supabase client) |
| Web portal | — | ✅ Yes (via Supabase JS) |

This means: **a user who subscribes on web will also have premium access on mobile** (and vice versa) — as long as they use the same account.

---

## Deployment

```bash
# Deploy all edge functions
supabase functions deploy create_checkout_session
supabase functions deploy stripe_webhook
supabase functions deploy revenuecat_webhook

# Set secrets
supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
supabase secrets set STRIPE_MONTHLY_PRICE=price_xxx
supabase secrets set STRIPE_YEARLY_PRICE=price_xxx
supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_rc_secret
```
