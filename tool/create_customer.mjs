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

async function createCustomer() {
  try {
    console.log('🔧 Creating Customer user...\n');

    const email = 'customer@lifesprout.com';
    const password = 'Customer@123';

    // 1. Get the existing tenant (we'll use the first one)
    const { data: tenants, error: tenantError } = await supabase
      .from('tenants')
      .select('id, business_name')
      .limit(1);

    if (tenantError || !tenants || tenants.length === 0) {
      console.error('❌ No tenant found. Please create a tenant first.');
      return;
    }

    const tenantId = tenants[0].id;
    console.log(`✅ Using tenant: ${tenants[0].business_name}`);
    console.log(`   Tenant ID: ${tenantId}\n`);

    // 2. Create auth user
    console.log('📝 Step 1: Creating authentication user...');
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true,
    });

    if (authError) {
      console.error('❌ Error creating auth user:', authError.message);
      return;
    }

    const userId = authData.user.id;
    console.log(`✅ Auth user created: ${email}`);
    console.log(`   User ID: ${userId}\n`);

    // 3. Create user profile with customer role
    console.log('📝 Step 2: Creating customer profile...');
    
    const { error: profileError } = await supabase
      .from('users')
      .insert({
        id: userId,
        tenant_id: tenantId,
        email: email,
        name: 'Rajesh Kumar',
        phone: '9876543210',
        role: 'customer',
        is_active: true,
      });

    if (profileError) {
      console.error('❌ Error creating customer profile:', profileError.message);
      return;
    }

    console.log(`✅ Customer profile created\n`);

    // 4. Verify the user
    const { data: verifyProfile, error: verifyError } = await supabase
      .from('users')
      .select('id, email, name, role, tenant_id')
      .eq('id', userId)
      .single();

    if (verifyError) {
      console.error('❌ Error verifying profile:', verifyError.message);
      return;
    }

    console.log('✅ ✅ ✅ CUSTOMER CREATED! ✅ ✅ ✅\n');
    console.log('Customer Login Credentials:');
    console.log(`  Email: ${email}`);
    console.log(`  Password: ${password}`);
    console.log(`  Name: ${verifyProfile.name}`);
    console.log(`  Role: ${verifyProfile.role}`);
    console.log(`  User ID: ${verifyProfile.id}`);
    console.log(`  Tenant ID: ${verifyProfile.tenant_id}`);
    console.log('\n🎉 You can now logout and login with these credentials!');
    console.log('   Customer portal allows viewing purchase history, orders, etc.');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

createCustomer();
