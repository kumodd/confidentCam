// Pure, deterministic script pipeline helpers shared by the Supabase Edge Function
// and executable directly in Node/Deno unit tests (zero external network dependencies).

export const OPENAI_MODEL = 'gpt-4o-mini'
export const SPEAKING_WPM = 140
export const BUILTIN_PROMPT_VERSION = 2

export interface PromptTemplateRecord {
    prompt_key: string
    version: number
    system_prompt: string | null
    user_prompt_template: string
}

export function renderPromptTemplate(
    template: string,
    vars: Record<string, string>,
): string {
    return template
        .replace(/\{\{(\w+)\}\}/g, (_match, key: string) => vars[key] ?? '')
        .replace(/\n{3,}/g, '\n\n')
        .trim()
}

export interface ExistingScript {
    title?: string
    part1?: string
    part2?: string
    part3?: string
}

export interface PromptProfilePayload {
    systemPersona?: string
    coreIntent?: string
    speakerMindset?: string
    emotionalArc?: string
    forbiddenPatterns?: string
    closingBehavior?: string
    humanSpeechRules?: string
    audienceMirrorRules?: string
    culturalRules?: string
}

export interface GenerateRequest {
    action?: 'generate' | 'refine' | 'weekly' | 'warmup' | 'enhance_idea'
    spokenTranscript?: string
    template?: string
    topic?: string
    audience?: string
    coreMessage?: string
    message?: string
    tone?: string
    length?: string
    platform?: string
    ctaStyle?: string
    customPrompt?: string
    languageCode?: string
    languageText?: string
    scriptStyle?: 'spoken_natural' | 'romanized'
    markdownMode?: boolean
    refineInstruction?: string
    existingScript?: ExistingScript
    // Weekly / Warmup challenge fields
    weekNumber?: number
    startDay?: number
    endDay?: number
    firstName?: string
    age?: number
    location?: string
    goal?: string
    onboardingAnswers?: Record<string, unknown>
    promptProfile?: PromptProfilePayload
}

export interface RawEnhancedIdeaOutput {
    detectedLanguageCode: string
    detectedLanguageName: string
    detectedScriptStyle: 'spoken_natural' | 'romanized'
    topic: string
    audience: string
    coreMessage: string
    suggestedTemplate: string
    suggestedTone: string
    suggestedLength: string
    suggestedPlatform: string
    summaryNote: string
}

export interface RawScriptOutput {
    title: string
    part1: string
    bodyBeats: string[]
    part3: string
    hookAlternatives: string[]
}

export interface RawWeeklyScriptItem {
    dayNumber: number
    title: string
    part1: string
    part2: string
    part3: string
    focus: string
    duration: string
}

export interface RawWeeklyScriptsOutput {
    scripts: RawWeeklyScriptItem[]
}

export interface RawWarmupScriptItem {
    warmupIndex: number
    title: string
    part1: string
    part2: string
    part3: string
    focus: string
}

export interface RawWarmupScriptsOutput {
    scripts: RawWarmupScriptItem[]
}

export const TEMPLATE_ALIASES: Record<string, string> = {
    educational: 'educational',
    education: 'educational',
    explainer: 'educational',
    howto: 'howto',
    how_to: 'howto',
    tutorial: 'howto',
    story: 'story',
    storytelling: 'story',
    personal_story: 'story',
    tips: 'tips',
    listicle: 'tips',
    list: 'tips',
    review: 'review',
    productreview: 'review',
    product_review: 'review',
    dayinlife: 'dayinlife',
    day_in_life: 'dayinlife',
    vlog: 'dayinlife',
    mythbuster: 'mythbuster',
    myth_buster: 'mythbuster',
    myth: 'mythbuster',
    opinion: 'mythbuster',
    contrarian: 'mythbuster',
    custom: 'custom',
}

export const TONE_ALIASES: Record<string, string> = {
    casual: 'casual',
    friendly: 'casual',
    conversational: 'casual',
    professional: 'professional',
    authoritative: 'professional',
    educational: 'professional',
    energetic: 'energetic',
    hype: 'energetic',
    enthusiastic: 'energetic',
    inspiring: 'inspiring',
    inspirational: 'inspiring',
    motivational: 'inspiring',
    humorous: 'humorous',
    funny: 'humorous',
    witty: 'humorous',
    playful: 'humorous',
    calm: 'calm',
    empathetic: 'calm',
    reassuring: 'calm',
}

export const LENGTH_CONFIG: Record<string, {
    label: string
    min: number
    max: number
    p1: string
    p2: string
    p3: string
    beats: string
    wordsPerBeat: string
}> = {
    short: {
        label: '30-45 second short-form',
        min: 75,
        max: 115,
        p1: '15-25 words',
        p2: '45-68 words',
        p3: '15-22 words',
        beats: '2-3',
        wordsPerBeat: '18-26 words each',
    },
    medium: {
        label: '60-90 second video',
        min: 140,
        max: 215,
        p1: '20-35 words',
        p2: '100-150 words',
        p3: '20-30 words',
        beats: '3-4',
        wordsPerBeat: '30-42 words each',
    },
    long: {
        label: '2-3 minute deep-dive',
        min: 260,
        max: 370,
        p1: '25-40 words',
        p2: '210-290 words',
        p3: '25-40 words',
        beats: '5-6',
        wordsPerBeat: '40-55 words each',
    },
}

export const PLATFORM_GUIDANCE: Record<string, string> = {
    reels_shorts: 'Instagram Reels / YouTube Shorts (vertical short-form): land the hook + viewer qualifier in the first 2 seconds with zero warm-up, chain tight 1-idea beats for mobile completion rate, and close on a sharp bookend line with one save/comment/follow cue.',
    youtube: 'YouTube long-form / talking head: line 1 must immediately confirm the title promise (zero throat-clearing), open a loop closed only in the payoff, chain micro-cliffhangers across beats, add a deliberate re-hook/twist around the 40-60% midpoint sag point, and end with one crisp watch-next or subscribe cue.',
    linkedin: 'LinkedIn founder/creator video: grounded practitioner insight with an honest opinion someone could disagree with, specific lived mechanism over corporate buzzwords, zero broetry or hollow "Agree?" bait.',
    general: 'Direct-to-camera social video or confidence practice: natural one-friend conversational cadence, uneven human rhythm, effortless to deliver off a teleprompter.',
}

export const TEMPLATE_INSTRUCTIONS: Record<string, string> = {
    educational: 'Teach one clear concept. Hook with a curiosity gap + emotional mirror that qualifies the right viewer, build conflict around the common wrong habit, unpack the real mechanism with one concrete everyday analogy (spend most words on the sharpest detail), and close with a bookend takeaway.',
    howto: 'Walk the viewer through a repeatable physical process. Hook with the specific outcome or pain removed, break the method into 3-4 sequential actionable steps (if step 2 is skipped, the method fails), and close by naming the exact 2-minute first step to try right now.',
    story: 'Tell a real-feeling first-person micro-story using active spoken delivery (never storybook "Once upon a time" clichés). Drop straight into the moment of tension, escalate the obstacle, hit the turning point (pattern + surprise), and land the honest takeaway for the viewer.',
    tips: 'Open by calling out a relatable mistake your exact audience repeats, deliver 3-5 specific high-signal tips (each anchored in concrete "how" + "so what?" payoff, never vague advice), include one surprising tip mid-list to re-hook attention, and close by naming which single tip to try first.',
    review: 'Give an honest, grounded review with real nuance (mention who it is NOT for as well as who benefits). Keep part1 strictly as a 1-2 sentence hook with your upfront verdict (under 30 words); save ALL specific real-world observations, strengths, and trade-offs for bodyBeats; and end part3 with a crisp buy-or-skip recommendation.',
    dayinlife: 'Drop the viewer straight into one vivid, relatable moment of the day (never "Hey guys, come spend a day with me"). Move through 3 concrete checkpoints with candid practitioner commentary and a small unexpected snag, and close with one grounded reflection that echoes the opening moment.',
    mythbuster: 'Call out a widely repeated bad habit or false belief right in line 1, show concretely how it backfires in practice (without using "It\'s not X, it\'s Y" clichés), show the specific replacement that actually works, and close with a simple real-world test the viewer can run today.',
    custom: 'Follow the creator custom instructions faithfully while applying spoken teleprompter craft, curiosity-gap hooking, concrete specificity, and zero AI tells.',
}

