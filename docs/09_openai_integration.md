# 09 — OpenAI Integration

## Overview

Confident Creator uses OpenAI's `gpt-4o-mini` model to generate **personalized, spoken-word scripts** for:

1. **30-day daily challenge scripts** (generated in weekly batches during onboarding)
2. **3 warmup scripts** (generated once during onboarding)
3. **Extension scripts** (post Day-30, 15 days per extension, up to 4 extensions)
4. **Content Creator scripts** (on-demand via questionnaire)

All generation happens in `lib/services/openai_service.dart`. The service makes direct HTTPS calls to the OpenAI REST API — no SDK, just `package:http`.

---

## Configuration

In `lib/core/config/app_config.dart`:

```dart
static const String openAiApiKey  = 'sk-proj-...';
static const String openAiModel   = 'gpt-4o-mini';
static const String openAiBaseUrl = 'https://api.openai.com/v1';
static const int    maxScriptTokens = 16300;
```

> ⚠️ The API key is currently hardcoded. Before production, move to environment variables or Supabase secrets (call via an Edge Function to keep the key server-side).

---

## Generation Methods

### 1. `generateWeeklyScripts()` — Primary method

Generates **7 scripts per call** (one week at a time). Called 4–5 times during onboarding.

```dart
final scripts = await openAiService.generateWeeklyScripts(
  weekNumber: 1,         // 1–5 (5 weeks = 30 days + partial 5th)
  firstName: 'Riya',
  age: 24,
  location: 'Mumbai',
  goal: 'Build a fitness brand on Instagram',
  onboardingAnswers: { 'challenges': ['self-doubt', 'consistency'] },
  language: 'hinglish', // 'en' | 'hi' | 'hinglish'
  promptMode: PromptMode.selfDiscovery,
  humanTouch: HumanTouchLevel.natural,
  culture: AudienceCulture.india,
);
```

**Word count progression (scales with confidence):**

| Week | Days | Words per Script |
|---|---|---|
| 1 | 1–7   | 175–225 words |
| 2 | 8–14  | 225–275 words |
| 3 | 15–21 | 275–325 words |
| 4 | 22–28 | 325–375 words |
| 5 | 29–30 | 375–425 words |

### 2. `generateWarmupScripts()`

Generates 3 warmup scripts (30–60 seconds each). Called once at the end of onboarding.

```dart
final warmups = await openAiService.generateWarmupScripts(
  firstName: 'Riya',
  location: 'Mumbai',
  goal: 'Build a fitness brand',
  language: 'en',
);
// Returns: [{ warmupIndex: 0, title: 'First Steps', part1, part2, part3, focus }]
```

### 3. `generateExtensionScripts()`

Called when a user completes Day 30 and unlocks extension packs:

```dart
final extension = await openAiService.generateExtensionScripts(
  firstName: 'Riya',
  goal: 'Build a fitness brand',
  extensionNumber: 1,     // 1–4
  startDay: 31,
  endDay: 45,             // 15 days per extension
);
```

### 4. `generateScripts()` *(deprecated)*

Legacy method that tried to generate all 30 scripts in a single API call. Replaced by the weekly approach due to token limits. Do not use.

---

## Script Structure (JSON Output)

Every script from OpenAI follows a **strict 3-part structure**:

```json
{
  "dayNumber": 1,
  "title": "The Fear Nobody Talks About",
  "part1": "You're not bad at being on camera. You're just scared of being seen.",
  "part2": "There's a difference. Bad means skill. Scared means human. ...",
  "part3": "Today, that's all you're proving. Save this for when you forget.",
  "focus": "recognizing camera anxiety vs skill gap",
  "duration": "1-2 minutes"
}
```

| Part | Section | Word Count (Wk 1) | Purpose |
|---|---|---|---|
| `part1` | Hook | ~27 words | Scroll-stopper. Bold claim or question. |
| `part2` | Body | ~123 words | Core value/insight delivery. |
| `part3` | Close | ~27 words | CTA or final thought. |

---

## Prompt Configuration (`lib/core/config/prompt_config.dart`)

Scripts are tuned by combining three orthogonal dimensions:

