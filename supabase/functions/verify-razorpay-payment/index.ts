// Supabase Edge Function: Verify Razorpay Payment
// This function verifies the payment signature on the backend

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'https://deno.land/std@0.168.0/node/crypto.ts'

const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') || ''

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { order_id, payment_id, signature } = await req.json()

    // Validate inputs
    if (!order_id || !payment_id || !signature) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: order_id, payment_id, signature' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify signature
    const data = `${order_id}|${payment_id}`
    const hmac = createHmac('sha256', RAZORPAY_KEY_SECRET)
    hmac.update(data)
    const generatedSignature = hmac.digest('hex')

    const isVerified = generatedSignature === signature

    if (!isVerified) {
      console.error('Payment signature verification failed')
      console.error('Expected:', generatedSignature)
      console.error('Received:', signature)
    }

    return new Response(
      JSON.stringify({
        verified: isVerified,
        order_id: order_id,
        payment_id: payment_id,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in verify-razorpay-payment:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
