// ============================================================================
// Supabase Edge Function: Notify Demo Request
// ============================================================================
// This function sends demo request notifications to arifsheik@lifesproutcare.com
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || ''
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@lifesproutcare.com'
const DEMO_RECIPIENT = 'arifsheik@lifesproutcare.com'

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
    // Parse request body
    const {
      name,
      email,
      mobile,
      businessName,
      city,
      pincode,
      businessType,
      numBranches,
      message,
    } = await req.json()

    // Validate required fields
    if (!name || !mobile) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: name, mobile' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build email subject
    const subject = `🆕 New BillSprout Demo Request - ${name}`

    // Build email HTML
    const emailHtml = buildDemoNotificationEmail({
      name,
      email,
      mobile,
      businessName,
      city,
      pincode,
      businessType,
      numBranches,
      message,
      requestedAt: new Date().toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      }),
    })

    // Prepare email data
    const emailData = {
      from: FROM_EMAIL,
      to: [DEMO_RECIPIENT],
      reply_to: email || undefined, // Use requester's email as reply-to if provided
      subject: subject,
      html: emailHtml,
    }

    // Send email via Resend API
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
        JSON.stringify({ 
          error: 'Failed to send notification email', 
          details: errorData 
        }),
        { 
          status: resendResponse.status, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const result = await resendResponse.json()

    console.log(`Demo request notification sent to ${DEMO_RECIPIENT} for ${name}`)

    return new Response(
      JSON.stringify({
        success: true,
        email_id: result.id,
        message: 'Demo request notification sent successfully',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in notify-demo-request:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

// Build demo notification email HTML
function buildDemoNotificationEmail(data: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      line-height: 1.6; 
      color: #333; 
      margin: 0;
      padding: 0;
    }
    .container { 
      max-width: 650px; 
      margin: 20px auto; 
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      overflow: hidden;
    }
    .header { 
      background: linear-gradient(135deg, #1976D2 0%, #1565C0 100%);
      color: white; 
      padding: 30px; 
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 600;
    }
    .content { 
      padding: 30px; 
    }
    .section {
      background: #f8f9fa;
      border-left: 4px solid #1976D2;
      padding: 20px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .section-title {
      font-size: 16px;
      font-weight: 600;
      color: #1976D2;
      margin-bottom: 12px;
    }
    .field {
      display: flex;
      padding: 8px 0;
      border-bottom: 1px solid #e0e0e0;
    }
    .field:last-child {
      border-bottom: none;
    }
    .field-label {
      font-weight: 600;
      width: 180px;
      color: #555;
    }
    .field-value {
      flex: 1;
      color: #333;
      word-break: break-word;
    }
    .message-box {
      background: #fff;
      border: 1px solid #e0e0e0;
      border-radius: 4px;
      padding: 15px;
      margin-top: 10px;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .highlight {
      background: #fff3cd;
      padding: 15px;
      border-left: 4px solid #ffc107;
      margin: 20px 0;
      border-radius: 4px;
    }
    .footer { 
      background: #f8f9fa;
      text-align: center; 
      padding: 20px; 
      color: #666; 
      font-size: 13px;
      border-top: 1px solid #e0e0e0;
    }
    .badge {
      display: inline-block;
      background: #1976D2;
      color: white;
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 600;
      margin-right: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🆕 NEW DEMO REQUEST</h1>
      <p style="margin: 10px 0 0 0; opacity: 0.9;">BillSprout Pharmacy ERP</p>
    </div>
    
    <div class="content">
      <div class="highlight">
        <strong>⏰ Action Required:</strong> A potential customer has requested a demo of BillSprout. Please reach out within 24-48 hours.
      </div>

      <div class="section">
        <div class="section-title">📋 Contact Information</div>
        
        <div class="field">
          <div class="field-label">Name:</div>
          <div class="field-value"><strong>${data.name}</strong></div>
        </div>
        
        <div class="field">
          <div class="field-label">Mobile:</div>
          <div class="field-value"><strong><a href="tel:${data.mobile}">${data.mobile}</a></strong></div>
        </div>
        
        ${data.email ? `
        <div class="field">
          <div class="field-label">Email:</div>
          <div class="field-value"><a href="mailto:${data.email}">${data.email}</a></div>
        </div>
        ` : ''}
      </div>

      <div class="section">
        <div class="section-title">🏢 Business Details</div>
        
        ${data.businessName ? `
        <div class="field">
          <div class="field-label">Business Name:</div>
          <div class="field-value"><strong>${data.businessName}</strong></div>
        </div>
        ` : ''}
        
        <div class="field">
          <div class="field-label">Business Type:</div>
          <div class="field-value">${data.businessType || 'Not specified'}</div>
        </div>
        
        <div class="field">
          <div class="field-label">Number of Branches:</div>
          <div class="field-value"><span class="badge">${data.numBranches || 1}</span></div>
        </div>
        
        ${data.city || data.pincode ? `
        <div class="field">
          <div class="field-label">Location:</div>
          <div class="field-value">${[data.city, data.pincode].filter(Boolean).join(', ')}</div>
        </div>
        ` : ''}
      </div>

      ${data.message ? `
      <div class="section">
        <div class="section-title">💬 Message / Requirements</div>
        <div class="message-box">${data.message}</div>
      </div>
      ` : ''}

      <div class="section">
        <div class="section-title">📅 Request Details</div>
        
        <div class="field">
          <div class="field-label">Requested At:</div>
          <div class="field-value">${data.requestedAt}</div>
        </div>
        
        <div class="field">
          <div class="field-label">Source:</div>
          <div class="field-value">BillSprout Website - Demo Request Form</div>
        </div>
      </div>

      <div class="highlight" style="background: #e8f5e9; border-left-color: #4caf50; margin-top: 30px;">
        <strong>✅ Next Steps:</strong>
        <ol style="margin: 10px 0 0 0; padding-left: 20px;">
          <li>Contact ${data.name} at ${data.mobile}${data.email ? ` or ${data.email}` : ''}</li>
          <li>Schedule a personalized demo at their convenience</li>
          <li>Understand their specific requirements and pain points</li>
          <li>Showcase relevant BillSprout features for their business</li>
        </ol>
      </div>
    </div>
    
    <div class="footer">
      <p><strong>BillSprout by LifeSprout Care</strong></p>
      <p>Smart ERP & Billing System for Pharmacies</p>
      <p style="margin-top: 10px; font-size: 12px; color: #999;">
        This email was automatically generated by the BillSprout demo request system.<br>
        ${data.email ? 'You can reply directly to this email to reach the requester.' : 'Contact the requester via phone as no email was provided.'}
      </p>
    </div>
  </div>
</body>
</html>
  `
}
