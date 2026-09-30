// Supabase Edge Function: Send Email
// This function sends transactional emails using Resend API

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || ''
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@lifesprout.com'

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify authentication (use service role for internal calls)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    // Allow service role calls without user auth (for webhook triggers)
    const isServiceRole = req.headers.get('Authorization')?.includes(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '')

    if (!user && !isServiceRole) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { to, subject, html, template, template_data } = await req.json()

    if (!to || !subject) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to, subject' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build email content
    let emailHtml = html || ''
    
    if (template) {
      emailHtml = buildEmailTemplate(template, template_data || {})
    }

    // Send email via Resend API
    const emailData = {
      from: FROM_EMAIL,
      to: Array.isArray(to) ? to : [to],
      subject: subject,
      html: emailHtml,
    }

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify(emailData),
    })

    if (!resendResponse.ok) {
      const errorData = await resendResponse.json()
      console.error('Resend API error:', errorData)
      return new Response(
        JSON.stringify({ error: 'Failed to send email', details: errorData }),
        { status: resendResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const result = await resendResponse.json()

    return new Response(
      JSON.stringify({
        success: true,
        email_id: result.id,
        message: 'Email sent successfully',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in send-email:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Build email templates
function buildEmailTemplate(templateName: string, data: any): string {
  switch (templateName) {
    case 'subscription_activated':
      return subscriptionActivatedTemplate(data)
    case 'subscription_expiring':
      return subscriptionExpiringTemplate(data)
    case 'payment_success':
      return paymentSuccessTemplate(data)
    case 'demo_request_confirmation':
      return demoRequestConfirmationTemplate(data)
    case 'welcome':
      return welcomeTemplate(data)
    default:
      return '<p>No template found</p>'
  }
}

function subscriptionActivatedTemplate(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .plan-card { background: white; border: 2px solid #4CAF50; border-radius: 8px; padding: 20px; margin: 20px 0; }
    .feature-list { list-style: none; padding: 0; }
    .feature-list li { padding: 8px 0; padding-left: 24px; position: relative; }
    .feature-list li:before { content: "✓"; position: absolute; left: 0; color: #4CAF50; font-weight: bold; }
    .button { display: inline-block; background: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 Welcome to ${data.plan_name || 'LifeSprout'}!</h1>
      <p>Your subscription is now active</p>
    </div>
    <div class="content">
      <p>Hello ${data.customer_name || 'there'},</p>
      
      <p>Great news! Your ${data.plan_name || 'subscription'} plan has been successfully activated.</p>
      
      <div class="plan-card">
        <h2>${data.plan_name || 'Your Plan'}</h2>
        <p><strong>Billing Cycle:</strong> ${data.billing_cycle || 'Monthly'}</p>
        <p><strong>Amount Paid:</strong> ₹${data.amount_paid || '0'}</p>
        <p><strong>Valid Until:</strong> ${data.valid_until || 'N/A'}</p>
        
        ${data.features ? `
        <h3>Your Plan Includes:</h3>
        <ul class="feature-list">
          ${data.features.map((f: string) => `<li>${f}</li>`).join('')}
        </ul>
        ` : ''}
      </div>
      
      <p><strong>What's Next?</strong></p>
      <ul>
        <li>Log in to your dashboard to start using all features</li>
        <li>Set up your branches and add team members</li>
        <li>Import your product inventory</li>
        <li>Start billing customers with ease</li>
      </ul>
      
      <a href="${data.dashboard_url || 'https://app.lifesprout.com'}" class="button">Go to Dashboard</a>
      
      <p>If you have any questions or need help getting started, our support team is here to help.</p>
      
      <p>Best regards,<br>The LifeSprout Team</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} LifeSprout. All rights reserved.</p>
      <p>Questions? Email us at support@lifesprout.com</p>
    </div>
  </div>
</body>
</html>
  `
}

function paymentSuccessTemplate(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #4CAF50; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .receipt { background: white; border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin: 20px 0; }
    .receipt-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .total { font-size: 18px; font-weight: bold; color: #4CAF50; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✓ Payment Successful</h1>
      <p>Thank you for your payment</p>
    </div>
    <div class="content">
      <p>Hello ${data.customer_name || 'there'},</p>
      
      <p>We've received your payment successfully. Here are your payment details:</p>
      
      <div class="receipt">
        <h3>Payment Receipt</h3>
        <div class="receipt-row">
          <span>Transaction ID:</span>
          <span>${data.transaction_id || 'N/A'}</span>
        </div>
        <div class="receipt-row">
          <span>Payment ID:</span>
          <span>${data.payment_id || 'N/A'}</span>
        </div>
        <div class="receipt-row">
          <span>Date:</span>
          <span>${data.payment_date || new Date().toLocaleDateString()}</span>
        </div>
        <div class="receipt-row">
          <span>Description:</span>
          <span>${data.description || 'Subscription Payment'}</span>
        </div>
        <div class="receipt-row total">
          <span>Amount Paid:</span>
          <span>₹${data.amount || '0'}</span>
        </div>
      </div>
      
      <p>Your subscription will be activated shortly. You'll receive a confirmation email once it's ready.</p>
      
      <p>Best regards,<br>The LifeSprout Team</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} LifeSprout. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

function subscriptionExpiringTemplate(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #ff9800; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .button { display: inline-block; background: #ff9800; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⏰ Subscription Expiring Soon</h1>
    </div>
    <div class="content">
      <p>Hello ${data.customer_name || 'there'},</p>
      
      <p>Your ${data.plan_name || 'subscription'} plan will expire in ${data.days_remaining || 'a few'} days.</p>
      
      <p><strong>Expiry Date:</strong> ${data.expiry_date || 'N/A'}</p>
      
      <p>Don't let your subscription lapse! Renew now to continue enjoying uninterrupted access to all features.</p>
      
      <a href="${data.renewal_url || 'https://app.lifesprout.com/subscription'}" class="button">Renew Now</a>
      
      <p>If you have any questions, please don't hesitate to contact us.</p>
      
      <p>Best regards,<br>The LifeSprout Team</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} LifeSprout. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

function demoRequestConfirmationTemplate(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #2196F3; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📞 Demo Request Received</h1>
    </div>
    <div class="content">
      <p>Hello ${data.name || 'there'},</p>
      
      <p>Thank you for requesting a demo of LifeSprout! We're excited to show you how our platform can transform your pharmacy management.</p>
      
      <p>Our team will reach out to you within 24-48 hours to schedule a personalized demo at your convenience.</p>
      
      <p><strong>Your Contact Details:</strong></p>
      <ul>
        <li>Email: ${data.email || 'N/A'}</li>
        <li>Phone: ${data.phone || 'N/A'}</li>
        ${data.business_name ? `<li>Business: ${data.business_name}</li>` : ''}
      </ul>
      
      <p>In the meantime, feel free to explore our features on our website.</p>
      
      <p>Best regards,<br>The LifeSprout Team</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} LifeSprout. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

function welcomeTemplate(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .button { display: inline-block; background: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Welcome to LifeSprout! 🌱</h1>
    </div>
    <div class="content">
      <p>Hello ${data.name || 'there'},</p>
      
      <p>Welcome to LifeSprout - your smart pharmacy management solution!</p>
      
      <p>We're thrilled to have you on board. Here's what you can do next:</p>
      
      <ol>
        <li>Complete your business profile</li>
        <li>Set up your first branch</li>
        <li>Add your team members</li>
        <li>Start managing your inventory</li>
      </ol>
      
      <a href="${data.dashboard_url || 'https://app.lifesprout.com'}" class="button">Get Started</a>
      
      <p>If you need any help, our support team is always here for you.</p>
      
      <p>Best regards,<br>The LifeSprout Team</p>
    </div>
    <div class="footer">
      <p>© ${new Date().getFullYear()} LifeSprout. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}
