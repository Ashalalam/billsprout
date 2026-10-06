// ============================================================================
// Supabase Edge Function: Protected Software Download
// ============================================================================
// This function generates authorized download URLs for Business Admins
// based on their subscription and access status
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
    // Create Supabase client with auth
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get user's tenant_id and role
    const { data: userData, error: userError } = await supabaseClient
      .from('users')
      .select('tenant_id, role, name')
      .eq('id', user.id)
      .single()

    if (userError || !userData) {
      return new Response(
        JSON.stringify({ error: 'User data not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Only Business Admin can download
    if (userData.role !== 'business_admin' && userData.role !== 'super_admin') {
      return new Response(
        JSON.stringify({ error: 'Access denied. Only Business Admins can download software.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const tenantId = userData.tenant_id

    if (!tenantId) {
      return new Response(
        JSON.stringify({ error: 'No business associated with this account' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { version_id, platform } = await req.json()

    if (!version_id) {
      return new Response(
        JSON.stringify({ error: 'version_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check download authorization
    const { data: authData, error: authCheckError } = await supabaseClient.rpc(
      'get_download_authorization',
      { p_tenant_id: tenantId }
    )

    if (authCheckError) {
      console.error('Authorization check error:', authCheckError)
      return new Response(
        JSON.stringify({ error: 'Failed to check authorization' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const authorization = authData[0]

    // If not authorized, log the attempt and deny
    if (!authorization.can_download) {
      // Log failed download attempt
      await supabaseClient.from('download_logs').insert({
        tenant_id: tenantId,
        user_id: user.id,
        version_id: version_id,
        platform: platform || 'Unknown',
        was_authorized: false,
        failure_reason: authorization.reason,
        ip_address: req.headers.get('x-forwarded-for') || 'unknown',
        user_agent: req.headers.get('user-agent') || 'unknown',
      })

      return new Response(
        JSON.stringify({
          error: 'Download not authorized',
          reason: authorization.reason,
          subscription_status: authorization.subscription_status,
          license_status: authorization.license_status,
          access_status: authorization.access_status,
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get software version details
    const { data: versionData, error: versionError } = await supabaseClient
      .from('software_versions')
      .select('*')
      .eq('id', version_id)
      .eq('status', 'active')
      .single()

    if (versionError || !versionData) {
      return new Response(
        JSON.stringify({ error: 'Software version not found or inactive' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if file exists in storage
    if (!versionData.file_path) {
      return new Response(
        JSON.stringify({ error: 'Download file not available' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client for storage access
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Generate signed URL (valid for 1 hour)
    const { data: signedUrlData, error: urlError } = await supabaseAdmin.storage
      .from('software')
      .createSignedUrl(versionData.file_path, 3600)

    if (urlError || !signedUrlData) {
      console.error('Failed to generate download URL:', urlError)
      return new Response(
        JSON.stringify({ error: 'Failed to generate download URL' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log successful download
    await supabaseClient.from('download_logs').insert({
      tenant_id: tenantId,
      user_id: user.id,
      version_id: version_id,
      platform: platform || versionData.platform,
      was_authorized: true,
      ip_address: req.headers.get('x-forwarded-for') || 'unknown',
      user_agent: req.headers.get('user-agent') || 'unknown',
    })

    // Increment download count
    await supabaseAdmin
      .from('software_versions')
      .update({ download_count: versionData.download_count + 1 })
      .eq('id', version_id)

    console.log(
      `Authorized download for ${userData.name} (${user.email}) - ${versionData.software_name} v${versionData.version_number}`
    )

    return new Response(
      JSON.stringify({
        success: true,
        download_url: signedUrlData.signedUrl,
        software_name: versionData.software_name,
        version: versionData.version_number,
        platform: versionData.platform,
        file_size_mb: versionData.file_size_mb,
        expires_in: 3600, // 1 hour
        message: 'Download authorized. URL valid for 1 hour.',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in download-software:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
