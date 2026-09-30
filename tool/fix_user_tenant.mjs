#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixUserTenant() {
  try {
    console.log('🔍 Checking user and tenant data...\n');

    // 1. Check if admin user exists
    const userEmail = 'admin@lifesproutcare.com';
    const { data: authUser, error: authError } = await supabase.auth.admin.listUsers();
    
    if (authError) {
      console.error('❌ Error fetching users:', authError.message);
      return;
    }

    const user = authUser.users.find(u => u.email === userEmail);
    if (!user) {
      console.error(`❌ User ${userEmail} not found`);
      return;
    }

    console.log(`✅ Found user: ${user.email}`);
    console.log(`   User ID: ${user.id}\n`);

    // 2. Check if tenant exists
    const { data: tenants, error: tenantError } = await supabase
      .from('tenants')
      .select('*')
      .limit(5);

    if (tenantError) {
      console.error('❌ Error fetching tenants:', tenantError.message);
      return;
    }

    let tenantId;

    if (tenants && tenants.length > 0) {
      // Use existing tenant
      tenantId = tenants[0].id;
      console.log(`✅ Found existing tenant: ${tenants[0].business_name}`);
      console.log(`   Tenant ID: ${tenantId}\n`);
    } else {
      // Create a new tenant
      console.log('📝 No tenants found. Creating default tenant...\n');
      
      const { data: newTenant, error: createError } = await supabase
        .from('tenants')
        .insert({
          business_name: 'LifeSprout Admin Pharmacy',
          owner_name: 'Admin',
          email: userEmail,
          phone: '9999999999',
          industry_type: 'pharmacy',
          business_mode: 'retail',
          subscription_plan: 'trial',
          subscription_status: 'active',
          is_active: true,
        })
        .select()
        .single();

      if (createError) {
        console.error('❌ Error creating tenant:', createError.message);
        return;
      }

      tenantId = newTenant.id;
      console.log(`✅ Created new tenant: ${newTenant.business_name}`);
      console.log(`   Tenant ID: ${tenantId}\n`);
    }

    // 3. Check if user profile exists
    const { data: existingProfile, error: profileCheckError } = await supabase
      .from('users')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    if (profileCheckError) {
      console.error('❌ Error checking user profile:', profileCheckError.message);
      return;
    }

    if (existingProfile) {
      // Update existing profile with tenant_id
      console.log('📝 Updating existing user profile with tenant_id...\n');
      
      const { error: updateError } = await supabase
        .from('users')
        .update({ tenant_id: tenantId })
        .eq('id', user.id);

      if (updateError) {
        console.error('❌ Error updating user profile:', updateError.message);
        return;
      }

      console.log(`✅ Updated user profile with tenant_id: ${tenantId}`);
    } else {
      // Create new profile
      console.log('📝 Creating user profile with tenant_id...\n');
      
      const { error: insertError } = await supabase
        .from('users')
        .insert({
          id: user.id,
          tenant_id: tenantId,
          email: user.email,
          name: user.email.split('@')[0],
          role: 'business_admin',
          is_active: true,
        });

      if (insertError) {
        console.error('❌ Error creating user profile:', insertError.message);
        return;
      }

      console.log(`✅ Created user profile with tenant_id: ${tenantId}`);
    }

    // 4. Verify the fix
    const { data: verifyProfile, error: verifyError } = await supabase
      .from('users')
      .select('id, email, tenant_id, role')
      .eq('id', user.id)
      .single();

    if (verifyError) {
      console.error('❌ Error verifying fix:', verifyError.message);
      return;
    }

    console.log('\n✅ ✅ ✅ FIX COMPLETE! ✅ ✅ ✅\n');
    console.log('User Profile:');
    console.log(`  Email: ${verifyProfile.email}`);
    console.log(`  User ID: ${verifyProfile.id}`);
    console.log(`  Tenant ID: ${verifyProfile.tenant_id}`);
    console.log(`  Role: ${verifyProfile.role}`);
    console.log('\n🎉 Now restart the Flutter app and try the payment again!');
    console.log('   Press "r" in the Flutter terminal to hot reload');
    console.log('   Or go back and re-login to refresh your session');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

fixUserTenant();
