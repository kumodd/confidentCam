// Supabase Edge Function: create_user_record
// This creates the user record in public.users table using service role
// Deploy: supabase functions deploy create_user_record

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

        // Parse request body
        const { email, phone } = await req.json()

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

        console.log(`Creating user record for: ${user.id}, email: ${email}`)

        // Check if user already exists
        const { data: existingUser } = await supabaseAdmin
            .from('users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle()

        if (existingUser) {
            console.log('User already exists, returning existing data')
            const { data: userData } = await supabaseAdmin
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single()

            return new Response(
                JSON.stringify({ success: true, user: userData, isNew: false }),
                {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    status: 200,
                }
            )
        }

        // Insert new user record
        const { data: newUser, error: insertError } = await supabaseAdmin
            .from('users')
            .insert({
                id: user.id,
                email: email || user.email,
                phone: phone || null,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
            })
            .select()
            .single()

        if (insertError) {
            console.error('Error inserting user:', insertError)
            throw new Error(`Failed to create user record: ${insertError.message}`)
        }

        console.log('User record created:', newUser.id)

        // Create user_progress record
        const { error: progressError } = await supabaseAdmin
            .from('user_progress')
            .insert({
                user_id: user.id,
                current_day: 0,
                total_days_completed: 0,
                streak_count: 0,
                warmup_0_done: false,
                warmup_1_done: false,
                warmup_2_done: false,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
            })

        if (progressError) {
            console.error('Error creating progress:', progressError)
            // Don't fail, user was created
        } else {
            console.log('User progress created')
        }

        return new Response(
            JSON.stringify({ success: true, user: newUser, isNew: true }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )
    } catch (error) {
        console.error('Error in create_user_record function:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