export const TONE_DESCRIPTIONS: Record<string, string> = {
    casual: 'warm, relaxed, spoken-like-to-one-friend',
    professional: 'clear, credible, practitioner-to-peer without stiffness or jargon',
    energetic: 'upbeat, decisive, high-momentum without shouting or hype clichés',
    inspiring: 'honest, encouraging, grounded in real struggle and forward motion',
    humorous: 'lighthearted, witty, self-aware observational humor that lands naturally on camera without cringe puns or forced stand-up jokes',
    calm: 'steady, reassuring, unhurried—designed to help a camera-shy speaker breathe easily',
}

export const CTA_INSTRUCTIONS: Record<string, string> = {
    auto: 'Choose the single most natural close for this video (question for comments, follow prompt, or direct takeaway).',
    follow: 'End with an earned, low-pressure reason to follow or subscribe for the next part.',
    comment: 'End with one specific, easy-to-answer question that sparks genuine viewer replies.',
    save_share: 'End by nudging viewers to save this for their next shoot or share it with a friend who needs it.',
    link: 'End by pointing naturally to the link or resource in bio/caption without sounding salesy.',
    reflection: 'End with a grounded single-line thought or mini-challenge rather than asking for metrics.',
}

export const LANGUAGE_NAME_BY_CODE: Record<string, { name: string; nativeScript: string; isBilingual?: boolean }> = {
    en: { name: 'English', nativeScript: 'English' },
    hi: { name: 'Hindi', nativeScript: 'Devanagari script (हिन्दी)' },
    hinglish: { name: 'Hinglish', nativeScript: 'Roman letters mixing conversational Hindi and English', isBilingual: true },
    ta: { name: 'Tamil', nativeScript: 'Tamil script (தமிழ்)' },
    te: { name: 'Telugu', nativeScript: 'Telugu script (తెలుగు)' },
    tanglish: { name: 'Tanglish', nativeScript: 'Roman letters mixing conversational Tamil and English', isBilingual: true },
    mr: { name: 'Marathi', nativeScript: 'Devanagari script (मराठी)' },
    bn: { name: 'Bengali', nativeScript: 'Bengali script (বাংলা)' },
    gu: { name: 'Gujarati', nativeScript: 'Gujarati script (ગુજરાતી)' },
    kn: { name: 'Kannada', nativeScript: 'Kannada script (ಕನ್ನಡ)' },
    ml: { name: 'Malayalam', nativeScript: 'Malayalam script (മലയാളം)' },
    pa: { name: 'Punjabi', nativeScript: 'Gurmukhi script (ਪੰਜਾਬੀ)' },
}

export const SCRIPT_JSON_SCHEMA = {
    name: 'video_script_response',
    strict: true,
    schema: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'part1', 'bodyBeats', 'part3', 'hookAlternatives'],
        properties: {
            title: { type: 'string' },
            part1: { type: 'string' },
            bodyBeats: {
                type: 'array',
                items: { type: 'string' },
            },
            part3: { type: 'string' },
            hookAlternatives: {
                type: 'array',
                items: { type: 'string' },
            },
        },
    },
}

export const WEEKLY_SCRIPTS_JSON_SCHEMA = {
    name: 'weekly_challenge_scripts_response',
    strict: true,
    schema: {
        type: 'object',
        additionalProperties: false,
        required: ['scripts'],
        properties: {
            scripts: {
                type: 'array',
                items: {
                    type: 'object',
                    additionalProperties: false,
                    required: ['dayNumber', 'title', 'part1', 'part2', 'part3', 'focus', 'duration'],
                    properties: {
                        dayNumber: { type: 'integer' },
                        title: { type: 'string' },
                        part1: { type: 'string' },
                        part2: { type: 'string' },
                        part3: { type: 'string' },
                        focus: { type: 'string' },
                        duration: { type: 'string' },
                    },
                },
            },
        },
    },
}

export const WARMUP_SCRIPTS_JSON_SCHEMA = {
    name: 'warmup_scripts_response',
    strict: true,
    schema: {
        type: 'object',
        additionalProperties: false,
        required: ['scripts'],
        properties: {
            scripts: {
                type: 'array',
                items: {
                    type: 'object',
                    additionalProperties: false,
                    required: ['warmupIndex', 'title', 'part1', 'part2', 'part3', 'focus'],
                    properties: {
                        warmupIndex: { type: 'integer' },
                        title: { type: 'string' },
                        part1: { type: 'string' },
                        part2: { type: 'string' },
                        part3: { type: 'string' },
                        focus: { type: 'string' },
                    },
                },
            },
        },
    },
}

export const ENHANCE_IDEA_JSON_SCHEMA = {
    name: 'enhanced_script_idea_response',
    strict: true,
    schema: {
        type: 'object',
        additionalProperties: false,
        required: [
            'detectedLanguageCode',
            'detectedLanguageName',
            'detectedScriptStyle',
            'topic',
            'audience',
            'coreMessage',
            'suggestedTemplate',
            'suggestedTone',
            'suggestedLength',
            'suggestedPlatform',
            'summaryNote',
        ],
        properties: {
            detectedLanguageCode: { type: 'string' },
            detectedLanguageName: { type: 'string' },
            detectedScriptStyle: {
                type: 'string',
                enum: ['spoken_natural', 'romanized'],
            },
            topic: { type: 'string' },
            audience: { type: 'string' },
            coreMessage: { type: 'string' },
            suggestedTemplate: {
                type: 'string',
                enum: ['educational', 'story', 'tips', 'review', 'dayinlife', 'custom'],
            },
            suggestedTone: {
                type: 'string',
                enum: ['Casual', 'Professional', 'Inspirational', 'Humorous', 'Educational'],
            },
            suggestedLength: {
                type: 'string',
                enum: ['short', 'medium', 'long'],
            },
            suggestedPlatform: {
                type: 'string',
                enum: ['reels_shorts', 'youtube', 'linkedin', 'general'],
            },
            summaryNote: { type: 'string' },
        },
    },
}

export function redactSecrets(msg: string): string {
    return msg.replace(/sk-[A-Za-z0-9_*-]{8,}/g, '[redacted-key]')
}

export function normalizeTemplate(raw?: string): string {
    const key = (raw ?? 'educational').trim().toLowerCase().replace(/[\s-]+/g, '_')
    return TEMPLATE_ALIASES[key] ?? 'educational'
}

export function normalizeTone(raw?: string): string {
    const key = (raw ?? 'casual').trim().toLowerCase()
    return TONE_ALIASES[key] ?? 'casual'
}

export function normalizeLength(raw?: string): 'short' | 'medium' | 'long' {
    const val = (raw ?? 'medium').trim().toLowerCase()
    if (val === 'short' || val === 'medium' || val === 'long') return val
    if (val.includes('short') || val.includes('30') || val.includes('45')) return 'short'
    if (val.includes('long') || val.includes('2') || val.includes('3')) return 'long'
    return 'medium'
}

export function normalizePlatform(raw?: string): string {
    const val = (raw ?? 'reels_shorts').trim().toLowerCase()
    if (val in PLATFORM_GUIDANCE) return val
    if (val.includes('youtube')) return 'youtube'
    if (val.includes('linkedin')) return 'linkedin'
    if (val.includes('general')) return 'general'
    return 'reels_shorts'
}

export function getWordRangeForWeek(weekNumber: number): { min: number; max: number } {
    switch (weekNumber) {
        case 1:
            return { min: 175, max: 225 }
        case 2:
            return { min: 225, max: 275 }
        case 3:
            return { min: 275, max: 325 }
        case 4:
            return { min: 325, max: 375 }
        default:
            return { min: 375, max: 425 }
    }
}

