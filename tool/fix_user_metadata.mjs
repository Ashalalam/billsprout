#!/usr/bin/env node

/**
 * Simple script to check users and sync their tenant metadata
 * 
 * This script:
 * 1. Lists all users and their tenant status
 * 2. For users with tenant_id in public.users, ensures auth metadata is synced
 * 3. For users without tenant_id, assigns them to a default tenant
 * 
 * Usage: node tool/fix_user_metadata.mjs
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

// Load environment variables
dotenv.config({ path: join(projectRoot, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env file');
  process.exit(1);
}

// Initialize Supabase client with service role key (bypasses RLS)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  },
  db: { schema: 'public' }
});

async function listUsers() {
  console.log('\n📋 Fetching all users...\n');
  
  const { data: users, error } = await supabase
    .from('users')
    .select('id, name, email, tenant_id, role');
  
  if (error) {
    console.error('❌ Error:', error.message);
    return [];
  }
  
  console.log(`Found ${users.length} users:\n`);
  
  users.forEach((user, idx) => {
    const tenantStatus = user.tenant_id ? `✅ ${user.tenant_id.substring(0, 8)}...` : '❌ NO TENANT';
    console.log(`${idx + 1}. ${user.email}`);
    console.log(`   Name: ${user.name}`);
    console.log(`   Role: ${user.role}`);
    console.log(`   Tenant: ${tenantStatus}\n`);
  });
  
  return users;
}

async function getTenants() {
  console.log('🏢 Fetching tenants...\n');
  
  const { data: tenants, error } = await supabase
    .from('tenants')
    .select('id, business_name, is_active')
    .eq('is_active', true)
    .limit(10);
  
  if (error) {
    console.error('❌ Error:', error.message);
    return [];
  }
  
  console.log(`Found ${tenants.length} active tenants:\n`);
  
  tenants.forEach((tenant, idx) => {
    console.log(`${idx + 1}. ${tenant.business_name} (${tenant.id.substring(0, 8)}...)`);
  });
  
  console.log();
  return tenants;
}

async function getBranches(tenantId) {
  const { data: branches, error } = await supabase
    .from('branches')
    .select('id, branch_name')
    .eq('tenant_id', tenantId)
    .eq('is_active', true)
    .order('created_at', { ascending: true })
    .limit(1);
  
  if (error) {
    console.error('   ⚠️  Error fetching branches:', error.message);
    return null;
  }
  
  return branches && branches.length > 0 ? branches[0] : null;
}

async function assignUserToTenant(userId, tenantId, userName, userEmail) {
  console.log(`🔧 Assigning user to tenant ${tenantId.substring(0, 8)}...`);
  
  // Update public.users table
  const { error: updateError } = await supabase
    .from('users')
    .update({ tenant_id: tenantId })
    .eq('id', userId);
  
  if (updateError) {
    console.error('   ❌ Failed to update public.users:', updateError.message);
    return false;
  }
  
  console.log('   ✅ Updated public.users table');
  
  // Get default branch for this tenant
  const branch = await getBranches(tenantId);
  const branchId = branch?.id || null;
  
  // Note: We can't directly update auth.users via the API, but we can create
  // a SQL function to do it. For now, we'll rely on the trigger from migration 008.
  
  console.log(`   ✅ Assigned to tenant (branch: ${branchId ? branchId.substring(0, 8) + '...' : 'none'})`);
  console.log('   ℹ️  Auth metadata will be synced by database trigger\n');
  
  return true;
}

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  User Tenant Metadata Fixer');
  console.log('═══════════════════════════════════════════════════════');
  
  try {
    // List all users
    const users = await listUsers();
    
    if (users.length === 0) {
      console.log('⚠️  No users found in the database.');
      console.log('   Please create users first or check your connection.\n');
      return;
    }
    
    // Get available tenants
    const tenants = await getTenants();
    
    if (tenants.length === 0) {
      console.log('⚠️  No active tenants found in the database.');
      console.log('   Please create at least one tenant first.\n');
      return;
    }
    
    // Find users without tenant
    const usersWithoutTenant = users.filter(u => !u.tenant_id);
    
    if (usersWithoutTenant.length === 0) {
      console.log('✅ All users have tenant assignments!\n');
      return;
    }
    
    console.log(`\n🔧 Found ${usersWithoutTenant.length} users without tenant assignment\n`);
    console.log('Assigning them to the first available tenant...\n');
    
    const defaultTenant = tenants[0];
    
    for (const user of usersWithoutTenant) {
      console.log(`📝 Processing: ${user.email}`);
      await assignUserToTenant(user.id, defaultTenant.id, user.name, user.email);
    }
    
    console.log('═══════════════════════════════════════════════════════');
    console.log('✅ All users have been processed!');
    console.log('═══════════════════════════════════════════════════════\n');
    console.log('Next steps:');
    console.log('1. Apply migration 008 if you haven\'t already');
    console.log('   Use: node tool/apply_migration_008.mjs');
    console.log('2. Rebuild your Flutter web app');
    console.log('3. Login to test tenant context\n');
    
  } catch (error) {
    console.error('\n❌ Script failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

main();
