// Supabase Edge Function to delete user account and all associated data
// Deploy with: supabase functions deploy delete_account

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get the authorization header
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Missing authorization header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Create Supabase client with user's token to get their ID
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

        if (!supabaseUrl || !supabaseServiceKey) {
            return new Response(
                JSON.stringify({ error: 'Server configuration error' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Client with user token to verify user
        const userClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        })

        // Get the user making the request
        const { data: userData, error: userError } = await userClient.auth.getUser()

        if (userError || !userData?.user) {
            return new Response(
                JSON.stringify({ error: 'Invalid user token' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const userId = userData.user.id
        console.log(`Deleting account for user: ${userId}`)

        // Admin client to delete data and user
        const adminClient = createClient(supabaseUrl, supabaseServiceKey)

        // Delete all user data from tables (in order to avoid foreign key issues)
        const tablesToDelete = [
            'daily_completions',
            'daily_scripts',
            'achievements',
            'ai_feedback',
            'notification_settings',
            'premium_status',
            'user_progress',
            'user_profiles',
            'users'
        ]

        for (const table of tablesToDelete) {
            const columnName = table === 'users' ? 'id' : 'user_id'
            const { error } = await adminClient
                .from(table)
                .delete()
                .eq(columnName, userId)

            if (error) {
                console.log(`Warning: Could not delete from ${table}: ${error.message}`)
            } else {
                console.log(`Deleted data from ${table}`)
            }
        }

        // Delete the auth user using admin API
        const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(userId)

        if (deleteUserError) {
            console.error('Error deleting auth user:', deleteUserError)
            return new Response(
                JSON.stringify({ error: 'Failed to delete auth user', details: deleteUserError.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`Successfully deleted account for user: ${userId}`)

        return new Response(
            JSON.stringify({ success: true, message: 'Account deleted successfully' }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error'
        console.error('Error in delete_account:', errorMessage)
        return new Response(
            JSON.stringify({ error: 'Internal server error', details: errorMessage }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