export function validateRequest(body: GenerateRequest): string | null {
    const action = body.action ?? 'generate'

    if (action === 'weekly') {
        const week = Number(body.weekNumber ?? 1)
        if (!Number.isInteger(week) || week < 1 || week > 5) {
            return 'weekNumber must be an integer between 1 and 5.'
        }
        const startDay = body.startDay !== undefined ? Number(body.startDay) : (week - 1) * 7 + 1
        const endDay = body.endDay !== undefined ? Number(body.endDay) : Math.min(30, week * 7)
        if (!Number.isInteger(startDay) || !Number.isInteger(endDay) || startDay < 1 || endDay > 30 || endDay < startDay || (endDay - startDay) > 6) {
            return 'startDay and endDay must define a valid 1-7 day window within days 1-30.'
        }
        return null
    }

    if (action === 'warmup') {
        return null
    }

    if (action === 'enhance_idea') {
        const spoken = (body.spokenTranscript ?? body.topic ?? '').trim()
        if (!spoken || spoken.length < 3) {
            return 'Please speak or enter a brief video idea (at least 3 characters).'
        }
        if (spoken.length > 1500) {
            return 'Spoken idea is too long (maximum 1500 characters).'
        }
        return null
    }

    if (action === 'refine') {
        if (!body.existingScript || (!body.existingScript.part1 && !body.existingScript.part2)) {
            return 'Existing script content is required for refinement.'
        }
        return null
    }

    const topic = (body.topic ?? '').trim()
    if (!topic || topic.length < 3) {
        return 'Please provide a topic (at least 3 characters).'
    }
    if (topic.length > 500) {
        return 'Topic is too long (maximum 500 characters).'
    }
    if (body.customPrompt && body.customPrompt.length > 1500) {
        return 'Custom instructions are too long (maximum 1500 characters).'
    }
    if ((body.coreMessage || body.message || '').length > 1000) {
        return 'Core takeaway text is too long (maximum 1000 characters).'
    }

    return null
}

export function resolveLanguageInstruction(req: GenerateRequest): string {
    const code = (req.languageCode ?? '').trim().toLowerCase()
    const customText = (req.languageText ?? '').trim()
    const isRomanized = req.scriptStyle === 'romanized'

    if (code === 'hinglish' || customText.toLowerCase().includes('hinglish')) {
        return 'Write ALL fields (including title and hookAlternatives) in natural everyday urban Hinglish using ROMAN (English) letters ONLY (e.g., "Dekho, simple si baat hai...", never Devanagari and NEVER stiff textbook Hindi like "sochiyega" or "avashyakta"). Mix conversational Hindi grammar with natural English creator words, and stay consistent in pronoun register throughout (use friendly "tum" OR respectful "aap"—never mix both in one script).'
    }
    if (code === 'tanglish' || customText.toLowerCase().includes('tanglish')) {
        return 'Write ALL fields (including title and hookAlternatives) in natural everyday spoken Tanglish using ROMAN (English) letters ONLY (mix conversational Tamil and natural English cleanly as real creators speak, keeping pronoun register consistent).'
    }

    const langMeta = LANGUAGE_NAME_BY_CODE[code]
    if (isRomanized && code && code !== 'en') {
        const langName = langMeta?.name || customText || code
        return `Write ALL fields (including title and hookAlternatives) in natural everyday spoken ${langName}, transliterated cleanly into easy-to-read ROMAN (English) letters for a teleprompter. Think directly in natural spoken ${langName} creator idioms (never literal English translation), stay 100% on topic, and keep pronouns consistent throughout.`
    }

    if (langMeta && code !== 'en') {
        return `Write ALL fields (title, part1, bodyBeats/part2, part3, and hookAlternatives) in natural everyday spoken ${langMeta.name} using ${langMeta.nativeScript}. Think directly in real ${langMeta.name} creator speech—NEVER translate English prompt templates literally or leave the title in English.`
    }

    if (customText && customText.toLowerCase() !== 'english' && code !== 'en') {
        return `Write ALL fields (including title and hookAlternatives) in ${customText}. Use natural everyday conversational phrasing spoken by real creators—never literal textbook translation or English titles.`
    }

    return 'Write ALL fields in natural spoken English using contractions.'
}

export function buildSystemPrompt(
    markdownMode: boolean,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const markdownRule = markdownMode
        ? 'MARKDOWN EMPHASIS (REQUIRED): Include **bold** emphasis on 1-3 key spoken punch words across part1, bodyBeats, and part3, and put list items on separate lines starting with "- " when listing steps or tips.'
        : 'PLAIN TEXT ONLY: Do not use **bold**, *italics*, markdown bullets, or special formatting characters.'

    const rawDb = dbTemplate?.system_prompt?.trim()
    if (rawDb) {
        if (rawDb.includes('{{markdownRule}}')) {
            return renderPromptTemplate(rawDb, { markdownRule })
        }
        return `${rawDb}\n\n${markdownRule}`
    }

    return [
        'You are an elite spoken-word video scriptwriter, retention architect, and teleprompter coach for creators.',
        '',
        'CONTEXT:',
        'Every script is spoken aloud directly into a camera lens using a voice-following teleprompter (Instagram Reels, YouTube Shorts, YouTube talking-head, LinkedIn video, or camera-confidence practice). Interpret filming terms like "lens", "eye contact", "frame", "hook", or "cuts" in the context of filming video on camera unless the topic explicitly names another domain.',
        '',
        'PSYCHOLOGY & RETENTION ENGINE (THE SIX LEVERS):',
        '1. Curiosity Gap: Open a specific, unresolved loop in line 1; never answer the hook inside the hook. Close every loop you open before the end.',
        '2. Emotional Mirror: Target the private feeling underneath the fact (frustration, fear, pride, relief) instead of stating a dry topic label.',
        '3. Conflict Engine: Pair what the viewer wants with the hidden mistake or self-made trap blocking them.',
        '4. Relatability + Viewer Qualification: Speak to one specific viewer situation so the right audience stays and follows. Never use generic hype like "stop scrolling!" without qualifying who it is for.',
        '5. Pattern + Surprise: Set up the common assumption, then break it with a sharper reality or turning point.',
        '6. Open-Loop Flow + Bookend Close: Let each body beat naturally lead into the next (on medium/long videos, inject a fresh re-hook or escalation around the midpoint where attention normally sags). Close by echoing a key phrase, image, or number from the hook and folding ONE natural CTA into it.',
        '',
        'ZERO AI TELLS (HARD STRUCTURAL & LEXICAL BANS):',
        '- NEVER use contrast reveals: "It\'s not X, it\'s Y", "Not just X, but Y", "Not because X. Because Y.", "Less X, more Y", or equivalent constructions in any language. State Y directly with the real reason.',
        '- NEVER use negation lists: "No fluff, no filler, no guesswork." Say what actually happens.',
        '- NEVER use self-answered questions or colon reveals: "The result? 3x faster.", "The catch? None.", "The best part: ...". Just state the point.',
        '- NEVER use staged run-ups, meta-announcements, or AI empathy clichés: "Hello everyone", "Hey guys, welcome back", "In today\'s video", "Today I\'m going to share", "In today\'s fast-paced world", "Here\'s the thing", "Let\'s dive in", "Let\'s talk about", "Let\'s find out", "Let\'s break this down", "Chalo samajhte hain", "Chalo yeh myth bust karte hain", "Real talk", "You\'re not alone", "Here\'s why this matters", "This is where it gets interesting", "Let that sink in", "Read that again", "At the end of the day", or "Ultimately".',
        '- NEVER stack forced triads ("fast, simple, and effective") or broetry fragments ("Simple. Fast. Done."). Vary sentence length naturally from the thought.',
        '- NEVER use em dashes (—) or en dashes (–) in spoken teleprompter copy; use clean periods, commas, or breath breaks.',
        '- NEVER bolt shallow "-ing" clauses onto claims ("..., ensuring you stand out", "..., showcasing your growth"). End the sentence at the claim.',
        '- NEVER use stock AI words: delve, tapestry, testament, realm, embark, beacon, paradigm, synergy, elevate, unlock, unleash, empower, streamline, harness, foster, game-changer, landscape, crucial, vital, pivotal, robust, seamless, transformative, holistic, next-level, or figurative "journey".',
        '- NEVER invent fake statistics, percentages ("70%", "90%"), fake research studies ("studies show"), or fabricated achievements. Only cite numbers provided by the user; otherwise use concrete, believable everyday scenes and physical actions.',
        '',
        'NON-NEGOTIABLE SPOKEN-WORD & TELEPROMPTER RULES:',
        '1. Output ONLY exact words meant to be spoken aloud. NEVER write stage directions ([pause], (smile), [B-roll], [0-5 sec]), section labels ("Hook:", "Body:", "Close:", "Part 1:"), markdown headings (#), code blocks, URLs, hashtags (#tag), or emojis.',
        '2. NEVER write slashes ("and/or"), abbreviations ("e.g.", "i.e.", "etc.", "w/"), or shorthand like "₹1L/mo". Write how humans speak them ("for example", "one lakh a month", "thirty seconds").',
        '3. Write for the ear, not the eye: contractions, direct "You" address, concrete physical actions, breathable sentences (mostly 6-14 words, varied naturally so it never sounds robotic).',
        '4. Express ideas natively in the requested language\'s real creator idioms—never translate English templates word for word.',
        `5. ${markdownRule}`,
        '6. Provide 3 genuinely different hook angles in "hookAlternatives" (1: Curiosity Gap, 2: Emotional Mirror / Relatability, 3: Contrarian / Pattern Break), all matching the requested language, tone, and topic.',
    ].join('\n')
}

