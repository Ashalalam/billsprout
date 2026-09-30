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

async function createSuperAdmin() {
  try {
    console.log('🔧 Creating Super Admin user...\n');

    const email = 'superadmin@lifesprout.com';
    const password = 'SuperAdmin@123';

    // 1. Create auth user
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

    // 2. Create user profile with super_admin role
    console.log('📝 Step 2: Creating user profile with super_admin role...');
    
    const { error: profileError } = await supabase
      .from('users')
      .insert({
        id: userId,
        tenant_id: null, // Super admin has no tenant - can access all tenants
        email: email,
        name: 'Super Admin',
        role: 'super_admin',
        is_active: true,
      });

    if (profileError) {
      console.error('❌ Error creating user profile:', profileError.message);
      return;
    }

    console.log(`✅ User profile created with super_admin role\n`);

    // 3. Verify the user
    const { data: verifyProfile, error: verifyError } = await supabase
      .from('users')
      .select('id, email, role, tenant_id')
      .eq('id', userId)
      .single();

    if (verifyError) {
      console.error('❌ Error verifying profile:', verifyError.message);
      return;
    }

    console.log('✅ ✅ ✅ SUPER ADMIN CREATED! ✅ ✅ ✅\n');
    console.log('Super Admin Credentials:');
    console.log(`  Email: ${email}`);
    console.log(`  Password: ${password}`);
    console.log(`  Role: ${verifyProfile.role}`);
    console.log(`  User ID: ${verifyProfile.id}`);
    console.log(`  Tenant ID: ${verifyProfile.tenant_id || 'None (Global Access)'}`);
    console.log('\n🎉 You can now logout and login with these credentials!');
    console.log('   Super Admin can access ALL tenants and system settings.');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

createSuperAdmin();
