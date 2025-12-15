// Supabase Edge Function: generate-script
// Securely proxies OpenAI API calls for script generation
// Deploy this via Supabase Dashboard -> Edge Functions

// Deno TypeScript for Supabase Edge Functions
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!
const OPENAI_MODEL = 'gpt-4o-mini'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GenerateRequest {
    template: string
    topic: string
    audience?: string
    tone: string
    length: string
    customPrompt?: string
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
    }

    try {
        // Verify authentication
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Unauthorized' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Parse request body
        const { template, topic, audience, tone, length, customPrompt }: GenerateRequest = await req.json()

        if (!topic) {
            return new Response(
                JSON.stringify({ error: 'Topic is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Build the prompt
        const prompt = buildPrompt({ template, topic, audience, tone, length, customPrompt })

        // Call OpenAI
        const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: OPENAI_MODEL,
                messages: [
                    {
                        role: 'system',
                        content: 'You are a viral content scriptwriter. You write scripts meant to be SPOKEN, not read. Always respond with valid JSON only.'
                    },
                    {
                        role: 'user',
                        content: prompt
                    }
                ],
                max_tokens: 1000,
                temperature: 0.8
            })
        })

        if (!openaiResponse.ok) {
            const error = await openaiResponse.json()
            console.error('OpenAI API error:', error)
            return new Response(
                JSON.stringify({ error: 'Failed to generate script' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const data = await openaiResponse.json()
        const content = data.choices[0].message.content

        // Parse the JSON response
        const script = parseScriptResponse(content)

        return new Response(
            JSON.stringify(script),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Edge function error:', error)
        return new Response(
            JSON.stringify({ error: 'Internal server error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

function buildPrompt({ template, topic, audience, tone, length, customPrompt }: GenerateRequest): string {
    const wordCounts: Record<string, { min: number; max: number }> = {
        short: { min: 80, max: 120 },
        medium: { min: 150, max: 250 },
        long: { min: 300, max: 400 }
    }

    const templateInstructions: Record<string, string> = {
        educational: 'Create an educational script that teaches something valuable. Start with a hook that promises value, deliver the lesson clearly, and end with a memorable takeaway.',
        story: 'Create a story-driven script with a personal narrative. Start with an intriguing situation, build tension with the journey, and conclude with the lesson learned.',
        tips: 'Create a tips-based script with actionable advice. Open with why this matters, deliver 3-5 quick tips, and close with encouragement to take action.',
        review: 'Create an authentic review script. Start with your verdict, share specific pros and cons, and end with your recommendation.',
        dayinlife: 'Create a day-in-the-life style script. Open with what makes today special, share key moments with personality, and close with reflection.',
        custom: customPrompt || 'Create a compelling video script based on the topic.'
    }

    const toneDescriptions: Record<string, string> = {
        casual: 'friendly and conversational, like talking to a friend',
        professional: 'polished and authoritative, but still approachable',
        energetic: 'high-energy and enthusiastic, keeping viewers engaged',
        inspiring: 'motivational and uplifting, encouraging action'
    }

    const { min, max } = wordCounts[length] || wordCounts.medium
    const audienceText = audience ? `The target audience is: ${audience}.` : ''

    return `You are an expert video scriptwriter creating content for social media.

TASK: Create a ${length} video script about: "${topic}"

${templateInstructions[template] || templateInstructions.educational}

TONE: Write in a ${toneDescriptions[tone] || toneDescriptions.casual} tone.
${audienceText}

WORD COUNT: Between ${min} and ${max} words total.

IMPORTANT RULES:
1. Write ONLY the words to be spoken aloud - no stage directions, no labels
2. Use SHORT, punchy sentences - this is spoken word, not an essay
3. Start with a strong HOOK that stops the scroll
4. Be conversational - use contractions, questions, direct address ("you")
5. NO corporate jargon or overly formal language
6. The close should have a clear call-to-action

OUTPUT FORMAT:
Return a JSON object with exactly this structure:
{
    "title": "A catchy 3-7 word title for the script",
    "part1": "The hook - grab attention immediately (15-25% of words)",
    "part2": "The body - deliver the main value (50-70% of words)", 
    "part3": "The close - call to action (15-25% of words)"
}

Return ONLY the JSON object, no markdown formatting or extra text.`
}

function parseScriptResponse(content: string): Record<string, string> {
    let cleaned = content.trim()

    // Remove markdown code blocks if present
    if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7)
    } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3)
    }
    if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3)
    }

    return JSON.parse(cleaned.trim())
}