export function buildGenerateUserPrompt(
    req: GenerateRequest,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const template = normalizeTemplate(req.template)
    const tone = normalizeTone(req.tone)
    const lengthKey = normalizeLength(req.length)
    const lengthCfg = LENGTH_CONFIG[lengthKey]
    const platformKey = normalizePlatform(req.platform)
    const ctaKey = (req.ctaStyle ?? 'auto').trim().toLowerCase()
    const markdownMode = req.markdownMode !== false
    const coreMessage = (req.coreMessage || req.message || '').trim()

    const audienceBlock = req.audience?.trim() ? `TARGET AUDIENCE: ${req.audience.trim()}\n` : ''
    const messageBlock = coreMessage ? `CORE TAKEAWAY / MUST INCLUDE POINTS: ${coreMessage}\n` : ''
    const customPromptBlock = req.customPrompt?.trim() ? `CREATOR CUSTOM INSTRUCTIONS: ${req.customPrompt.trim()}\n` : ''
    const formattingInstruction = markdownMode
        ? 'FORMATTING: Use **bold** on 1-3 key spoken punch words per beat and "- " bullets where lists fit.'
        : 'FORMATTING: Clean plain spoken sentences only, zero markdown symbols.'

    const vars: Record<string, string> = {
        topic: (req.topic ?? '').trim(),
        audience: (req.audience ?? '').trim(),
        message: coreMessage,
        tone: TONE_DESCRIPTIONS[tone] ?? TONE_DESCRIPTIONS.casual,
        language: (req.languageText ?? req.languageCode ?? 'English').trim(),
        languageInstruction: resolveLanguageInstruction(req),
        templateName: template.toUpperCase(),
        templateGuide: TEMPLATE_INSTRUCTIONS[template],
        platformGuidance: PLATFORM_GUIDANCE[platformKey],
        ctaGuidance: CTA_INSTRUCTIONS[ctaKey] ?? CTA_INSTRUCTIONS.auto,
        lengthLabel: lengthCfg.label,
        minWords: String(lengthCfg.min),
        maxWords: String(lengthCfg.max),
        part1Words: lengthCfg.p1,
        part2Words: lengthCfg.p2,
        part3Words: lengthCfg.p3,
        beatsCount: lengthCfg.beats,
        wordsPerBeat: lengthCfg.wordsPerBeat,
        audienceBlock,
        messageBlock,
        customPromptBlock,
        customPrompt: req.customPrompt?.trim() ?? '',
        formattingInstruction,
    }

    const rawDb = dbTemplate?.user_prompt_template?.trim()
    if (rawDb) {
        return renderPromptTemplate(rawDb, vars)
    }

    return renderPromptTemplate([
        'TOPIC: {{topic}}',
        'TOPIC ADHERENCE: Stay 100% anchored to the exact TOPIC above from a video creator\'s camera perspective. Every example, tension beat, and takeaway must directly serve this topic.',
        'PLATFORM & RETENTION PACING: {{platformGuidance}}',
        'TEMPLATE ARCHITECTURE ({{templateName}}): {{templateGuide}}',
        'TONE: {{tone}}',
        'LANGUAGE: {{languageInstruction}}',
        'CTA GOAL: {{ctaGuidance}}',
        '{{audienceBlock}}{{messageBlock}}{{customPromptBlock}}',
        'STRICT LENGTH & BEAT ARCHITECTURE ({{lengthLabel}}):',
        '- Total spoken words MUST fall between {{minWords}} and {{maxWords}} words.',
        '- part1 (Hook, {{part1Words}}): STRICTLY 1-2 short punchy spoken sentences (no blank lines, NEVER 3-4 sentences). Confirm the title\'s promise immediately, stack 2-3 psychology levers (Curiosity Gap + Emotional Mirror + Viewer Qualification), and leave the core loop open. NEVER end part1 with announcement filler ("Let\'s find out", "Let\'s talk about", "Chalo samajhte hain") or "You\'re not alone".',
        '- bodyBeats (Main Body): Return EXACTLY {{beatsCount}} distinct spoken beats ({{wordsPerBeat}}, totaling {{part2Words}}). Spend the most words on the sharpest concrete mechanism, scene, or example (uneven natural density beats robotic equal-length bullets). Chain open loops so each beat pulls into the next; on medium/long scripts, place a fresh twist, contrarian check, or escalation around the midpoint beat to beat viewer drop-off.',
        '- part3 (Bookend Close & CTA, {{part3Words}}): Pay off the opening loop, echo a phrase or image from part1 for satisfying completion, and fold ONE low-friction CTA into the final line.',
        '',
        '{{formattingInstruction}}',
        '',
        'QUALITY SELF-CHECK BEFORE RETURNING:',
        '- Zero "It\'s not X, it\'s Y", zero "No X, no Y, no Z", zero em dashes, zero self-answered questions ("The result? ..."), zero staged openers ("Here\'s the thing", "Let\'s dive in"), zero AI buzzwords.',
        '- Title: 3-7 punchy words in the target language, front-loading the curiosity hook (honest promise, never clickbait).',
        '- hookAlternatives: 3 genuinely distinct spoken hooks in the same language and tone (1: Curiosity Gap, 2: Emotional Mirror / Relatability, 3: Contrarian / Pattern Break).',
    ].join('\n'), vars)
}

export function buildLengthExpansionPrompt(
    raw: RawScriptOutput,
    req: GenerateRequest,
    lengthKey: 'short' | 'medium' | 'long',
    currentWords: number,
): string {
    const cfg = LENGTH_CONFIG[lengthKey]
    const currentBody = (raw.bodyBeats ?? []).join('\n\n')
    const markdownMode = req.markdownMode !== false
    return [
        `The draft script below is only ${currentWords} words, which is TOO SHORT for a ${cfg.label} (target: ${cfg.min}-${cfg.max} words).`,
        `EXPAND bodyBeats to EXACTLY ${cfg.beats} rich spoken beats (${cfg.wordsPerBeat}) by adding concrete real-world examples, a common mistake to avoid, a midpoint twist or escalation, and actionable specifics directly about: "${(req.topic ?? '').trim()}".`,
        `Keep the exact same language, tone, and zero-AI-tell spoken style (no "It's not X, it's Y", no em dashes, no filler buzzwords).`,
        `LANGUAGE: ${resolveLanguageInstruction(req)}`,
        markdownMode
            ? 'Preserve **bold** emphasis on key spoken punch words.'
            : 'Use plain text only with zero markdown symbols.',
        '',
        'DRAFT TO EXPAND:',
        `Title: ${raw.title}`,
        `Hook (part1): ${raw.part1}`,
        `Body:\n${currentBody}`,
        `Close (part3): ${raw.part3}`,
        '',
        `Return the expanded JSON with total words strictly between ${cfg.min} and ${cfg.max} words.`,
    ].join('\n')
}

