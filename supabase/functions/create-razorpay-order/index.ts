// Supabase Edge Function: Create Razorpay Order
// This function creates a Razorpay order on the backend to keep the API secret secure

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') || ''
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') || ''
const RAZORPAY_API_URL = 'https://api.razorpay.com/v1'

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
    // Debug: Log environment variables (without revealing secrets)
    console.log('RAZORPAY_KEY_ID present:', !!RAZORPAY_KEY_ID)
    console.log('RAZORPAY_KEY_SECRET present:', !!RAZORPAY_KEY_SECRET)
    console.log('RAZORPAY_KEY_ID length:', RAZORPAY_KEY_ID.length)
    console.log('Authorization header present:', !!req.headers.get('Authorization'))

    // Verify authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    console.log('User authenticated:', !!user)
    console.log('User ID:', user?.id)

    if (!user) {
      return new Response(
        JSON.stringify({ 
          error: 'Unauthorized - Please login to BillSprout app first',
          debug: {
            auth_header_present: !!req.headers.get('Authorization'),
            supabase_url_present: !!Deno.env.get('SUPABASE_URL'),
            supabase_anon_key_present: !!Deno.env.get('SUPABASE_ANON_KEY')
          }
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { amount, currency, receipt, notes } = await req.json()

    // Validate inputs
    if (!amount || !currency || !receipt) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: amount, currency, receipt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Razorpay order
    const orderData = {
      amount: amount, // Amount in paise
      currency: currency,
      receipt: receipt,
      notes: notes || {},
    }

    const basicAuth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)

    const razorpayResponse = await fetch(`${RAZORPAY_API_URL}/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${basicAuth}`,
      },
      body: JSON.stringify(orderData),
    })

    if (!razorpayResponse.ok) {
      const errorData = await razorpayResponse.json()
      console.error('Razorpay API error:', errorData)
      return new Response(
        JSON.stringify({ error: 'Failed to create Razorpay order', details: errorData }),
        { status: razorpayResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const razorpayOrder = await razorpayResponse.json()

    return new Response(
      JSON.stringify({
        success: true,
        order_id: razorpayOrder.id,
        amount: razorpayOrder.amount,
        currency: razorpayOrder.currency,
        receipt: razorpayOrder.receipt,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in create-razorpay-order:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
