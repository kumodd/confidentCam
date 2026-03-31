# 03 — Backend: Supabase

## Project Details

| Setting | Value |
|---|---|
| Supabase URL | `https://govbpayonsbfwrfxzbgq.supabase.co` |
| Anon Key | Stored in `lib/core/config/app_config.dart` |
| Auth Providers | Email/Password, Phone OTP |
| Edge Functions | `create_user_record`, `delete_account` |

---

## Database Schema

### `public.users`

```sql
CREATE TABLE public.users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  phone       TEXT,            -- nullable (email-only signups)
  display_name TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### `public.user_progress`

```sql
CREATE TABLE public.user_progress (
  user_id              UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  current_day          INTEGER DEFAULT 0,
  total_days_completed INTEGER DEFAULT 0,
  streak_count         INTEGER DEFAULT 0,
  last_completion_date DATE,
  warmup_0_done        BOOLEAN DEFAULT FALSE,
  warmup_1_done        BOOLEAN DEFAULT FALSE,
  warmup_2_done        BOOLEAN DEFAULT FALSE,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);
```

### `public.content_scripts`

Stores AI-generated scripts from the Content Creator feature.

```sql
-- Fields: id, user_id, title, part1, part2, part3,
--         prompt_template, questionnaire (jsonb), 
--         is_recorded, created_at, updated_at
```

### Future Table: `public.subscriptions`

> **To be created for RevenueCat webhook sync.** See [06_subscription_plan.md](./06_subscription_plan.md).

```sql
CREATE TABLE public.subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID REFERENCES public.users(id) ON DELETE CASCADE,
  revenuecat_user_id    TEXT NOT NULL,
  product_id            TEXT,                     -- e.g. 'confident_creator_monthly'
  plan_type             TEXT,                     -- 'monthly' | 'yearly' | 'free'
  entitlement           TEXT,                     -- e.g. 'premium'
  is_active             BOOLEAN DEFAULT FALSE,
  expires_at            TIMESTAMPTZ,
  started_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Row Level Security (RLS)

All tables have RLS enabled. Policies follow the pattern:

```sql
-- Users can only read/write their own rows
USING (auth.uid() = id)         -- for users table
USING (auth.uid() = user_id)    -- for user_progress table
```

### Current Policies

| Table | Operation | Policy |
|---|---|---|
| `users` | SELECT | auth.uid() = id |
| `users` | INSERT | auth.uid() = id |
| `users` | UPDATE | auth.uid() = id |
| `users` | DELETE | auth.uid() = id |
| `user_progress` | SELECT | auth.uid() = user_id |
| `user_progress` | INSERT | auth.uid() = user_id |
| `user_progress` | UPDATE | auth.uid() = user_id |

---

## Triggers & Functions

### `handle_new_user()` — auto-creates profile on signup

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.users (id, email, phone, created_at)
  VALUES (NEW.id, NEW.email, NEW.phone, NOW())
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, updated_at = NOW();

  INSERT INTO public.user_progress (user_id, created_at)
  VALUES (NEW.id, NOW())
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fires after every new auth.users insert
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### `update_updated_at_column()` — auto-timestamp updates

Applied to `users` and `user_progress` tables via `BEFORE UPDATE` triggers.

---

## Edge Functions

### `create_user_record`

Called during email signup when the database trigger is too slow. Accepts `{ email, phone }` in the body, creates the user record and initial progress row.

### `delete_account`

Deletes auth user and cascading data. Requires `Authorization: Bearer <access_token>` header.

---

## SQL Setup Files

| File | Purpose |
|---|---|
| `supabase_complete_setup.sql` | Full schema + RLS + triggers (run first) |
| `supabase_rls_fix.sql` | Fixes for RLS policy updates |
| `supabase_trigger_fix.sql` | Trigger recreation if it breaks |
| `content_scripts_rls_setup.sql` | RLS for content_scripts table |
| `web_sessions_setup.sql` | Web QR login session tracking |
| `fix_phone_nullable.sql` | Make phone column nullable |
| `FRESH_START_AUTH_SETUP.sql` | Nuclear reset: drops all and recreates |

---

## Web Portal: Supabase Integration

The web portal uses the Supabase JavaScript SDK (CDN):

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

Config in `web_portal/js/config.js`:

```js
const SUPABASE_URL = 'https://govbpayonsbfwrfxzbgq.supabase.co';
const SUPABASE_ANON_KEY = '...';
```

---

## Realtime

The web portal uses Supabase Realtime for QR login token polling:

- `web_portal/js/realtime.js` — subscribes to `web_sessions` table changes
- Detects when mobile app scans QR and confirms login
