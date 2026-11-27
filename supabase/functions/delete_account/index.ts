// Supabase Edge Function: delete_account
// Deploy: supabase functions deploy delete_account

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get auth token from request
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing Authorization header')
        }

        // Create Supabase client with service role (admin privileges)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false,
                },
            }
        )

        // Get user from JWT
        const token = authHeader.replace('Bearer ', '')
        const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

        if (userError || !user) {
            throw new Error('Invalid token or user not found')
        }

        console.log(`Deleting account for user: ${user.id}`)

        // Delete user-owned rows across tables without CASCADE FK (e.g., content_scripts has text user_id)
        const ownedTables = [
            'content_scripts',
            'ai_feedback',
            'achievements',
            'challenge_extensions',
            'daily_completions',
            'daily_scripts',
            'notification_settings',
            'premium_status',
            'user_profiles',
            'web_sessions',
            'user_progress',
        ]
        for (const table of ownedTables) {
            const { error: tableErr } = await supabaseAdmin
                .from(table)
                .delete()
                .eq('user_id', user.id)
            if (tableErr) {
                console.warn(`Notice deleting from ${table}:`, tableErr.message)
            }
        }

        // Delete user record (cascade will handle remaining foreign keys)
        const { error: usersError } = await supabaseAdmin
            .from('users')
            .delete()
            .eq('id', user.id)

        if (usersError) {
            console.error('Error deleting users record:', usersError)
            // Continue anyway
        }

        // Finally, delete auth user (this cascades to users table)
        const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

        if (authError) {
            throw new Error(`Failed to delete auth user: ${authError.message}`)
        }

        console.log(`Successfully deleted account for user: ${user.id}`)

        return new Response(
            JSON.stringify({ success: true, message: 'Account deleted successfully' }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )
    } catch (error) {
        console.error('Error in delete_account function:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
