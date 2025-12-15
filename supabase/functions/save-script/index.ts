// Supabase Edge Function: save-script
// Allows saving scripts for both email/password and QR-authenticated users
// Deploy: supabase functions deploy save-script

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ScriptData {
    user_id: string
    title: string
    part1: string
    part2: string
    part3: string
    prompt_template?: string
    questionnaire?: object
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
    }

    try {
        // Get request body
        const scriptData: ScriptData = await req.json()

        // Validate required fields
        if (!scriptData.user_id) {
            return new Response(
                JSON.stringify({ error: 'user_id is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (!scriptData.title) {
            return new Response(
                JSON.stringify({ error: 'title is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Create Supabase client with service role (bypasses RLS)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

        const supabase = createClient(supabaseUrl, supabaseServiceKey)

        // Insert the script
        const { data, error } = await supabase
            .from('content_scripts')
            .insert({
                user_id: scriptData.user_id,
                title: scriptData.title,
                part1: scriptData.part1 || '',
                part2: scriptData.part2 || '',
                part3: scriptData.part3 || '',
                prompt_template: scriptData.prompt_template || null,
                questionnaire: scriptData.questionnaire || null,
                is_recorded: false,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .select()
            .single()

        if (error) {
            console.error('Database error:', error)
            return new Response(
                JSON.stringify({ error: error.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        return new Response(
            JSON.stringify({ success: true, script: data }),
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