export function buildRefineUserPrompt(
    req: GenerateRequest,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const existing = req.existingScript ?? {}
    const origWords = countWords(`${existing.part1 ?? ''} ${existing.part2 ?? ''} ${existing.part3 ?? ''}`)
    const rawInstr = (req.refineInstruction ?? '').trim()
    const markdownMode = req.markdownMode !== false

    const shortMin = Math.max(35, Math.round(origWords * 0.62))
    const shortMax = Math.max(50, Math.round(origWords * 0.75))

    const instructionMap: Record<string, string> = {
        punchier_hook: [
            'Rewrite part1 with a GENUINELY DIFFERENT, much stronger 2-second scroll-stopping hook stacking Curiosity Gap + Emotional Mirror + Viewer Qualification.',
            'FORBIDDEN: Do NOT just add or swap 1-2 adjectives in the existing hook, and NEVER use "It\'s not X, it\'s Y" or "Here\'s the thing". Change the opening structure completely (open an unresolved tension loop or pattern break).',
            'Keep bodyBeats and part3 aligned with the new hook (bookend part3 back to the new hook), and provide 3 completely distinct hookAlternatives.',
        ].join(' '),
        shorter: [
            `STRICT WORD BUDGET: The current script is ${origWords} words. Your tightened version MUST be between ${shortMin} and ${shortMax} words total (25-35% shorter).`,
            'Cut filler words, weak intensifiers, throat-clearing, and redundant lines across ALL sections—including part1 (hook), bodyBeats, and part3—while keeping the sharpest concrete example and bookend close intact.',
        ].join(' '),
        more_casual: 'Rewrite the phrasing so it sounds effortlessly natural—like talking to one close friend over coffee. Use spoken contractions, looser human rhythm, and everyday words while keeping the exact core insight.',
        add_example: 'Add one vivid, relatable everyday real-world scene or concrete physical analogy as a clear spoken beat inside bodyBeats so the viewer immediately pictures the idea (never invent fake stats).',
    }

    const refineGoal = instructionMap[rawInstr] || rawInstr || 'Polish clarity, spoken rhythm, hook punchiness, and remove any AI tells while keeping the creator’s core topic intact.'
    const formattingInstruction = markdownMode
        ? 'FORMATTING: Preserve teleprompter-friendly **bold** emphasis and "- " bullets where appropriate.'
        : 'FORMATTING: Output clean plain text with zero markdown characters.'

    const vars: Record<string, string> = {
        refineGoal,
        languageInstruction: resolveLanguageInstruction(req),
        formattingInstruction,
        existingTitle: existing.title ?? '',
        existingPart1: existing.part1 ?? '',
        existingPart2: existing.part2 ?? '',
        existingPart3: existing.part3 ?? '',
    }

    const rawDb = dbTemplate?.user_prompt_template?.trim()
    if (rawDb) {
        return renderPromptTemplate(rawDb, vars)
    }

    return renderPromptTemplate([
        'EDITING BRIEF: {{refineGoal}}',
        '',
        'COPY-EDITING & HUMANIZER RULES:',
        '- Preserve the creator\'s core topic, true facts, and authentic voice—only change what serves the editing brief above plus removing any AI tells.',
        '- Strip any surviving "It\'s not X, it\'s Y", negation lists, em dashes (—), self-answered questions ("The result? ..."), filler intensifiers ("very", "really", "actually", "literally", "simply"), or staged openers ("Here\'s the thing", "Let\'s dive in").',
        '- Keep every sentence concrete, active, and effortless to speak aloud on a teleprompter.',
        '- Ensure part3 still closes the opening loop cleanly with a single clear CTA.',
        '',
        'LANGUAGE CONSTRAINT: {{languageInstruction}}',
        '{{formattingInstruction}}',
        '',
        'CURRENT SCRIPT:',
        'Title: {{existingTitle}}',
        'Hook (part1): {{existingPart1}}',
        'Body (part2): {{existingPart2}}',
        'Close (part3): {{existingPart3}}',
        '',
        'Return the refined title, part1, bodyBeats (array of clean spoken body paragraphs), part3, and 3 genuinely distinct hookAlternatives (Curiosity Gap, Emotional Mirror, Pattern Break) in the exact same language.',
    ].join('\n'), vars)
}

export function buildWeeklyChallengeSystemPrompt(
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const rawDb = dbTemplate?.system_prompt?.trim()
    if (rawDb) {
        return rawDb
    }

    return [
        'You are an expert camera-confidence coach and spoken-word video scriptwriter.',
        'Every script is read aloud directly into a phone camera on a voice-following teleprompter by a creator building genuine confidence on camera.',
        '',
        'CORE CRAFT (HUMAN VOICE + SIX STORYTELLING LEVERS):',
        '- Open mid-thought in line 1 with an emotional mirror (naming the private feeling the viewer carries), a specific curiosity gap, or a relatable admission. Never open with "Hello everyone", "Welcome to Day X", "Today I want to talk about...", or storybook past tense ("Once upon a time...").',
        '- Build gentle tension around a real everyday obstacle (hesitation, overthinking, perfectionism, fear of judgement) and move toward a concrete, grounded realization or small shift.',
        '- End with a satisfying bookend that echoes the opening image or feeling, rather than a loud motivational slogan.',
        '',
        'ZERO AI TELLS (HARD BANS):',
        '- NEVER write "It\'s not X, it\'s Y", "Not just X, but Y", "No X, no Y, no Z", "Here\'s the thing", "Let\'s dive in", "Let that sink in", "Read that again", "In today\'s world", or "Ultimately".',
        '- NEVER use em dashes (—), forced 3-adjective lists, trailing "-ing" fluff ("..., unlocking your potential"), or buzzwords (delve, elevate, unlock, unleash, empower, transformative, pivotal, crucial, landscape, game-changer).',
        '- NEVER invent fake stats or hollow hype. Speak like one honest human talking to one friend across a table.',
        '',
        'SPOKEN TELEPROMPTER RULES:',
        '1. Write ONLY exact words meant to be spoken aloud. NEVER write stage directions ([pause], (smile)), labels ("Hook:", "Part 1:"), hashtags, URLs, or emojis.',
        '2. Keep sentences short, natural, and breathable (mostly 6-14 words, varied in rhythm) with \\n\\n breaks between thoughts. Use contractions and spoken numbers.',
        '3. Every day in a multi-day batch MUST explore a distinct situation and emotional angle progressing the speaker\'s comfort on camera.',
        '4. Follow the exact language instruction for EVERY field, including titles (no English titles when a non-English language is requested).',
    ].join('\n')
}