### `PromptMode` — Controls the emotional frame

| Mode | Persona | Arc |
|---|---|---|
| `selfDiscovery` (default) | Beginner learning to feel safe | Fear → Familiarity → Small relief |
| `clarityTraining` | Helps thoughts slow and form naturally | Confusion → Structure → Clarity |
| `storytelling` | Speaks through lived moments | Moment → Emotion → Staying inside it |
| `authorityBuild` | Calm, grounded, no dominance | Presence → Steadiness |
| `rawDiary` | Real person thinking out loud | Emotion → Release → No resolution |

### `HumanTouchLevel` — Controls speech naturalness

| Level | Rules |
|---|---|
| `raw` | Incomplete thoughts, contradictions, messy flow |
| `natural` (default) | Natural repetition, gentle pauses using "...", imperfect flow |
| `composed` | Calm pacing, fewer words, controlled pauses |

### `AudienceCulture` — Contextualises emotional reference

| Culture | Context |
|---|---|
| `india` (default) | Quiet self-doubt, fear of judgement, guilt around self-focus |
| `global` | Neutral — no cultural overlay |

---

## Language Support

| Code | Description |
|---|---|
| `en` | English (casual, spoken-word, international) |
| `hi` | Hindi in Devanagari script |
| `hinglish` | Hindi + English mix in Roman script (most popular for Indian creators) |

---

## Anti-Robotic Rules (Embedded in Every Prompt)

These rules are explicitly injected into every prompt to prevent AI-sounding scripts:

- ❌ No "Hello everyone, today I want to talk about..."
- ❌ No storybook narration: "Once I went to the market..."
- ❌ No labels in the output: "Hook:", "Part 1:", "[pause]"
- ❌ No meta-phrases: "In this video", "Today I'll show you"
- ✅ Start with a controversial statement, question, or vulnerable admission
- ✅ Use "You" to address audience directly
- ✅ Mimic natural speech patterns (short fragments, imperfect flow)

---

## API Call Details

```dart
POST https://api.openai.com/v1/chat/completions

headers:
  Authorization: Bearer {openAiApiKey}
  Content-Type: application/json

body:
  model: gpt-4o-mini
  messages:
    - role: system
      content: "You are a viral content scriptwriter. You write scripts meant to be SPOKEN..."
    - role: user
      content: {prompt}
  max_completion_tokens: 16300
  temperature: 1
```

The high `temperature: 1` encourages creative, varied scripts rather than formulaic ones.

---

## Response Parsing

The service handles OpenAI's habit of wrapping JSON in markdown fences:

```dart
// Strips ```json ... ``` if present
// Validates response ends with ']'
// If truncated → throws Exception (not silently partial data)
// Logs first/last 500 chars for debugging truncation issues
```

**Common failure: truncation.** If `finish_reason` is `"length"`, the model ran out of tokens. Solution: increase `maxScriptTokens` in `AppConfig` or split into smaller batches.

---

## Planned: Move API Key Server-Side

For production security, the OpenAI key should **not** be embedded in the app binary.

**Recommended approach:**

1. Create a Supabase Edge Function `generate_scripts`
2. Store `OPENAI_API_KEY` in Supabase Secrets
3. Mobile app calls the Edge Function with its Supabase JWT
4. Edge function validates auth, calls OpenAI, returns scripts
5. Rate-limit by user to prevent abuse

```dart
// Future: replace direct OpenAI call with:
final response = await supabase.functions.invoke(
  'generate_scripts',
  headers: {'Authorization': 'Bearer ${session.accessToken}'},
  body: { 'weekNumber': 1, 'firstName': 'Riya', ... },
);
```

---

## Cost Estimate (gpt-4o-mini)

| Operation | Tokens (approx) | Cost per run |
|---|---|---|
| Weekly scripts (7 days) | ~3,000 tokens | ~$0.001 |
| Full onboarding (30 days + warmups) | ~15,000 tokens | ~$0.005 |
| Content Creator script | ~1,000 tokens | ~$0.0003 |

> At scale (10,000 new users/month), onboarding AI cost ≈ **$50/month** — very affordable.
