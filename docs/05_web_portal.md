# 05 — Web Portal

## Overview

The **Confident Creator Web Portal** is a standalone HTML/CSS/JavaScript application located in `web_portal/`. It allows users to manage their scripts, generate AI content, and use a professional teleprompter — all from any web browser.

**Stack:** Vanilla HTML5 + CSS3 + JavaScript (ES6 modules concept via script tags)
**Backend:** Supabase JS SDK (CDN)

---

## Pages

| File | Route | Description |
|---|---|---|
| `index.html` | `/` | Login page (email + QR code modes) |
| `dashboard.html` | `/dashboard` | Recent scripts overview |
| `generator.html` | `/generator` | AI-powered script generator |
| `scripts.html` | `/scripts` | Full script manager (list, edit, delete) |
| `teleprompter.html` | `/teleprompter` | Professional teleprompter display |
| `privacy-policy.html` | `/privacy-policy` | Legal privacy policy |
| `terms-of-service.html` | `/terms-of-service` | Legal terms of service |

---

## JavaScript Modules

| File | Role |
|---|---|
| `js/config.js` | Supabase URL + anon key configuration |
| `js/supabase-client.js` | Initialize Supabase JavaScript client |
| `js/auth.js` | Auth state management, session persistence, auto-redirect |
| `js/login.js` | Email login form, forgot password modal, tab switching |
| `js/qr-auth.js` | QR code generation + realtime session polling |
| `js/dashboard.js` | Fetch and display recent scripts |
| `js/scripts-page.js` | Script CRUD operations (list, edit, delete, share) |
| `js/generator.js` | Multi-step script generator form + OpenAI integration |
| `js/teleprompter.js` | Teleprompter engine (scroll, voice control, settings) |
| `js/realtime.js` | Supabase Realtime subscription for QR login |
| `js/scripts.js` | Shared script utility functions |

---

## Login Flow

### Email Login
1. User enters email + password
2. `js/login.js` calls Supabase `signInWithPassword()`
3. On success → redirect to `dashboard.html`
4. Session persisted via Supabase SDK

### QR Code Login
1. Page generates a unique `session_token` (UUID)
2. Inserts into `web_sessions` table with status `pending`
3. Renders QR code using `qrcodejs` library
4. `js/realtime.js` subscribes to `web_sessions` row changes
5. User scans QR with mobile app (`Settings → Web Login`)
6. Mobile app updates `web_sessions` row with auth token + status `authenticated`
7. Realtime fires → web reads auth token → calls Supabase `setSession()`
8. Redirects to dashboard

### Auth Protection
All pages except `index.html`, `privacy-policy.html`, and `terms-of-service.html` check for a valid Supabase session on load via `js/auth.js`. Unauthenticated users are redirected to `index.html`.

---

## Script Generator (AI)

**File:** `js/generator.js`

Multi-step questionnaire that collects:
- Script topic
- Target audience
- Key message / call-to-action
- Tone (professional, casual, inspirational, etc.)
- Script template (Educational, Story, Tips, Review, DayInLife, Custom)

Then calls the OpenAI API (or Supabase Edge Function) to generate a 3-part script (`Hook / Body / Close`). The script is saved to Supabase `content_scripts` table.

---

## Teleprompter

**File:** `js/teleprompter.js`

Features:
- Variable scroll speed control
- Font size adjustment
- Auto-scroll with start/pause toggle
- Voice control (using Web Speech API — `SpeechSynthesisUtterance` or speech recognition)
- Full-screen mode
- Mirror mode (for physical teleprompter setups)
- Script loaded from Supabase (by ID from URL params) or pasted directly

---

## CSS Structure

| File | Content |
|---|---|
| `css/style.css` | Global tokens, reset, typography, utilities |
| `css/login.css` | Login page-specific styles |

Design uses CSS variables for theming:

```css
:root {
  --color-primary: #6366F1;    /* Indigo */
  --color-secondary: #22D3EE;  /* Cyan */
  --color-bg: #0F0F1A;         /* Deep dark */
  --color-surface: #1E1E2E;    /* Card surface */
  --font-heading: 'Outfit', sans-serif;
  --font-body: 'Inter', sans-serif;
}
```

---

## Planned: Web Subscription Integration

The web portal will need a subscription/pricing page for web users who want to subscribe without going through the app stores.

**Recommended approach:** Stripe Checkout (embedded) with RevenueCat webhook sync.

See [08_revenuecat_web.md](./08_revenuecat_web.md) for the full plan.

### Pages to Add

| Page | Purpose |
|---|---|
| `pricing.html` | Plan comparison + subscribe buttons |
| `billing.html` | Manage subscription (cancel, upgrade) |
| `success.html` | Post-payment confirmation page |

### Feature Gating on Web

Premium-only features (e.g., AI generator, advanced teleprompter) should:
1. Check subscription status from Supabase `subscriptions` table on page load
2. Show upgrade prompt if free tier
3. Allow access if `is_active = true` and `expires_at > now()`