export function buildWeeklyChallengeUserPrompt(
    req: GenerateRequest,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const weekNumber = Number(req.weekNumber ?? 1)
    const startDay = req.startDay !== undefined ? Number(req.startDay) : (weekNumber - 1) * 7 + 1
    const endDay = req.endDay !== undefined ? Number(req.endDay) : Math.min(30, weekNumber * 7)
    const scriptCount = endDay - startDay + 1
    const range = getWordRangeForWeek(weekNumber)
    const part1Words = Math.round(range.min * 0.15)
    const part2Words = Math.round(range.min * 0.70)
    const part3Words = Math.round(range.min * 0.15)

    const answers = req.onboardingAnswers ?? {}
    const formatAnswer = (key: string, fallback: string): string => {
        const val = answers[key]
        if (Array.isArray(val) && val.length > 0) return val.join(', ')
        if (typeof val === 'string' && val.trim()) return val.trim()
        return fallback
    }

    const p = req.promptProfile ?? {}
    const profileLines: string[] = []
    if (p.systemPersona) profileLines.push(`Persona: ${p.systemPersona}`)
    if (p.coreIntent) profileLines.push(`Core Intent: ${p.coreIntent}`)
    if (p.speakerMindset) profileLines.push(`Speaker Mindset: ${p.speakerMindset}`)
    if (p.emotionalArc) profileLines.push(`Emotional Arc: ${p.emotionalArc}`)
    if (p.closingBehavior) profileLines.push(`Closing Behavior: ${p.closingBehavior}`)
    if (p.humanSpeechRules) profileLines.push(`Human Speech Rules:\n${p.humanSpeechRules.trim()}`)
    if (p.audienceMirrorRules) profileLines.push(`Audience Mirror:\n${p.audienceMirrorRules.trim()}`)
    if (p.culturalRules) profileLines.push(`Cultural Context:\n${p.culturalRules.trim()}`)
    if (p.forbiddenPatterns) profileLines.push(`Avoid:\n${p.forbiddenPatterns.trim()}`)

    const promptProfileBlock = profileLines.length > 0
        ? `COACHING VOICE & STYLE PROFILE:\n${profileLines.join('\n')}\n\n`
        : ''

    const vars: Record<string, string> = {
        languageInstruction: resolveLanguageInstruction(req),
        weekNumber: String(weekNumber),
        scriptCount: String(scriptCount),
        startDay: String(startDay),
        endDay: String(endDay),
        firstName: (req.firstName ?? 'Creator').trim() || 'Creator',
        age: String(req.age ?? 25),
        location: (req.location ?? '').trim() || 'Not specified',
        goal: (req.goal ?? 'build camera confidence').trim(),
        challenges: formatAnswer('challenges', 'camera nervousness and self-doubt'),
        contentStyle: formatAnswer('content_style', 'talking-head and educational videos'),
        platforms: formatAnswer('platform', 'Instagram Reels and YouTube'),
        timeCommitment: formatAnswer('time_commitment', '10-20 minutes'),
        systemPersona: p.systemPersona ?? '',
        coreIntent: p.coreIntent ?? '',
        promptProfileBlock,
        part1Words: String(part1Words),
        part2Words: String(part2Words),
        part3Words: String(part3Words),
        minWords: String(range.min),
        maxWords: String(range.max),
    }

    const rawDb = dbTemplate?.user_prompt_template?.trim()
    if (rawDb) {
        return renderPromptTemplate(rawDb, vars)
    }

    return renderPromptTemplate([
        'LANGUAGE: {{languageInstruction}}',
        '',
        'WEEK {{weekNumber}} OF 30-DAY CAMERA CONFIDENCE JOURNEY',
        'Generate EXACTLY {{scriptCount}} personalized spoken scripts for Days {{startDay}} through {{endDay}}.',
        '',
        'CREATOR PROFILE:',
        '- Name: {{firstName}}',
        '- Age: {{age}}',
        '- Location: {{location}}',
        '- Primary Goal: {{goal}}',
        '- Camera Challenges: {{challenges}}',
        '- Content Style: {{contentStyle}}',
        '- Target Platforms: {{platforms}}',
        '- Daily Time Commitment: {{timeCommitment}}',
        '',
        '{{promptProfileBlock}}PROGRESSION & RETENTION ARCHITECTURE:',
        '- Each day from Day {{startDay}} to Day {{endDay}} must tackle a distinct everyday moment or mindset hurdle tied to their real goal and challenges—never repeat the same opening or lesson twice.',
        '- Apply the Six Storytelling Levers gently: open with a specific emotional mirror or relatable micro-moment, unpack one concrete obstacle and practical shift in the body, and land a calm bookend close.',
        '- Zero AI tells ("It\'s not X, it\'s Y", em dashes, "Here\'s the thing", "Let that sink in", fake stats, or loud motivational clichés).',
        '',
        'STRICT 3-PART SPOKEN STRUCTURE PER DAY:',
        '- part1 (Hook, ~{{part1Words}} words): Immediate scroll-stopper—relatable admission, direct feeling mirror, or sharp question. Never "Hello everyone" or "Welcome to Day X".',
        '- part2 (Body, ~{{part2Words}} words): Grounded conversational paragraphs separated by \\n\\n, turning one concrete camera/creator situation into an honest lived insight.',
        '- part3 (Close, ~{{part3Words}} words): Bookend line echoing part1\'s feeling or image, paired with one quiet viewer question or grounded closing thought.',
        '- Total spoken words per script: {{minWords}} to {{maxWords}} words.',
        '- Title: 3-6 punchy words in the target language (honest curiosity, never generic labels like "Day 1 Confidence").',
        '',
        'Return JSON with "scripts" array containing EXACTLY {{scriptCount}} items with dayNumber from {{startDay}} to {{endDay}}.',
    ].join('\n'), vars)
}

export function buildWarmupUserPrompt(
    req: GenerateRequest,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const firstName = (req.firstName ?? 'Creator').trim() || 'Creator'
    const location = (req.location ?? '').trim()
    const goal = (req.goal ?? 'build camera confidence').trim()
    const locationText = location ? ` from ${location}` : ''

    const vars: Record<string, string> = {
        languageInstruction: resolveLanguageInstruction(req),
        firstName,
        locationText,
        goal,
    }

    const rawDb = dbTemplate?.user_prompt_template?.trim()
    if (rawDb) {
        return renderPromptTemplate(rawDb, vars)
    }

    return renderPromptTemplate([
        'LANGUAGE: {{languageInstruction}}',
        '',
        'Create EXACTLY 3 short, natural camera-warmup scripts (60-95 words / 30-45 seconds each) for {{firstName}}{{locationText}}.',
        'Their goal: {{goal}}',
        '',
        'THEMES (PROGRESSIVE COMFORT ARC):',
        '- warmupIndex 0 ("First Steps"): Emotional mirror for first-take awkwardness—normalizing nervous energy and hitting record anyway.',
        '- warmupIndex 1 ("Finding Your Energy"): Loosening posture, speaking to one friend through the lens instead of performing for a crowd.',
        '- warmupIndex 2 ("Ready to Start"): Grounded quiet commitment to show up consistently over the next 30 days toward their real goal.',
        '',
        'SPOKEN CRAFT & ANTI-AI RULES:',
        '- Sound like talking to one close friend on FaceTime: contractions, varied short sentences (6-13 words) with \\n\\n breaks, zero robotic stiffness.',
        '- Zero AI tells: no "It\'s not X, it\'s Y", no "Here\'s the thing", no em dashes, no "unlock your potential" motivational fluff.',
        '- part1 (Hook, 12-22 words): Immediate relatable opener straight into the feeling (no "Hi I\'m..." or "Welcome").',
        '- part2 (Body, 36-55 words): One concrete honest realization tied directly to their goal.',
        '- part3 (Close, 12-20 words): Calm bookend commitment echoing the opening thought.',
        '- Title: 2-5 natural words in the target language.',
        '- Spoken words ONLY: zero stage directions, zero labels, zero emojis.',
    ].join('\n'), vars)
}

