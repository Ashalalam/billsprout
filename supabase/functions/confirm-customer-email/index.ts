// ============================================================================
// Supabase Edge Function: Auto-Confirm Customer Email
// ============================================================================
// This function automatically confirms a customer's email after signup
// bypassing the email confirmation requirement for customer registrations
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId } = await req.json()

    if (!userId) {
      throw new Error('userId is required')
    }

    // Create Supabase admin client with service role key
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

    // Manually confirm the user's email using admin client
    const { data: user, error } = await supabaseAdmin.auth.admin.updateUserById(
      userId,
      {
        email_confirm: true,
      }
    )

    if (error) {
      console.error('Error confirming email:', error)
      throw error
    }

    console.log('Email confirmed for user:', userId)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Email confirmed successfully',
        user,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
