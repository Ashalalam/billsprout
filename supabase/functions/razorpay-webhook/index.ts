// Supabase Edge Function: Razorpay Webhook Handler
// This function handles webhook callbacks from Razorpay for payment events

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'https://deno.land/std@0.168.0/node/crypto.ts'

const RAZORPAY_WEBHOOK_SECRET = Deno.env.get('RAZORPAY_WEBHOOK_SECRET') || ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-razorpay-signature',
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Use service role client for admin operations
    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get webhook signature
    const signature = req.headers.get('x-razorpay-signature')
    if (!signature) {
      console.error('Missing Razorpay signature header')
      return new Response(
        JSON.stringify({ error: 'Missing signature' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get request body
    const body = await req.text()
    
    // Verify webhook signature
    const hmac = createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
    hmac.update(body)
    const expectedSignature = hmac.digest('hex')

    if (signature !== expectedSignature) {
      console.error('Webhook signature verification failed')
      
      // Log webhook attempt
      await supabaseClient.from('webhook_logs').insert({
        source: 'razorpay',
        event_type: 'unknown',
        payload: JSON.parse(body),
        signature: signature,
        status: 'failed',
        error_message: 'Invalid signature',
      })

      return new Response(
        JSON.stringify({ error: 'Invalid signature' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse webhook payload
    const payload = JSON.parse(body)
    const event = payload.event
    const paymentEntity = payload.payload?.payment?.entity || payload.payload?.order?.entity

    console.log('Received webhook event:', event)

    // Log webhook
    const webhookLog = await supabaseClient.from('webhook_logs').insert({
      source: 'razorpay',
      event_type: event,
      payload: payload,
      signature: signature,
      status: 'processing',
    }).select().single()

    // Handle different event types
    let processed = false

    switch (event) {
      case 'payment.captured':
        processed = await handlePaymentCaptured(supabaseClient, paymentEntity)
        break
      
      case 'payment.failed':
        processed = await handlePaymentFailed(supabaseClient, paymentEntity)
        break
      
      case 'order.paid':
        processed = await handleOrderPaid(supabaseClient, paymentEntity)
        break
      
      default:
        console.log('Unhandled webhook event:', event)
        processed = true // Mark as processed to avoid retries
    }

    // Update webhook log
    await supabaseClient.from('webhook_logs').update({
      status: processed ? 'processed' : 'failed',
      processed_at: new Date().toISOString(),
    }).eq('id', webhookLog.data.id)

    return new Response(
      JSON.stringify({ success: true, event: event }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in razorpay-webhook:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Handle payment.captured event
async function handlePaymentCaptured(supabase: any, payment: any) {
  try {
    console.log('Handling payment.captured:', payment.id)

    // Find payment transaction by order_id
    const { data: transaction } = await supabase
      .from('payment_transactions')
      .select('*')
      .eq('razorpay_order_id', payment.order_id)
      .single()

    if (!transaction) {
      console.error('Transaction not found for order:', payment.order_id)
      return false
    }

    // Update transaction status
    await supabase.from('payment_transactions').update({
      status: 'success',
      razorpay_payment_id: payment.id,
      payment_method: payment.method,
      payment_completed_at: new Date(payment.created_at * 1000).toISOString(),
    }).eq('id', transaction.id)

    // Activate subscription if metadata contains plan info
    if (transaction.metadata?.plan_id) {
      await activateSubscription(supabase, {
        tenant_id: transaction.tenant_id,
        plan_id: transaction.metadata.plan_id,
        billing_cycle: transaction.metadata.billing_cycle || 'monthly',
        amount_paid: transaction.amount,
        payment_method: payment.method,
      })
      
      // Send payment success email
      await sendPaymentSuccessEmail(supabase, transaction.tenant_id, transaction.id, payment.id, transaction.amount)
    }

    return true
  } catch (error) {
    console.error('Error handling payment.captured:', error)
    return false
  }
}

// Handle payment.failed event
async function handlePaymentFailed(supabase: any, payment: any) {
  try {
    console.log('Handling payment.failed:', payment.id)

    // Find payment transaction
    const { data: transaction } = await supabase
      .from('payment_transactions')
      .select('*')
      .eq('razorpay_order_id', payment.order_id)
      .single()

    if (!transaction) {
      console.error('Transaction not found for order:', payment.order_id)
      return false
    }

    // Update transaction status
    await supabase.from('payment_transactions').update({
      status: 'failed',
      razorpay_payment_id: payment.id,
      metadata: {
        ...transaction.metadata,
        error_code: payment.error_code,
        error_description: payment.error_description,
      },
    }).eq('id', transaction.id)

    return true
  } catch (error) {
    console.error('Error handling payment.failed:', error)
    return false
  }
}

// Handle order.paid event
async function handleOrderPaid(supabase: any, order: any) {
  try {
    console.log('Handling order.paid:', order.id)
    
    // Similar to payment.captured, but for order-level events
    return true
  } catch (error) {
    console.error('Error handling order.paid:', error)
    return false
  }
}

// Activate subscription after successful payment
async function activateSubscription(supabase: any, data: any) {
  try {
    const startDate = new Date()
    const endDate = new Date()
    
    if (data.billing_cycle === 'yearly') {
      endDate.setFullYear(endDate.getFullYear() + 1)
    } else {
      endDate.setMonth(endDate.getMonth() + 1)
    }

    // Check if subscription already exists
    const { data: existing } = await supabase
      .from('tenant_subscriptions')
      .select('id')
      .eq('tenant_id', data.tenant_id)
      .eq('status', 'active')
      .maybeSingle()

    if (existing) {
      console.log('Active subscription already exists for tenant:', data.tenant_id)
      return
    }

    // Create subscription
    await supabase.from('tenant_subscriptions').insert({
      tenant_id: data.tenant_id,
      plan_id: data.plan_id,
      billing_cycle: data.billing_cycle,
      status: 'active',
      amount_paid: data.amount_paid,
      payment_method: data.payment_method,
      start_date: startDate.toISOString(),
      end_date: endDate.toISOString(),
      auto_renew: true,
    })

    console.log('Subscription activated for tenant:', data.tenant_id)

    // Send confirmation email
    await sendSubscriptionActivatedEmail(supabase, data.tenant_id, data.plan_id, data.amount_paid, data.billing_cycle)

  } catch (error) {
    console.error('Error activating subscription:', error)
    throw error
  }
}

// Send subscription activated email
async function sendSubscriptionActivatedEmail(supabase: any, tenantId: string, planId: string, amountPaid: number, billingCycle: string) {
  try {
    // Get tenant and plan details
    const { data: tenant } = await supabase
      .from('tenants')
      .select('business_name, owner_name, email')
      .eq('id', tenantId)
      .single()

    const { data: plan } = await supabase
      .from('subscription_plans')
      .select('plan_name, features')
      .eq('id', planId)
      .single()

    if (!tenant || !plan) {
      console.error('Tenant or plan not found for email')
      return
    }

    const endDate = new Date()
    if (billingCycle === 'yearly') {
      endDate.setFullYear(endDate.getFullYear() + 1)
    } else {
      endDate.setMonth(endDate.getMonth() + 1)
    }

    // Call send-email edge function
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        to: tenant.email,
        subject: `🎉 Your ${plan.plan_name} Subscription is Active!`,
        template: 'subscription_activated',
        template_data: {
          customer_name: tenant.owner_name || tenant.business_name,
          plan_name: plan.plan_name,
          billing_cycle: billingCycle,
          amount_paid: amountPaid,
          valid_until: endDate.toLocaleDateString('en-IN'),
          features: plan.features || [],
          dashboard_url: `${SUPABASE_URL.replace('/rest/v1', '')}/dashboard`,
        },
      }),
    })

    console.log('Subscription activation email sent to:', tenant.email)
  } catch (error) {
    console.error('Error sending subscription email:', error)
    // Don't throw - email failure shouldn't block subscription activation
  }
}


// Send payment success email
async function sendPaymentSuccessEmail(supabase: any, tenantId: string, transactionId: string, paymentId: string, amount: number) {
  try {
    // Get tenant details
    const { data: tenant } = await supabase
      .from('tenants')
      .select('business_name, owner_name, email')
      .eq('id', tenantId)
      .single()

    if (!tenant) {
      console.error('Tenant not found for payment email')
      return
    }

    // Call send-email edge function
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        to: tenant.email,
        subject: '✓ Payment Successful - LifeSprout',
        template: 'payment_success',
        template_data: {
          customer_name: tenant.owner_name || tenant.business_name,
          transaction_id: transactionId,
          payment_id: paymentId,
          payment_date: new Date().toLocaleDateString('en-IN'),
          description: 'LifeSprout Subscription Payment',
          amount: amount.toFixed(2),
        },
      }),
    })

    console.log('Payment success email sent to:', tenant.email)
  } catch (error) {
    console.error('Error sending payment email:', error)
    // Don't throw - email failure shouldn't block payment processing
  }
}