export function stripNonSpokenArtifacts(text: string, markdownMode: boolean): string {
    if (!text) return ''

    let s = text.replace(/\r\n/g, '\n')

    // Remove fenced code blocks if an LLM accidentally emits them
    s = s.replace(/```[\s\S]*?```/g, '')

    // Remove bracketed stage directions / timestamps like [Pause], [0-5 sec], [Cut to B-roll]
    s = s.replace(/\[[^\]]{1,60}\]/g, '')

    // Remove parenthetical stage directions (never speak cues)
    s = s.replace(/\(\s*(?:short\s+)?(?:pauses?|beats?|smiles?|smiling|laughs?|laughing|sighs?|nods?|cut to [^)]{0,30}|b-roll[^)]{0,30}|look at camera|camera [^)]{0,20}|music[^)]{0,20}|tone[^)]{0,20})\s*\)/gi, '')

    // Remove spoken label prefixes if placed at start of lines or text
    s = s.replace(/^(?:hook|part\s*[123]|body|close|outro|cta|intro)\s*[:\-–—]\s*/gim, '')

    // Remove markdown headings (# Title -> Title)
    s = s.replace(/^\s{0,3}#{1,6}\s+/gm, '')

    // Remove hashtags like #Reels or #CameraConfidence
    s = s.replace(/(^|\s)#[A-Za-z0-9_]+/g, '$1')

    // Remove graphic emojis that clutter teleprompter reading
    s = s.replace(/[\p{Extended_Pictographic}\uFE0F]/gu, '')

    // Replace em/en dashes with natural spoken comma pauses for teleprompter cadence
    s = s.replace(/\s*[—–]\s*/g, ', ')

    // Split crammed inline bullet runs like "Point one. • Point two." onto separate lines
    s = s.replace(/\s*[•●▪◦]\s*/g, '\n- ')
    s = s.replace(/^\n+/, '')

    if (!markdownMode) {
        s = s
            .replace(/\*\*(.*?)\*\*/g, '$1')
            .replace(/__(.*?)__/g, '$1')
            .replace(/`([^`]*)`/g, '$1')
            .replace(/^\s*[-*]\s+/gm, '')
    }

    s = s
        .replace(/[ \t]+\n/g, '\n')
        .replace(/\n{3,}/g, '\n\n')
        .replace(/[ \t]{2,}/g, ' ')
        .trim()

    return s
}

export function countWords(text: string): number {
    const cleaned = text.trim()
    if (!cleaned) return 0
    return cleaned.split(/\s+/).filter(Boolean).length
}

export function joinBodyBeats(beats: string[] | undefined, markdownMode: boolean): string {
    if (!Array.isArray(beats) || beats.length === 0) return ''
    return beats
        .map((b) => stripNonSpokenArtifacts(b || '', markdownMode))
        .filter(Boolean)
        .join('\n\n')
}

export function sanitizeAndEnrich(
    raw: RawScriptOutput,
    req: GenerateRequest,
    norm: { template: string; tone: string; length: 'short' | 'medium' | 'long'; platform: string; markdownMode: boolean },
    promptMeta?: { source: 'db' | 'fallback'; version: number },
) {
    const title = stripNonSpokenArtifacts(raw.title || req.topic || 'Untitled Script', false)
        .replace(/^[“"'‘]|[”"'’]$/g, '')
        .slice(0, 120)

    const part1 = stripNonSpokenArtifacts(raw.part1 || '', norm.markdownMode)
    const part2 = joinBodyBeats(raw.bodyBeats, norm.markdownMode)
    const part3 = stripNonSpokenArtifacts(raw.part3 || '', norm.markdownMode)

    const altSet = new Set<string>()
    if (part1) altSet.add(part1)
    if (Array.isArray(raw.hookAlternatives)) {
        for (const h of raw.hookAlternatives) {
            const cleanH = stripNonSpokenArtifacts(h || '', norm.markdownMode)
            if (cleanH && !altSet.has(cleanH)) {
                altSet.add(cleanH)
            }
            if (altSet.size >= 3) break
        }
    }

    const p1Words = countWords(part1)
    const p2Words = countWords(part2)
    const p3Words = countWords(part3)
    const totalWords = p1Words + p2Words + p3Words
    const estimatedSeconds = totalWords > 0 ? Math.max(5, Math.round((totalWords / SPEAKING_WPM) * 60)) : 0

    const cfg = LENGTH_CONFIG[norm.length]
    const warnings: string[] = []
    if (!part1 || !part2 || !part3) {
        warnings.push('One or more script sections came back short; review before recording.')
    }
    if (req.action !== 'refine' && totalWords < Math.round(cfg.min * 0.85)) {
        warnings.push(`Generated ${totalWords} words (below ${norm.length} target ${cfg.min}-${cfg.max}w).`)
    }

    return {
        title,
        part1,
        part2,
        part3,
        hookAlternatives: Array.from(altSet),
        meta: {
            model: OPENAI_MODEL,
            action: req.action === 'refine' ? 'refine' : 'generate',
            promptSource: promptMeta?.source ?? 'fallback',
            promptVersion: promptMeta?.version ?? BUILTIN_PROMPT_VERSION,
            template: norm.template,
            tone: norm.tone,
            length: norm.length,
            platform: norm.platform,
            languageCode: req.languageCode || null,
            markdownMode: norm.markdownMode,
            wordCount: totalWords,
            partWords: { part1: p1Words, part2: p2Words, part3: p3Words },
            estimatedSeconds,
            warnings,
        },
    }
}

export function sanitizeWeeklyScripts(
    raw: RawWeeklyScriptsOutput,
    req: GenerateRequest,
) {
    const weekNumber = Number(req.weekNumber ?? 1)
    const startDay = req.startDay !== undefined ? Number(req.startDay) : (weekNumber - 1) * 7 + 1
    const items = Array.isArray(raw.scripts) ? raw.scripts : []

    const scripts = items.map((item, idx) => {
        const expectedDay = startDay + idx
        const dayNumber = Number.isInteger(item.dayNumber) && item.dayNumber >= 1 && item.dayNumber <= 30
            ? item.dayNumber
            : expectedDay
        const title = stripNonSpokenArtifacts(item.title || `Day ${dayNumber}`, false)
            .replace(/^[“"'‘]|[”"'’]$/g, '')
            .slice(0, 120)
        const part1 = stripNonSpokenArtifacts(item.part1 || '', false)
        const part2 = stripNonSpokenArtifacts(item.part2 || '', false)
        const part3 = stripNonSpokenArtifacts(item.part3 || '', false)
        const wordCount = countWords(`${part1} ${part2} ${part3}`)
        const estSec = Math.max(15, Math.round((wordCount / SPEAKING_WPM) * 60))

        return {
            dayNumber,
            title: title || `Day ${dayNumber}`,
            part1,
            part2,
            part3,
            focus: stripNonSpokenArtifacts(item.focus || 'Camera confidence', false).slice(0, 80),
            duration: item.duration?.trim() || `${estSec} seconds`,
            wordCount,
        }
    })

    return {
        scripts,
        meta: {
            model: OPENAI_MODEL,
            action: 'weekly',
            weekNumber,
            languageCode: req.languageCode || 'en',
            count: scripts.length,
        },
    }
}

export function sanitizeWarmupScripts(
    raw: RawWarmupScriptsOutput,
    req: GenerateRequest,
) {
    const items = Array.isArray(raw.scripts) ? raw.scripts : []
    const defaultTitles = ['First Steps', 'Finding Your Energy', 'Ready to Start']

    const scripts = items.slice(0, 3).map((item, idx) => {
        const warmupIndex = Number.isInteger(item.warmupIndex) && item.warmupIndex >= 0 && item.warmupIndex <= 2
            ? item.warmupIndex
            : idx
        return {
            warmupIndex,
            title: stripNonSpokenArtifacts(item.title || defaultTitles[warmupIndex] || `Warmup ${warmupIndex + 1}`, false)
                .replace(/^[“"'‘]|[”"'’]$/g, '')
                .slice(0, 100),
            part1: stripNonSpokenArtifacts(item.part1 || '', false),
            part2: stripNonSpokenArtifacts(item.part2 || '', false),
            part3: stripNonSpokenArtifacts(item.part3 || '', false),
            focus: stripNonSpokenArtifacts(item.focus || 'Warmup presence', false).slice(0, 80),
        }
    })

    return {
        scripts,
        meta: {
            model: OPENAI_MODEL,
            action: 'warmup',
            languageCode: req.languageCode || 'en',
            count: scripts.length,
        },
    }
}

const VALID_IDEA_TEMPLATES = new Set([
    'educational',
    'story',
    'tips',
    'review',
    'dayinlife',
    'custom',
])

const DISPLAY_TONE_MAP: Record<string, string> = {
    casual: 'Casual',
    friendly: 'Casual',
    conversational: 'Casual',
    professional: 'Professional',
    authoritative: 'Professional',
    inspirational: 'Inspirational',
    inspiring: 'Inspirational',
    motivational: 'Inspirational',
    humorous: 'Humorous',
    funny: 'Humorous',
    witty: 'Humorous',
    playful: 'Humorous',
    educational: 'Educational',
    energetic: 'Casual',
    calm: 'Casual',
}

export function buildIdeaEnhancerSystemPrompt(
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const rawDb = dbTemplate?.system_prompt?.trim()
    if (rawDb) return rawDb

    return [
        'You are a sharp video content strategist and creative producer helping a creator turn a brief, rough spoken voice note into a clear, high-retention video content brief.',
        '',
        'YOUR JOB:',
        '1. DETECT THE SPOKEN LANGUAGE AUTOMATICALLY from the raw transcript (CRITICAL):',
        '   - If the speaker explicitly asks for a specific language inside the transcript (e.g. "Hindi mein video banao", "make an English reel", "Hinglish mein likho"), honor that requested language.',
        '   - Otherwise detect the exact language of the transcript: Romanized Hindi mixed with English ("chat GPT Kaise kam karta hai") -> detectedLanguageCode = "hinglish", detectedLanguageName = "Hinglish", detectedScriptStyle = "romanized"; Devanagari Hindi -> "hi" / "Hindi" / "spoken_natural"; pure English -> "en" / "English" / "spoken_natural"; Romanized Tamil+English -> "tanglish" / "Tanglish" / "romanized"; any other language -> its ISO 639-1 code and readable name.',
        '   - Do NOT default to English when the transcript is Hinglish, Hindi, or another language!',
        '2. Clean up speech-to-text noise, filler words ("uh", "um", "like", "matlab", "toh"), repetitions, and rambling without inventing fake statistics or changing the creator\'s genuine core idea.',
        '3. Sharpen the TOPIC into one clear, focused, curiosity-worthy video angle (8-18 words max).',
        '4. Qualify the TARGET AUDIENCE specifically (who should stay and follow, not "everyone").',
        '5. Distill the CORE MESSAGE into one crisp, actionable takeaway or perspective the video must deliver.',
        '6. Choose the best matching template (educational, story, tips, review, dayinlife, custom), tone (Casual, Professional, Inspirational, Humorous, Educational), length (short, medium, long), and platform (reels_shorts, youtube, linkedin, general) based on what the speaker asked for.',
        '7. Write topic, audience, coreMessage, and summaryNote naturally in the DETECTED language (never stiff textbook translation or AI buzzwords).',
    ].join('\n')
}

export function buildIdeaEnhancerUserPrompt(
    req: GenerateRequest,
    dbTemplate?: PromptTemplateRecord | null,
): string {
    const spokenTranscript = (req.spokenTranscript ?? req.topic ?? '').trim()
    const rawCode = (req.languageCode ?? '').trim().toLowerCase()
    const isAutoDetect = !rawCode || rawCode === 'auto'
    const languageInstruction = isAutoDetect
        ? 'AUTO-DETECT directly from the RAW SPOKEN VOICE IDEA above (do NOT force English if the speaker spoke Hinglish, Hindi, or another language). Write topic, audience, coreMessage, and summaryNote in the detected language.'
        : resolveLanguageInstruction(req)

    const vars: Record<string, string> = {
        spokenTranscript,
        languageInstruction,
        toneHint: (req.tone ?? 'Casual').trim() || 'Casual',
        lengthHint: normalizeLength(req.length),
        platformHint: normalizePlatform(req.platform),
    }

    const rawDb = dbTemplate?.user_prompt_template?.trim()
    if (rawDb) {
        return renderPromptTemplate(rawDb, vars)
    }

    return renderPromptTemplate([
        'RAW SPOKEN VOICE IDEA (from Speech-to-Text):',
        '"{{spokenTranscript}}"',
        '',
        'LANGUAGE MODE: {{languageInstruction}}',
        'CURRENT FORM HINTS (optional defaults only if the speaker did not specify):',
        '- Tone hint: {{toneHint}}',
        '- Length hint: {{lengthHint}}',
        '- Platform hint: {{platformHint}}',
        '',
        'Detect the spoken language from the transcript above, then analyze the idea and return a clean, structured JSON content brief (detectedLanguageCode, detectedLanguageName, detectedScriptStyle, topic, audience, coreMessage, suggestedTemplate, suggestedTone, suggestedLength, suggestedPlatform, summaryNote) written in the detected language and ready to feed straight into the AI scriptwriter.',
    ].join('\n'), vars)
}

export function sanitizeEnhancedIdea(
    raw: RawEnhancedIdeaOutput,
    req: GenerateRequest,
    promptMeta?: { source: 'db' | 'fallback'; version: number },
) {
    const fallbackTranscript = (req.spokenTranscript ?? req.topic ?? '').trim()
    const cleanField = (val: string | undefined, fallback: string, maxLen: number): string =>
        stripNonSpokenArtifacts(val || fallback, false)
            .replace(/^[“"'‘]|[”"'’]$/g, '')
            .slice(0, maxLen)

    const rawTpl = (raw.suggestedTemplate ?? '').trim().toLowerCase().replace(/[\s-]+/g, '_')
    const mappedTpl = VALID_IDEA_TEMPLATES.has(rawTpl)
        ? rawTpl
        : VALID_IDEA_TEMPLATES.has(normalizeTemplate(rawTpl))
            ? normalizeTemplate(rawTpl)
            : 'educational'

    const rawToneKey = (raw.suggestedTone ?? req.tone ?? 'Casual').trim().toLowerCase()
    const suggestedTone = DISPLAY_TONE_MAP[rawToneKey] ?? 'Casual'

    const suggestedLength = normalizeLength(raw.suggestedLength || req.length)
    const suggestedPlatform = normalizePlatform(raw.suggestedPlatform || req.platform)

    const rawDetectedCode = (raw.detectedLanguageCode ?? '').trim().toLowerCase()
    const reqCode = (req.languageCode ?? '').trim().toLowerCase()
    const detectedLanguageCode = (rawDetectedCode && rawDetectedCode !== 'auto')
        ? rawDetectedCode
        : (reqCode && reqCode !== 'auto' ? reqCode : 'en')

    const knownLangName = detectedLanguageCode === 'hinglish'
        ? 'Hinglish'
        : detectedLanguageCode === 'tanglish'
            ? 'Tanglish'
            : (LANGUAGE_NAME_BY_CODE[detectedLanguageCode]?.name ?? 'English')
    const detectedLanguageName = cleanField(raw.detectedLanguageName, knownLangName, 40)
    const detectedScriptStyle: 'spoken_natural' | 'romanized' =
        raw.detectedScriptStyle === 'romanized' ||
        detectedLanguageCode === 'hinglish' ||
        detectedLanguageCode === 'tanglish'
            ? 'romanized'
            : 'spoken_natural'

    return {
        detectedLanguageCode,
        detectedLanguageName,
        detectedScriptStyle,
        topic: cleanField(raw.topic, fallbackTranscript, 200),
        audience: cleanField(raw.audience, 'Creators and viewers interested in this topic', 200),
        coreMessage: cleanField(raw.coreMessage, fallbackTranscript, 450),
        suggestedTemplate: mappedTpl,
        suggestedTone,
        suggestedLength,
        suggestedPlatform,
        summaryNote: cleanField(raw.summaryNote, 'Sharpened your spoken note into a structured video brief.', 180),
        meta: {
            model: OPENAI_MODEL,
            action: 'enhance_idea',
            promptSource: promptMeta?.source ?? 'fallback',
            promptVersion: promptMeta?.version ?? BUILTIN_PROMPT_VERSION,
            languageCode: detectedLanguageCode,
        },
    }
}
